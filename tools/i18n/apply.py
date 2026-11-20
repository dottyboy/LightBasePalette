import json,re,collections,os,sys
os.chdir(os.path.expanduser('~/Desktop/Development/LightPalette/src'))
u=json.load(open('/tmp/i18n/uniq.json'))
M={}
for n in (1,2,3):
    ns={}
    exec(open(f'/tmp/i18n/tr{n}.py').read(),ns)
    M.update(ns['T'])
idx={t:i for i,t in enumerate(u)}
def eng_for(orig):
    i=idx.get(orig)
    if i is None or i not in M: return None
    e=M[i]
    lead=orig[:len(orig)-len(orig.lstrip())]
    trail=orig[len(orig.rstrip()):]
    return lead+e.strip()+trail
# collisions: same English, different Croatian
pairs={}
coll=[]
for t,i in idx.items():
    e=eng_for(t)
    if e is None: continue
    if e in pairs and pairs[e]!=t: coll.append((e,pairs[e],t))
    pairs.setdefault(e,t)
# percent consistency
bad=[(e,t) for e,t in pairs.items() if e.count('%')!=t.count('%') or e.count('{')!=t.count('{')]
print('pairs',len(pairs),'collisions',len(coll),'pct/brace mismatch',len(bad))
for c in coll[:40]: print('COLL',c)
for b in bad[:20]: print('BAD',b)
json.dump({'pairs':pairs,'coll':coll},open('/tmp/i18n/pairs.json','w'),ensure_ascii=False)

# ---- overrides for collisions ----
OVR={'Briši':'Remove','Vrsta:':'Kind:','Spremi u bazu podataka':'Save into the database','Sva':'All fields','Novi':'New item'}
def eng_final(orig):
    if orig in OVR:
        lead=orig[:len(orig)-len(orig.lstrip())]; trail=orig[len(orig.rstrip()):]
        return lead+OVR[orig]+trail
    return eng_for(orig)
pairs={}
for t in idx:
    e=eng_final(t)
    if e is None: continue
    pairs.setdefault(e,t)
sel=json.load(open('/tmp/i18n/sel.json'))
CTX=re.compile(r"(Notify|AskRunner|ShowMessage|MessageDlg|MessageBox|Caption\s*:=|\.Hint\s*:=|TextHint\s*:=|\bLbl|InputBox|InputQuery|raise Exception\.Create|\.Title\s*:=)\s*\(?")
lit=re.compile(r"'((?:[^']|'')*)'")
files=collections.defaultdict(set)
for f,n,t in sel: files[f].add(n)
changed=0; skipped_tr=0; touched=[]
for f,lines in files.items():
    src=open(f,encoding='utf-8').read().split('\n')
    mod=False
    for n in lines:
        line=src[n-1]
        c=CTX.search(line)
        if not c: continue
        start=c.end()
        seg=line[start:]
        outs=[]
        pos=0
        res=''
        for m in lit.finditer(seg):
            t=m.group(1)
            e=eng_final(t)
            pre=seg[:m.start()].rstrip()
            if e is None or pre.endswith('Tr('):
                if pre.endswith('Tr('): skipped_tr+=1
                continue
            res+=seg[pos:m.start()]+"Tr('"+e.replace("'","''")+"')"
            pos=m.end()
            changed+=1
        res+=seg[pos:]
        if res!=seg:
            src[n-1]=line[:start]+res
            mod=True
    if mod:
        text='\n'.join(src)
        # add ta_i18n to uses
        im=text.find('\nimplementation')
        def add_uses(text):
            if re.search(r'\bta_i18n\b',text): return text
            if im>=0:
                m2=re.compile(r'\n(uses)\b').search(text,im)
                # a uses clause belonging to the implementation (before first routine)
                first_rout=re.compile(r'\n(procedure|function|constructor|destructor|var|const|type)\b').search(text,im)
                if m2 and (not first_rout or m2.start()<first_rout.start()):
                    return text[:m2.end()]+'\n  ta_i18n,'+text[m2.end():]
                # insert a new uses clause right after "implementation"
                k=text.find('\n',im+1)
                return text[:k]+'\n\nuses\n  ta_i18n;\n'+text[k:]
            m2=re.compile(r'\n(uses)\b').search(text)
            return text[:m2.end()]+'\n  ta_i18n,'+text[m2.end():] if m2 else text
        text=add_uses(text)
        open(f,'w',encoding='utf-8').write(text)
        touched.append(f)
print('replaced',changed,'already-Tr',skipped_tr,'files',len(touched))
# ---- generated hr table ----
items=sorted(pairs.items())
def q(s): return "'"+s.replace("'","''")+"'"
out=["unit ta_i18n_hr_ui;","{ GENERIRANO (tools/i18n): hrvatski prijevodi tekstova sucelja (engleski izvor -> hrvatski). Ne uredivati rucno;","  izmjene idu u tablicu i ponovno generiranje, ili u ta_i18n_hr za nove poruke. }","{$mode objfpc}{$H+}","","interface","","implementation","","uses","  ta_i18n;","","initialization"]
CH=100
for k in range(0,len(items),CH):
    chunk=items[k:k+CH]
    out.append("  RegisterTranslations('hr', [")
    out.append(",\n".join(f"    {q(e)}, {q(h)}" for e,h in chunk))
    out.append("  ]);")
out+=["","end."]
open('core/ta_i18n_hr_ui.pas','w',encoding='utf-8').write('\n'.join(out)+'\n')
print('pairs written',len(items))
