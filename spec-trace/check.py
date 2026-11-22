#!/usr/bin/env python3
"""Check the spec, its firewall from the research, and the trace map; regenerate spec/INDEX.md.

Spec (spec/dsdma, spec/setupds and spec/interaction; each a numbered chapter set):
  - every requirement line is `- **ID** `LEVEL` `tag` [`DS-Y`/`DS-I`] - text`; IDs are unique and consecutive per prefix
  - every `PREFIX-n` mention resolves
  - firewall: no finding/experiment numbers, links out of the folder, harness or script mentions, internal addresses
    or decompiler symbols of the original program (the spec must stand alone and describe behaviour, not code)
Trace map (spec-trace/TRACE.md):
  - every requirement has exactly one row and every row a requirement; level and tag match the spec
  - `verified` rows cite evidence (a finding, an experiment or a datasheet); cited findings and experiments exist

usage: python3 spec-trace/check.py          (exit status 1 on any problem)"""
import re, sys, glob, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SPEC = f'{ROOT}/spec'
PREFIXES = 'HW|EMU|TRAP|DPMI|LIFE|TEST|SDS|STEST|INT|ITEST'
DECS = 'DEC|SDEC|IDEC'
REQ = re.compile(r'^- \*\*([A-Z]+)-(\d+)\*\* `(MUST|SHOULD|MAY)` `(verified|inferred|untested)`(?: `(DS-[YI](?: DS-[YI])*)`)? - (.*)$')
DEC = re.compile(r'^- \*\*(' + DECS + r')-(\d+)\*\* - (.*)$')

def nums(pattern):
    return {int(m.group(1)) for p in glob.glob(pattern) if (m := re.match(r'(\d+)-', os.path.basename(p)))}
findings = nums(f'{ROOT}/findings/[0-9][0-9]-*.md')
experiments = nums(f'{ROOT}/experiments/[0-9][0-9]-*')

problems, reqs, ids = [], [], set()
files = sorted(glob.glob(f'{SPEC}/*/[0-9][0-9]-*.md'))
texts = {f: open(f).read() for f in files}
readme = open(f'{SPEC}/README.md').read()

for f, text in texts.items():
    name = os.path.relpath(f, SPEC)
    for n, line in enumerate(text.split('\n'), 1):
        if not re.match(r'- \*\*[A-Z]+-\d+\*\*', line): continue
        d = DEC.match(line)
        if d: ids.add(f'{d.group(1)}-{d.group(2)}'); continue
        m = REQ.match(line)
        if not m: problems.append(f'{name}:{n}: malformed requirement line: {line[:70]}'); continue
        prefix, num, level, tag, ds, body = m.groups()
        rid = f'{prefix}-{num}'
        if rid in ids: problems.append(f'{name}:{n}: duplicate id {rid}')
        ids.add(rid)
        reqs.append((rid, prefix, int(num), level, tag, ds or '', body, name))

by_prefix = {}
for r in reqs: by_prefix.setdefault(r[1], []).append(r[2])
for p, ns in by_prefix.items():
    if ns != list(range(1, len(ns) + 1)): problems.append(f'{p}: ids are not consecutive 1..{len(ns)}: {ns}')

alltext = '\n'.join(texts.values())
for m in re.finditer(r'`((?:' + PREFIXES + '|' + DECS + r')-\d+)`', alltext):
    if m.group(1) not in ids: problems.append(f'reference to unknown id {m.group(1)}')

# firewall: the spec must not point at, or be written in terms of, the research or the original's code
FIREWALL = [(r'\b[FE]\d{1,2}\b', 'finding/experiment number'), (r'[Ff]inding \d', 'finding reference'),
            (r'[Ee]xperiments?\b', 'experiment'), (r'\bharness\b', 'harness'), (r'\.\./', 'link out of the spec folder'),
            (r'\]\(https?:', 'external link'), (r'verify\.sh|run-experiment', 'research script'),
            (r'\bFUN_[0-9A-Fa-f]+', 'decompiler symbol'), (r'\b0x[0-9A-Fa-f]{3,}\b', '0x address'),
            (r'\b[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4,8}\b', 'segment:offset'), (r'\bIP\s*0x', 'IP address'),
            (r'\[[0-9A-Fa-f]{4}\]', 'bracketed data address'), (r'[Gg]hidra|decompil', 'decompiler')]
# product and file names of the original package: allowed only where a scope chapter or the README identifies the originals
NAMES = [(r'ds\.ini', 'settings file name')]
IDENT = [(r'(?i)\b(?:setupds|dsdma|loadtsr|ymfirq|fmmidi)(?![/\w])', 'name of an original program or file')]
# the settings-file keys include one (LOADTSR) that is also the boot batch file's name; allowed in the interaction spec only
IDENT_KEYS = [(r'(?i)\b(?:setupds|dsdma|ymfirq|fmmidi)(?![/\w])', 'name of an original program or file')]
for f, text in {**texts, f'{SPEC}/README.md': readme}.items():
    allowed_names = os.path.basename(f) in ('00-scope-and-terms.md', 'README.md')
    ident = IDENT_KEYS if f.startswith(f'{SPEC}/interaction/') else IDENT
    for n, line in enumerate(text.split('\n'), 1):
        for pat, what in FIREWALL + NAMES + ([] if allowed_names else ident):
            for m in re.finditer(pat, line):
                problems.append(f'{os.path.relpath(f, SPEC)}:{n}: {what}: {m.group(0)}')

# trace map
trace = open(f'{HERE}/TRACE.md').read()
rows = {}
for n, line in enumerate(trace.split('\n'), 1):
    c = [x.strip() for x in line.strip().strip('|').split('|')]
    if len(c) == 7 and re.fullmatch(r'(?:' + PREFIXES + r')-\d+', c[0]):
        if c[0] in rows: problems.append(f'TRACE.md:{n}: duplicate row {c[0]}')
        rows[c[0]] = (c[1], c[2], c[3], c[4], c[5], n)
spec_by_id = {r[0]: r for r in reqs}
for rid in spec_by_id:
    if rid not in rows: problems.append(f'TRACE.md: no row for {rid}')
for rid, (lv, tag, F, E, D, n) in rows.items():
    if rid not in spec_by_id: problems.append(f'TRACE.md:{n}: row {rid} has no requirement in the spec'); continue
    s = spec_by_id[rid]
    if lv != s[3]: problems.append(f'TRACE.md:{n}: {rid}: level {lv} differs from spec {s[3]}')
    if tag != s[4]: problems.append(f'TRACE.md:{n}: {rid}: tag {tag} differs from spec {s[4]}')
    fs = [int(x) for x in re.findall(r'\[F(\d+)\]', F)]; es = [int(x) for x in re.findall(r'\[E(\d+)\]', E)]
    for x in fs:
        if x not in findings: problems.append(f'TRACE.md:{n}: {rid}: F{x} does not exist')
    for x in es:
        if x not in experiments: problems.append(f'TRACE.md:{n}: {rid}: E{x} does not exist')
    if tag == 'verified' and not (fs or es or D not in ('', '-')): problems.append(f'TRACE.md:{n}: {rid}: verified needs evidence')
    if s[5] and not all(d in D for d in s[5].split()): problems.append(f'TRACE.md:{n}: {rid}: spec cites {s[5]}, trace shows {D}')

# index
order = PREFIXES.split('|')
reqs.sort(key=lambda r: (order.index(r[1]), r[2]))
counts = {t: sum(1 for r in reqs if r[4] == t) for t in ('verified', 'inferred', 'untested')}
out = ['# Requirement index', '', '*Generated file. Do not edit by hand.*', '',
       f'{len(reqs)} requirements: {counts["verified"]} verified, {counts["inferred"]} inferred, {counts["untested"]} untested.', '',
       '| ID | Level | Evidence | Datasheet | Requirement | File |', '|---|---|---|---|---|---|']
for rid, prefix, num, level, tag, ds, body, name in reqs:
    short = body.split('. ')[0].rstrip('.')
    short = (short[:140] + '...') if len(short) > 140 else short
    out.append(f'| {rid} | {level} | {tag} | {ds} | {short.replace("|", "/")} | [{name}]({name}) |')
open(f'{SPEC}/INDEX.md', 'w').write('\n'.join(out) + '\n')

if problems:
    print('\n'.join(problems)); print(f'\n{len(problems)} problem(s)'); sys.exit(1)
print(f'OK: {len(reqs)} requirements ({counts["verified"]} verified, {counts["inferred"]} inferred, {counts["untested"]} untested); trace map complete; index written')
