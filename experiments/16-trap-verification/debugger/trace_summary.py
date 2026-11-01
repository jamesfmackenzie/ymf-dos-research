#!/usr/bin/env python3
"""Reduce harness/dbg.py output to a stable form.
usage: trace_summary.py seq  <dbg-output>   one line per register snapshot: 'sN CS:EIP EAX'  (cf. results/trap_seq.txt)
       trace_summary.py dump <dbg-output>   '## snap NAME' + the hex rows of each B-* memory dump (the A-* ones are timing dependent and not compared) (cf. results/dv_dump.txt)"""
import re, sys
mode, text = sys.argv[1], open(sys.argv[2], errors='replace').read()
for blk in text.split('=== SNAP snap ')[1:]:
    name, _, body = blk.partition('\n'); name = name.strip()
    if mode == 'seq' and re.fullmatch(r's\d+', name):
        m = re.search(r'EAX=(\w{8}).*?\n.*?CS=(\w{4})\s+EIP=(\w{8})', body)
        if m: print(f'{name} {m.group(2)}:{m.group(3)} EAX={m.group(1)}')
    elif mode == 'dump' and re.match(r'B-', name):
        print('## snap', name)
        for l in body.splitlines():
            m = re.match(r'\s+([0-9A-F]{6,8}) ((?:(?:[0-9A-F]{2}|pf) ){16})', l)
            if m: print('     ' + m.group(1) + ' ' + m.group(2).rstrip())
