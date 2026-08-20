#!/bin/bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
p=Path('index.html')
s=p.read_text()

# iPhone/Safari styling and persistent auth storage.
s=s.replace('button{font:inherit;cursor:pointer}', 'button{font:inherit;cursor:pointer;-webkit-appearance:none;appearance:none;-webkit-tap-highlight-color:transparent}')
s=s.replace('.app{max-width:1000px;margin:auto;padding:18px 16px 42px}', '.app{max-width:1000px;margin:auto;padding:calc(18px + env(safe-area-inset-top)) 16px calc(42px + env(safe-area-inset-bottom))}')
s=s.replace('input[type=email]{', 'input[type=email],input[type=password]{')

s=s.replace('const SUPABASE_URL="https://umlrugknndundkrfvofa.supabase.co", SUPABASE_KEY="sb_publishable_ecsKv40x9hJDAPlZgGe-6A_pD79G_2l";', 'const SUPABASE_URL="https://umlrugknndundkrfvofa.supabase.co", SUPABASE_KEY="sb_publishable_ecsKv40x9hJDAPlZgGe-6A_pD79G_2l";')
old='const supabase=createClient(SUPABASE_URL,SUPABASE_KEY);'
new='const OWNER_ID="a40bea08-44dd-4c34-a455-38bfc7e68cb6";\nconst supabase=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,storageKey:"qcm-trainer-auth"}});'
s=s.replace(old,new)

# Replace local-bank loader + user-specific bank loading with shared Supabase bank loading.
s=re.sub(r'async function localBank\(\)\{.*?\nasync function loadUser\(\)\{.*?\n\}', '''async function loadUser(){
 const {data}=await supabase.auth.getSession(); user=data.session?.user||null;
 if(user){
   const {data:b,error}=await supabase.from("question_banks").select("*").eq("is_active",true).order("created_at",{ascending:false}).limit(1).maybeSingle();
   if(error) console.error(error);
   if(b){bank=b.questions; bankId=b.id;} else {bank=[]; bankId=null;}
 } else {bank=[]; bankId=null;}
}''', s, flags=re.S)

# State: add shared bank id and auth mode.
s=s.replace('let bank=[], user=null, quiz=null, page="dashboard";', 'let bank=[], bankId=null, user=null, quiz=null, page="dashboard", authMode="signin";')

# Replace magic-link auth UI/function.
s=re.sub(r'async function sendMagicLink\(\)\{.*?\n\}', '''async function signIn(){
 const email=$("#email").value.trim(), password=$("#password").value;
 if(!email||!password){$("#loginStatus").textContent="Enter your email and password.";return;}
 $("#loginStatus").textContent="Signing in…";
 const {error}=await supabase.auth.signInWithPassword({email,password});
 $("#loginStatus").textContent=error?error.message:"Signed in.";
 if(!error){await loadUser();render();}
}
async function signUp(){
 const email=$("#email").value.trim(), password=$("#password").value;
 if(!email||password.length<6){$("#loginStatus").textContent="Enter an email and a password of at least 6 characters.";return;}
 $("#loginStatus").textContent="Creating account…";
 const {data,error}=await supabase.auth.signUp({email,password});
 if(error){$("#loginStatus").textContent=error.message;return;}
 if(data.session){await loadUser();render();}
 else $("#loginStatus").textContent="Account created. Confirm your email once if required, then sign in.";
}
async function resetPassword(){
 const email=$("#email").value.trim(); if(!email){$("#loginStatus").textContent="Enter your email first.";return;}
 const {error}=await supabase.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});
 $("#loginStatus").textContent=error?error.message:"Password reset email sent.";
}''', s, flags=re.S)

s=re.sub(r'function loginPage\(\)\{.*?\n\}', '''function loginPage(){
 $("#main").innerHTML=`<section class="card"><h1>${authMode==="signin"?"Welcome back":"Create your account"}</h1><p class="muted">Sign in once and QCM Trainer will keep your session on this device.</p><div style="display:flex;gap:8px;margin:18px 0 4px"><button class="ghost ${authMode==="signin"?"active":""}" id="signInTab">Sign In</button><button class="ghost ${authMode==="signup"?"active":""}" id="signUpTab">Create Account</button></div><input id="email" type="email" placeholder="Email address" autocomplete="email"><input id="password" type="password" placeholder="Password" autocomplete="${authMode==="signin"?"current-password":"new-password"}"><div class="actions"><button class="primary" id="authBtn">${authMode==="signin"?"Sign In":"Create Account"}</button></div>${authMode==="signin"?`<button class="ghost" id="forgot" style="margin-top:12px">Forgot Password?</button>`:""}<div id="loginStatus" class="status"></div></section>`;
 $("#signInTab").onclick=()=>{authMode="signin";render()};
 $("#signUpTab").onclick=()=>{authMode="signup";render()};
 $("#authBtn").onclick=authMode==="signin"?signIn:signUp;
 if($("#forgot"))$("#forgot").onclick=resetPassword;
}''', s, flags=re.S)

# Finish quiz should save the shared bank id.
s=s.replace('question_bank_id:null,mode', 'question_bank_id:bankId,mode')

# Shared bank UI + owner-only import.
s=re.sub(r'function bankPage\(\)\{.*?\n\}', '''function bankPage(){
 const owner=user?.id===OWNER_ID;
 $("#main").innerHTML=`<section class="card"><h1>Question Bank</h1><p class="muted">Current shared bank: <b>${bank.length} questions</b></p>${owner?`<label class="file">📄 Import New PDF<input id="pdf" type="file" accept="application/pdf"></label><div class="notice">Only the owner can replace the shared question bank. Other accounts can practice it but cannot modify it.</div>`:`<div class="notice">This question bank is shared for practice. Only the owner can replace it.</div>`}<div id="importStatus"></div></section>`;
 if(owner)$("#pdf").onchange=importPDF;
}''', s, flags=re.S)

s=re.sub(r'async function importPDF\(e\)\{.*?\n\}', '''async function importPDF(e){
 const file=e.target.files[0]; if(!file)return; const status=$("#importStatus"); status.textContent="Reading PDF…";
 try{
  const pdfjs=await import("https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.4.168/pdf.min.mjs"); pdfjs.GlobalWorkerOptions.workerSrc="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.4.168/pdf.worker.min.mjs";
  const doc=await pdfjs.getDocument({data:await file.arrayBuffer()}).promise; let text="";
  for(let i=1;i<=doc.numPages;i++){const p=await doc.getPage(i),c=await p.getTextContent();text+=c.items.map(x=>x.str).join(" ")+"\\n";}
  const parsed=parseImportedText(text); if(parsed.length<1)throw Error("No questions were detected.");
  if(!confirm(`Detected ${parsed.length} questions. Replace the shared question bank?`))return;
  const {data:old}=await supabase.from("question_banks").select("id").eq("is_active",true).order("created_at",{ascending:false}).limit(1).maybeSingle();
  if(old?.id)await supabase.from("question_banks").update({is_active:false}).eq("id",old.id);
  const {data:newBank,error}=await supabase.from("question_banks").insert({user_id:OWNER_ID,name:file.name,question_count:parsed.length,questions:parsed,is_active:true}).select().single();
  if(error)throw error; bank=newBank.questions; bankId=newBank.id; status.innerHTML=`<span class="good">Imported ${bank.length} questions successfully for all users.</span>`;
 }catch(err){status.innerHTML=`<span class="danger">${esc(err.message)}</span>`}
}''', s, flags=re.S)

# Settings copy.
s=s.replace('Your quiz history and imported question bank are stored in Supabase and protected by Row Level Security for your account.', 'Quiz history is private to each account. The question bank is shared for practice; only the owner can replace it.')

p.write_text(s)
PY

# The public repo no longer needs the question bank file once the update is applied.
rm -f questions.json

git add index.html questions.json
git commit -m "V3 password auth and secured shared question bank"
git push origin main

echo "V3 update complete. GitHub Pages may take a few minutes to publish."