"""Render the original Galaxy Strike score and Foley without external audio assets.

Requires NumPy and ffmpeg with libvorbis. From the repository root:
    python3 audio/render_scores.py
"""

from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
TAU = 2 * np.pi
MUSIC_RATE = 32000
EFFECT_RATE = 24000
RNG = np.random.default_rng(0x4753)


def hz(note):
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def clock(seconds, rate=MUSIC_RATE):
    return np.arange(round(seconds * rate), dtype=np.float64) / rate


def window(t, attack, release):
    attack_curve = np.minimum(1.0, t / max(attack, 1e-6))
    release_curve = np.clip((t[-1] - t) / max(release, 1e-6), 0, 1)
    return np.sin(attack_curve * np.pi / 2) ** 2 * np.sin(release_curve * np.pi / 2) ** 2


def osc(t, start, finish=None):
    if finish is None:
        return np.sin(TAU * start * t)
    return np.sin(TAU * (start * t + (finish - start) * t * t / (2 * t[-1])))


def noise(t, frequency, bandwidth, rate):
    frequencies = np.fft.rfftfreq(t.size, 1.0 / rate)
    band = np.exp(-0.5 * ((frequencies - frequency) / bandwidth) ** 2)
    sound = np.fft.irfft(np.fft.rfft(RNG.normal(size=t.size)) * band, n=t.size)
    return sound / max(1e-8, np.std(sound))


def add(stereo, sound, beat, beat_length, pan=0.0, gain=1.0):
    start = round(beat * beat_length * MUSIC_RATE) % stereo.shape[0]
    position = (start + np.arange(sound.size)) % stereo.shape[0]
    pan_angle = (1 + pan) * np.pi / 4
    np.add.at(stereo[:, 0], position, sound * gain * np.cos(pan_angle))
    np.add.at(stereo[:, 1], position, sound * gain * np.sin(pan_angle))


def pad(note, seconds, part):
    t = clock(seconds)
    f = hz(note)
    slow = 0.92 + 0.08 * np.sin(t * TAU * 0.21 + part)
    tone = (
        0.62 * np.sin(TAU * f * t + 0.10 * np.sin(TAU * 0.34 * t))
        + 0.22 * np.sin(TAU * (f * 1.0037) * t)
        + 0.10 * np.sin(TAU * f * 2.0 * t + np.sin(TAU * 0.44 * t) * 0.43)
        + 0.055 * np.sin(TAU * f * 3.0 * t)
    )
    return tone * slow * window(t, seconds * 0.40, seconds * 0.29)


def glass(note, seconds, bright=1.0):
    t = clock(seconds)
    phase = TAU * hz(note) * t
    envelope = np.exp(-t / (seconds * 0.29)) * window(t, 0.012, 0.075)
    return (0.81 * np.sin(phase + 0.65 * bright * np.exp(-t * 8) * np.sin(phase * 2))
            + 0.14 * np.sin(phase * 2.003) + 0.05 * np.sin(phase * 4.008)) * envelope


def bass(note, seconds, drive):
    t = clock(seconds)
    phase = TAU * hz(note) * t
    tone = np.sin(phase) + 0.32 * np.sin(phase * 2.0)
    if drive:
        tone += 0.11 * np.sin(phase * 3.0) + 0.042 * np.sin(phase * 5.0)
    return np.tanh(tone * (0.8 if drive else 0.65)) * window(t, 0.032, seconds * 0.39)


def kick():
    t = clock(0.31)
    tone = np.sin(TAU * (51.0 * t + 5.0 * (1.0 - np.exp(-t * 29))))
    knock = 0.08 * noise(t, 470.0, 270.0, MUSIC_RATE) * np.exp(-t * 77)
    return (tone * np.exp(-t * 14) + knock) * window(t, 0.005, 0.028)


def percussion(kind, variation):
    if kind == "hat":
        t = clock(0.11 + (variation % 3) * 0.012)
        airy = noise(t, 5900.0, 2300.0, MUSIC_RATE)
        return airy * np.exp(-t * 42) * window(t, 0.005, 0.032)
    t = clock(0.20)
    rim = osc(t, 246, 153) * np.exp(-t * 32) * 0.29
    skin = noise(t, 1450.0, 730.0, MUSIC_RATE) * np.exp(-t * 20) * 0.5
    return (rim + skin) * window(t, 0.002, 0.04)


def shimmer(t, phase, rate):
    layer = noise(t, 1350.0, 460.0, rate)
    return layer * np.sin(np.linspace(0, np.pi, len(t))) ** 3 * phase


def delayed_space(stereo, ambience):
    # The delay is circular. The tail of the last bar returns to the start.
    dry = stereo.copy()
    for seconds, gain in ((0.081, 0.073), (0.179, 0.095), (0.307, 0.069), (0.473, 0.038)):
        offset = round(seconds * MUSIC_RATE)
        stereo += np.roll(dry[:, ::-1], offset, axis=0) * gain * ambience


CHORDS = [
    # Dm(add9), Bbmaj7, F(add9)/A, C6
    (38, (50, 57, 60, 64, 65), (69, 72, 76, 77)),
    (34, (50, 53, 57, 60, 65), (69, 74, 77, 81)),
    (33, (48, 53, 57, 60, 67), (67, 69, 72, 77)),
    (36, (48, 55, 57, 62, 64), (67, 69, 74, 76)),
]
MOTIF = [0, 2, 1, 3, 2, 0, 1, 2]


def compose(combat):
    bpm = 124 if combat else 92
    bars = 32 if combat else 24
    beat_length = 60 / bpm
    pad_length = 6.65 * beat_length
    stereo = np.zeros((round(bars * 4 * beat_length * MUSIC_RATE), 2), dtype=np.float64)
    for bar in range(bars):
        phrase = bar // 8
        root, voicing, bell_notes = CHORDS[(bar // 2) % len(CHORDS)]
        start = bar * 4

        if bar % 2 == 0:
            sustain = pad_length + beat_length * 4
            for part, note in enumerate(voicing):
                if part == 4 and phrase == 0:
                    continue
                sound = pad(note, sustain, part + phrase / 2)
                spread = (part - 2) * 0.32
                gain = (0.055 if combat else 0.103) * (0.84 if part == 0 else 1.0)
                add(stereo, sound, start - 1.45, beat_length, spread, gain)

        if combat:
            for step in (0, 0.75, 1.50, 2.0, 2.75, 3.50):
                note = root + (12 if step == 3.5 and bar % 2 else 0)
                add(stereo, bass(note, beat_length * 0.48, True), start + step, beat_length, 0.0, 0.245)
            for beat in (0, 2, 2.75) if phrase == 2 else (0, 2):
                add(stereo, kick(), start + beat, beat_length, 0, 0.27)
            for beat in (1, 3):
                add(stereo, percussion("rim", bar), start + beat, beat_length, -0.09, 0.13)
            if phrase != 0 or bar >= 4:
                for step in range(8):
                    velocity = 0.048 if step % 2 else 0.025
                    pan = -0.41 if step % 2 else 0.41
                    add(stereo, percussion("hat", bar + step), start + step / 2, beat_length, pan, velocity)
        else:
            if bar % 2 == 0:
                add(stereo, bass(root, beat_length * 7.9, False), start - 0.4, beat_length, 0, 0.15)
            if phrase != 0 and bar % 2 == 0:
                add(stereo, kick(), start, beat_length, 0, 0.085)

        steps = (0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5) if combat else (0.0, 1.5, 2.5, 3.5)
        for index, beat in enumerate(steps):
            if not combat and phrase == 0 and (bar + index) % 3 == 1:
                continue
            note = bell_notes[MOTIF[(index + (bar % 2) * 3) % 8]]
            if combat and phrase == 3 and index % 3 == 0:
                note -= 12
            pan = (-0.42, 0.34, -0.25, 0.42)[index % 4]
            length = (0.75 if combat else 1.4) * beat_length
            ping = glass(note, length, 1.0 if combat else 0.64)
            add(stereo, ping, start + beat, beat_length, pan, 0.12 if combat else 0.096)
            add(stereo, ping, start + beat + 0.75, beat_length, -pan, 0.042 if combat else 0.035)
            add(stereo, ping, start + beat + 1.5, beat_length, pan * 0.7, 0.018)
        if bar % 8 == 7:
            t = clock(beat_length * 2.2)
            sweep = shimmer(t, 0.038 if combat else 0.029, MUSIC_RATE)
            add(stereo, sweep, start + 2, beat_length, -0.55, 1.0)
            add(stereo, sweep[::-1], start + 2.16, beat_length, 0.55, 0.72)

    delayed_space(stereo, 0.65 if combat else 1.25)
    stereo = np.tanh(stereo * (1.38 if combat else 1.15))
    return stereo * (0.86 / np.max(np.abs(stereo)))


def clean(signal, attack=0.004, release=0.03):
    t = np.arange(len(signal)) / EFFECT_RATE
    return signal * window(t, attack, release)


def ping(t, note, start, gain=1.0, glide=0.0, tail=0.15):
    out = np.zeros(t.size, dtype=np.float64)
    mask = t >= start
    local = t[mask] - start
    phase = TAU * (hz(note) * local + glide * local * local / 2)
    envelope = (1 - np.exp(-local * 420)) * np.exp(-local / tail)
    out[mask] = gain * envelope * (
        0.76 * np.sin(phase + 0.19 * np.sin(phase * 3.0))
        + 0.15 * np.sin(phase * 2.016)
        + 0.05 * np.sin(phase * 4.032)
    )
    return out


def music_phrase(duration, notes, fall=False):
    t = clock(duration, EFFECT_RATE)
    chime = np.zeros(t.shape)
    for note, start, level in notes:
        chime += ping(t, note, start, level, -55 if fall else 17, 0.20)
    shroud = noise(t, 1050, 380, EFFECT_RATE) * np.exp(-t * 12) * 0.034
    return clean(chime + shroud, release=0.12)


SOUND_DESIGNS = {
    "navigation": (0.105, 634, 110, 0.07, 11),
    "equip": (0.26, 221, 287, 0.17, 10),
    "crate": (1.14, 190, 490, 0.13, 4.5),
    "upgrade": (0.74, 320, 672, 0.08, 4.0),
    "reward": (0.55, 392, 659, 0.06, 5.5),
    "hit": (0.079, 292, 132, 0.37, 36),
    "kill": (0.26, 157, 58, 0.26, 10.2),
    "hurt": (0.33, 235, 78, 0.20, 12.0),
    "pickup": (0.18, 740, 1030, 0.041, 18),
    "shot": (0.137, 735, 211, 0.19, 31),
    "missile": (0.44, 234, 87, 0.29, 8.6),
    "nova": (0.51, 310, 77, 0.13, 5.4),
    "laser": (0.40, 680, 340, 0.085, 6.6),
    "drone": (0.123, 777, 510, 0.07, 16),
    "tesla": (0.265, 416, 216, 0.26, 9.9),
    "boss_warning": (0.82, 275, 149, 0.06, 2.9),
    "boss_break": (1.30, 139, 53, 0.20, 3.6),
}


def effect(name, spec):
    duration, f0, f1, grit, decay = spec
    t = clock(duration, EFFECT_RATE)
    frequency = (f0 if name != "tesla" else 325.0)
    texture = noise(t, 820 + frequency * 1.9, 400 + frequency * 0.77, EFFECT_RATE)
    sweep = osc(t, f0, f1)
    film = osc(t, f0 * 1.73, f1 * 1.3) * 0.16
    sub = osc(t, max(71, f0 * 0.58), max(49, f1 * 0.48)) * 0.25
    tone = (0.60 * sweep + film + sub) * np.exp(-t * decay)
    tone += texture * (grit * 0.57) * np.exp(-t * decay * 1.02)
    match name:
        case "shot" | "hit":
            tone += 0.075 * noise(t, 4200.0, 1800.0, EFFECT_RATE) * np.exp(-t * 68)
        case "kill" | "hurt" | "boss_break":
            tone += noise(t, 230.0, 149.0, EFFECT_RATE) * (0.12 if name != "boss_break" else 0.24) * np.exp(-t * 10.5)
        case "nova":
            tone *= (0.64 + 0.36 * np.sin(TAU * 20.0 * t) ** 2)
        case "tesla":
            tone *= (0.54 + 0.46 * np.sin(TAU * 37.0 * t) ** 2)
        case "boss_warning":
            tone = tone * 0.28
            for index, start in enumerate((0.0, 0.19, 0.38)):
                tone += ping(t, 55 if index % 2 == 1 else 50, start, 0.48, -40, 0.118)
        case "crate":
            tone *= 0.35
            for note, start in ((62, 0.13), (69, 0.24), (72, 0.32), (76, 0.44), (81, 0.58)):
                tone += ping(t, note, start, 0.37, 12, 0.24)
        case "upgrade" | "reward":
            tone *= 0.32
            notes = (62, 69, 76) if name == "upgrade" else (69, 74, 81)
            for index, note in enumerate(notes):
                tone += ping(t, note, index * 0.09, 0.40, 7, 0.18)
        case "equip":
            tone += ping(t, 62, 0.072, 0.27, -34, 0.075)
        case "pickup":
            tone += ping(t, 76, 0.038, 0.29, 105, 0.064)
    return clean(tone, release=min(0.085, duration * 0.28))


def save_wav(path, signal, rate, normalized=False):
    peak = np.max(np.abs(signal))
    if normalized and peak > 0:
        signal = signal * (0.79 / peak)
    pcm = (np.clip(signal, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(signal.shape[1] if signal.ndim > 1 else 1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(pcm.tobytes())


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as staging:
        for name, combat in (("docking_bay", False), ("hostile_orbit", True)):
            wav = Path(staging) / (name + ".wav")
            save_wav(wav, compose(combat), MUSIC_RATE)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a",
                "libvorbis", "-q:a", "4",
                "-metadata", "title=" + name.replace("_", " ").title(),
                "-metadata", "artist=Galaxy Strike original score",
                str(OUTPUT / (name + ".ogg")),
            ], check=True)
    for name, spec in SOUND_DESIGNS.items():
        save_wav(OUTPUT / (name + ".wav"), effect(name, spec), EFFECT_RATE, normalized=True)
    win = [(50, 0.0, 0.32), (57, 0.08, 0.40), (62, 0.17, 0.44), (69, 0.26, 0.48),
           (74, 0.42, 0.58), (77, 0.42, 0.31), (81, 0.43, 0.26)]
    loss = [(62, 0.0, 0.54), (60, 0.18, 0.42), (57, 0.33, 0.43), (50, 0.51, 0.56)]
    save_wav(OUTPUT / "victory.wav", music_phrase(1.46, win), EFFECT_RATE, normalized=True)
    save_wav(OUTPUT / "defeat.wav", music_phrase(1.15, loss, True), EFFECT_RATE, normalized=True)


if __name__ == "__main__":
    main()
