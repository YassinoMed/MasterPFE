#!/usr/bin/env bash
# Print consolidated k6 benchmark summary from reports/k6/*/k6-report-*.json
set -euo pipefail

python3 - <<'PY'
import json, os, glob
rows=[]
for d in sorted(os.listdir('reports/k6'), reverse=True)[:4]:
    for f in sorted(glob.glob('reports/k6/'+d+'/k6-report-*.json')):
        try:
            doc=json.load(open(f))
        except Exception:
            continue
        meta=doc.get('meta',{}); s=doc.get('summary',{})
        if not meta or not s: continue
        rows.append([
            d[-6:], meta.get('test_name','-'), s.get('total_requests','-'),
            f"{(s.get('failure_rate',0) or 0)*100:.1f}%",
            f"{s.get('avg_latency_ms',0) or 0:.1f}ms",
            f"{s.get('p95_latency_ms',0) or 0:.1f}ms",
        ])
print('| Run | Test | Requêtes | Fail% | Avg (ms) | p95 (ms) |')
print('|---|---:|---:|---:|---:|---:|')
for r in rows:
    print(f'| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | {r[5]} |')
PY
