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
            // Process the image before uploading
            const processedImageBuffer = await processImage(file);
            
            // Send processed image data to server
            const response = await fetch('/profiles/upload', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/octet-stream'
                },
                body: processedImageBuffer
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
    
    /**
     * Process image by resizing and compressing it
     * @param {File} file - The image file to process
     * @returns {Promise<ArrayBuffer>} - The processed image as an ArrayBuffer
     */
    async function processImage(file) {
        return new Promise((resolve, reject) => {
            // Create an image element to load the file
            const img = new Image();
            
            img.onload = () => {
                // Create a canvas to draw the image
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');
                
                // Calculate new dimensions while maintaining aspect ratio
                let width = img.width;
                let height = img.height;
                
                // Rescale if height is greater than 256px
                if (height > 256) {
                    const ratio = 256 / height;
                    height = 256;
                    width = Math.round(width * ratio);
                }
                
                // Set canvas dimensions to the new size
                canvas.width = width;
                canvas.height = height;
                
                // Draw the image on the canvas (this will resize it)
                ctx.drawImage(img, 0, 0, width, height);
                
                // Convert canvas to blob with compression
                canvas.toBlob((blob) => {
                    if (!blob) {
                        reject(new Error('Failed to create image blob'));
                        return;
                    }
                    
                    // Convert blob to ArrayBuffer
                    const reader = new FileReader();
                    reader.onload = () => {
                        resolve(reader.result);
                    };
                    reader.onerror = () => {
                        reject(new Error('Failed to read image data'));
                    };
                    reader.readAsArrayBuffer(blob);
                }, 'image/png', 0.8); // 0.8 quality for compression
            };
            
            img.onerror = () => {
                reject(new Error('Failed to load image'));
            };
            
            // Load the image from the file
            img.src = URL.createObjectURL(file);
        });
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
        return url;
        // url pattern-matching done by markdown parser
        // const fullUrl = url.startsWith('http') || url.startsWith('https') ? url : `http://${url}`;
        // return `<a href="${fullUrl}" target="_blank" rel="noopener noreferrer">${url}</a>`;
    }).replace(/@([A-Za-z0-9_]+)/g, (mention) => {
        return `<span style="background-color: #31304F; color: #A5B5F9; border-radius: 5px; text-decoration: underline;">${mention}</span>`;
    }).replace(':sob:', '😭');

    // Check if the processed text contains only emojis
    const emojiOnlyRegex = /^(\p{Extended_Pictographic}|\p{Emoji}\uFE0F|\p{Emoji_Modifier_Base}\p{Emoji_Modifier}?)+$/u;
    const isEmojiOnly = emojiOnlyRegex.test(processedText);

    messageElement.innerHTML = `
        <img src="${profilePicture}" onerror="this.onerror=null; this.src='logo.svg'" alt="profile" class="message-profile-picture">
        <div class="message-content">
            <div class="message-header">
                <span class="message-username">${username}</span>
                <span class="message-date">${date}</span>
            </div>
            <div class="message-text">${marked.parse(processedText)}</div>
        </div>
    `;

    // If the message contains only emojis, add a class for only emoji
    if (isEmojiOnly) {
        messageElement.querySelector('.message-text').classList.add('emoji-only');
    }
    
    messagesContainer.appendChild(messageElement);
    twemoji.parse(messageElement.querySelector('.message-text'));
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
