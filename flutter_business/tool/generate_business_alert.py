#!/usr/bin/env python3
"""Generate ALIN's short, original business notification chime.

No bundled third-party audio. Generates a mono 44.1kHz WAV for Android and
an Apple-compatible 16-bit PCM CAF for the iOS Runner bundle on macOS.
"""
from __future__ import annotations

import math
import struct
import subprocess
import sys
import wave
from pathlib import Path

RATE = 44100
# Ascending friendly bell-like arpeggio (an original notification cue).
NOTES = ((659.25, 0.00, .15), (830.61, .14, .15), (1046.50, .28, .30))
DURATION = .77

def tone() -> bytes:
    frames = bytearray()
    for i in range(int(RATE * DURATION)):
        t = i / RATE
        y = 0.0
        for hz, start, duration in NOTES:
            age = t - start
            if age < 0 or age >= duration + .13:
                continue
            fade_in = min(1.0, age / .009)
            decay = math.exp(-5.2 * age / (duration + .13))
            envelope = fade_in * decay
            # Soft bell with clean fundamental and two quiet partials.
            y += envelope * (
                math.sin(2 * math.pi * hz * age)
                + .22 * math.sin(2 * math.pi * hz * 2 * age)
                + .07 * math.sin(2 * math.pi * hz * 3 * age)
            )
        frames.extend(struct.pack('<h', int(max(-1, min(1, y * .28)) * 32767)))
    return bytes(frames)

def write_wav(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(tone())

def main() -> None:
    platform = sys.argv[1] if len(sys.argv) > 1 else 'android'
    if platform == 'android':
        write_wav(Path('android/app/src/main/res/raw/alin_control_alert.wav'))
    elif platform == 'ios':
        target = Path('ios/Runner/alin_control_alert.caf')
        wav = Path('ios/Runner/alin_control_alert.wav')
        write_wav(wav)
        subprocess.run([
            'afconvert', '-f', 'caff', '-d', 'LEI16@44100',
            str(wav), str(target),
        ], check=True)
        wav.unlink()
    else:
        raise SystemExit('Usage: generate_business_alert.py android|ios')
    print('ALIN original notification chime generated for', platform)

if __name__ == '__main__':
    main()
