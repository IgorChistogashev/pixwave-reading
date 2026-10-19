"""Original soft pixel-game feedback; mathematical synthesis, MIT."""
from pathlib import Path
import wave, math, struct
root = Path(__file__).resolve().parents[1]/'assets/audio'
for name,notes in [('light',[(76,0,.13),(83,.08,.17)]),('gate',[(60,0,.5),(64,.08,.5),(67,.16,.5),(72,.24,.6)])]:
 samples=[0.0]*22050
 for note,start,length in notes:
  f=440*2**((note-69)/12)
  for i in range(int(length*22050)):
   t=i/22050
   env=min(1,t/.008)*(1-t/length)**2
   samples[int(start*22050)+i]+=math.sin(2*math.pi*f*t)*env*.2
 with wave.open(str(root/(name+'.wav')),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(v*32767)) for v in samples))
