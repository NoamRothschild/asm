import { Screen } from './screen.js';
import { GameClient, readFileAsUint8Array } from './gameClient.js';

let screen = undefined;
let client = undefined;

async function buttonClick() {
    const paletteFileInput = document.getElementById('paletteFile');
    try {
        let readPal = await readFileAsUint8Array(paletteFileInput.files[0]);
        screen.setPalette(readPal);
    } catch (error) {
        console.error('Error:', error);
        alert('An error occurred: ' + error.message);
    }
};

document.addEventListener("DOMContentLoaded", async () => {
  screen = new Screen("imageCanvas", 320, 200);

  document.getElementById('viewBtn').addEventListener('click', buttonClick);
  document.getElementById('wsBtn').addEventListener('click', ()=>{
    if (!client) client = new GameClient("ws://localhost:8000", screen, true);
  });
});