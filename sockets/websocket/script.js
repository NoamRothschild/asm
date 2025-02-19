document.addEventListener('DOMContentLoaded', () => {
  const wsUrlInput = document.getElementById('wsUrl');
  const connectBtn = document.getElementById('connectBtn');
  const messageInput = document.getElementById('messageText');
  const sendBtn = document.getElementById('sendBtn');
  const logBox = document.getElementById('logBox');

  let websocket = null;

  function logMessage(message) {
    const logEntry = document.createElement('div');
    logEntry.textContent = message;
    logBox.appendChild(logEntry);
    logBox.scrollTop = logBox.scrollHeight; // Auto-scroll to bottom
  }

  connectBtn.addEventListener('click', () => {
    const wsUrl = wsUrlInput.value;

    if (websocket) {
      websocket.close();
    }

    websocket = new WebSocket(wsUrl);

    websocket.onopen = () => {
      logMessage('Connected to WebSocket server.');
      connectBtn.textContent = 'Disconnect';
    };

    websocket.onclose = () => {
      logMessage('Disconnected from WebSocket server.');
      connectBtn.textContent = 'Connect';
      websocket = null;
    };

    websocket.onerror = (error) => {
      logMessage('WebSocket connection error: ' + error);
    };

    websocket.onmessage = (event) => {
      logMessage('Received: ' + event.data);
    };
  });

  sendBtn.addEventListener('click', () => {
    if (!websocket || websocket.readyState !== WebSocket.OPEN) {
      logMessage('Not connected to WebSocket server.');
      return;
    }

    const message = messageInput.value;
    websocket.send(message);
    logMessage('Sent: ' + message);
    messageInput.value = ''; // Clear input after sending
  });
});