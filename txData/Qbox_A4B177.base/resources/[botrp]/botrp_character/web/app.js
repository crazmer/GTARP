const app=document.getElementById('app');
const cards=document.getElementById('cards');
const create=document.getElementById('create');
const error=document.getElementById('error');
let chars=[];

const nui=(name,data={})=>fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})
  .then(r=>r.json())
  .catch(e=>{console.error(`[BotRP] NUI ${name} failed`,e);return {ok:false,error:'Connection to the game client failed.'}});

function render(list){
  chars=list||[];
  const count=document.getElementById('slotCount');
  if(count) count.textContent=String(chars.filter(c=>!c.empty).length).padStart(2,'0');
  cards.innerHTML='';

  chars.forEach(c=>{
    const el=document.createElement('article');
    el.className='card '+(c.empty?'empty':'');
    el.dataset.slot=c.slot;

    if(c.empty){
      el.innerHTML=`
        <div class="slot-badge">${String(c.slot).padStart(2,'0')}</div>
        <div class="card-main">
          <strong>EMPTY SLOT</strong>
          <small>Create a new life in Los Santos</small>
        </div>
        <div class="card-side"><div class="card-side-label">AVAILABLE</div><button type="button" class="play">CREATE →</button></div>`;
      el.addEventListener('click',()=>openCreate(c.slot));
      el.querySelector('.play').addEventListener('click',e=>{e.preventDefault();e.stopPropagation();openCreate(c.slot)});
    }else{
      el.innerHTML=`
        <div class="slot-badge">${String(c.slot).padStart(2,'0')}</div>
        <div class="card-main">
          <div class="slot">CHARACTER ${String(c.slot).padStart(2,'0')}</div>
          <div class="name">${esc(c.firstname)} ${esc(c.lastname)}</div>
          <div class="cid">ID · ${esc(c.citizenid)}</div>
          <div class="meta">
            <span class="pill">${esc(c.job)}${c.jobGrade?' · '+esc(c.jobGrade):''}</span>
            <span class="pill">${esc(c.birthdate)}</span>
            <span class="pill">${esc(c.gender)}</span>
          </div>
        </div>
        <div class="card-side">
          <div class="card-side-label">READY TO ENTER</div>
          <button type="button" class="play" data-play-slot="${c.slot}">PLAY CHARACTER <span>→</span></button>
        </div>`;
      el.addEventListener('click',()=>select(c.slot));
      el.querySelector('.play').addEventListener('click',async e=>{
        e.preventDefault();
        e.stopPropagation();
        await playCharacter(c.slot,e.currentTarget);
      });
    }
    cards.appendChild(el);
  });
}

async function playCharacter(slot,btn){
  if(btn.dataset.busy==='1') return;
  btn.dataset.busy='1';
  btn.disabled=true;
  btn.innerHTML='ENTERING LOS SANTOS…';
  const r=await nui('play',{slot:Number(slot)});
  if(!r.ok){
    btn.dataset.busy='0';
    btn.disabled=false;
    btn.innerHTML='PLAY CHARACTER <span>→</span>';
    if(error) error.textContent=r.error||'Unable to load character.';
  }
}

function select(slot){
  nui('select',{slot});
  document.querySelectorAll('.card').forEach(x=>x.classList.remove('selected'));
  document.querySelector(`.card[data-slot="${slot}"]`)?.classList.add('selected');
}

function openCreate(slot){
  cards.classList.add('hidden');
  document.querySelector('.intro')?.classList.add('hidden');
  create.classList.remove('hidden');
  create.dataset.slot=slot;
  error.textContent='';
  document.getElementById('firstname')?.focus();
}

document.getElementById('back').onclick=()=>{
  create.classList.add('hidden');
  cards.classList.remove('hidden');
  document.querySelectorAll('.intro').forEach(x=>x.classList.remove('hidden'));
};

document.getElementById('createBtn').onclick=async()=>{
  error.textContent='';
  const data={
    slot:Number(create.dataset.slot),
    firstname:v('firstname'),
    lastname:v('lastname'),
    nationality:v('nationality'),
    birthdate:v('birthdate'),
    gender:v('gender')
  };
  if(!data.firstname||!data.lastname||!data.nationality||!data.birthdate){
    error.textContent='Please complete every field.';
    return;
  }
  const r=await nui('create',data);
  if(!r.ok) error.textContent=r.error||'Unable to create character.';
};

function v(id){return document.getElementById(id).value.trim()}
function esc(s){return String(s??'').replace(/[&<>'"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m]))}

window.addEventListener('message',e=>{
  const d=e.data||{};
  if(d.action==='open') app.classList.remove('hidden');
  if(d.action==='characters') render(d.characters);
  if(d.action==='transition'){
    app.classList.remove('hidden');
    const sub=document.querySelector('.sub');
    if(sub) sub.textContent=d.text||'Loading...';
  }
  if(d.action==='hide') app.classList.add('hidden');
});
