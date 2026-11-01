import re,sys
t=open(sys.argv[1],errors='replace').read()
parts=re.split(r'=== SNAP snap (\S+)\n',t)
snaps={parts[i]:parts[i+1] for i in range(1,len(parts),2)}
def buf(stop):
    mem={}
    for k in range(5):
        s=snaps.get('s%d-%d'%(stop,k))
        if s is None: return None
        for m in re.finditer(r'^\s+(F7C0[0-9A-F]{4}) ((?:[0-9A-F]{2} ){16})',s,re.M):
            mem[int(m.group(1),16)]=bytes.fromhex(m.group(2))
    return mem
def counts(stop):
    mem=buf(stop)
    if mem is None: return None
    c={}
    for a in range(0xF7C09100,0xF7C09300,16):
        row=mem.get(a)
        if row is None: continue
        for al in range(16):
            if row[al] not in (0,): c[((a-0xF7C09100)//16<<8)|al]=row[al]
    return c
prev={}
for s in range(4):
    c=counts(s)
    if c is None: print('stop',s,'missing'); continue
    print('stop',s,'cumulative:',' '.join('%04X:%d'%(k,v) for k,v in sorted(c.items())))
    d={k:v-prev.get(k,0) for k,v in c.items() if v!=prev.get(k,0)}
    print('  delta:',' '.join('%04X:%d'%(k,v) for k,v in sorted(d.items())))
    prev=c
