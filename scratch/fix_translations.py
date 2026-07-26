import re

filepath = '/home/aditya/clones/Card/scratch/generate_translations.py'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace the corrupted sec_footer section
# We will match everything from ('sec_footer', { down to ('agree_disclaimer', {
sec_footer_pattern = re.compile(r"\(\'sec_footer\'\,\s*\{.*?\n\s*\)\,\s*\n\s*\(\'agree_disclaimer\'", re.DOTALL)
replacement_sec_footer = """('sec_footer', {
        'English': '100% SECURE & GOVERNMENT SCHEME COMPLIANT',
        'Hindi': '100% सुरक्षित एवं सरकारी योजना के अनुपालन में',
        'Bengali': '১০০% সুরক্ষিত এবং সরকারি প্রকল্পের সাথে সামঞ্জস্যपूर्ण',
        'Telugu': '100% సురక్షితమైనది & ప్రభుత్వ పథకానికి అనుగుణంగా ఉంటుంది',
        'Tamil': '100% பாதுகாப்பானது & அரசு திட்டத்திற்கு உட்பட்டது',
        'Marathi': '100% सुरक्षित आणि सरकारी योजनेचे पालन करणारे',
        'Gujarati': '100% સુરક્ષิต અને સરકારી યોજનાના અનુપાલનમાં',
        'Kannada': '100% ಸುರಕ್ಷಿತ ಮತ್ತು ಸರ್ಕಾರಿ ಯೋಜನೆಗೆ ಅನುಗುಣವಾಗಿದೆ',
        'Malayalam': '100% സുരക്ഷിതവും സർക്കാർ പദ്ധതിക്ക് അനുസൃതവുമാണ്',
        'Punjabi': '100% ਸੁਰੱਖਿਅਤ ਅਤੇ ਸਰਕਾਰੀ ਯੋਜਨਾ ਦੇ ਅਨੁਕੂਲ',
        'Odia': '100% ସୁରକ୍ଷିତ ଏବଂ ସରକାରୀ ଯୋଜନା ଅନୁପାଳିତ',
        'Urdu': '100% محفوظ اور سرکاری اسکیم کے مطابق'
    }),
    ('agree_disclaimer'"""

content, count1 = sec_footer_pattern.subn(replacement_sec_footer, content)
print(f"Replaced sec_footer: {count1} times")

# 2. Replace ('mobile_number', { ... })
mobile_number_pattern = re.compile(r"\(\'mobile_number\'\,\s*\{.*?\n\s*\)\,\n", re.DOTALL)
replacement_mobile_number = """('mobile_number', {
        'English': 'Mobile Number', 'Hindi': 'मोबाइल नंबर', 'Bengali': 'মোবাইল নম্বর', 'Telugu': 'మొబైల్ నంబర్',
        'Tamil': 'கைபேసి எண்', 'Marathi': 'मोबाईल नंबर', 'Gujarati': 'મોબાઈલ નંબર', 'Kannada': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
        'Malayalam': 'മൊബൈൽ നമ്പർ', 'Punjabi': 'ਮੋਬਾਈਲ ਨੰਬਰ', 'Odia': 'මୋବାଇଲ୍ ନମ୍ବਰ', 'Urdu': 'موبائل نمبر'
    }),
"""
content, count2 = mobile_number_pattern.subn(replacement_mobile_number, content)
print(f"Replaced mobile_number: {count2} times")

# 3. Replace ('enter_hint', { ... })
enter_hint_pattern = re.compile(r"\(\'enter_hint\'\,\s*\{.*?\n\s*\)\,\n", re.DOTALL)
replacement_enter_hint = """('enter_hint', {
        'English': 'Enter mobile number', 'Hindi': 'मोबाइल नंबर दर्ज करें', 'Bengali': 'মোবাইল নম্বর লিখুন',
        'Telugu': 'మొబైల్ నंबర్‌ను నమోదు చేయండి', 'Tamil': 'கைபேసి எண்ணை உள்ளிடவும்', 'Marathi': 'मोबाईल नंबर प्रविष्ट करा',
        'Gujarati': 'મોબાઈલ નંબર દાખલ કરો', 'Kannada': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ', 'Malayalam': 'മൊബൈൽ നമ്പർ നൽകുക',
        'Punjabi': 'ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ', 'Odia': 'මୋବାଇଲ୍ ନମ୍ବਰ ଲେଖନ୍ତု', 'Urdu': 'موبائل نمبر درج کریں'
    }),
"""
content, count3 = enter_hint_pattern.subn(replacement_enter_hint, content)
print(f"Replaced enter_hint: {count3} times")

# 4. Replace ('change_mobile', { ... })
change_mobile_pattern = re.compile(r"\(\'change_mobile\'\,\s*\{.*?\n\s*\)\,\n", re.DOTALL)
replacement_change_mobile = """('change_mobile', {
        'English': 'Change Mobile Number', 'Hindi': 'मोबाइल नंबर बदलें', 'Bengali': 'মোবাইল নম্বর পরিবর্তন করুন',
        'Telugu': 'మొబైల్ నంబర్‌ను మార్చండి', 'Tamil': 'கைபேసి எண்ணை மாற்றவும்', 'Marathi': 'मोबाईल नंबर बदला',
        'Gujarati': 'મોબાઈલ નંબર બદલો', 'Kannada': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ಬದಲಾಯಿಸಿ', 'Malayalam': 'മൊബൈൽ നമ്പർ മാറ്റുക',
        'Punjabi': 'ਮੋਬਾਈਲ ਨੰਬਰ ਬਦਲੋ', 'Odia': 'మୋବାଇଲ୍ ନମ୍ବਰ ବଦଳାନ୍ତು', 'Urdu': 'موبائل نمبر تبدیل کریں'
    }),
"""
content, count4 = change_mobile_pattern.subn(replacement_change_mobile, content)
print(f"Replaced change_mobile: {count4} times")

# 5. Replace ('mobile_error', { ... })
mobile_error_pattern = re.compile(r"\(\'mobile_error\'\,\s*\{.*?\n\s*\)\,\n", re.DOTALL)
replacement_mobile_error = """('mobile_error', {
        'English': 'Please enter a valid 10-digit mobile number', 'Hindi': 'कृपया एक वैध 10-अंकीय मोबाइल नंबर दर्ज करें',
        'Bengali': 'অনুগ্রহ করে একটি বৈধ ১০-সংখ্যার মোবাইল নম্বর লিখুন', 'Telugu': 'దయచేసి సరైన 10 అంకెల మొబైల్ నంబర్‌ను నమోదు చేయండి',
        'Tamil': 'செல்லுபடியாகும் 10 இலக்க கைபேసి எண்ணை உள்ளிடவும்', 'Marathi': 'कृपया वैध १०-अंकी मोबाईल नंबर प्रविष्ट करा',
        'Gujarati': 'કૃપા કરીને માન્ય 10-આંકડાનો મોબાઇલ નંબર દાખલ કરો', 'Kannada': 'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10-ಅಂಕಿಯ ಮೊಬైಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
        'Malayalam': 'ദയവായി ഒരു സാധുവായ 10 അക്ക മൊബൈൽ നമ്പർ നൽകുക', 'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10-ਅੰਕਾਂ ਦਾ ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Odia': 'ଦୟାକରି ଏକ ବୈଧ ୧୦-ଅଙ୍କ ବିଶିଷ୍ଟ ମୋବାଇଲ୍ ନମ୍ବਰ ଲେଖନ୍ତု', 'Urdu': 'براہ کرم ایک درست 10 ہندسوں کا موبائل نمبر درج کریں'
    }),
"""
content, count5 = mobile_error_pattern.subn(replacement_mobile_error, content)
print(f"Replaced mobile_error: {count5} times")

# 6. Replace ('error_10digit', { ... })
error_10digit_pattern = re.compile(r"\(\'error_10digit\'\,\s*\{.*?\n\s*\)\,\n", re.DOTALL)
replacement_error_10digit = """('error_10digit', {
        'English': 'Please enter a valid 10-digit mobile number', 'Hindi': 'कृपया एक वैध 10-अंकीय मोबाइल नंबर दर्ज करें',
        'Bengali': 'অনুগ্রহ করে একটি वैध ১০-সংখ্যার মোবাইল নম্বর লিখুন', 'Telugu': 'దయచేసి సరైన 10 అంకెల మొబైಲ್ నంబర్‌ను నమోదు చేయండి',
        'Tamil': 'செல்லுபடியாகும் 10 இலக்க கைபேసి எண்ணை உள்ளிடவும்', 'Marathi': 'कृपया वैध १०-अंकी मोबाईल नंबर प्रविष्ट करा',
        'Gujarati': 'કૃપા કરીને માન્ય 10-આંકડાનો મોબાઇલ નંબર દાખલ કરો', 'Kannada': 'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10-ಅಂಕಿಯ ಮೊಬైಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
        'Malayalam': 'ദയവായി ഒരു സാധുവായ 10 അക്ക മൊബൈಲ್ നമ്പർ നൽകുക', 'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10-ਅੰਕਾਂ ਦਾ ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Odia': 'ଦୟାକରି ଏକ ବୈଧ ୧୦-ଅଙ୍କ ବିଶିଷ୍ଟ ମୋବାଇଲ୍ ନମ୍ବਰ ଲେଖନ୍ତု', 'Urdu': 'براہ کرم ایک درست 10 ہندسوں کا موبائل نمبر درج کریں'
    }),
"""
content, count6 = error_10digit_pattern.subn(replacement_error_10digit, content)
print(f"Replaced error_10digit: {count6} times")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done fixing translations file.")
