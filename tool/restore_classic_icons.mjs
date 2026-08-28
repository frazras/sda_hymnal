// Recover existing artwork; never regenerate the legacy logo.
// Run with --check in CI to verify provenance without rewriting files.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';
import { deflateSync, inflateSync } from 'node:zlib';

// Package the old iOS PNGs as RGB on their intended white background.
// Native app icons must be opaque; retain the original colors and geometry.
function opaqueRGB(png) {
  const chunks = [];
  for (let at = 8; at < png.length;) {
    const length = png.readUInt32BE(at);
    chunks.push({ type: png.toString('ascii', at + 4, at + 8), data: png.subarray(at + 8, at + 8 + length) });
    at += length + 12;
  }
  const header = Buffer.from(chunks.find(c => c.type === 'IHDR').data);
  if (header[9] === 2) return png;
  if (header[8] !== 8 || header[9] !== 6 || header[12] !== 0) throw Error('Expected non-interlaced RGBA8 icon');
  const width = header.readUInt32BE(0), height = header.readUInt32BE(4), stride = width * 4;
  const packed = inflateSync(Buffer.concat(chunks.filter(c => c.type === 'IDAT').map(c => c.data)));
  const pixels = Buffer.alloc(stride * height);
  const rgb = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) {
    const filter = packed[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const left = x >= 4 ? pixels[y * stride + x - 4] : 0;
      const up = y ? pixels[(y - 1) * stride + x] : 0;
      const corner = y && x >= 4 ? pixels[(y - 1) * stride + x - 4] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      else if (filter === 2) predictor = up;
      else if (filter === 3) predictor = Math.floor((left + up) / 2);
      else if (filter === 4) {
        const p = left + up - corner;
        const a = Math.abs(p - left), b = Math.abs(p - up), c = Math.abs(p - corner);
        predictor = a <= b && a <= c ? left : b <= c ? up : corner;
      } else if (filter !== 0) throw Error('Invalid PNG filter');
      pixels[y * stride + x] = (packed[y * (stride + 1) + x + 1] + predictor) & 255;
    }
    for (let x = 0; x < width; x++) {
      const source = y * stride + x * 4, target = y * (width * 3 + 1) + 1 + x * 3;
      const alpha = pixels[source + 3];
      for (let color = 0; color < 3; color++) {
        rgb[target + color] = Math.round((pixels[source + color] * alpha + 255 * (255 - alpha)) / 255);
      }
    }
  }
  const chunk = (type, data) => {
    const body = Buffer.concat([Buffer.from(type), data]);
    let crc = 0xffffffff;
    for (const byte of body) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
    const length = Buffer.alloc(4), checksum = Buffer.alloc(4);
    length.writeUInt32BE(data.length); checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
    return Buffer.concat([length, body, checksum]);
  };
  header[9] = 2;
  return Buffer.concat([
    png.subarray(0, 8), chunk('IHDR', header),
    ...chunks.filter(c => !['IHDR', 'IDAT', 'IEND'].includes(c.type)).map(c => chunk(c.type, c.type === 'sBIT' ? c.data.subarray(0, 3) : c.data)),
    chunk('IDAT', deflateSync(rgb)), chunk('IEND', Buffer.alloc(0)),
  ]);
}

const revision = '6a860f7';
const catalog = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const files = execFileSync('git', ['ls-tree', '-r', '--name-only', revision, catalog], { encoding: 'utf8' }).trim().split('\n');
const copies = [
  ['assets/icon.png', 'assets/icon_classic.png'],
  ...files.map(path => [path, path.replace('/AppIcon.appiconset/', '/ClassicIcon.appiconset/')]),
  ...['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'].map(density => [
    `android/app/src/main/res/mipmap-${density}/launcher_icon.png`,
    `android/app/src/main/res/mipmap-${density}/launcher_classic.png`,
  ]),
];
for (const [source, destination] of copies) {
  const original = execFileSync('git', ['show', `${revision}:${source}`], { maxBuffer: 10 * 1024 * 1024 });
  const output = source.startsWith('ios/') && source.endsWith('.png') ? opaqueRGB(original) : original;
  if (process.argv.includes('--check') || existsSync(destination)) {
    const existing = readFileSync(destination);
    if (!process.argv.includes('--check') && existing.equals(original) && !existing.equals(output)) {
      writeFileSync(destination, output);
    } else if (!existing.equals(output)) throw Error(`Classic icon differs: ${destination}`);
  } else {
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, output, { flag: 'wx' });
  }
}
console.log(`Verified ${copies.length} original icon files from ${revision} (iOS: opaque white background).`);
