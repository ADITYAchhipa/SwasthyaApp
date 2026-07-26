import re
import json
import os

dart_path = "/home/aditya/clones/Card/lib/utils/translation_service.dart"
ts_out_path = "/home/aditya/clones/Card/swasthyatap-next/src/lib/translations.ts"

with open(dart_path, 'r', encoding='utf-8') as f:
    content = f.read()

# We want to extract _localizedValues map.
# In dart, it is:
# static const Map<String, Map<String, String>> _localizedValues = {
#   'English': {
#     'key': 'value',
#     ...
#   },
#   'Hindi': { ... }
# };

# Let's find the start of _localizedValues
start_match = re.search(r'static const Map<String, Map<String, String>> _localizedValues = \{', content)
if not start_match:
    print("Could not find _localizedValues in Dart file")
    exit(1)

start_index = start_match.end()

# Let's parse the languages.
# We will match: 'LanguageName': { ... }
# Inside, we match 'key': 'value' or "key": "value"
# Let's do a simple brace counting/parsing or regex.

languages = {}
# Find all language blocks
# e.g., 'English': {
lang_blocks = re.findall(r"['\"]([a-zA-Z\s]+)['\"]\s*:\s*\{([^}]+)\}", content)

for lang, block in lang_blocks:
    lang = lang.strip()
    languages[lang] = {}
    # Find all key-values inside
    # e.g. 'key': 'value' or 'key': "value" or 'key': 'value\n...'
    kv_pairs = re.findall(r"['\"]([a-zA-Z0-9_]+)['\"]\s*:\s*['\"](.*?)['\"]\s*,", block)
    for k, v in kv_pairs:
        # Clean escape characters if any
        v_clean = v.replace("\\\\'", "'").replace("\\'", "'")
        languages[lang][k] = v_clean

# Write to typescript file
ts_content = f"""// Generated from Dart TranslationService
export const TRANSLATIONS: Record<string, Record<string, string>> = {json.dumps(languages, indent=2, ensure_ascii=False)};
"""

with open(ts_out_path, 'w', encoding='utf-8') as f:
    f.write(ts_content)

print(f"Successfully generated translations for {len(languages)} languages!")
