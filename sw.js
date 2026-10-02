const CACHE='qcm-trainer-v19';
const APP='./app-v5.html';

self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(['./','./index.html','./app-v5.html','./import-app-builder.html','./import-platform-developer.html','./manifest.webmanifest'])).then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim()))});

function patchMultiAnswerSupport(html){
  const oldFn="function shuffleOptions(q){const entries=Object.entries(q.options||{}),s=shuffle(entries),labels='ABCDE'.slice(0,s.length).split(''),options={},map={};s.forEach(([old,v],i)=>{options[labels[i]]=v;map[String(old)]=labels[i]});const original=Array.isArray(q.correct)?q.correct.map(String):[String(q.correct)];return {...q,options,correct:original.map(k=>map[k]).filter(Boolean)}}";
  const newFn="function normalizeCorrectAnswers(value,options){const keys=new Set(Object.keys(options||{}).map(String));const raw=Array.isArray(value)?value:[value],out=[];raw.forEach(v=>{const s=String(v??'').trim().toUpperCase();if(!s)return;if(keys.has(s)){out.push(s);return}const compact=s.replace(/[^A-Z]/g,'');if(compact&&[...compact].every(k=>keys.has(k))){[...compact].forEach(k=>out.push(k));return}const tokens=s.split(/[^A-Z]+/).filter(Boolean);if(tokens.length&&tokens.every(k=>keys.has(k)))tokens.forEach(k=>out.push(k))});return[...new Set(out)]}function shuffleOptions(q){const entries=Object.entries(q.options||{}),s=shuffle(entries),labels='ABCDE'.slice(0,s.length).split(''),options={},map={};s.forEach(([old,v],i)=>{options[labels[i]]=v;map[String(old)]=labels[i]});const original=normalizeCorrectAnswers(q.correct,q.options);return {...q,options,correct:original.map(k=>map[k]).filter(Boolean)}}";
  if(html.includes(oldFn)) return html.replace(oldFn,newFn);
  return html;
}

self.addEventListener('fetch',event=>{if(event.request.method!=='GET')return;const url=new URL(event.request.url);
  if(url.pathname.endsWith('/index.html')||url.pathname.endsWith('/qcm-trainer/')){event.respondWith(fetch(event.request,{cache:'no-store'}).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put('./index.html',copy));return response}).catch(()=>caches.match('./index.html')));return}
  if(url.pathname.endsWith('/app-v5.html')){event.respondWith(fetch(event.request,{cache:'no-store'}).then(async response=>{const text=await response.text();const patched=patchMultiAnswerSupport(text);const out=new Response(patched,{status:response.status,statusText:response.statusText,headers:response.headers});caches.open(CACHE).then(cache=>cache.put(APP,out.clone()));return out}).catch(()=>caches.match(APP)));return}
  event.respondWith(fetch(event.request).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return response}).catch(()=>caches.match(event.request)))
});
