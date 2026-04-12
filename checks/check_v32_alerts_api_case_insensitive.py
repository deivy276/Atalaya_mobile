import json
import urllib.request

url = 'http://127.0.0.1:8010/api/v1/alerts?fresh=true&limit=10'
with urllib.request.urlopen(url) as resp:
    headers = {k.lower(): v for k, v in resp.headers.items()}
    body = resp.read().decode('utf-8')
    payload = json.loads(body)

print('x-alerts-cache-status =', headers.get('x-alerts-cache-status'))
print('x-alerts-source =', headers.get('x-alerts-source'))
print('x-alerts-text-repairs =', headers.get('x-alerts-text-repairs'))
print()
alerts = payload.get('alerts', payload if isinstance(payload, list) else [])
for i, alert in enumerate(alerts[:10], 1):
    desc = alert.get('description', '')
    print(f'{i:02d}. {desc!r}')
