const app=document.getElementById('app');
const title=document.getElementById('title');
const subtitle=document.getElementById('subtitle');
const status=document.getElementById('status');
const bar=document.getElementById('bar');
const percent=document.getElementById('percent');
const glow=document.querySelector('.progress-glow');
const tip=document.getElementById('tip');
let progress=0;
const tips=['Building your Los Santos experience.','Preparing the world around you.','Loading BotRP resources.','Finalizing your connection.'];
function setProgress(value){const next=Math.max(progress,Math.round(Math.max(0,Math.min(1,Number(value)||0))*100));progress=next;if(bar)bar.style.width=next+'%';if(glow)glow.style.left=`calc(${next}% - 2px)`;if(percent)percent.textContent=`${next}%`;let state='CONNECTING TO SERVER';if(next>=98)state='READY TO ENTER';else if(next>=70)state='LOADING RESOURCES';else if(next>=30)state='LOADING WORLD';if(status)status.textContent=state;for(const [id,threshold] of [['step2',30],['step3',65],['step4',98]]){const el=document.getElementById(id);if(el&&next>=threshold)el.classList.add('active')}if(tip)tip.textContent=tips[Math.min(tips.length-1,Math.floor(next/25))]}
window.addEventListener('message',e=>{const d=e.data||{};if(d.eventName==='loadProgress'){setProgress(d.loadFraction);return}if(d.action==='show'){if(title)title.textContent=d.title||'Welcome to BotRP';if(subtitle)subtitle.textContent=d.subtitle||'Your next story starts here.';app.classList.remove('hidden');return}if(d.action==='hide'){app.classList.add('hidden')}});
setProgress(0.01);
