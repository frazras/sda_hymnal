#!/usr/bin/env python3
"""Check complete message-key coverage; Flutter gen-l10n validates ICU syntax."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate(directory):
    source = json.loads((directory / 'app_en.arb').read_text())
    expected = {key for key in source if not key.startswith('@')}
    for language in ('en', 'es', 'pt', 'ru'):
        path = directory / f'app_{language}.arb'
        messages = json.loads(path.read_text())
        if messages.get('@@locale') != language:
            raise ValueError(f'{path.name}: wrong locale')
        actual = {key for key in messages if not key.startswith('@')}
        if actual != expected:
            raise ValueError(f'{path.name}: missing={sorted(expected-actual)}, extra={sorted(actual-expected)}')
        for key in expected:
            if not isinstance(messages[key], str) or not messages[key].strip():
                raise ValueError(f'{path.name}: empty or invalid message {key}')
    return len(expected)


if __name__ == '__main__':
    print(f'Validated {validate(ROOT / "lib/l10n")} messages in four interface catalogs.')
