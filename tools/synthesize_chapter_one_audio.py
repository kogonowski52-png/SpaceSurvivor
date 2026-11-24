#!/usr/bin/env python3
"""Rebuild the original Frontier score and battle cues with NumPy and FFmpeg."""

from pathlib import Path
from subprocess import run
from tempfile import TemporaryDirectory
import wave

import numpy as np


RATE = 44_100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "frontier"
RNG = np.random.default_rng(1376)


def clock(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def oscillator(t, start, end=None):
    finish = start if end is None else end
    phase = 2 * np.pi * (start * t + (finish - start) * t**2 / (2 * (t[-1] + 1 / RATE)))
    return np.sin(phase)


def band(t, smoothing):
    samples = RNG.uniform(-1, 1, t.size)
    return np.convolve(samples, np.ones(smoothing) / smoothing, mode="same")


def taper(t, attack, decay):
    return np.minimum(1, t / attack) * np.exp(-t * decay) * np.minimum(1, (t[-1] - t) * 85)


def write_wav(path, samples):
    clipped = np.clip(samples, -0.999, 0.999)
    frames = (clipped * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setparams((1 if frames.ndim == 1 else 2, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(frames.tobytes())


def cues():
    t = clock(0.64)
    write_wav(OUT / "impact.wav", taper(t, .012, 5.2) * (
        .65 * oscillator(t, 86., 32.) + .8 * band(t, 22) + .21 * band(t, 4) * np.exp(-t * 15)))
    t = clock(0.51)
    write_wav(OUT / "rail.wav", taper(t, .007, 7.1) * (
        .33 * oscillator(t, 485, 91.) + .19 * oscillator(t, 910, 142.) + .44 * band(t, 8)))
    t = clock(0.76)
    pulse = .64 + .36 * oscillator(t, 8., 5.)
    write_wav(OUT / "shift.wav", taper(t, .052, 2.9) * pulse * (
        .28 * oscillator(t, 133., 200.) + .21 * oscillator(t, 281, 416) + .14 * oscillator(t, 420, 619.)))
    t = clock(0.30)
    write_wav(OUT / "contact.wav", taper(t, .018, 8.6) * (.32 * oscillator(t, 546, 425) +
        .16 * oscillator(t, 731, 578) * (np.sin(2 * np.pi * 11 * t) ** 2)))
    t = clock(0.28)
    write_wav(OUT / "shield.wav", taper(t, .009, 11.) * (
        .33 * oscillator(t, 1_000, 200) + .17 * oscillator(t, 1_352, 316) + .39 * band(t, 6)))
    t = clock(.90)
    write_wav(OUT / "module.wav", taper(t, .011, 4.5) * (
        .52 * oscillator(t, 107, 54) + .85 * band(t, 16) + .18 * oscillator(t, 460, 110) * np.exp(-t * 4)))


def score():
    beat = 60 / 106
    length = round(8 * 4 * beat * RATE)
    mix = np.zeros((length, 2), dtype=np.float64)

    def add(seconds, signal, pan):
        indices = (round(seconds * RATE) + np.arange(signal.size)) % length
        mix[indices, 0] += signal * np.sqrt(1 - pan)
        mix[indices, 1] += signal * np.sqrt(pan)

    def frequency(note):
        return 440 * 2 ** ((note - 69) / 12)

    chords = [(38, 53, 57, 60), (34, 53, 58, 62), (41, 52, 57, 60), (36, 55, 58, 63)]
    for bar in range(8):
        start = bar * beat * 4
        chord = chords[bar // 2]
        for layer, note in enumerate(chord[1:]):
            t = clock(beat * 4.73)
            f = frequency(note)
            env = np.minimum(t / .64, 1) * np.minimum(1, (t[-1] - t) / .81)
            voice = (oscillator(t, f) + .30 * oscillator(t, f * 2.00) +
                     .22 * oscillator(t, f * 1.005)) * env * .035
            add(start - .15, voice, .22 + layer * .27)
        for step in range(8):
            t = clock(beat * 1.15)
            arp = chord[1 + (step * 2 + bar) % 3] + (12 if step % 3 else 0)
            f = frequency(arp)
            envelope = taper(t, .017, 6.5)
            voice = (.74 * oscillator(t, f) + .26 * oscillator(t, f * 2.014)) * envelope * .040
            pan = .29 + .42 * (step % 2)
            add(start + step * beat * .5, voice, pan)
            add(start + (step * .5 + .75) * beat, voice * .21, 1 - pan)
        for note_beat in [0, 1.5, 2.5, 3.5]:
            t = clock(beat * .79)
            f = frequency(chord[0])
            add(start + note_beat * beat, taper(t, .019, 5.3) *
                (.075 * oscillator(t, f) + .019 * oscillator(t, f * 2)), .50)
        for kick_at in [0, 2.0]:
            t = clock(.23)
            add(start + kick_at * beat, .105 * oscillator(t, 78, 40) * taper(t, .006, 14), .50)
        for hat_at in [0.5, 1.5, 2.5, 3.5]:
            t = clock(.10)
            add(start + hat_at * beat, .045 * band(t, 5) * taper(t, .008, 23), .67)

    return mix


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cues()
    with TemporaryDirectory(prefix="frontier-score-") as folder:
        rendered = Path(folder) / "score.wav"
        write_wav(rendered, score())
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(rendered),
             "-c:a", "libvorbis", "-q:a", "5", str(OUT / "score.ogg")], check=True)


if __name__ == "__main__":
    main()
