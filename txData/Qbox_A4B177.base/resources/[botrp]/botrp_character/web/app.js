const app=document.getElementById('app');
const cards=document.getElementById('cards');
const create=document.getElementById('create');
const error=document.getElementById('error');
const deleteModal=document.getElementById('deleteModal');
const deleteName=document.getElementById('deleteName');
const deleteConfirm=document.getElementById('deleteConfirm');
let chars=[];
let pendingDeleteSlot=null;
let deleteInProgress=false;
let lobbyBusy=false;

const nui=(name,data={})=>fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})
  .then(r=>r.json())
  .catch(e=>{console.error(`[BotRP] NUI ${name} failed`,e);return {ok:false,error:'Connection to the game client failed.'}});

function setLobbyBusy(busy){
  lobbyBusy=busy;
  document.querySelectorAll('.delete,.play').forEach(btn=>{btn.disabled=busy;btn.classList.toggle('busy',busy)});
}

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
      el.addEventListener('click',()=>{if(!lobbyBusy) openCreate(c.slot)});
      el.querySelector('.play').addEventListener('click',e=>{e.preventDefault();e.stopPropagation();if(!lobbyBusy) openCreate(c.slot)});
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
          <div class="card-actions">
            <button type="button" class="delete" data-delete-slot="${c.slot}">DELETE</button>
            <button type="button" class="play" data-play-slot="${c.slot}">PLAY CHARACTER <span>→</span></button>
          </div>
        </div>`;
      el.addEventListener('click',()=>{if(!lobbyBusy) select(c.slot)});
      el.querySelector('.play').addEventListener('click',async e=>{
        e.preventDefault();
        e.stopPropagation();
        if(lobbyBusy) return;
        await playCharacter(c.slot,e.currentTarget);
      });
      el.querySelector('.delete').addEventListener('click',e=>{
        e.preventDefault();
        e.stopPropagation();
        if(lobbyBusy) return;
        openDelete(c.slot);
      });
    }
    cards.appendChild(el);
  });
}

async function playCharacter(slot,btn){
  if(lobbyBusy||btn.dataset.busy==='1') return;
  btn.dataset.busy='1';
  setLobbyBusy(true);
  btn.disabled=true;
  btn.innerHTML='ENTERING LOS SANTOS…';
  const r=await nui('play',{slot:Number(slot)});
  if(!r.ok){
    btn.dataset.busy='0';
    setLobbyBusy(false);
    btn.disabled=false;
    btn.innerHTML='PLAY CHARACTER <span>→</span>';
    if(error) error.textContent=r.error||'Unable to load character.';
  }
}

function select(slot){
  if(lobbyBusy) return;
  nui('select',{slot});
  document.querySelectorAll('.card').forEach(x=>x.classList.remove('selected'));
  document.querySelector(`.card[data-slot="${slot}"]`)?.classList.add('selected');
}

function openCreate(slot){
  if(lobbyBusy) return;
  cards.classList.add('hidden');
  document.querySelector('.intro')?.classList.add('hidden');
  create.classList.remove('hidden');
  app.classList.add('create-mode');
  create.dataset.slot=slot;
  error.textContent='';
  document.getElementById('firstname')?.focus();
}

function openDelete(slot){
  if(lobbyBusy||deleteInProgress) return;
  const character=chars.find(c=>Number(c.slot)===Number(slot)&&!c.empty);
  if(!character) return;
  pendingDeleteSlot=Number(slot);
  deleteName.textContent=`${character.firstname} ${character.lastname}`;
  deleteModal.classList.remove('hidden');
  deleteConfirm.disabled=false;
  deleteConfirm.textContent='DELETE CHARACTER';
}

function closeDelete(){
  if(deleteInProgress) return;
  pendingDeleteSlot=null;
  deleteModal.classList.add('hidden');
}

document.getElementById('deleteCancel').onclick=closeDelete;
document.querySelector('.modal-backdrop').onclick=closeDelete;
deleteConfirm.onclick=async()=>{
  if(pendingDeleteSlot===null||deleteInProgress) return;
  const slot=pendingDeleteSlot;
  const character=chars.find(c=>Number(c.slot)===slot&&!c.empty);
  if(!character) { closeDelete(); return; }

  deleteInProgress=true;
  setLobbyBusy(true);
  deleteConfirm.disabled=true;
  deleteConfirm.textContent='DELETING…';

  try{
    const r=await nui('delete',{slot});
    if(r.ok){
      pendingDeleteSlot=null;
      deleteModal.classList.add('hidden');
    }else{
      deleteConfirm.disabled=false;
      deleteConfirm.textContent='DELETE CHARACTER';
      if(error) error.textContent=r.error||'Unable to delete character.';
    }
  }catch(e){
    console.error('[BotRP] delete failed',e);
    deleteConfirm.disabled=false;
    deleteConfirm.textContent='DELETE CHARACTER';
    if(error) error.textContent='Unable to delete character.';
  }finally{
    deleteInProgress=false;
    setLobbyBusy(false);
  }
};

document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!deleteModal.classList.contains('hidden')&&!deleteInProgress) closeDelete()});

document.getElementById('back').onclick=()=>{
  if(lobbyBusy) return;
  create.classList.add('hidden');
  cards.classList.remove('hidden');
  document.querySelectorAll('.intro').forEach(x=>x.classList.remove('hidden'));
  app.classList.remove('create-mode');
};

document.getElementById('createBtn').onclick=async()=>{
  if(lobbyBusy) return;
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
  setLobbyBusy(true);
  const r=await nui('create',data);
  setLobbyBusy(false);
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
