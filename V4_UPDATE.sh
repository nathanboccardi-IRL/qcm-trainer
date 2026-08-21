#!/bin/bash
set -e

python3 - <<'PY'
from pathlib import Path
import re

p = Path('index.html')
s = p.read_text()

# Add Quick Quiz styling.
quick_css = r'''
.quick-card:before{background:#9a7cff}
#quick .mode-arrow{color:#9a7cff}
@media(max-width:720px){.mode-card{width:100%}}
'''
if '.quick-card:before' not in s:
    s=s.replace('</style>', quick_css+'\n</style>',1)

# Add recovery state.
s=s.replace("let user=null,bank=[],bankId=null,page=\"dashboard\",authMode=\"signin\",quiz=null;","let user=null,bank=[],bankId=null,page=\"dashboard\",authMode=\"signin\",quiz=null,recoveringPassword=false;")

# Replace render() so password recovery gets its own screen.
pat=r"function render\(\)\{.*?\n\}"
new_render='''function render(){renderNav();if(recoveringPassword){renderPasswordRecovery();return}if(!user){renderLogin();return}if(page==='dashboard')renderDashboard();else if(page==='quiz')renderQuiz();else if(page==='history')renderHistory();else if(page==='bank')renderBank();else renderSettings()}'''
s,n=re.subn(pat,new_render,s,count=1,flags=re.S)
if n!=1: raise SystemExit('render() not found')

# Replace login UI to use password auth as the primary path.
pat=r"function renderLogin\(\)\{.*?\n\}"
new_login='''function renderLogin(){
$("main").innerHTML=`<section class="card"><h1>${authMode==='signin'?'Welcome back':'Create your account'}</h1><p class="muted">${authMode==='signin'?'Sign in once and QCM Trainer will keep your session on this device.':'Create your personal QCM Trainer account.'}</p><div style="display:flex;gap:8px;margin:18px 0 4px"><button class="ghost ${authMode==='signin'?'active':''}" id="signinTab">Sign In</button><button class="ghost ${authMode==='signup'?'active':''}" id="signupTab">Create Account</button></div><input id="email" type="email" placeholder="Email address" autocomplete="email"><input id="password" type="password" placeholder="Password" autocomplete="${authMode==='signin'?'current-password':'new-password'}"><div class="actions"><button class="primary" id="authBtn">${authMode==='signin'?'Sign In':'Create Account'}</button></div>${authMode==='signin'?'<div class="actions" style="justify-content:flex-start"><button class="ghost" id="forgot">Forgot Password?</button></div>':''}<div id="status" class="status"></div></section>`;
$("signinTab").onclick=()=>{authMode='signin';render()};$("signupTab").onclick=()=>{authMode='signup';render()};$("authBtn").onclick=authMode==='signin'?signIn:signUp;$("forgot")?.addEventListener('click',sendReset);
}'''
s,n=re.subn(pat,new_login,s,count=1,flags=re.S)
if n!=1: raise SystemExit('renderLogin() not found')

# Insert password recovery screen/function and replace auth listener block.
pat=r"async function sendReset\(\).*?\n"
# keep existing sendReset, insert after it
m=re.search(pat,s,flags=re.S)
if not m: raise SystemExit('sendReset not found')
insert='''async function updatePassword(){const a=$("newPassword")?.value||"",b=$("confirmPassword")?.value||"";if(a.length<6){setStatus('Password must be at least 6 characters.');return}if(a!==b){setStatus('Passwords do not match.');return}setStatus('Updating password…');const r=await supabase.auth.updateUser({password:a});if(r.error){setStatus(r.error.message,'danger');return}recoveringPassword=false;user=r.data.user||user;setStatus('Password updated. Signing you in…','good');await loadBank();page='dashboard';setTimeout(render,300)}
function renderPasswordRecovery(){$("main").innerHTML=`<section class="card"><h1>Set your new password</h1><p class="muted">Choose a new password for your QCM Trainer account.</p><input id="newPassword" type="password" placeholder="New password" autocomplete="new-password"><input id="confirmPassword" type="password" placeholder="Confirm password" autocomplete="new-password"><div class="actions"><button class="primary" id="updatePasswordBtn">Update Password</button></div><div id="status" class="status"></div></section>`;$("updatePasswordBtn").onclick=updatePassword}
'''
s=s[:m.end()]+insert+s[m.end():]

# Dashboard: Exam 65, Quick 10, Full all, pass mark 60.
pat=r"function renderDashboard\(\)\{.*?\n\}"
new_dash='''function renderDashboard(){const n=bank.length;$("main").innerHTML=`<section class="card"><div class="mode-kicker"><span class="mode-dot"></span> TRAINING</div><h1 style="margin:7px 0 6px">Choose your training mode</h1><p class="muted" style="margin-top:0">Choose how you want to practice today.</p><div class="grid"><div class="stat"><span class="muted">Question bank</span><b>${n}</b></div><div class="stat"><span class="muted">Exam pass mark</span><b>60%</b></div><div class="stat"><span class="muted">Account</span><b style="font-size:16px;word-break:break-word">${esc(user.email)}</b></div></div><div class="mode-grid"><button class="mode-card" id="exam"><span class="mode-kicker">SIMULATE THE EXAM</span><h2>EXAM MODE</h2><div class="mode-count">65 Questions</div><div class="mode-desc">A random selection from your ${n}-question bank.<br><b>60% required to pass.</b></div><div class="mode-arrow">Start Exam →</div></button><button class="mode-card quick-card" id="quick"><span class="mode-kicker">FAST PRACTICE</span><h2>QUICK QUIZ</h2><div class="mode-count">10 Questions</div><div class="mode-desc">A short random quiz for quick practice.<br><b>Final score and percentage saved.</b></div><div class="mode-arrow">Start Quick →</div></button><button class="mode-card" id="full"><span class="mode-kicker">COMPLETE PRACTICE</span><h2>FULL MODE</h2><div class="mode-count">${n} Questions</div><div class="mode-desc">Practice the complete question bank in a random order.<br><b>Final percentage shown and saved.</b></div><div class="mode-arrow">Start Full →</div></button></div></section>`;$("exam").onclick=()=>startQuiz('exam');$("quick").onclick=()=>startQuiz('quick');$("full").onclick=()=>startQuiz('full')}'''
s,n=re.subn(pat,new_dash,s,count=1,flags=re.S)
if n!=1: raise SystemExit('renderDashboard() not found')

# Quiz creation.
pat=r"function startQuiz\(mode\)\{.*?\n\}"
new_start='''function startQuiz(mode){if(!bank.length){alert('No question bank is available.');return}const count=mode==='exam'?65:mode==='quick'?10:bank.length;quiz={mode,items:shuffle(bank).slice(0,Math.min(count,bank.length)),index:0,correct:0,answers:[],locked:false,startedAt:new Date().toISOString()};page='quiz';render()}'''
s,n=re.subn(pat,new_start,s,count=1,flags=re.S)
if n!=1: raise SystemExit('startQuiz() not found')

# Quiz renderer with dynamic A-E options and mode labels.
pat=r"function renderQuiz\(\)\{.*?\n\}"
new_quiz='''function renderQuiz(){if(!quiz){renderDashboard();return}if(quiz.index>=quiz.items.length){finishQuiz();return}const q=quiz.items[quiz.index];const selected=quiz.answers[quiz.index]?.selected||[];const correct=Array.isArray(q.correct)?q.correct.map(String):[String(q.correct)];const multi=correct.length>1;const score=pct(quiz.correct,quiz.index);const label=quiz.mode==='exam'?'Exam Mode':quiz.mode==='quick'?'Quick Quiz':'Full Mode';$("main").innerHTML=`<section class="card"><div class="topline"><span class="pill">${label} · Question ${quiz.index+1} / ${quiz.items.length}</span><span class="score">Score: ${score}%</span></div><div class="progress"><div class="bar" style="width:${quiz.index/quiz.items.length*100}%"></div></div><div class="muted">${multi?'Select all that apply':'Select one answer'}</div><div class="q">${esc(q.question)}</div><div class="answers">${Object.entries(q.options||{}).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>`<label class="answer ${quiz.locked&&correct.includes(k)?'correct':''} ${quiz.locked&&selected.includes(k)&&!correct.includes(k)?'incorrect':''}"><input name="answer" type="${multi?'checkbox':'radio'}" value="${esc(k)}" ${selected.includes(k)?'checked':''} ${quiz.locked?'disabled':''}><span><b>${esc(k)}.</b> ${esc(v)}</span></label>`).join('')}</div>${quiz.locked?`<div class="feedback ${quiz.answers[quiz.index].isCorrect?'good':'bad'}"><strong>${quiz.answers[quiz.index].isCorrect?'Correct':'Incorrect'}</strong><div class="explain"><b>Correct answer:</b> ${esc(correct.join(', '))}<br><br>${esc(q.explanation||'No explanation available.')}</div></div>`:''}<div class="actions">${quiz.locked?`<button class="primary" id="next">${quiz.index===quiz.items.length-1?'Finish Quiz':'Next Question'}</button>`:'<button class="primary" id="validate">Validate Answer</button>'}</div></section>`;$("validate")?.addEventListener('click',validateAnswer);$("next")?.addEventListener('click',()=>{quiz.index++;quiz.locked=false;render()})}'''
s,n=re.subn(pat,new_quiz,s,count=1,flags=re.S)
if n!=1: raise SystemExit('renderQuiz() not found')

# Finish: all modes are saved, only exam is pass/fail.
pat=r"async function finishQuiz\(\)\{.*?\n\}"
new_finish='''async function finishQuiz(){const mode=quiz.mode,score=quiz.correct,total=quiz.items.length,p=pct(score,total);const passed=mode==='exam'?p>=60:null;const attempt={user_id:user.id,question_bank_id:bankId,score,total,percentage:p,passed,started_at:quiz.startedAt||new Date().toISOString(),completed_at:new Date().toISOString(),answers:quiz.answers,mode};const r=await supabase.from('quiz_attempts').insert(attempt);if(r.error){console.error(r.error);alert('The quiz result could not be saved to history. Please try again.');return}const label=mode==='exam'?'Exam Mode':mode==='quick'?'Quick Quiz':'Full Mode';$("main").innerHTML=`<section class="card"><span class="pill">${label} complete</span><h1>Quiz complete</h1><div class="result ${passed===null?'':passed?'pass':'fail'}">${p}%</div><p class="muted">${score} correct out of ${total}.</p>${passed!==null?`<p class="${passed?'good':'danger'}"><b>${passed?'PASS':'FAIL'}</b> · 60% required.</p>`:'<p class="good"><b>Saved to History</b></p>'}<div class="actions"><button class="primary" id="retry">Retry ${mode==='exam'?'Exam':mode==='quick'?'Quick Quiz':'Full Mode'}</button><button class="ghost" id="historyBtn">View History</button><button class="ghost" id="dashBtn">Dashboard</button></div></section>`;$("retry").onclick=()=>startQuiz(mode);$("historyBtn").onclick=()=>{quiz=null;page='history';render()};$("dashBtn").onclick=()=>{quiz=null;page='dashboard';render()}}'''
s,n=re.subn(pat,new_finish,s,count=1,flags=re.S)
if n!=1: raise SystemExit('finishQuiz() not found')

# History: explicitly label all three modes and show score + percentage.
pat=r"async function renderHistory\(\)\{.*?\n\}"
new_hist='''async function renderHistory(){$("main").innerHTML=`<section class="card"><h1>Quiz History</h1><div id="history" class="empty">Loading…</div></section>`;const r=await supabase.from('quiz_attempts').select('mode,score,total,percentage,passed,completed_at').eq('user_id',user.id).order('completed_at',{ascending:false});if(r.error){$("history").textContent=r.error.message;return}if(!r.data?.length){$("history").textContent='No quizzes completed yet.';return}const rows=r.data;$("history").className='';$("history").innerHTML=`<table><thead><tr><th>Date</th><th>Mode</th><th>Score</th><th>Percentage</th><th>Result</th></tr></thead><tbody>${rows.map(x=>{const m=x.mode==='exam'?'Exam':x.mode==='quick'?'Quick':'Full';return `<tr><td>${new Date(x.completed_at).toLocaleString()}</td><td>${m}</td><td>${x.score}/${x.total}</td><td>${Number(x.percentage)}%</td><td>${x.passed===null?'—':x.passed?'<span class="good">PASS</span>':'<span class="danger">FAIL</span>'}</td></tr>`}).join('')}</tbody></table>`}'''
s,n=re.subn(pat,new_hist,s,count=1,flags=re.S)
if n!=1: raise SystemExit('renderHistory() not found')

# Replace bank page with owner-only PDF import and validation.
pat=r"function renderBank\(\)\{.*?\n\}"
new_bank='''function renderBank(){const owner=user?.id===OWNER_ID;$("main").innerHTML=`<section class="card"><h1>Question Bank</h1><p class="muted">Current shared bank: <b>${bank.length} questions</b>.</p>${owner?`<label class="ghost" style="display:inline-flex;align-items:center;gap:8px;cursor:pointer">📄 Import New PDF<input id="pdfFile" type="file" accept="application/pdf" style="display:none"></label><div class="notice">Owner-only import. The file is validated before replacing the shared question bank. Quiz history is preserved.</div><div id="importStatus" class="status"></div>`:`<div class="notice">The question bank is read-only. Only the owner can replace it.</div>`}</section>`;$("pdfFile")?.addEventListener('change',importPdf)}'''
s,n=re.subn(pat,new_bank,s,count=1,flags=re.S)
if n!=1: raise SystemExit('renderBank() not found')

# Insert PDF parser after renderBank.
anchor=new_bank+'\n'
parser=r'''async function importPdf(e){const file=e.target.files?.[0];if(!file)return;const st=$("importStatus");st.textContent='Reading and validating PDF…';try{const pdfjs=await import('https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.4.168/pdf.min.mjs');pdfjs.GlobalWorkerOptions.workerSrc='https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.4.168/pdf.worker.min.mjs';const doc=await pdfjs.getDocument({data:await file.arrayBuffer()}).promise;let text='';for(let i=1;i<=doc.numPages;i++){const pageObj=await doc.getPage(i);const c=await pageObj.getTextContent();text+=c.items.map(x=>x.str).join(' ')+'\n'}const parsed=parseImportedText(text);const found=parsed.questions.length;if(found===0)throw new Error('No questions could be parsed from this PDF.');const invalid=parsed.invalid;st.textContent=`Detected ${found} valid questions${invalid?` and ${invalid} questions requiring review`:''}.`;if(invalid||found<100){throw new Error(`Import blocked: ${invalid||'the detected question count is too low'}. Review the PDF format before replacing the shared bank.`)}if(!confirm(`Detected ${found} valid questions and 0 requiring review. Replace the current shared question bank?`))return;const old=bankId;if(old){const u=await supabase.from('question_banks').update({is_active:false}).eq('id',old);if(u.error)throw u.error}const ins=await supabase.from('question_banks').insert({user_id:OWNER_ID,name:file.name,question_count:found,questions:parsed.questions,is_active:true}).select().single();if(ins.error)throw ins.error;bank=ins.data.questions;bankId=ins.data.id;st.innerHTML=`<span class="good">Imported ${bank.length} questions successfully.</span>`;alert(`Question bank replaced successfully with ${bank.length} questions.`);render()}catch(err){st.innerHTML=`<span class="danger">${esc(err.message)}</span>`}}
function cleanImportedText(v){return String(v||'').replace(/IT Certification Guaranteed, The Easy Way!\s*\d*/gi,'').replace(/([A-Za-z])\d+([A-Za-z])/g,'$1$2').replace(/([?.!])\s*\d{1,4}\s*$/g,'$1').replace(/^\s*\d+\s+/,'').replace(/\s+/g,' ').trim()}
function parseImportedText(text){const blocks=text.split(/(?=NO\.\s*\d+\b)/);const questions=[],invalid=[];for(const raw of blocks){const head=raw.match(/^NO\.\s*(\d+)\s+/);if(!head)continue;const answerMatch=raw.match(/\bAnswer:\s*([A-E](?:\s+[A-E])*)/i);if(!answerMatch){invalid.push(head[1]);continue}const body=raw.slice(0,answerMatch.index);const optRe=/(?:^|\s)([A-E])\.\s+/g;const matches=[...body.matchAll(optRe)];if(!matches.length){invalid.push(head[1]);continue}const firstA=matches.findIndex(m=>m[1]==='A');if(firstA<0){invalid.push(head[1]);continue}const seq=matches.slice(firstA);if(seq.length<4||seq.length>5){invalid.push(head[1]);continue}const options={};let valid=true;for(let i=0;i<seq.length;i++){const key=seq[i][1];const start=seq[i].index+(seq[i][0].startsWith(' ')?1:0)+2;const end=i+1<seq.length?seq[i+1].index:body.length;const value=cleanImportedText(body.slice(start,end));if(!value){valid=false;break}options[key]=value}if(!valid){invalid.push(head[1]);continue}const qEnd=seq[0].index;const question=cleanImportedText(body.slice(0,qEnd));if(Object.keys(options).length<4||!question){invalid.push(head[1]);continue}const explanationMatch=raw.match(/\bExplanation:\s*(.*)$/is);questions.push({id:Number(head[1]),source:file?.name||'Imported PDF',correct:answerMatch[1].trim().split(/\s+/),options,question,explanation:cleanImportedText(explanationMatch?.[1]||'')})}return {questions:questions.sort((a,b)=>a.id-b.id),invalid:invalid.length}}
'''
s=s.replace(anchor,anchor+parser,1)

# Password recovery listener: replace existing listener with one that shows the recovery screen.
old="supabase.auth.onAuthStateChange((event,session)=>{if(event==='SIGNED_IN'||event==='TOKEN_REFRESHED'){user=session?.user||user;if(user)loadBank().then(render)}if(event==='SIGNED_OUT'){user=null;bank=[];quiz=null;page='dashboard';render()}if(event==='PASSWORD_RECOVERY'){render()}});"
new="supabase.auth.onAuthStateChange((event,session)=>{if(event==='SIGNED_IN'||event==='TOKEN_REFRESHED'){user=session?.user||user;if(user&&!recoveringPassword)loadBank().then(render)}if(event==='SIGNED_OUT'){user=null;bank=[];quiz=null;page='dashboard';recoveringPassword=false;render()}if(event==='PASSWORD_RECOVERY'){recoveringPassword=true;render()}});"
if old not in s: raise SystemExit('auth listener not found')
s=s.replace(old,new,1)

p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p=Path('sw.js')
s=p.read_text().replace("const CACHE='qcm-trainer-v2'","const CACHE='qcm-trainer-v4'").replace(",'./questions.json'",'')
p.write_text(s)
PY

git add index.html sw.js
if git diff --cached --quiet; then echo 'No V4 changes detected.'; exit 0; fi
git commit -m "Add quick quiz and clean question bank support"
git pull --rebase origin main
git push origin main

echo "V4 update complete."
