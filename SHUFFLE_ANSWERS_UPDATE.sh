#!/bin/bash
set -e

python3 - <<'PY'
from pathlib import Path

p = Path('index.html')
s = p.read_text()

old = '''function startQuiz(mode){if(!bank.length){alert('No question bank is available.');return}const count=mode==='exam'?65:mode==='quick'?10:bank.length;quiz={mode,items:shuffle(bank).slice(0,Math.min(count,bank.length)),index:0,correct:0,answers:[],locked:false,startedAt:new Date().toISOString()};page='quiz';render()}'''

new = '''function shuffleQuestionOptions(q){
 const entries=Object.entries(q.options||{});
 const shuffled=shuffle(entries);
 const labels='ABCDE'.slice(0,shuffled.length).split('');
 const options={};
 const keyMap={};
 shuffled.forEach(([oldKey,value],i)=>{const newKey=labels[i];options[newKey]=value;keyMap[String(oldKey)]=newKey});
 const originalCorrect=Array.isArray(q.correct)?q.correct.map(String):[String(q.correct)];
 const correct=originalCorrect.map(k=>keyMap[k]).filter(Boolean);
 return {...q,options,correct};
}

function startQuiz(mode){
 if(!bank.length){alert('No question bank is available.');return}
 const count=mode==='exam'?65:mode==='quick'?10:bank.length;
 const items=shuffle(bank).slice(0,Math.min(count,bank.length)).map(shuffleQuestionOptions);
 quiz={mode,items,index:0,correct:0,answers:[],locked:false,startedAt:new Date().toISOString()};page='quiz';render()
}'''

if old not in s:
    raise SystemExit('Could not find startQuiz() block. No changes were made.')

s=s.replace(old,new,1)
p.write_text(s)
PY

git add index.html
git commit -m "Randomize answer positions in all quiz modes"
git push origin main

echo "Answer position randomization deployed." 
