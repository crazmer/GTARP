const resource = GetParentResourceName();
const panel = document.getElementById('panel');
const results = document.getElementById('results');
const details = document.getElementById('details');
const query = document.getElementById('query');

async function nui(name, data = {}) {
  const r = await fetch(`https://${resource}/${name}`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(data) });
  return r.json();
}

function render(rows) {
  results.innerHTML = rows.length ? rows.map(v => `<button class="row" data-id="${v.id}"><b>${v.plate}</b><span>${v.vehicle || 'unknown'} • ${v.citizenid}</span><small>ID ${v.id} • Garage: ${v.garage || 'none'} • State: ${v.state}</small></button>`).join('') : '<p class="empty">No vehicles found.</p>';
  results.querySelectorAll('.row').forEach(el => el.onclick = () => selectVehicle(el.dataset.id));
}

async function selectVehicle(id) {
  const v = await nui('get', {id});
  if (!v.id) return;
  details.classList.remove('hidden');
  details.innerHTML = `<h2>${v.plate}</h2><p>${v.vehicle || 'unknown'} • Owner: ${v.citizenid}</p><p>Garage: ${v.garage || 'none'} • State: ${v.state}</p><div class="actions"><button data-state="0">Set Out</button><button data-state="1">Store</button><button data-state="2">Depot</button><input id="garage" placeholder="Garage ID" value="${v.garage || ''}"><button id="saveGarage">Save Garage</button><button class="danger" id="delete">Delete Vehicle</button></div>`;
  details.querySelectorAll('[data-state]').forEach(b => b.onclick = () => nui('setState', {id:v.id, state:Number(b.dataset.state)}));
  document.getElementById('saveGarage').onclick = () => nui('setGarage', {id:v.id, garage:document.getElementById('garage').value});
  document.getElementById('delete').onclick = async () => { if (confirm('Permanently delete this vehicle?')) await nui('delete', {id:v.id}); };
}

document.getElementById('search').onclick = async () => render(await nui('search', {query:query.value}));
query.onkeydown = e => { if (e.key === 'Enter') document.getElementById('search').click(); };
document.getElementById('close').onclick = () => nui('close');

window.addEventListener('message', e => {
  if (e.data.action === 'open') { panel.classList.remove('hidden'); query.focus(); }
  if (e.data.action === 'close') { panel.classList.add('hidden'); details.classList.add('hidden'); }
});
