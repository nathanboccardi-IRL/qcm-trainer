#!/bin/bash
set -e

python3 - <<'PY'
from pathlib import Path
import re

p=Path('index.html')
s=p.read_text()

def replace_between(s, start, end, replacement):
    a=re.search(start,s,re.S)
    if not a: raise SystemExit(f'Missing start: {start}')
    b=re.search(end,s[a.end():],re.S)
    if not b: raise SystemExit(f'Missing end: {end}')
    return s[:a.start()]+replacement+s[a.end()+b.start():]

# Add Quick Quiz styling.
if '.quick-card:before' not in s:
    s=s.replace('</style>','\n.quick-card:before{background:#9a7cff!important}\n.quick-card .mode-arrow{color:#9a7cff!important}\n@media(max-width:720px){.mode-grid{grid-template-columns:1fr}.mode-card{width:100%}}\n</style>',1)

# Add recovery state if this checkout still uses the older V3 state declaration.
s=s.replace('let user=null,bank=[],bankId=null,page="dashboard",authMode="signin",quiz=null;','let user=null,bank=[],bankId=null,page="dashboard",authMode="signin",quiz=null,recoveringPassword=false;')

s=replace_between(s,r'function render\(\)\{',r'\nfunction renderNav',r'''function render(){renderNav();if(recoveringPassword){renderPasswordRecovery();return}if(!user){renderLogin();return}if(page==='dashboard')renderDashboard();else if(page==='quiz')renderQuiz();else if(page==='history')renderHistory();else if(page==='bank')renderBank();else renderSettings()}
''')

s=replace_between(s,r'function renderLogin\(\)\{',r'\nasync function signIn',r'''function renderLogin(){$("main").innerHTML=`<section class="card"><h1>${authMode==='signin'?'Welcome back':'Create your account'}</h1><p class="muted">${authMode==='signin'?'Sign in once and QCM Trainer will keep your session on this device.':'Create your personal QCM Trainer account.'}</p><div style="display:flex;gap:8px;margin:18px 0 4px"><button class="ghost ${authMode==='signin'?'active':''}" id="signinTab">Sign In</button><button class="ghost ${authMode==='signup'?'active':''}" id="signupTab">Create Account</button></div><input id="email" type="email" placeholder="Email address" autocomplete="email"><input id="password" type="password" placeholder="Password" autocomplete="${authMode==='signin'?'current-password':'new-password'}"><div class="actions"><button class="primary" id="authBtn">${authMode==='signin'?'Sign In':'Create Account'}</button></div>${authMode==='signin'?'<div class="actions" style="justify-content:flex-start"><button class="ghost" id="forgot">Forgot Password?</button></div>':''}<div id="status" class="status"></div></section>`;$('signinTab').onclick=()=>{authMode='signin';render()};$('signupTab').onclick=()=>{authMode='signup';render()};$('authBtn').onclick=authMode==='signin'?signIn:signUp;$("forgot")?.addEventListener('click',sendReset)}
''')

# Add password recovery UI after sendReset if missing.
if 'function renderPasswordRecovery' not in s:
    idx=s.find('function renderDashboard')
    if idx<0: raise SystemExit('renderDashboard not found')
    recovery='''function renderPasswordRecovery(){$("main").innerHTML=`<section class="card"><h1>Set your new password</h1><p class="muted">Choose a new password for your QCM Trainer account.</p><input id="newPassword" type="password" placeholder="New password" autocomplete="new-password"><input id="confirmPassword" type="password" placeholder="Confirm password" autocomplete="new-password"><div class="actions"><button class="primary" id="updatePasswordBtn">Update Password</button></div><div id="status" class="status"></div></section>`;$("updatePasswordBtn").onclick=updatePassword}\nasync function updatePassword(){const a=$("newPassword").value,b=$("confirmPassword").value;if(a.length<6){setStatus('Password must be at least 6 characters.');return}if(a!==b){setStatus('Passwords do not match.');return}setStatus('Updating password…');const r=await supabase.auth.updateUser({password:a});if(r.error){setStatus(r.error.message,'danger');return}recoveringPassword=false;user=r.data.user||user;await loadBank();page='dashboard';render()}\n'''
    s=s[:idx]+recovery+s[idx:]

s=replace_between(s,r'function renderDashboard\(\)\{',r'\nfunction startQuiz',r'''function renderDashboard(){const n=bank.length;$("main").innerHTML=`<section class="card"><div class="mode-kicker"><span class="mode-dot"></span> TRAINING</div><h1 style="margin:7px 0 6px">Choose your training mode</h1><p class="muted">Choose how you want to practice today.</p><div class="grid"><div class="stat"><span class="muted">Question bank</span><b>${n}</b></div><div class="stat"><span class="muted">Exam pass mark</span><b>60%</b></div><div class="stat"><span class="muted">Account</span><b style="font-size:16px;word-break:break-word">${esc(user.email)}</b></div></div><div class="mode-grid"><button class="mode-card" id="exam"><span class="mode-kicker">SIMULATE THE EXAM</span><h2>EXAM MODE</h2><div class="mode-count">65 Questions</div><div class="mode-desc">A random selection from your ${n}-question bank.<br><b>60% required to pass.</b></div><div class="mode-arrow">Start Exam →</div></button><button class="mode-card quick-card" id="quick"><span class="mode-kicker">FAST PRACTICE</span><h2>QUICK QUIZ</h2><div class="mode-count">10 Questions</div><div class="mode-desc">A short random quiz for quick practice.<br><b>Final score and percentage saved.</b></div><div class="mode-arrow">Start Quick →</div></button><button class="mode-card" id="full"><span class="mode-kicker">COMPLETE PRACTICE</span><h2>FULL MODE</h2><div class="mode-count">${n} Questions</div><div class="mode-desc">Practice the complete question bank in random order.<br><b>Final percentage shown and saved.</b></div><div class="mode-arrow">Start Full →</div></button></div></section>`;$("exam").onclick=()=>startQuiz('exam');$("quick").onclick=()=>startQuiz('quick');$("full").onclick=()=>startQuiz('full')}
''')

s=replace_between(s,r'function startQuiz\(mode\)\{',r'\nfunction renderQuiz',r'''function startQuiz(mode){if(!bank.length){alert('No question bank is available.');return}const count=mode==='exam'?65:mode==='quick'?10:bank.length;quiz={mode,items:shuffle(bank).slice(0,Math.min(count,bank.length)),index:0,correct:0,answers:[],locked:false,startedAt:new Date().toISOString()};page='quiz';render()}
''')

s=replace_between(s,r'function renderQuiz\(\)\{',r'\nfunction validateAnswer',r'''function renderQuiz(){if(!quiz){renderDashboard();return}if(quiz.index>=quiz.items.length){finishQuiz();return}const q=quiz.items[quiz.index];const selected=quiz.answers[quiz.index]?.selected||[];const correct=Array.isArray(q.correct)?q.correct.map(String):[String(q.correct)];const multi=correct.length>1;const score=pct(quiz.correct,quiz.index);const label=quiz.mode==='exam'?'Exam Mode':quiz.mode==='quick'?'Quick Quiz':'Full Mode';const entries=Object.entries(q.options||{}).sort(([a],[b])=>a.localeCompare(b));$("main").innerHTML=`<section class="card"><div class="topline"><span class="pill">${label} · Question ${quiz.index+1} / ${quiz.items.length}</span><span class="score">Score: ${score}%</span></div><div class="progress"><div class="bar" style="width:${quiz.index/quiz.items.length*100}%"></div></div><div class="muted">${multi?'Select all that apply':'Select one answer'}</div><div class="q">${esc(q.question)}</div><div class="answers">${entries.map(([k,v])=>`<label class="answer ${quiz.locked&&correct.includes(k)?'correct':''} ${quiz.locked&&selected.includes(k)&&!correct.includes(k)?'incorrect':''}"><input name="answer" type="${multi?'checkbox':'radio'}" value="${esc(k)}" ${selected.includes(k)?'checked':''} ${quiz.locked?'disabled':''}><span><b>${esc(k)}.</b> ${esc(v)}</span></label>`).join('')}</div>${quiz.locked?`<div class="feedback ${quiz.answers[quiz.index].isCorrect?'good':'bad'}"><strong>${quiz.answers[quiz.index].isCorrect?'Correct':'Incorrect'}</strong><div class="explain"><b>Correct answer:</b> ${esc(correct.join(', '))}<br><br>${esc(q.explanation||'No explanation available.')}</div></div>`:''}<div class="actions">${quiz.locked?`<button class="primary" id="next">${quiz.index===quiz.items.length-1?'Finish Quiz':'Next Question'}</button>`:'<button class="primary" id="validate">Validate Answer</button>'}</div></section>`;$("validate")?.addEventListener('click',validateAnswer);$("next")?.addEventListener('click',()=>{quiz.index++;quiz.locked=false;render()})}
''')

s=replace_between(s,r'async function finishQuiz\(\)\{',r'\nasync function renderHistory',r'''async function finishQuiz(){const mode=quiz.mode,score=quiz.correct,total=quiz.items.length,p=pct(score,total),passed=mode==='exam'?p>=60:null;const attempt={user_id:user.id,question_bank_id:bankId,score,total,percentage:p,passed,started_at:quiz.startedAt,completed_at:new Date().toISOString(),answers:quiz.answers,mode};const r=await supabase.from('quiz_attempts').insert(attempt);if(r.error){console.error(r.error);alert('The quiz result could not be saved to history. Please try again.');return}const label=mode==='exam'?'Exam Mode':mode==='quick'?'Quick Quiz':'Full Mode';$("main").innerHTML=`<section class="card"><span class="pill">${label} complete</span><h1>Quiz complete</h1><div class="result ${passed===null?'':passed?'pass':'fail'}">${p}%</div><p class="muted">${score} correct out of ${total}.</p>${passed!==null?`<p class="${passed?'good':'danger'}"><b>${passed?'PASS':'FAIL'}</b> · 60% required.</p>`:'<p class="good"><b>Saved to History</b></p>'}<div class="actions"><button class="primary" id="retry">Retry ${label}</button><button class="ghost" id="historyBtn">View History</button><button class="ghost" id="dashBtn">Dashboard</button></div></section>`;$("retry").onclick=()=>startQuiz(mode);$("historyBtn").onclick=()=>{quiz=null;page='history';render()};$("dashBtn").onclick=()=>{quiz=null;page='dashboard';render()}}
''')

s=replace_between(s,r'async function renderHistory\(\)\{',r'\nfunction renderBank',r'''async function renderHistory(){$("main").innerHTML=`<section class="card"><h1>Quiz History</h1><div id="history" class="empty">Loading…</div></section>`;const r=await supabase.from('quiz_attempts').select('mode,score,total,percentage,passed,completed_at').eq('user_id',user.id).order('completed_at',{ascending:false});if(r.error){$("history").textContent=r.error.message;return}if(!r.data?.length){$("history").textContent='No quizzes completed yet.';return}$("history").className='';$("history").innerHTML=`<table><thead><tr><th>Date</th><th>Mode</th><th>Score</th><th>Percentage</th><th>Result</th></tr></thead><tbody>${r.data.map(x=>{const m=x.mode==='exam'?'Exam':x.mode==='quick'?'Quick':'Full';return `<tr><td>${new Date(x.completed_at).toLocaleString()}</td><td>${m}</td><td>${x.score}/${x.total}</td><td>${Number(x.percentage)}%</td><td>${x.passed===null?'—':x.passed?'<span class="good">PASS</span>':'<span class="danger">FAIL</span>'}</td></tr>`}).join('')}</tbody></table>`}
''')

# Fix auth recovery event.
old="supabase.auth.onAuthStateChange((event,session)=>{if(event==='SIGNED_IN'||event==='TOKEN_REFRESHED'){user=session?.user||user;if(user)loadBank().then(render)}if(event==='SIGNED_OUT'){user=null;bank=[];quiz=null;page='dashboard';render()}if(event==='PASSWORD_RECOVERY'){render()}});"
new="supabase.auth.onAuthStateChange((event,session)=>{if(event==='PASSWORD_RECOVERY'){recoveringPassword=true;render();return}if(event==='SIGNED_IN'||event==='TOKEN_REFRESHED'){user=session?.user||user;if(user&&!recoveringPassword)loadBank().then(render)}if(event==='SIGNED_OUT'){user=null;bank=[];quiz=null;page='dashboard';recoveringPassword=false;render()}});"
if old in s:s=s.replace(old,new,1)

p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p=Path('sw.js')
s=p.read_text().replace("const CACHE='qcm-trainer-v2'","const CACHE='qcm-trainer-v4'").replace("'./questions.json',",'')
p.write_text(s)
PY

git add index.html sw.js
git diff --cached --quiet && { echo 'No V4 changes detected.'; exit 0; }
git commit -m "Add Quick Quiz and fix history"
git pull --rebase origin main
git push origin main

echo "V4 update complete."
