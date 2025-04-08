function addMessage(username, text, date, profilePicture = 'logo.svg') {
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

// Example usage:
addMessage('John Doe', 'Check out this link: https://example.com and this one: google.com', 'Today at 2:30 PM');
addMessage('Alice Smith', 'Visit our docs at docs.example.com', 'Today at 2:32 PM', 'custom-profile.jpg');

// Message input functionality
const messageInput = document.querySelector('.message-input');
const sendButton = document.querySelector('.send-button');

function sendMessage() {
    const text = messageInput.value.trim();
    if (text) {
        const now = new Date();
        const hours = now.getHours();
        const minutes = now.getMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;
        
        const date = `Today at ${formattedHours}:${minutes.toString().padStart(2, '0')} ${ampm}`;
        
        addMessage('You', text, date);
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