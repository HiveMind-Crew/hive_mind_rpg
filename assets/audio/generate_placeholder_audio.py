#!/usr/bin/env python3
"""Generates the placeholder audio set for issue #25.

Every .wav in this directory is synthesized from scratch by this script
(pure Python stdlib, deterministic), so the assets carry no third-party
license — see LICENSES.md. Re-run from the repository root to regenerate:

    python3 assets/audio/generate_placeholder_audio.py
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
OUTPUT_DIR = Path(__file__).parent


def write_wav(name: str, samples: list[float]) -> None:
    path = OUTPUT_DIR / name
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            clipped = max(-1.0, min(1.0, sample))
            frames += struct.pack("<h", int(clipped * 32767))
        wav_file.writeframes(bytes(frames))
    print(f"wrote {path.name}: {len(samples) / SAMPLE_RATE:.2f}s")


def seconds(duration: float) -> range:
    return range(int(duration * SAMPLE_RATE))


def ambient_forest_drone() -> list[float]:
    # 6-second loop. Every partial completes a whole number of cycles in 6s
    # (55, 82.5, 110 Hz and the 0.5 Hz detune beat), so the loop point clicks
    # as little as a placeholder drone can.
    duration = 6.0
    samples = []
    for i in seconds(duration):
        t = i / SAMPLE_RATE
        lfo = 0.75 + 0.25 * math.sin(2.0 * math.pi * t / duration)
        value = (
            0.45 * math.sin(2.0 * math.pi * 55.0 * t)
            + 0.30 * math.sin(2.0 * math.pi * 55.5 * t)
            + 0.20 * math.sin(2.0 * math.pi * 82.5 * t)
            + 0.12 * math.sin(2.0 * math.pi * 110.0 * t + math.sin(t * 2.0))
        )
        samples.append(0.28 * lfo * value)
    return samples


def noise_burst(duration: float, seed: int, lowpass: float) -> list[float]:
    rng = random.Random(seed)
    samples = []
    filtered = 0.0
    for _ in seconds(duration):
        filtered += lowpass * (rng.uniform(-1.0, 1.0) - filtered)
        samples.append(filtered)
    return samples


def envelope(i: int, total: int, attack: float) -> float:
    attack_samples = max(1, int(attack * total))
    if i < attack_samples:
        return i / attack_samples
    return math.exp(-4.0 * (i - attack_samples) / max(1, total - attack_samples))


def sfx_melee_swing() -> list[float]:
    # Broadband whoosh: lowpassed noise with the filter opening then closing.
    duration = 0.16
    noise = noise_burst(duration, seed=11, lowpass=0.35)
    total = len(noise)
    return [0.85 * envelope(i, total, 0.25) * value for i, value in enumerate(noise)]


def sfx_dash() -> list[float]:
    # Airier, shorter whoosh than the melee swing: brighter noise, fast decay.
    duration = 0.12
    noise = noise_burst(duration, seed=23, lowpass=0.75)
    total = len(noise)
    return [0.7 * envelope(i, total, 0.1) * value for i, value in enumerate(noise)]


def sfx_relic_cast() -> list[float]:
    # Synthetic zap: exponential pitch dive with a metallic overtone.
    duration = 0.3
    samples = []
    total = int(duration * SAMPLE_RATE)
    phase = 0.0
    for i in range(total):
        progress = i / total
        frequency = 1400.0 * math.pow(250.0 / 1400.0, progress)
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE
        value = 0.7 * math.sin(phase) + 0.3 * math.sin(2.7 * phase)
        samples.append(0.75 * envelope(i, total, 0.03) * value)
    return samples


def sfx_hit() -> list[float]:
    # Thud: short click into a pitch-dropping low sine.
    duration = 0.12
    total = int(duration * SAMPLE_RATE)
    click = noise_burst(0.008, seed=37, lowpass=0.9)
    samples = []
    phase = 0.0
    for i in range(total):
        progress = i / total
        frequency = 170.0 * math.pow(0.5, progress)
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE
        value = math.sin(phase)
        if i < len(click):
            value += 0.6 * click[i]
        samples.append(0.9 * envelope(i, total, 0.02) * value)
    return samples


def sfx_death() -> list[float]:
    # Long fall: a saw-flavored tone diving an octave and a half into noise.
    duration = 0.6
    total = int(duration * SAMPLE_RATE)
    rumble = noise_burst(duration, seed=53, lowpass=0.2)
    samples = []
    phase = 0.0
    for i in range(total):
        progress = i / total
        frequency = 220.0 * math.pow(55.0 / 220.0, progress)
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE
        value = 0.6 * math.sin(phase) + 0.25 * math.sin(2.0 * phase) + 0.35 * rumble[i]
        samples.append(0.8 * envelope(i, total, 0.05) * value)
    return samples


def main() -> None:
    write_wav("ambient_forest_drone.wav", ambient_forest_drone())
    write_wav("sfx_melee_swing.wav", sfx_melee_swing())
    write_wav("sfx_dash.wav", sfx_dash())
    write_wav("sfx_relic_cast.wav", sfx_relic_cast())
    write_wav("sfx_hit.wav", sfx_hit())
    write_wav("sfx_death.wav", sfx_death())


if __name__ == "__main__":
    main()
