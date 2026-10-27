"""Shared helpers: palette/sprites.js loading and the .spr source format (stdlib only).

.spr format (one or more sprites per file):
    # comment
    sprite <name> <w> <h> <section> "<Display label>"
    frame
    <h rows of exactly w chars>
    frame
    <h rows ...>
    end
"""
import json, os, re, shlex
HERE = os.path.dirname(os.path.abspath(__file__))

def load_js(path, var):
    t = open(path, encoding='utf-8').read()
    m = re.search(r'const\s+' + var + r'\s*=\s*(\{.*\})\s*;', t, re.S)
    return json.loads(m.group(1))

def load_palette(): return load_js(os.path.join(HERE, 'palette.js'), 'PALETTE')

def parse_spr(path):
    """returns (dict name->sprite, list of parse errors)"""
    out, errs, cur, frame = {}, [], None, None
    for ln, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        raw = line.rstrip('\r')
        s = raw.strip()
        if not s or s.startswith('#'): continue
        if s.startswith('sprite '):
            try: p = shlex.split(s)
            except ValueError as e: errs.append(f'{path}:{ln}: {e}'); continue
            if len(p) < 5: errs.append(f'{path}:{ln}: header needs: sprite name w h section ["label"]'); continue
            cur = {'w': int(p[2]), 'h': int(p[3]), 'section': p[4], 'label': p[5] if len(p) > 5 else p[1], 'frames': [], '_line': ln}
            if p[1] in out: errs.append(f'{path}:{ln}: duplicate sprite {p[1]}')
            out[p[1]] = cur; frame = None
        elif s == 'frame':
            if cur is None: errs.append(f'{path}:{ln}: frame outside sprite'); continue
            frame = []; cur['frames'].append(frame)
        elif s == 'end': cur = None; frame = None
        else:
            if frame is None: errs.append(f'{path}:{ln}: row outside frame: {s[:20]}'); continue
            frame.append(s)   # rows contain no spaces; strip only surrounding whitespace
    return out, errs
