const CACHE='qcm-trainer-v13';
const APP='./app-v5.html';

function patchApp(html){
  const target="document.querySelectorAll('[data-bank]').forEach(b=>b.onclick=()=>{selectedBank=banks.find(x=>x.id===b.dataset.bank);render()})}";
  const replacement="document.querySelectorAll('[data-bank]').forEach(b=>b.onclick=()=>{selectedBank=banks.find(x=>x.id===b.dataset.bank);render()});document.getElementById('exam')?.addEventListener('click',()=>startQuiz('exam'));document.getElementById('quick')?.addEventListener('click',()=>startQuiz('quick'));document.getElementById('full')?.addEventListener('click',()=>startQuiz('full'))}";
  return html.includes(target)?html.replace(target,replacement):html;
}

self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(['./','./index.html','./app-v5.html','./import-app-builder.html','./manifest.webmanifest'])).then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',event=>{if(event.request.method!=='GET')return;const url=new URL(event.request.url);
  if(url.pathname.endsWith('/index.html')||url.pathname.endsWith('/qcm-trainer/')){event.respondWith(fetch(event.request,{cache:'no-store'}).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put('./index.html',copy));return response}).catch(()=>caches.match('./index.html')));return}
  if(url.pathname.endsWith('/app-v5.html')){event.respondWith(fetch(event.request,{cache:'no-store'}).then(async response=>{const html=patchApp(await response.text());const patched=new Response(html,{status:response.status,statusText:response.statusText,headers:{'Content-Type':'text/html; charset=utf-8'}});caches.open(CACHE).then(cache=>cache.put(APP,patched.clone()));return patched}).catch(()=>caches.match(APP)));return}
  event.respondWith(fetch(event.request).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return response}).catch(()=>caches.match(event.request)))
});
