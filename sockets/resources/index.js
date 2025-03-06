import { Screen } from './screen.js';
import { GameClient, readFileAsUint8Array } from './gameClient.js';

let screen = undefined;
let client = undefined;

const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'; // Check if the protocol is HTTPS or HTTP
const domain = window.location.hostname; // Get the current domain
const port = window.location.port ? `:${window.location.port}` : ''; // Get the port if it exists, otherwise use an empty string
const wsUrl = `${protocol}://${domain}${port}`;

async function fetchPalette() {
  try {
      // Send a GET request to fetch the palette binary data from the server
      const response = await fetch('palette.bin');

      if (!response.ok) {
          throw new Error('Failed to fetch the palette data from the server');
      }

      // Get the binary data (ArrayBuffer) from the response
      const arrayBuffer = await response.arrayBuffer();

      // Convert the ArrayBuffer into a Uint8Array
      const readPal = new Uint8Array(arrayBuffer);

      // Call screen.setPalette with the binary data
      screen.setPalette(readPal);
  } catch (error) {
      console.error('Error:', error);
      alert('An error occurred: ' + error.message);
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  screen = new Screen("imageCanvas", 320, 200);

  document.getElementById('wsBtn').addEventListener('click', ()=>{
    if (!client) {
      client = new GameClient(wsUrl, screen, true);
      fetchPalette();
    }
  });
});