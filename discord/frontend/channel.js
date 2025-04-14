/**
 * Gets the currently selected channel from the sidebar
 * @returns {string} The name of the currently selected channel (without the # symbol)
 */
function getCurrentChannel() {
    const selectedChannelElement = document.getElementById('selected-channel');
    if (selectedChannelElement) {
        // Remove the # symbol from the channel name
        return selectedChannelElement.textContent.replace('#', '').trim();
    }
    return null;
}

/**
 * Converts the currently selected channel name to a URI
 * @returns {string} The URI of the currently selected channel
 */
function channelNameToURI(channelName) {
    return channelName.replace(' ', '-').toLowerCase();
}

/**
 * Updates the channel name in the channel bar to match the selected channel
 */
function updateChannelBar() {
    const currentChannel = getCurrentChannel();
    const channelBarElement = document.querySelector('.channel-name');
    
    if (currentChannel && channelBarElement) {
        channelBarElement.textContent = `# ${currentChannel}`;
    }
}

/**
 * WebSocket handler class for managing channel connections and messaging
 */
class ChannelWebSocket {
    /**
     * Create a new ChannelWebSocket instance
     * @param {string} initialChannel - The initial channel to connect to
     */
    constructor(initialChannel = null) {
        const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'; // Check if the protocol is HTTPS or HTTP
        const domain = window.location.hostname; // Get the current domain
        const port = window.location.port ? `:${window.location.port}` : ''; // Get the port if it exists, otherwise use an empty string

        this.serverUrl = `${protocol}://${domain}${port}`;
        this.socket = null;
        this.currentChannel = initialChannel || getCurrentChannel();
        this.connectionStatus = 'disconnected';
    }

    /**
     * Get the WebSocket URL for the current channel
     * @returns {string} The WebSocket URL for the current channel
     */
    getWebSocketURL() {
        return this.serverUrl + '/channels/' + channelNameToURI(this.currentChannel);
    }

    /**
     * Connect to the WebSocket server
     * @param {string} channelName - The name of the channel to join
     * @returns {Promise} A promise that resolves when connected
     */
    connect() {
        return new Promise((resolve, reject) => {
            try {
                this.socket = new WebSocket(this.getWebSocketURL());
                this.socket.binaryType = 'arraybuffer';
                
                this.socket.onopen = () => {
                    console.log(`WebSocket connection established to ${this.currentChannel}`);
                    this.connectionStatus = 'connected';
                    resolve();
                };
                
                this.socket.onmessage = (event) => {
                    this.handleMessage(event.data);
                };
                
                this.socket.onclose = () => {
                    console.log(`WebSocket connection closed to ${this.currentChannel}`);
                    this.connectionStatus = 'disconnected';
                };
                
                this.socket.onerror = (error) => {
                    window.location.href = '/login.html';

                    console.error(`WebSocket error to ${this.currentChannel}:`, error);
                    this.connectionStatus = 'error';
                    reject(error);
                };

            } catch (error) {
                console.error(`Failed to create WebSocket connection to ${this.currentChannel}:`, error);
                this.connectionStatus = 'error';
                reject(error);
            }
        });
    }

    
    /**
     * Switch to a different channel
     * @param {string} channelName - The name of the channel to switch to
     */
    switchChannel(channelName) {
        if (channelName === this.currentChannel) {
            console.log(`Already in channel: ${channelName}`);
            return;
        }
        
        this.disconnect();
        this.currentChannel = channelName;
        this.connect();
    }

    /**
     * Send a raw message to the WebSocket server
     * @param {string} message - The message to send
     * @param {number} maxLength - The maximum length of the message
     */
    sendMessage(message, maxLength = 64000) {
        if (!this.socket || this.connectionStatus !== 'connected') {
            console.error('Cannot send message: WebSocket not connected');
            return;
        }
        
        try {
            this.socket.send(message.substring(0, maxLength));
        } catch (error) {
            console.error('Error sending message:', error);
        }
    }

    /**
     * Handle incoming WebSocket messages
     * @param {string} data - The raw message data
     */
    handleMessage(data) {
        try {
            if (!(data instanceof ArrayBuffer)) {
                throw new Error('Invalid message format (non-binary)');
            } 
            const messageData = new Uint8Array(data);
            // first 4 bytes are UNIX timestamp and were sent in little endian format
            const timestamp = new Date(messageData.subarray(0, 4).reverse().join(''));
            // next bytes until a null byte are username
            let username = '';
            for (let i = 4; i < messageData.length; i++) {
                if (messageData[i] === 0) {
                    break;
                }
                username += String.fromCharCode(messageData[i]);
            }
            // next is message content
            const messageContent = String.fromCharCode(...messageData.slice(username.length + 5));
            
            // formatted like HH:MM AM/PM
            const date = new Date(timestamp);
            const hours = date.getHours();
            const minutes = date.getMinutes();
            const ampm = hours >= 12 ? 'PM' : 'AM';
            const formattedHours = hours % 12 || 12;
            const formattedDate = `${formattedHours}:${minutes.toString().padStart(2, '0')} ${ampm}`;

            window.addMessage(username, messageContent, formattedDate);
        } catch (error) {
            console.error('Error parsing message:', error);
        }
    }

    /**
     * Disconnect from the WebSocket server
     */
    disconnect() {
        if (this.socket) {
            this.socket.close();
            this.socket = null;
            this.connectionStatus = 'disconnected';
        }
    }
}

// Export functions and class for use in other files
export { 
    getCurrentChannel, 
    updateChannelBar, 
    channelNameToURI,
    ChannelWebSocket
}; 