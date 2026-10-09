import json
import tempfile
import unittest
from pathlib import Path

from validate_translations import validate


class TranslationValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        for language in ('en', 'es', 'pt', 'ru'):
            self.write(language, {
                '@@locale': language,
                'title': '{number} · {title}',
                '@title': {'placeholders': {'number': {'type': 'int'}, 'title': {'type': 'String'}}},
                'count': '{count, plural, one{# hymn} other{# hymns}}',
                '@count': {'placeholders': {'count': {'type': 'int'}}},
            })

    def write(self, language, data):
        (self.directory / f'app_{language}.arb').write_text(json.dumps(data))

    def edit(self, language, key, value):
        path = self.directory / f'app_{language}.arb'
        data = json.loads(path.read_text())
        data[key] = value
        self.write(language, data)

    def test_reordered_arguments_and_locale_specific_plural_branches(self):
        self.edit('es', 'title', '{title} ({number})')
        self.edit('ru', 'count', '{count, plural, one{# гимн} few{# гимна} many{# гимнов} other{# гимна}}')
        self.assertEqual(validate(self.directory), 2)

    def test_missing_title_argument_fails_despite_matching_keys(self):
        self.edit('pt', 'title', '{title}')
        with self.assertRaisesRegex(ValueError, 'app_pt.arb: title missing argument number'):
            validate(self.directory)

    def test_plain_word_does_not_satisfy_an_argument(self):
        self.edit('es', 'title', 'number {title}')
        with self.assertRaisesRegex(ValueError, 'missing argument number'):
            validate(self.directory)

    def test_missing_plural_argument(self):
        self.edit('ru', 'count', 'Гимны')
        with self.assertRaisesRegex(ValueError, 'count missing argument count'):
            validate(self.directory)

    def test_duplicate_message_key_is_not_silently_overwritten(self):
        path = self.directory / 'app_es.arb'
        path.write_text(path.read_text().replace('"title":', '"title": "earlier", "title":', 1))
        with self.assertRaisesRegex(ValueError, 'app_es.arb: duplicate key title'):
            validate(self.directory)

    def test_empty_and_missing_keys_still_fail(self):
        self.edit('es', 'count', '')
        with self.assertRaisesRegex(ValueError, 'empty or invalid message count'):
            validate(self.directory)


if __name__ == '__main__':
    unittest.main()
