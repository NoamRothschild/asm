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
    if (channelName == null) return null;
    return channelName.replace(/\s/gm, '-').toLowerCase();
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
        this.currentChannel = channelNameToURI(initialChannel) || getCurrentChannel();
        this.connectionStatus = 'disconnected';
    }

    /**
     * Get the WebSocket URL for the current channel
     * @returns {string} The WebSocket URL for the current channel
     */
    getWebSocketURL() {
        return this.serverUrl + '/channels/' + channelNameToURI(this.currentChannel);
    }

    aboutThisProject() {
        if (channelNameToURI(this.currentChannel) == 'about-this-project') {
            window.addMessage('NoamRTD', `## Introduction
Assembly. You all hate it. "unreadable machine code", "a debugging nightmare", "incompatitable across different devices" - some might say, but I think it is beautiful.

Something about uncovering those layers of abstraction, and understanding how things really work always make's me hooked.

Try once to look at something you take for granted, and tell yourself: "but how does it work?", and then do the same for your result on and on. Slowly but surely, layer by layer, you will begin to understand how things *really* work behind the sences.

In the old days, people were making compilers for languages like Fortran, or C to escape the hell of dealing with raw CPU instructions and memory (Another article from me will most likely come about this topic too). People wanted layers of abstraction that would help them program faster and with a better experience overall (I'm ignoring for now the cross-platform aspect since this is not what this article is about).

I did not live to experience those old days. Instead I was born into a world where you can drag a 3d cube into a grid, click a magic green button and have a game (has its pros and cons). While this process mainly made making games feel exciting as a child, it also lit a spark inside me - the fact that I can operate this black box to do those kinds of things, and the fact that once I'm done I can really feel ownership of a thing I made got me pumped into programming - venturing into the unknown.

Last year, I moved into a new school. I've been searching for a better place to learn Computer Science than my old school - And I found just the place. After our professor taught us the basics of 16 bit assembly, and guided us through our way to coding a simple snake game he threw us straight into work. "You have until the end of the year to make a project in assembly, and present it to the class".

## The project

I immediately knew I wanted to make something special - I wanted to stand out, and it had to be done with networking.
So I started researching. Our environment ([dosbox](https://www.dosbox.com/)) had poor networking capabilities. it only supported an old protocol named IPX. while I did have success emulating the TCP/IP model over IPX - using tools I found on the internet, it was not worth the trouble. I opted to learn another architecture of assembly, one that would allow me better access to networking.
My initial plans were to create a simple old forums website, allowing users to look and respond to simple posts.`, '27/4/2024');
        }

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
                    this.aboutThisProject();
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
                    //window.location.href = '/login.html';

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
        
        // Clear all messages from the current channel
        const messagesContainer = document.querySelector('.messages-container');
        if (messagesContainer) {
            messagesContainer.innerHTML = '';
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
            
            // Find the null byte that separates username from message content
            let nullByteIndex = -1;
            for (let i = 4; i < messageData.length; i++) {
                if (messageData[i] === 0) {
                    nullByteIndex = i;
                    break;
                }
            }
            
            if (nullByteIndex === -1) {
                throw new Error('Server sent a malformed message (no null byte found)');
            }
            
            // Extract username using TextDecoder for proper UTF-8 handling
            const usernameBytes = messageData.slice(4, nullByteIndex);
            const username = new TextDecoder('utf-8').decode(usernameBytes);
            
            // Extract message content using TextDecoder for proper UTF-8 handling
            const messageBytes = messageData.slice(nullByteIndex + 1);
            const messageContent = new TextDecoder('utf-8').decode(messageBytes);
            
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
