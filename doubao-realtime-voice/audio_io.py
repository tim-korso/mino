"""音频录放：pyaudio 录制上行 PCM 16kHz，播放下行 PCM 24kHz。"""
import pyaudio
import config as C

_pa = pyaudio.PyAudio()


class AudioIO:
    def __init__(self):
        self.input_stream = None
        self.output_stream = None

    def start(self):
        # 输入：16kHz 单声道 int16
        self.input_stream = _pa.open(
            format=pyaudio.paInt16,
            channels=C.INPUT_CHANNELS,
            rate=C.INPUT_SAMPLE_RATE,
            input=True,
            frames_per_buffer=C.CHUNK_SAMPLES,
        )
        # 输出：24kHz 单声道 float32（服务端返回的 PCM 是 float32 小端）
        self.output_stream = _pa.open(
            format=pyaudio.paFloat32,
            channels=1,
            rate=C.OUTPUT_SAMPLE_RATE,
            output=True,
        )

    def read_chunk(self) -> bytes:
        return self.input_stream.read(C.CHUNK_SAMPLES, exception_on_overflow=False)

    def play(self, audio_bytes: bytes):
        self.output_stream.write(audio_bytes)

    def stop(self):
        for s in (self.input_stream, self.output_stream):
            if s:
                try:
                    s.stop_stream()
                    s.close()
                except Exception:
                    pass
