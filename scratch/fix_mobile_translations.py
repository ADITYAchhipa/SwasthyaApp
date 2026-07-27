import re

filepath = "/home/aditya/clones/Card/lib/utils/translation_service.dart"

replacements = {
    'English': {
        'change_mobile': 'Change Mobile Number',
        'mobile_error': 'Please enter a valid mobile number',
        'error_10digit': 'Please enter a valid 10-digit mobile number'
    },
    'Hindi': {
        'change_mobile': 'मोबाइल नंबर बदलें',
        'mobile_error': 'कृपया एक वैध मोबाइल नंबर दर्ज करें',
        'error_10digit': 'कृपया एक वैध 10-अंकों का मोबाइल नंबर दर्ज करें'
    },
    'Bengali': {
        'change_mobile': 'মোবাইল নম্বর পরিবর্তন করুন',
        'mobile_error': 'অনুগ্রহ করে একটি সঠিক মোবাইল নম্বর লিখুন',
        'error_10digit': 'অনুগ্রহ করে একটি সঠিক ১০-ডিজিটের মোবাইল নম্বর লিখুন'
    },
    'Telugu': {
        'change_mobile': 'మొబైల్ సంఖ్యను మార్చండి',
        'mobile_error': 'దయచేసి సరైన మొబైల్ సంఖ్యను నమోదు చేయండి',
        'error_10digit': 'దయచేసి సరైన 10-అంకెల మొబైల్ సంఖ్యను నమోదు చేయండి'
    },
    'Tamil': {
        'change_mobile': 'கைபேசி எண்ணை மாற்றவும்',
        'mobile_error': 'தயவுசெய்து செல்லுபடியாகும் மொபைல் எண்ணை உள்ளிடவும்',
        'error_10digit': 'தயவுசெய்து செல்லுபடியாகும் 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்'
    },
    'Marathi': {
        'change_mobile': 'मोबाईल नंबर बदला',
        'mobile_error': 'कृपया वैध मोबाईल नंबर प्रविष्ट करा',
        'error_10digit': 'कृपया वैध 10-अंकी मोबाईल नंबर प्रविष्ट करा'
    },
    'Gujarati': {
        'change_mobile': 'મોબાઈલ નંબર બદલો',
        'mobile_error': 'કૃપા કરીને યોગ્ય મોબાઈલ નંબર દાખલ કરો',
        'error_10digit': 'કૃપા કરીને યોગ્ય 10-આંકડાનો મોબાઈલ નંબર દાખલ કરો'
    },
    'Kannada': {
        'change_mobile': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ಬದಲಾಯಿಸಿ',
        'mobile_error': 'ದಯವಿಟ್ಟು ಮಾನ್ಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
        'error_10digit': 'ದಯವಿಟ್ಟು ಮಾನ್ಯ 10-ಅಂಕಿಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ'
    },
    'Malayalam': {
        'change_mobile': 'മൊബൈൽ നമ്പർ മാറ്റുക',
        'mobile_error': 'ദയവായി ഒരു സാധുവായ മൊബൈൽ നമ്പർ നൽകുക',
        'error_10digit': 'ദയവായി ഒരു സാധുവായ 10 അക്ക മൊബൈൽ നമ്പർ നൽകുക'
    },
    'Punjabi': {
        'change_mobile': 'ਮੋਬਾਈਲ ਨੰਬਰ ਬਦਲੋ',
        'mobile_error': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'error_10digit': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10-ਅੰਕਾਂ ਦਾ ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ'
    },
    'Odia': {
        'change_mobile': 'ମୋବାଇଲ୍ ନମ୍ବର ବଦଳାନ୍ତୁ',
        'mobile_error': 'ଦୟାକରି ଏକ ବୈଧ ମୋବାଇଲ୍ ନମ୍ବਰ ଲେଖନ୍ତୁ',
        'error_10digit': 'ଦୟାକରି ଏକ ବୈଧ 10-ଅଙ୍କ ବିଶିଷ୍ଟ ମୋବାଇଲ୍ ନମ୍ବਰ ଲେଖନ୍ତୁ'
    },
    'Urdu': {
        'change_mobile': 'موبائل نمبر تبدیل کریں',
        'mobile_error': 'براہ کرم ایک درست موبائل نمبر درج کریں',
        'error_10digit': 'براہ کرم ایک درست 10 ہندسوں کا موبائل نمبر درج کریں'
    }
}

with open(filepath, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
current_lang = None

for line in lines:
    # Check for language header: 'English': {
    lang_match = re.search(r"^\s*'([A-Za-z]+)'\s*:\s*\{", line)
    if lang_match:
        current_lang = lang_match.group(1)
        # print(f"Entering block: {current_lang}")
    
    # Check if we are inside a known language block and have keys to replace
    if current_lang in replacements:
        replaced = False
        for key, new_val in replacements[current_lang].items():
            # Match: 'key': 'value',
            pattern = r"^(\s*'" + re.escape(key) + r"'\s*:\s*').*?('\s*,\s*)$"
            if re.match(pattern, line):
                new_line = re.sub(pattern, r"\g<1>" + new_val.replace("\\", "\\\\").replace("'", "\\'") + r"\g<2>", line)
                new_lines.append(new_line)
                replaced = True
                print(f"Replaced {key} for {current_lang} -> {new_val}")
                break
        if not replaced:
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(filepath, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Replacement complete.")
