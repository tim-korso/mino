"""查询账号可用音色列表，看 tianyin-002 在不在。"""
import requests, credentials
r = requests.post("https://api.minimaxi.com/v1/list_voice",
                  headers={"Authorization": f"Bearer {credentials.API_KEY}", "Content-Type": "application/json"},
                  json={})
print(r.status_code)
print(r.text[:2000])
