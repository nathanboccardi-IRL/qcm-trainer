#!/bin/bash
set -e
python3 - <<'PY'
from pathlib import Path
import re
p=Path('index.html')
s=p.read_text()
css='''\n.mode-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:22px}\n.mode-card{position:relative;text-align:left;background:linear-gradient(145deg,#151b24,#10151c);color:var(--text);border:1px solid var(--line);border-radius:16px;padding:22px;min-height:210px;cursor:pointer;transition:transform .18s ease,border-color .18s ease,box-shadow .18s ease;overflow:hidden}\n.mode-card:before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--accent);opacity:.9}\n.mode-card:hover{transform:translateY(-3px);border-color:#4a5a73;box-shadow:0 12px 32px rgba(0,0,0,.25)}\n.mode-card:active{transform:translateY(-1px) scale(.995)}\n.mode-card h2{margin:0 0 8px;font-size:15px;letter-spacing:.08em}\n.mode-count{font-size:30px;font-weight:800;letter-spacing:-.6px;margin:10px 0}\n.mode-desc{color:var(--muted);line-height:1.55;font-size:14px}.mode-desc b{color:var(--text);font-weight:650}\n.mode-arrow{position:absolute;right:20px;bottom:18px;color:var(--accent);font-weight:750;font-size:13px}\n.mode-kicker{display:inline-flex;align-items:center;gap:6px;color:var(--muted);font-size:12px}\n.mode-dot{width:7px;height:7px;border-radius:50%;background:var(--accent);display:inline-block}\n@media(max-width:720px){.mode-grid{grid-template-columns:1fr}.mode-card{min-height:185px}}\n'''
marker='</style>'
if '.mode-grid{' not in s:
    s=s.replace(marker,css+marker,1)
new=r'''function dashboard(){
 const n=bank.length;
 $("#main").innerHTML=`<section class="card">
 <div class="mode-kicker"><span class="mode-dot"></span> TRAINING</div>
 <h1 style="margin-top:7px">Choose your training mode</h1>
 <p class="muted">Choose how you want to practice today.</p>
 <div class="mode-grid">
   <button class="mode-card" id="examMode">
     <div class="mode-kicker">SIMULATE THE EXAM</div>
     <h2 style="margin-top:12px">EXAM MODE</h2>
     <div class="mode-count">65 Questions</div>
     <div class="mode-desc">A random selection from your ${n}-question bank.<br><b>60% required to pass.</b></div>
     <div class="mode-arrow">Start Exam →</div>
   </button>
   <button class="mode-card" id="fullMode">
     <div class="mode-kicker">COMPLETE PRACTICE</div>
     <h2 style="margin-top:12px">FULL MODE</h2>
     <div class="mode-count">${n} Questions</div>
     <div class="mode-desc">Practice the complete question bank in a random order.<br><b>Final percentage shown at the end.</b></div>
     <div class="mode-arrow">Start Full →</div>
   </button>
 </div>
 </section>`;
 $("#examMode").onclick=()=>startQuiz("exam");
 $("#fullMode").onclick=()=>startQuiz("full");
}
'''
pattern=r'function dashboard\(\)\{.*?\n\}\nfunction startQuiz'
s2,n=re.subn(pattern,new+'function startQuiz',s,count=1,flags=re.S)
if n!=1: raise SystemExit('Could not locate dashboard function')
p.write_text(s2)
PY

git add index.html
git commit -m "Polish training mode selector"
git pull --rebase origin main
git push origin main
