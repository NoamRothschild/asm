export class GameClient {
    constructor(wsUrl, screen, printDebug=false) {
        this.socket = new WebSocket(wsUrl);
        this.socket.binaryType = 'arraybuffer';
        this.printDebug = printDebug;
        this.screen = screen;

        this.socket.onopen = () => {
            this.#log('INFO: Connected to WebSocket server.');
        };

        this.socket.onclose = () => {
          this.#log('INFO: Disconnected from WebSocket server.');
        };

        this.socket.onerror = (error) => {
          this.#log('WARN: WebSocket connection error: ' + error);
        };

        this.socket.onmessage = async (event) => {
          this.#log('RECV: Received: ' + event.data);
    
          if (event.data instanceof ArrayBuffer) {
            const binaryData = new Uint8Array(event.data);
            await this.screen.draw(binaryData);
          } else {
            this.#log('RECV: Text data: ' + event.data);
          }
        };

        this.#BindKeyboard();
    }

    #BindKeyboard() {
        document.addEventListener("keydown", (event) => {
            const key = event.key.toUpperCase();
            if (['W','A','S','D', 'Z', 'X'].includes(key)) {
                this.socket.send(key);
                this.#log('SEND: Key pressed: ' + key);
            }
        });
    }

    #log(data) {
        if (this.printDebug) {
            console.log(data);
        }
    } 
}

export async function readFileAsUint8Array(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      
      reader.onload = function(event) {
        try {
          const buffer = event.target.result;
          const uint8Array = new Uint8Array(buffer);
          resolve(uint8Array);
        } catch (error) {
          reject(error);
        }
      };
      
      reader.onerror = function() {
        reject(new Error('Failed to read binary file'));
      };
      
      reader.readAsArrayBuffer(file);
    });
  }