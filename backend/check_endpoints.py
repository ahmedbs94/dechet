import time
import requests


def wait_for_server(url='http://127.0.0.1:8000/', timeout=10):
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(url, timeout=2)
            return r
        except Exception:
            time.sleep(0.5)
    return None


def main():
    print('Checking backend root...')
    r = wait_for_server()
    if not r:
        print('Server not reachable at http://127.0.0.1:8000/')
        return
    print('GET / ->', r.status_code)
    try:
        print('Body:', r.json())
    except Exception:
        print('Body (text):', r.text[:400])

    print('\nTesting /auth/facebook with invalid token...')
    try:
        resp = requests.post('http://127.0.0.1:8000/auth/facebook', json={'access_token': 'invalid_token'}, timeout=10)
        print('POST /auth/facebook ->', resp.status_code)
        print('Response:', resp.text)
    except Exception as e:
        print('POST failed:', e)


if __name__ == '__main__':
    main()
