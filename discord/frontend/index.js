import { ChannelWebSocket, getCurrentChannel, updateChannelBar, channelNameToURI } from './channel.js';

window.channelWebSocket = new ChannelWebSocket();

// Update profile name from localStorage
document.addEventListener('DOMContentLoaded', () => {
    const profileName = document.getElementById('profile-name');
    const username = localStorage.getItem('username');
    if (username) {
        profileName.textContent = username;
    }
    
    // Initialize profile picture upload functionality
    initProfilePictureUpload();
});

/**
 * Initialize profile picture upload functionality
 */
async function initProfilePictureUpload() {
    const profilePicture = document.getElementById('profile-picture');
    const profilePictureContainer = document.querySelector('.profile-picture-container');
    const uploadModal = document.getElementById('upload-modal');
    const uploadArea = document.getElementById('upload-area');
    const uploadButton = document.getElementById('upload-button');
    const fileInput = document.getElementById('file-input');
    const errorMessage = document.getElementById('error-message');
    
    // Open modal when clicking on profile picture
    profilePictureContainer.addEventListener('click', () => {
        uploadModal.style.display = 'flex';
    });
    
    // Close modal when clicking outside the modal content
    uploadModal.addEventListener('click', (e) => {
        if (e.target === uploadModal) {
            uploadModal.style.display = 'none';
            errorMessage.style.display = 'none';
        }
    });
    
    // Handle file selection via button
    uploadButton.addEventListener('click', () => {
        fileInput.click();
    });
    
    // Handle file selection
    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleFileUpload(e.target.files[0]);
        }
    });
    
    // Handle drag and drop
    uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('dragover');
    });
    
    uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('dragover');
    });
    
    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        
        if (e.dataTransfer.files.length > 0) {
            handleFileUpload(e.dataTransfer.files[0]);
        }
    });
    
    /**
     * Handle file upload
     * @param {File} file - The file to upload
     */
    async function handleFileUpload(file) {
        // Check if file is a PNG
        if (file.type !== 'image/png') {
            errorMessage.textContent = 'Please upload a PNG file';
            errorMessage.style.display = 'block';
            return;
        }
        
        try {
            // Read file as ArrayBuffer (raw binary data)
            const arrayBuffer = await file.arrayBuffer();

            if (arrayBuffer.byteLength > 1024 * 1024 * 0.85) {
                errorMessage.textContent = 'File size must be less than 85% of 1MB';
                errorMessage.style.display = 'block';
                return;
            }
            
            // Send raw binary data to server
            const response = await fetch('/profiles/upload', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/octet-stream'
                },
                body: arrayBuffer
            });
            
            if (!response.ok) {
                throw new Error('Upload failed');
            }
            
            // Update profile picture
            profilePicture.src = `profiles/${localStorage.getItem('username')}.png`;
            
            // Close modal
            uploadModal.style.display = 'none';
            
            // Refresh page
            window.location.reload();
        } catch (error) {
            // Show error message
            errorMessage.textContent = 'Failed to upload profile picture. Please try again.';
            errorMessage.style.display = 'block';
            console.error('Upload error:', error);
        }
    }
}

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
  

window.addMessage = function(username, text, date) {
    username = sanitize(username);
    text = sanitize(text);
    date = sanitize(date);
    const profilePicture = `profiles/${username}.png`;

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
        <img src="${profilePicture}" onerror="this.onerror=null; this.src='logo.svg'" alt="profile" class="message-profile-picture">
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
