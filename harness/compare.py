#!/usr/bin/env python3
"""Compare a harness run against a stored result file, section by section.
usage: compare.py <actual-run-output> <expected-file> [--ignore NAME ...] [--norm regs,ticks]
Both files are harness/run.sh output: sections headed '== ::/NAME.TXT'. Exit 0 if every expected
section is present and identical in the actual output, otherwise 1 (and prints the differences)."""
import sys, re, difflib
def sections(path):
    d, cur = {}, None
    for line in open(path, errors='replace').read().replace('\r', '').split('\n'):
        m = re.match(r'^== ::/(\S+)\s*$', line)
        if m: cur = m.group(1).upper(); d[cur] = []
        elif cur: d[cur].append(line.rstrip())
    return {k: '\n'.join(v).strip() for k, v in d.items()}
args = sys.argv[3:]; ign, norms, mode = set(), set(), None
for a in args:
    if a in ('--ignore', '--norm'): mode = a
    elif mode == '--ignore': ign.add(a.upper())
    elif mode == '--norm': norms.update(a.split(','))
# normalisers blank out values that legitimately vary between runs
NORM = {'regs': [(r'\b(si|di|esi|edi)=[0-9A-F]+', r'\1=*'),          # scratch-buffer addresses shift with the build
                 (r'\b(eax|ecx|edx|ebx)=[0-9A-F]{4}([0-9A-F]{4})', r'\1=****\2')],  # uninitialised upper halves
        'ticks': [(r'ticks=[0-9A-F]+', 'ticks=*')]}                     # BIOS-tick timings depend on host speed
def norm(text):
    for n in norms:
        for pat, rep in NORM[n]: text = re.sub(pat, rep, text)
    return text
act, exp = {k: norm(v) for k, v in sections(sys.argv[1]).items()}, {k: norm(v) for k, v in sections(sys.argv[2]).items()}
bad = 0
for k, v in exp.items():
    if k in ign: print(f'  skip   {k}'); continue
    if k not in act: print(f'  MISSING {k}'); bad += 1
    elif act[k] != v:
        print(f'  DIFF   {k}'); bad += 1
        for l in difflib.unified_diff(v.split('\n'), act[k].split('\n'), 'expected', 'actual', lineterm='', n=0): print('     ', l)
    else: print(f'  ok     {k}')
sys.exit(1 if bad or not exp else 0)
