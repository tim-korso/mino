"""验证 Silero VAD：实时录音，打印每帧是 speech/silence，5秒。
对它说话→停顿，看 Silero 能否准确区分。
"""
import os, time, struct
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import pyaudio
from silero_vad import load_silero_vad
import torch

model = load_silero_vad(onnx=True)
SR = 16000
CHUNK = 512  # Silero 推荐 512 samples (32ms @16k)

pa = pyaudio.PyAudio()
s = pa.open(format=pyaudio.paInt16, channels=1, rate=SR, input=True, frames_per_buffer=CHUNK)
print("Silero VAD 实时检测 5 秒（说话→停顿→说话）...")
t0 = time.time()
speech_frames = 0
total = 0
while time.time() - t0 < 5:
    data = s.read(CHUNK, exception_on_overflow=False)
    # int16 → float32 归一化
    samples = struct.unpack(f"<{CHUNK}h", data)
    tensor = torch.tensor(samples, dtype=torch.float32) / 32768.0
    prob = model(tensor, SR).item()
    is_speech = prob > 0.5
    total += 1
    if is_speech:
        speech_frames += 1
    bar = "█" * int(prob * 20)
    print(f"  prob={prob:.2f} {'说话' if is_speech else '静  '} {bar}")
s.stop_stream(); s.close(); pa.terminate()
print(f"\n说话帧: {speech_frames}/{total}")
print("✅ Silero 能区分说话/静音" if 0 < speech_frames < total else "⚠️ 需要校准")
