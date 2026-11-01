# Builds DSDMAL.EXE: a copy of Dsdma.exe whose INT 31h dispatcher (IP 0x361D) bumps a per-function counter.
# usage: python3 make_dsdmal.py path/to/Dsdma.exe  (needs lg31.bin from: nasm -f bin lg31.asm -o lg31.bin)
# counter byte for AX=AHAL lives at image IP 0x9100 + (AH&0x1f)*16 + (AL&0xf) (zero-filled, unreferenced region);
# resident linear address under Jemm: 0xF7C09100 (Dsdma image base F7C00000, per Finding 16).
# file offset = IP + 0x790 (MZ header 0x200 + image offset IP+0x590).
import sys,struct
d=bytearray(open(sys.argv[1],'rb').read()); cave=open('lg31.bin','rb').read()
assert d[0x9790:0x9790+len(cave)+0x200]==bytes(len(cave)+0x200)
d[0x9790:0x9790+len(cave)]=cave
assert d[0x3db0:0x3db3]==bytes.fromhex('8b7e06')          # mov di,[bp+6] at IP 0x3620
d[0x3db0:0x3db3]=b'\xe9'+struct.pack('<h',0x9000-0x3623)  # jmp cave (cave jumps back to 0x3623)
open('DSDMAL.EXE','wb').write(d)
