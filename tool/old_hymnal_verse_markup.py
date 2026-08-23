#!/usr/bin/env python3
"""Give the Old Hymnal the New Hymnal's verse and chorus markup.

The Old Hymnal's 703 bodies (inherited from the 2016 app) are bare lyric
lines: stanzas separated by a blank line, the refrain introduced by a line
that just says "Refrain". The New Hymnal's bodies carry
`<font color="#0B6138"><b>N</b></font>` verse markers and an
`<i><b><font color="#CD9B1D">CHORUS:</font></b> ... </i>` chorus block, which
the reader styles. This derives the same markup for the Old Hymnal from its
stanza structure, so both hymnals read alike. Idempotent: bodies that
already carry markers are left alone.

Run from the repo root:  python3 tool/old_hymnal_verse_markup.py
"""
import json, re, sys, collections

PATH = 'assets/hymns.json'
VERSE = '<font color="#0B6138"><b>{n}</b></font><br>\n'
CHORUS_OPEN = '<i><b><font color="#CD9B1D">CHORUS:</font></b><br>\n'
CHORUS_CLOSE = '</i><br>\n'
LABEL = re.compile(r'^\(?(refrain|chorus)[:.]?\)?$', re.I)
MARKER = re.compile(r'<b>\s*\d+\s*</b>')

def stanzas(body):
    """Blank-line-separated groups of lyric lines, `<br>` prefixes stripped."""
    out = [[]]
    for line in body.split('\n'):
        text = re.sub(r'^\s*<br>\s*', '', line).strip()
        if text == '':
            out.append([])
        else:
            out[-1].append(text)
    return [s for s in out if s]

def blocks_of(st):
    """(kind, lines) blocks: verses, and chorus blocks from a stanza whose
    first line is the Refrain label (or a lone label followed by its text).
    A lone label whose next stanza is NOT the already-seen chorus text is a
    reminder to sing the refrain again (hymn 103) and is dropped; a repeated
    full chorus is dropped too — the hymnal prints a refrain once."""
    blocks = []
    chorus_text = None
    i = 0
    while i < len(st):
        s = st[i]
        if LABEL.match(s[0]):
            if len(s) > 1:
                text = s[1:]
            elif i + 1 < len(st) and (chorus_text is None or st[i + 1] == chorus_text):
                text = st[i + 1]
                i += 1
            else:
                i += 1
                continue  # a reminder label: the refrain was printed already
            if chorus_text is None:
                chorus_text = text
                blocks.append(('chorus', text))
            elif text != chorus_text:
                blocks.append(('chorus', text))  # a genuinely different refrain
        else:
            blocks.append(('verse', s))
        i += 1
    return blocks

def render(blocks):
    out = []
    n = 0
    for kind, lines in blocks:
        if kind == 'verse':
            n += 1
            out.append(VERSE.format(n=n) + ''.join(l + '<br>\n' for l in lines))
        else:
            out.append(CHORUS_OPEN + ''.join(l + '<br>\n' for l in lines) + CHORUS_CLOSE)
    return '<br>\n'.join(out)

# Hand repairs for records the generic rules cannot read.
def repair(h):
    body = h['body']
    if h['number'] == 477:
        # No line breaks at all in the source, and the last two lines fused;
        # the hymn is four four-line verses.
        lines = [l.strip() for l in body.split('\n') if l.strip()]
        lines = lines[:-1] + [l.strip() for l in re.split(r',(?=We do it)', lines[-1])]
        lines[-2] += ','
        assert len(lines) == 16, lines
        body = '\n<br>\n'.join('\n<br>'.join(lines[i:i + 4]) for i in range(0, 16, 4))
    if h['number'] == 535:
        body = re.sub(r'</?div[^>]*>', '', body)
    return body

def main(write=True):
    raw = open(PATH, encoding='utf-8').read()
    data = json.loads(raw)
    report = collections.Counter()
    untouched = []
    for h in data['hymns']:
        if h['version'] != 'old' or MARKER.search(h['body']):
            continue
        body = repair(h)
        st = stanzas(body)
        if len(st) < 2:
            untouched.append(h['number'])
            continue
        blocks = blocks_of(st)
        verses = sum(1 for k, _ in blocks if k == 'verse')
        choruses = sum(1 for k, _ in blocks if k == 'chorus')
        report['converted'] += 1
        report[f'{verses} verses'] += 1
        if choruses:
            report['with a chorus'] += 1
            first_chorus = next(i for i, (k, _) in enumerate(blocks) if k == 'chorus')
            if first_chorus == 0:
                report['chorus before verse 1'] += 1
            elif first_chorus == len(blocks) - 1:
                report['chorus after the last verse'] += 1
        h['body'] = render(blocks)
    out = json.dumps(data, indent=1, ensure_ascii=False)
    if write:
        open(PATH, 'w', encoding='utf-8').write(out)
    print('converted:', report['converted'], '| untouched single-stanza:', untouched)
    for k in sorted(report):
        if k != 'converted':
            print(f'  {k}: {report[k]}')

if __name__ == '__main__':
    main(write='--dry-run' not in sys.argv)
