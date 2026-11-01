"""Drive the DOSBox-X text debugger through a pty. Run from capture/dosbox/ after harness/build_image.sh.
usage: python3 harness/dbg.py script.txt
script lines: 'send <text>' (types text+Enter), 'wait <sec>', 'raw <hex>' ; output (ANSI stripped) -> pty.out / stdout"""
import pyte,pty,os,sys,time,select,re,signal,fcntl,termios,struct
script=open(sys.argv[1]).read().splitlines()
pid,fd=pty.fork()
if pid==0:
    os.environ['TERM']='xterm'; os.environ['SDL_VIDEODRIVER']='dummy'   # no window: the debugger is driven through the pty
    os.execvp('dosbox-x',['dosbox-x','-conf',os.path.join(os.path.dirname(os.path.abspath(__file__)),'dosbox-x.conf'),'-fastlaunch','-nomenu','-break-start'])
fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',int(os.environ.get('ROWS','60')),200,0,0))
out=b''
screen=pyte.Screen(200,int(os.environ.get('ROWS','60'))); stream=pyte.ByteStream(screen)
def pump(t):
    global out
    t0=time.time()
    while time.time()-t0<t:
        r,_,_=select.select([fd],[],[],0.2)
        if r:
            try:
                d=os.read(fd,65536); out+=d; stream.feed(d)
            except OSError: return
pump(4)
for ln in script:
    if ln.startswith('send '):
        os.write(fd,ln[5:].encode()+b'\r'); pump(0.6)
    elif ln.startswith('wait '):
        pump(float(ln[5:]))
    elif ln.startswith('sh '):
        os.system(ln[3:])
    elif ln.startswith('snap'):
        print('=== SNAP', ln); print('\n'.join(l.rstrip() for l in screen.display if l.strip()))
    elif ln.startswith('raw '):
        os.write(fd,bytes.fromhex(ln[4:])); pump(0.6)
try: os.kill(pid,signal.SIGKILL)
except: pass
open('pty.out','wb').write(out)
t=re.sub(rb'\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][0-9A-B]',b'',out).decode('latin1')
print(t)
