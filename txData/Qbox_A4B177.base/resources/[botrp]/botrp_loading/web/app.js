const app=document.getElementById('app');
const title=document.getElementById('title');
const subtitle=document.getElementById('subtitle');
const status=document.getElementById('status');
const bar=document.getElementById('bar');
const percent=document.getElementById('percent');
const glow=document.getElementById('glow');
const tip=document.getElementById('tip');
let progress=0;
const tips=['Use /help in-game if you\'re ever unsure about something.','Your identity is yours. Build your story.','Explore Los Santos and find your place.','Finalizing your session. See you in the city.'];
function setProgress(value){
  const next=Math.max(progress,Math.round(Math.max(0,Math.min(1,Number(value)||0))*100));
  progress=next;
  if(bar)bar.style.width=`${next}%`;
  if(glow)glow.style.left=`calc(${next}% - 2px)`;
  if(percent)percent.textContent=`${next}%`;
  let state='CONNECTING TO SERVER', sub='Establishing a secure connection to BotRP...';
  if(next>=98){state='READY TO ENTER';sub='Everything is ready. Welcome to Los Santos.'}
  else if(next>=70){state='LOADING RESOURCES';sub='Bringing the BotRP experience online...'}
  else if(next>=30){state='LOADING WORLD';sub='Preparing Los Santos around you...'}
  if(status)status.textContent=state;
  if(subtitle)subtitle.textContent=sub;
  for(const [id,threshold] of [['step2',30],['step3',65],['step4',98]]){const el=document.getElementById(id);if(el&&next>=threshold)el.classList.add('active')}
  if(tip)tip.textContent=tips[Math.min(tips.length-1,Math.floor(next/25))];
}
window.addEventListener('message',e=>{
  const d=e.data||{};
  if(d.eventName==='loadProgress'){setProgress(d.loadFraction);return}
  if(d.action==='show'){if(title)title.textContent=d.title||'CONNECTING TO SERVER';if(subtitle)subtitle.textContent=d.subtitle||'Preparing your character...';return}
  if(d.action==='hide'){app.classList.add('hidden')}
});
setProgress(0.01);
