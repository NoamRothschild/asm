document.addEventListener('DOMContentLoaded', () => {
  const wsUrlInput = document.getElementById('wsUrl');
  const connectBtn = document.getElementById('connectBtn');
  const messageInput = document.getElementById('messageText');
  const sendBtn = document.getElementById('sendBtn');
  const logBox = document.getElementById('logBox');

  let websocket = null;

  function logMessage(reqType, message) {
    const reqClass = 'log-'+reqType.toLowerCase();
    const logEntry = document.createElement('div');
    logEntry.textContent = message;
    logEntry.classList.add(reqClass);
    logBox.appendChild(logEntry);
    logBox.scrollTop = logBox.scrollHeight; // Auto-scroll to bottom
  }

  function sendMessage() {
    if (!websocket || websocket.readyState !== WebSocket.OPEN) {
      logMessage('INFO', 'Not connected to WebSocket server.');
      return;
    }

    const message = messageInput.value;
    websocket.send(message);
    logMessage('SENT', 'Sent: ' + message);
    messageInput.value = ''; // Clear input after sending
  }

  connectBtn.addEventListener('click', () => {
    const wsUrl = wsUrlInput.value;

    if (websocket) {
      websocket.close();
    }

    websocket = new WebSocket(wsUrl);

    websocket.onopen = () => {
      logMessage('INFO', 'Connected to WebSocket server.');
      connectBtn.textContent = 'Disconnect';
    };

    websocket.onclose = () => {
      logMessage('INFO', 'Disconnected from WebSocket server.');
      connectBtn.textContent = 'Connect';
      websocket = null;
    };

    websocket.onerror = (error) => {
      logMessage('WARN', 'WebSocket connection error: ' + error);
    };

    websocket.onmessage = (event) => {
      if (document.getElementById('asHex').checked) {
        const hex = [...event.data]
          .map(c => c.charCodeAt(0).toString(16).padStart(2, '0'))
          .join(' ');
        logMessage('RECV', 'Received (hex): ' + hex);
      }
      logMessage('RECV', 'Received: ' + event.data);
    };
  });

  sendBtn.addEventListener('click', sendMessage);

  messageInput.addEventListener('keypress', (event) => {
    if (event.key === 'Enter') {
      sendMessage();
      event.preventDefault();
    }
  });
});