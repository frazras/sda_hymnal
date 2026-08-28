"""Native packaging checks that do not start a simulator or emulator."""
import hashlib
import json
from pathlib import Path
import struct
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class AppIconPackagingTests(unittest.TestCase):
    def test_artwork_matches_git_recovery_and_ios_packaging(self):
        # Derived once with restore_classic_icons.mjs --check. These also run
        # in shallow CI clones without requiring the historical Git object.
        for path, digest in {
            'assets/icon_classic.png': '7b20df3a802d47d267e9f8001b7a1a897df70e21fe598aa22436598c5ea4d611',
            'ios/Runner/Assets.xcassets/ClassicIcon.appiconset/Icon-App-1024x1024@1x.png': 'c5e6f4183a5299d4f58ed122d341c2f052f8455c6bb29ea0a24b6888be034bd6',
            'android/app/src/main/res/mipmap-xxxhdpi/launcher_classic.png': '8ab72fed8a4f300f0a7fd09d7a5104cb9b141db3df0f508f8e2757431db02a57',
        }.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)

    def test_classic_catalog_has_opaque_icons_at_every_declared_size(self):
        catalog = ROOT / 'ios/Runner/Assets.xcassets/ClassicIcon.appiconset'
        contents = json.loads((catalog / 'Contents.json').read_text())
        idioms = set()
        for icon in contents['images']:
            idioms.add(icon['idiom'])
            data = (catalog / icon['filename']).read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            size = float(icon['size'].split('x')[0]) * float(icon['scale'].removesuffix('x'))
            self.assertEqual(struct.unpack('>II', data[16:24]), (int(size), int(size)))
            self.assertEqual(data[25], 2, 'iOS app icons must be RGB, not RGBA')
        self.assertEqual(idioms, {'iphone', 'ipad', 'ios-marketing'})

    def test_ios_all_build_configurations_keep_modern_primary(self):
        project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        configurations = [block for block in re.findall(r'buildSettings = \{([^}]+)\}', project)
                          if 'PRODUCT_BUNDLE_IDENTIFIER = com.ionicframework.sdanewandoldhymnal816673;' in block]
        self.assertEqual(len(configurations), 3)
        for config in configurations:
            self.assertIn('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;', config)
            self.assertIn('ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = ClassicIcon;', config)

    def test_android_modern_default_keeps_existing_launcher_component(self):
        app = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot().find('application')
        activity = app.find('activity')
        self.assertEqual(activity.get(ANDROID + 'name'), '.HymnalActivity')
        self.assertIsNone(activity.find('intent-filter'))
        self.assertNotEqual(activity.get(ANDROID + 'enabled'), 'false')
        aliases = {alias.get(ANDROID + 'name'): alias for alias in app.findall('activity-alias')}
        self.assertEqual(set(aliases), {'.MainActivity', '.ClassicIcon'})
        for name, icon, enabled in [('.MainActivity', 'launcher_icon', 'true'),
                                    ('.ClassicIcon', 'launcher_classic', 'false')]:
            alias = aliases[name]
            self.assertEqual(alias.get(ANDROID + 'targetActivity'), '.HymnalActivity')
            self.assertEqual(alias.get(ANDROID + 'enabled'), enabled)
            self.assertEqual(alias.get(ANDROID + 'icon'), '@mipmap/' + icon)
            self.assertEqual(alias.get(ANDROID + 'exported'), 'true')
            self.assertEqual(alias.find('intent-filter/category').get(ANDROID + 'name'),
                             'android.intent.category.LAUNCHER')
            for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
                self.assertTrue((ROOT / f'android/app/src/main/res/mipmap-{density}/{icon}.png').is_file())


if __name__ == '__main__':
    unittest.main()
