#!/bin/zsh
set -e
python3 - <<'PY'
from pathlib import Path
p=Path('index.html')
s=p.read_text()

old='let bank=[], bankId=null, user=null, quiz=null, page="dashboard", authMode="signin";'
new='let bank=[], bankId=null, user=null, quiz=null, page="dashboard", authMode="signin", recoveryMode=false;'
if old not in s: raise SystemExit('state declaration not found')
s=s.replace(old,new,1)

old='supabase.auth.onAuthStateChange(async (_event,session)=>{user=session?.user||null; if(user){await loadUser();} else bank=[]; page="dashboard"; render();});'
new='supabase.auth.onAuthStateChange(async (event,session)=>{\n user=session?.user||null;\n if(event==="PASSWORD_RECOVERY"){recoveryMode=true; authMode="recovery"; render(); return;}\n if(user){await loadUser();} else {bank=[]; bankId=null;}\n if(!recoveryMode){page="dashboard"; render();}\n});'
if old not in s: raise SystemExit('auth listener not found')
s=s.replace(old,new,1)

old='const {error}=await supabase.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});'
new='const {error}=await supabase.auth.resetPasswordForEmail(email,{redirectTo:"https://nathanboccardi-irl.github.io/qcm-trainer/"});'
if old not in s: raise SystemExit('reset redirect not found')
s=s.replace(old,new,1)

marker='async function logout(){await supabase.auth.signOut();}'
insert='''async function updatePassword(){\n const password=$("#newPassword").value;\n const confirm=$("#confirmPassword").value;\n if(password.length<6){$("#recoveryStatus").textContent="Password must be at least 6 characters.";return;}\n if(password!==confirm){$("#recoveryStatus").textContent="Passwords do not match.";return;}\n $("#recoveryStatus").textContent="Updating password…";\n const {error}=await supabase.auth.updateUser({password});\n if(error){$("#recoveryStatus").textContent=error.message;return;}\n recoveryMode=false; authMode="signin";\n $("#recoveryStatus").textContent="Password updated. You are signed in.";\n await loadUser();\n page="dashboard";\n render();\n}\n'''+marker
if marker not in s: raise SystemExit('logout marker not found')
s=s.replace(marker,insert,1)

start=s.index('function loginPage(){')
end=s.index('function startQuiz',start)
new_login='''function loginPage(){\n if(recoveryMode){\n  $("#main").innerHTML=`<section class="card"><h1>Set your new password</h1><p class="muted">Choose a new password for your QCM Trainer account.</p><input id="newPassword" type="password" placeholder="New password" autocomplete="new-password"><input id="confirmPassword" type="password" placeholder="Confirm password" autocomplete="new-password"><div class="actions"><button class="primary" id="updatePasswordBtn">Update Password</button></div><div id="recoveryStatus" class="status"></div></section>`;\n  $("#updatePasswordBtn").onclick=updatePassword;\n  return;\n }\n $("#main").innerHTML=`<section class="card"><h1>${authMode==="signin"?"Welcome back":"Create your account"}</h1><p class="muted">Sign in once and QCM Trainer will keep your session on this device.</p><div style="display:flex;gap:8px;margin:18px 0 4px"><button class="ghost ${authMode==="signin"?"active":""}" id="signInTab">Sign In</button><button class="ghost ${authMode==="signup"?"active":""}" id="signUpTab">Create Account</button></div><input id="email" type="email" placeholder="Email address" autocomplete="email"><input id="password" type="password" placeholder="Password" autocomplete="${authMode==="signin"?"current-password":"new-password"}"><div class="actions"><button class="primary" id="authBtn">${authMode==="signin"?"Sign In":"Create Account"}</button></div>${authMode==="signin"?`<button class="ghost" id="forgot" style="margin-top:12px">Forgot Password?</button>`:""}<div id="loginStatus" class="status"></div></section>`;\n $("#signInTab").onclick=()=>{authMode="signin";render()};\n $("#signUpTab").onclick=()=>{authMode="signup";render()};\n $("#authBtn").onclick=authMode==="signin"?signIn:signUp;\n if($("#forgot"))$("#forgot").onclick=resetPassword;\n}\n'''
s=s[:start]+new_login+s[end:]

old='navigator.serviceWorker.register("./sw.js").catch(()=>{});'
new='navigator.serviceWorker.register("./sw.js?v=4").catch(()=>{});'
if old not in s: raise SystemExit('service worker registration not found')
s=s.replace(old,new,1)

p.write_text(s)
print('Password recovery + stale-cache fix applied.')
PY

git add index.html FIX_PASSWORD_RESET.sh
git commit -m "Fix password recovery and stale mobile cache"
git push origin main

echo "Fix deployed. Wait 1-2 minutes before requesting another reset email."
