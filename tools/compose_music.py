"""Original PIXWAVE chiptune, deterministic offline synthesis. MIT.
Run with Python 3; no packages required. No borrowed melodies or samples.
"""
from pathlib import Path
import math
import random
import wave
from array import array

RATE = 22050
BPM = 112
BEAT = 60 / BPM
# Original 16-bar melody, eighth-note grid. MIDI pitches, 0 = rest.
MELODY = [
 [72,0,76,79,0,76,74,76], [77,0,81,79,77,0,76,74],
 [76,79,84,0,83,79,76,0], [74,0,71,74,79,0,74,71],
 [72,76,0,79,81,79,76,0], [77,81,84,81,79,0,77,76],
 [74,77,0,81,79,77,74,71], [72,0,79,0,76,74,72,0],
 [84,0,83,79,81,0,79,76], [81,84,0,81,79,77,76,0],
 [79,83,86,0,84,83,79,0], [81,79,77,74,76,0,74,71],
 [72,0,76,79,84,0,79,76], [77,0,81,84,83,81,77,0],
 [79,77,74,0,71,74,79,71], [72,76,79,84,0,79,74,71],
]
CHORDS = [(48,52,55),(53,57,60),(48,52,55),(43,47,50),
 (45,48,52),(53,57,60),(50,53,57),(43,47,50),
 (45,48,52),(53,57,60),(43,47,50),(43,47,50),
 (48,52,55),(53,57,60),(43,47,50),(43,47,50)]
buffer = [0.0] * round(16 * 4 * BEAT * RATE)

def tone(start, duration, midi, gain, voice):
    if not midi:
        return
    start = round(start * RATE)
    count = round(duration * RATE)
    freq = 440 * 2 ** ((midi - 69) / 12)
    # Band-limited harmonics retain the square/triangle character without harsh aliasing.
    harmonics = [k for k in range(1, 16, 2) if k * freq < RATE * .44]
    for i in range(count):
        t = i / RATE
        envelope = min(1, t / .008) * min(1, (duration-t) / .035)
        if voice == 'pulse':
            sample = sum(math.sin(2*math.pi*freq*k*t)/k for k in harmonics) * .65
        else:
            sample = sum((-1)**((k-1)//2)*math.sin(2*math.pi*freq*k*t)/(k*k) for k in harmonics) * .8
        buffer[(start+i) % len(buffer)] += sample * gain * envelope

rng = random.Random(24)
for bar, notes in enumerate(MELODY):
    offset = bar * 4 * BEAT
    root, third, fifth = CHORDS[bar]
    for step, note in enumerate(notes):
        tone(offset + step * BEAT/2, BEAT*.36, note, .23, 'pulse')
    for beat, note in enumerate([root, fifth, root+12, fifth]):
        tone(offset + beat*BEAT, BEAT*.65, note, .23, 'triangle')
    for step, note in enumerate([root+24, third+24, fifth+24, third+24]*2):
        tone(offset + step*BEAT/2, BEAT*.18, note, .045, 'triangle')
    # Soft noise ticks; no loud snare or surprise accents.
    for step in range(8):
        start = round((offset+step*BEAT/2)*RATE)
        for i in range(round(.035*RATE)):
            buffer[(start+i) % len(buffer)] += rng.uniform(-1,1)*.025*math.exp(-i/(RATE*.009))

peak = max(abs(v) for v in buffer)
pcm = array('h', (round(v/peak*.72*32767) for v in buffer))
import sys
if sys.byteorder != 'little':
    pcm.byteswap()
path = Path(__file__).resolve().parents[1] / 'assets/audio/pixwave_meadow.wav'
with wave.open(str(path), 'wb') as wav:
    wav.setparams((1,2,RATE,0,'NONE','not compressed'))
    wav.writeframes(pcm.tobytes())
print(f'{path.name}: {len(buffer)/RATE:.2f}s, {BPM} BPM, peak {max(pcm)/32767:.3f}')
