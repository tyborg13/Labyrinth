import json,glob,sys,os
root=sys.argv[1]
pr=json.load(open(os.path.join(root,'data/pattern_rule_text.json')))
keys=[]
def walk(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if isinstance(v,str) and v.startswith('@pattern'): keys.append(k)
            else: walk(v)
walk(pr)
blob=''
for f in glob.glob(os.path.join(root,'data/*.json')):
    if f.endswith('pattern_rule_text.json'): continue
    blob+=open(f).read().replace('\\"','"')
for f in glob.glob(os.path.join(root,'scripts/*.gd')):
    blob+=open(f).read()
orph=[k for k in keys if k not in blob]
print(len(keys),'keys,',len(orph),'orphaned')
for k in orph: print('  ',k[:150])
