"""克隆音色：上传音频 → /v1/voice_clone → 得到 voice_id。
一次性脚本。voice_id 自己命名，后续 Realtime 用它。
"""
import os, sys, json, requests

API_KEY = "sk-api-vR8ZdzfXP7pZ_weqW2pcklVbSxm4OcqmZMtZPROH4ivAXsDHm-zTP6Ej7AdgL-pHznWO3pLG-eMyLoPuY8PC8LwBbUunN_TCNh-3MEgSEw2JIdCZDvHmmuE"
AUDIO_PATH = "/Users/1234/.myagents/projects/mino/minimax-realtime-voice/clone_input_2.mp3"
VOICE_ID = "nana_v2_20260617"   # 全新 id，避开 duplicate
UPLOAD_URL = "https://api.minimaxi.com/v1/files/upload"
CLONE_URL = "https://api.minimaxi.com/v1/voice_clone"
HEADERS = {"Authorization": f"Bearer {API_KEY}"}

# 克隆用的验证文本：必须是音频里实际说的话（ASR 相似度校验）。
# 不确定就留空字符串，但留空可能被拒（错误码 1043）。
CLONE_TEXT = sys.argv[1] if len(sys.argv) > 1 else "你好，很高兴认识你。"
MODEL = "speech-02-hd"   # 克隆模型；若报模型不存在，改 "speech-2.6-hd" / "speech-2.8-hd"


def main():
    print(f"上传音频: {AUDIO_PATH}")
    with open(AUDIO_PATH, "rb") as f:
        files = {"file": ("clone_input.m4a", f)}
        data = {"purpose": "voice_clone"}
        r = requests.post(UPLOAD_URL, headers=HEADERS, files=files, data=data, timeout=60)
    r.raise_for_status()
    file_id = r.json()["file"]["file_id"]
    print(f"✅ 上传成功 file_id={file_id}")

    print(f"克隆音色 voice_id={VOICE_ID} ...")
    payload = {
        "file_id": file_id,
        "voice_id": VOICE_ID,
        "text": CLONE_TEXT,
        "model": MODEL,
    }
    r = requests.post(CLONE_URL, headers={**HEADERS, "Content-Type": "application/json"},
                      json=payload, timeout=120)
    print(f"HTTP 状态码: {r.status_code}")
    data = r.json()
    base = data.get("base_resp", {})
    sc = base.get("status_code", 0)
    print(f"业务码: {sc}  {base.get('status_msg','')}")
    if sc == 0:
        print(f"\n🎉 克隆成功！voice_id={VOICE_ID}")
        print(f"在 config.py 里设 VOICE_ID = \"{VOICE_ID}\"")
    else:
        print(f"\n❌ 克隆失败: {base.get('status_msg')}")
        if sc == 2038:
            print("   → voice clone user forbidden：账号未开通克隆权限/未实名")


if __name__ == "__main__":
    main()
