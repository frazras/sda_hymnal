#!/usr/bin/env python3
"""Check complete message-key coverage; Flutter gen-l10n validates ICU syntax."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_catalog(path):
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'{path.name}: duplicate key {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique_pairs)


def validate(directory):
    source = load_catalog(directory / 'app_en.arb')
    expected = {key for key in source if not key.startswith('@')}
    for language in ('en', 'es', 'pt', 'ru'):
        path = directory / f'app_{language}.arb'
        messages = load_catalog(path)
        if messages.get('@@locale') != language:
            raise ValueError(f'{path.name}: wrong locale')
        actual = {key for key in messages if not key.startswith('@')}
        if actual != expected:
            raise ValueError(f'{path.name}: missing={sorted(expected-actual)}, extra={sorted(actual-expected)}')
        for key in expected:
            if not isinstance(messages[key], str) or not messages[key].strip():
                raise ValueError(f'{path.name}: empty or invalid message {key}')
            # The English template declares the arguments consumed by callers.
            # Order and plural branches may vary, but none may be silently lost.
            metadata = source.get(f'@{key}', {})
            for argument in metadata.get('placeholders', {}):
                pattern = r'\{\s*' + re.escape(argument) + r'\s*[,}]'
                if not re.search(pattern, messages[key]):
                    raise ValueError(f'{path.name}: {key} missing argument {argument}')
    return len(expected)


if __name__ == '__main__':
    print(f'Validated {validate(ROOT / "lib/l10n")} messages in four interface catalogs.')
