# import soundfile as sf
# f = sf.SoundFile('isolated_failure_sounds/A.wav')

# print('samples = {}'.format(len(f)))
# print('sample rate = {}'.format(f.samplerate))
# print('seconds = {}'.format(len(f) / f.samplerate))

import wave
import contextlib
fname = 'isolated_failure_sounds/D.wav'
with contextlib.closing(wave.open(fname,'r')) as f:
    frames = f.getnframes()
    framerate = f.getframerate()
    duration = frames / float(framerate)
    print('frames = {}'.format(frames))
    print('frame rate = {}'.format(framerate))
    print('duration = {}'.format(duration))