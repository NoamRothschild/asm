import re, os
from sys import argv
os.chdir(os.path.abspath(os.path.dirname(__file__)))

pattern = '^([^\s.;][^:]*)(?=:\s*(;.*)?\s*$)'
labels = []

for root, dirs, files in os.walk(".", topdown=False):
    for name in files:
        if not name.endswith('.asm'): continue
        if 'misc' in root: continue
        file = open(os.path.join(root, name), 'r', encoding='utf-8').read()
        matches = re.findall(pattern, file, re.MULTILINE | re.DOTALL)
        for i, match in enumerate(matches):
            matches[i] = match[0].split('\n')[-1].split('\t')[-1]
        labels += matches

docs = open('docs/docs.json', 'r').read()
for label in labels:
    if label == '_start': continue
    if label.startswith('.'): continue
    if label not in docs:
        print(label)
