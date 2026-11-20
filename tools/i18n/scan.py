import re,glob,collections,sys,json
SKIP={'gui/ta_manualdata.pas','core/ta_catalogdata.pas','core/ta_showcasedata.pas','gui/ta_iconsdata.pas','core/ta_showcase.pas','core/ta_showcase2.pas','core/ta_blocksdemo.pas','core/ta_i18n_hr.pas'}
lit=re.compile(r"'((?:[^']|'')*)'")
# user-facing contexts: literal appears after one of these tokens on the same line
CTX=re.compile(r"(Notify|AskRunner|ShowMessage|MessageDlg|MessageBox|Caption\s*:=|\.Hint\s*:=|TextHint\s*:=|\bLbl|InputBox|InputQuery|raise Exception\.Create|\.Title\s*:=)\s*\(?")
words=re.compile(r"[A-Za-zČčĆćŠšŽžĐđ]{2,}")
res=[]
for f in sorted(glob.glob('**/*.pas',recursive=True)):
    if f in SKIP: continue
    for n,line in enumerate(open(f,encoding='utf-8',errors='ignore'),1):
        s=line.strip()
        if s.startswith('{') or s.startswith('//') or s.startswith('(*'): continue
        for c in CTX.finditer(line):
            seg=line[c.end():]
            # literals up to the end of the call expression on this line
            for m in lit.finditer(seg):
                t=m.group(1)
                if len(words.findall(t))>=1 and not re.fullmatch(r"[\W\d_]*",t):
                    res.append((f,n,t))
            break
json.dump(res,open('/tmp/i18n/cand.json','w'),ensure_ascii=False)
u=collections.Counter(t for _,_,t in res)
print(len(res),len(u))
c=collections.Counter(f for f,_,_ in res)
for f,k in c.most_common(30): print(k,f)
