#!/bin/bash
set -e

python3 <<'PY'
from pathlib import Path
import re
p = Path('index.html')
s = p.read_text()

css = r'''
.mode-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:22px}
.mode-card{position:relative;display:flex;flex-direction:column;align-items:flex-start;min-height:215px;padding:23px;background:linear-gradient(145deg,#151b24,#10151c);color:var(--text);border:1px solid var(--line);border-radius:17px;text-align:left;overflow:hidden;cursor:pointer;transition:transform .18s ease,border-color .18s ease,box-shadow .18s ease}
.mode-card:before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--accent);opacity:.9}
.mode-card:hover{transform:translateY(-3px);border-color:#4a5a73;box-shadow:0 12px 32px rgba(0,0,0,.26)}
.mode-card:active{transform:translateY(-1px) scale(.995)}
.mode-card h2{margin:10px 0 7px;font-size:15px;letter-spacing:.09em;font-weight:800}
.mode-count{font-size:30px;line-height:1;font-weight:800;letter-spacing:-.5px;margin:13px 0 9px}
.mode-desc{font-size:14px;line-height:1.55;color:var(--muted)}
.mode-desc b{color:var(--text);font-weight:650}
.mode-kicker{display:inline-flex;align-items:center;gap:7px;color:var(--muted);font-size:11px;letter-spacing:.11em;font-weight:750}
.mode-dot{width:7px;height:7px;border-radius:50%;background:var(--accent);display:inline-block}
.mode-arrow{margin-top:auto;padding-top:20px;color:var(--accent);font-size:13px;font-weight:750}
#fullMode:before{background:#667487}
#fullMode .mode-dot{background:#667487}
@media(max-width:720px){.mode-grid{grid-template-columns:1fr;gap:12px}.mode-card{min-height:185px;padding:20px}.mode-count{font-size:27px}}
'''
if '/* QCM Trainer polished mode selector */' not in s:
    s=s.replace('</style>', '/* QCM Trainer polished mode selector */\n'+css+'\n</style>', 1)

start=s.find('function dashboard(){')
end=s.find('function startQuiz(', start)
if start < 0 or end < 0:
    raise SystemExit('Could not locate dashboard function')

new_dashboard='''function dashboard(){
 const n=bank.length;
 $("#main").innerHTML=`<section class="card">
 <div class="mode-kicker"><span class="mode-dot"></span> TRAINING</div>
 <h1 style="margin:7px 0 6px">Choose your training mode</h1>
 <p class="muted" style="margin-top:0">Choose how you want to practice today.</p>
 <div class="mode-grid">
   <button class="mode-card" id="examMode">
     <div class="mode-kicker">SIMULATE THE EXAM</div>
     <h2>EXAM MODE</h2>
     <div class="mode-count">65 Questions</div>
     <div class="mode-desc">A random selection from your ${n}-question bank.<br><b>60% required to pass.</b></div>
     <div class="mode-arrow">Start Exam →</div>
   </button>
   <button class="mode-card" id="fullMode">
     <div class="mode-kicker"><span class="mode-dot"></span> COMPLETE PRACTICE</div>
     <h2>FULL MODE</h2>
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
s=s[:start]+new_dashboard+s[end:]
p.write_text(s)
PY

git add index.html
git commit -m "Polish training mode selector"
git pull --rebase origin main
git push origin main

echo "UI update pushed successfully."
