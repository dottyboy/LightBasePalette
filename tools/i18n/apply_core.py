import json,re,collections,os
os.chdir(os.path.expanduser('~/Desktop/Development/LightPalette/src'))
u=json.load(open('/tmp/i18n/uniq_core.json'))
ns={}; exec(open('/tmp/i18n/trc.py').read(),ns); M=ns['T']
idx={t:i for i,t in enumerate(u)}
def eng(orig):
    i=idx.get(orig)
    if i is None or i not in M: return None
    lead=orig[:len(orig)-len(orig.lstrip())]; trail=orig[len(orig.rstrip()):]
    return lead+M[i].strip()+trail
sel=json.load(open('/tmp/i18n/sel_core.json'))
CTX=re.compile(r"(Notify|AskRunner|ShowMessage|MessageDlg|MessageBox|Caption\s*:=|\.Hint\s*:=|TextHint\s*:=|\bLbl|InputBox|InputQuery|raise Exception\.Create|\.Title\s*:=)\s*\(?")
lit=re.compile(r"'((?:[^']|'')*)'")
files=collections.defaultdict(set)
for f,n,t in sel: files[f].add(n)
pairs={}; changed=0; touched=[]
for f,lines in files.items():
    src=open(f,encoding='utf-8').read().split('\n'); mod=False
    for n in lines:
        line=src[n-1]; c=CTX.search(line)
        if not c: continue
        start=c.end(); seg=line[start:]; pos=0; res=''
        for m in lit.finditer(seg):
            t=m.group(1); e=eng(t)
            pre=seg[:m.start()].rstrip()
            if e is None or pre.endswith('Tr(') or pre.endswith('#31'): continue
            # literal glued to #nn chars or other literal: skip
            nxt=seg[m.end():m.end()+1]
            if nxt=='#' : continue
            res+=seg[pos:m.start()]+"Tr('"+e.replace("'","''")+"')"; pos=m.end(); pairs.setdefault(e,t); changed+=1
        res+=seg[pos:]
        if res!=seg: src[n-1]=line[:start]+res; mod=True
    if mod:
        text='\n'.join(src)
        if not re.search(r'\bta_i18n\b',text):
            im=text.find('\nimplementation')
            m2=re.compile(r'\n(uses)\b').search(text,im)
            first=re.compile(r'\n(procedure|function|constructor|destructor|var|const|type)\b').search(text,im)
            if m2 and (not first or m2.start()<first.start()):
                text=text[:m2.end()]+'\n  ta_i18n,'+text[m2.end():]
            else:
                k=text.find('\n',im+1)
                text=text[:k]+'\n\nuses\n  ta_i18n;\n'+text[k:]
        open(f,'w',encoding='utf-8').write(text); touched.append(f)
print('replaced',changed,'files',touched)
def q(s): return "'"+s.replace("'","''")+"'"
items=sorted(pairs.items())
out=["unit ta_i18n_hr_core;","{ GENERIRANO (tools/i18n): hrvatski prijevodi poruka jezgre (engleski izvor -> hrvatski). }","{$mode objfpc}{$H+}","","interface","","implementation","","uses","  ta_i18n;","","initialization"]
for k in range(0,len(items),100):
    out.append("  RegisterTranslations('hr', [")
    out.append(",\n".join(f"    {q(e)}, {q(h)}" for e,h in items[k:k+100]))
    out.append("  ]);")
out+=["","end."]
open('core/ta_i18n_hr_core.pas','w',encoding='utf-8').write('\n'.join(out)+'\n')
print('pairs',len(items))
