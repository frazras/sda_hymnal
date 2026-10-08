import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('translation_validator', ROOT/'tool/validate_translations.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)

class TranslationTest(unittest.TestCase):
    def test_catalogs_have_full_current_key_coverage(self):
        self.assertGreaterEqual(tool.validate(ROOT/'lib/l10n'), 59)

    def test_missing_empty_and_wrong_locale_are_rejected(self):
        for defect in ('missing','empty','locale'):
            with tempfile.TemporaryDirectory() as name:
                root = Path(name)
                for language in ('en','es','pt','ru'):
                    data = {'@@locale':language,'search':'Search'}
                    if language == 'es':
                        if defect == 'missing': del data['search']
                        if defect == 'empty': data['search']=' '
                        if defect == 'locale': data['@@locale']='en'
                    (root/f'app_{language}.arb').write_text(json.dumps(data))
                with self.assertRaises(ValueError): tool.validate(root)
