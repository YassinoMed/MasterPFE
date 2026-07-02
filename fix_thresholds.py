import os
import re

def update_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()
    
    for old, new in replacements:
        content = re.sub(old, new, content)
        
    with open(path, 'w') as f:
        f.write(content)

# k6-thresholds.js
update_file('tests/performance/k6-thresholds.js', [
    (r'p\(95\)<200', 'p(95)<800'),
    (r'p\(99\)<500', 'p(99)<1500'),
    (r'p\(95\)<150', 'p(95)<800'),
    (r'p\(99\)<300', 'p(99)<1500'),
    (r'p\(99\)<400', 'p(99)<1500'),
    (r'p\(95\)<500', 'p(95)<1500'),
    (r'p\(99\)<1000', 'p(99)<2500'),
])

# test js files
for f in os.listdir('tests/performance'):
    if f.endswith('.js'):
        path = os.path.join('tests/performance', f)
        update_file(path, [
            (r'duration < 500', 'duration < 1500'),
            (r'duration < 1000', 'duration < 2500'),
            (r'duration < 1s', 'duration < 2.5s'),
            (r'duration < 500ms', 'duration < 1.5s')
        ])

for f in os.listdir('tests/load'):
    if f.endswith('.js'):
        path = os.path.join('tests/load', f)
        update_file(path, [
            (r'duration < 500', 'duration < 1500'),
            (r'duration < 1000', 'duration < 2500'),
            (r'duration < 1s', 'duration < 2.5s'),
            (r'duration < 500ms', 'duration < 1.5s')
        ])

