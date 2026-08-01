import urllib.request
import json

url = 'https://www.api.swasthyatap.in/api/auth/hospital/send-otp'
data = json.dumps({'hospitalId': 'HOSP-004'}).encode('utf-8')
req = urllib.request.Request(
    url,
    data=data,
    headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}
)

try:
    with urllib.request.urlopen(req) as response:
        print("Status Code:", response.getcode())
        print("Response:", response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("HTTP Error Status:", e.code)
    print("Response Body:", e.read().decode('utf-8'))
except Exception as e:
    print("General Error:", e)
