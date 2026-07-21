"""音频录放：pyaudio 录制 PCM 24kHz int16，播放下行 PCM 24kHz int16。"""
import pyaudio
import config as C

_pa = pyaudio.PyAudio()


class AudioIO:
    def __init__(self):
        self.input_stream = None
        self.output_stream = None

    def start(self):
        self.input_stream = _pa.open(
            format=pyaudio.paInt16, channels=C.CHANNELS, rate=C.SAMPLE_RATE,
            input=True, frames_per_buffer=C.CHUNK_SAMPLES)
        self.output_stream = _pa.open(
            format=pyaudio.paInt16, channels=C.CHANNELS, rate=C.SAMPLE_RATE,
            output=True)

    def read_chunk(self) -> bytes:
        return self.input_stream.read(C.CHUNK_SAMPLES, exception_on_overflow=False)

    def play(self, pcm_bytes: bytes):
        self.output_stream.write(pcm_bytes)

    def stop(self):
        for s in (self.input_stream, self.output_stream):
            if s:
                try:
                    s.stop_stream(); s.close()
                except Exception:
                    pass
