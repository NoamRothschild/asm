import { ChannelWebSocket, getCurrentChannel, updateChannelBar, channelNameToURI } from './channel.js';

window.channelWebSocket = new ChannelWebSocket();

// Update profile name from localStorage
document.addEventListener('DOMContentLoaded', () => {
    const profileName = document.getElementById('profile-name');
    const username = localStorage.getItem('username');
    if (username) {
        profileName.textContent = username;
    }
});

/**
 * Sanitizes a string to prevent XSS attacks
 * @param {string} string - The string to sanitize
 * @returns {string} - The sanitized string
 * 
 * *source: https://stackoverflow.com/questions/2794137/sanitizing-user-input-before-adding-it-to-the-dom-in-javascript
 */
function sanitize(string) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#x27;',
        "/": '&#x2F;',
    };
    const reg = /[&<>"'/]/ig;
    return string.replace(reg, (match)=>(map[match]));
}
  

window.addMessage = function(username, text, date, profilePicture = 'logo.svg') {
    username = sanitize(username);
    text = sanitize(text);
    date = sanitize(date);
    profilePicture = sanitize(profilePicture);

    const messagesContainer = document.querySelector('.messages-container');
    
    const messageElement = document.createElement('div');
    messageElement.className = 'message';
    
    // Convert URLs to clickable links
    const urlRegex = /([\w+]+\:\/\/)?([\w\d-]+\.)*[\w-]+[\.\:]\w+([\/\?\=\&\#\.]?[\w-]+)*\/?/gm;
    const processedText = text.replace(urlRegex, (url) => {
        // Ensure URL has protocol
        const fullUrl = url.startsWith('http') ? url : `http://${url}`;
        return `<a href="${fullUrl}" target="_blank" rel="noopener noreferrer">${url}</a>`;
    });
    
    messageElement.innerHTML = `
        <img src="${profilePicture}" alt="profile" class="message-profile-picture">
        <div class="message-content">
            <div class="message-header">
                <span class="message-username">${username}</span>
                <span class="message-date">${date}</span>
            </div>
            <div class="message-text">${processedText}</div>
        </div>
    `;
    
    messagesContainer.appendChild(messageElement);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

const messageInput = document.querySelector('.message-input');
const sendButton = document.querySelector('.send-button');

function sendMessage() {
    const text = messageInput.value.trim();
    if (text) {
        // Send message through WebSocket if available
        if (window.channelWebSocket) {
            window.channelWebSocket.sendMessage(text);
        } 
        messageInput.value = '';
        messageInput.style.height = 'auto';
    }
}

messageInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
    }
});

sendButton.addEventListener('click', sendMessage);

// Channel switching functionality
document.addEventListener('DOMContentLoaded', () => {
    // Connect to WebSocket when page loads
    if (window.channelWebSocket) {
        window.channelWebSocket.connect()
            .then(() => {
                console.log('Connected to WebSocket server');
            })
            .catch(error => {
                console.error('Failed to connect to WebSocket server:', error);
            });
    }
    
    // Add click handlers to all channel elements
    const channelElements = document.querySelectorAll('.category-channels h4');
    channelElements.forEach(channelElement => {
        channelElement.addEventListener('click', () => {
            // Remove selected-channel ID from all channels
            channelElements.forEach(el => {
                el.id = el.id.replace('selected-channel', '');
            });
            
            // Add selected-channel ID to clicked channel
            channelElement.id = 'selected-channel';
            
            // Update channel bar
            updateChannelBar();
            
            // Switch channel in WebSocket if available
            if (window.channelWebSocket && window.channelWebSocket.connectionStatus === 'connected') {
                window.channelWebSocket.switchChannel(channelNameToURI(getCurrentChannel()));
            }
        });
    });
});
