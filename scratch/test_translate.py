from deep_translator import GoogleTranslator

langs = {
    'Bengali': 'bn',
    'Telugu': 'te',
    'Tamil': 'ta',
    'Marathi': 'mr',
    'Gujarati': 'gu',
    'Kannada': 'kn',
    'Malayalam': 'ml',
    'Punjabi': 'pa',
    'Odia': 'or',
    'Urdu': 'ur'
}

text = "In Emergency, anyone can tap your card"
for lang, code in langs.items():
    translated = GoogleTranslator(source='en', target=code).translate(text)
    print(f"{lang}: {translated}")
