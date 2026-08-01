import urllib.request
import urllib.error

urls = [
    "http://api.swasthyatap.in/api/ping",
    "https://api.swasthyatap.in/api/ping",
    "http://api.swasthyatap.in/ping",
    "https://api.swasthyatap.in/ping"
]

for url in urls:
    print(f"=== Testing URL: {url} ===")
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            print("Status Code:", response.getcode())
            print("Final URL after redirects:", response.geturl())
            print("Headers:")
            for header, value in response.getheaders():
                print(f"  {header}: {value}")
            content = response.read().decode('utf-8')
            print("Content (first 500 chars):", content[:500])
    except urllib.error.HTTPError as e:
        print("HTTP Error:", e.code)
        try:
            print("Error body:", e.read().decode('utf-8'))
        except Exception:
            pass
    except Exception as e:
        print("Error:", e)
    print("\n")
