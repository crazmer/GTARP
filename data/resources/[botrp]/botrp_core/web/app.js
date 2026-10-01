const app = document.getElementById('app');
const selection = document.getElementById('selection');
const creation = document.getElementById('creation');
const list = document.getElementById('characterList');
const message = document.getElementById('message');

function nui(event, data = {}) {
    return fetch(`https://botrp_core/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function showMessage(text) {
    message.textContent = text;
    message.style.display = 'block';
    setTimeout(() => message.style.display = 'none', 3000);
}

function renderCharacters(characters) {
    list.innerHTML = '';

    if (!characters.length) {
        const empty = document.createElement('div');
        empty.className = 'character';
        empty.textContent = 'No characters yet.';
        list.appendChild(empty);
        return;
    }

    characters.forEach(character => {
        const card = document.createElement('div');
        card.className = 'character';

        const info = document.createElement('div');
        const name = document.createElement('strong');
        name.textContent = `${character.firstName} ${character.lastName}`;
        const details = document.createElement('span');
        details.textContent = `DOB: ${character.dateOfBirth} • ${character.nationality} • ${character.gender}`;

        const select = document.createElement('button');
        select.className = 'primary';
        select.textContent = 'Select';
        select.onclick = () => nui('selectCharacter', { id: character.id });

        info.appendChild(name);
        info.appendChild(details);
        card.appendChild(info);
        card.appendChild(select);
        list.appendChild(card);
    });
}

window.addEventListener('message', event => {
    const data = event.data || {};

    if (data.action === 'open') {
        app.classList.remove('hidden');
        selection.classList.remove('hidden');
        creation.classList.add('hidden');
        renderCharacters(data.characters || []);
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }

    if (data.action === 'characters') {
        renderCharacters(data.characters || []);
    }

    if (data.action === 'message') {
        showMessage(data.message || '');
    }
});

document.getElementById('newCharacter').onclick = () => {
    selection.classList.add('hidden');
    creation.classList.remove('hidden');
};

document.getElementById('back').onclick = () => {
    creation.classList.add('hidden');
    selection.classList.remove('hidden');
};

document.getElementById('characterForm').onsubmit = event => {
    event.preventDefault();

    nui('createCharacter', {
        firstName: document.getElementById('firstName').value,
        lastName: document.getElementById('lastName').value,
        dateOfBirth: document.getElementById('dateOfBirth').value,
        nationality: document.getElementById('nationality').value,
        gender: document.getElementById('gender').value
    });
};
