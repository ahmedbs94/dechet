import requests

def test_root():
    try:
        r = requests.get('http://127.0.0.1:8000/')
        print('GET / ->', r.status_code, r.text)
    except Exception as e:
        print('GET / error:', e)

def test_facebook_invalid():
    try:
        r = requests.post('http://127.0.0.1:8000/auth/facebook', json={'access_token': 'invalid_token'})
        print('POST /auth/facebook ->', r.status_code, r.text)
    except Exception as e:
        print('POST /auth/facebook error:', e)

if __name__ == '__main__':
    test_root()
    test_facebook_invalid()
