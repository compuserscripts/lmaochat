// Required dependencies
const express = require('express');
const crypto = require('crypto');
const { Client } = require('discord.js-selfbot-v13');

const SERVER_VERSION = "1.0.0";

// Database configuration
const debugDb = true; // Set to true to use SQLite, false for MySQL

// Dynamic database imports
const mysql = !debugDb ? require('mysql2/promise') : null;
const mysqlPool = !debugDb ? mysql.createPool({
    host: 'localhost',
    user: 'chatuser',
    password: 'chatpass',
    database: 'chatdb',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
}) : null;
const Database = debugDb ? require('better-sqlite3') : null;

const app = express();
const port = 8080;

// Database configuration
const dbConfig = debugDb ? {
    filename: './chat.db'
} : {
    host: 'localhost',
    user: 'chatuser',
    password: 'chatpass',
    database: 'chatdb'
};

// Global message queue
let messageQueue = [];
const MESSAGE_LIFETIME = 4500; // 4.5 seconds in milliseconds
const MAX_RESPONSE_BYTES = 144;
const SEPARATOR = ':';
const NICKNAME_MAX_LENGTH = 16;
const MESSAGE_MAX_LENGTH = 127;
const OFFLINE_THRESHOLD = 20000; // 20 seconds in milliseconds
const BASE_COOLDOWN = 5000; // 5 seconds base cooldown
const MAX_COOLDOWN = 30000; // Maximum cooldown of 30 seconds
const CONSECUTIVE_MESSAGE_LIMIT = 2; // Number of messages before exponential backoff

// User activity and message tracking
const userActivity = new Map();
const userMessageTimers = new Map();
const userConsecutiveMessages = new Map();
const displayOrder = []; // Array to maintain order of displayed users
const MAX_DISPLAYED_USERS = 10; // Maximum users to show in list

const COLON_REPLACEMENT = '꞉'; // U+A789 MODIFIER LETTER COLON
const REAL_SEPARATOR = ':';

const RESERVED_NICKNAMES = ['SRV', 'DC'];
const RESERVED_USERNAMES = ['SRV', 'DC'];

// Discord Integration
const discordClient = new Client();
const targetServerId = '1055898368968245348';

discordClient.on('ready', () => {
    console.log('Discord bot is ready!');
    console.log('Logged in as:', discordClient.user.tag);
});

discordClient.on('messageCreate', async (message) => {
    // Skip bot messages
    if (message.author.bot || message.author.username === discordClient.user.username) {
        return;
    }

    // Check if message is from target server
    if (message.guild?.id !== targetServerId) {
        return;
    }

    // Only log messages from actual users
    console.log('Discord message received:', {
        user: message.author.username,
        channel: message.channel.name,
        content: message.content.slice(0, 50) + (message.content.length > 50 ? '...' : '')
    });

    if (message.content.trim() === '') {
        return;
    }

    // Format author name and channel, replacing any colons with the modifier letter colon
    const prefix = `${(message.author.globalName || message.author.username).replace(/:/g, COLON_REPLACEMENT)} @ ${message.channel.name.replace(/:/g, COLON_REPLACEMENT)}`;
    
    // Process message content
    let content = message.content
        // First replace all types of newlines with spaces
        .replace(/\r\n|\r|\n/g, ' ')
        // Replace all colons with the modifier letter colon
        .replace(/:/g, COLON_REPLACEMENT);
    
    // Find all URLs in the content
    const urlMatches = [...content.matchAll(/https?:\/\/\S+/g)];
    
    if (urlMatches.length > 0) {
        // Keep track of where we want to cut the content
        let cutIndex = content.length;
        
        // Remove all URLs first
        content = content.replace(/https?:\/\/\S+/g, '');
        
        // Try to add back the first URL if it's complete and fits
        const firstUrl = urlMatches[0][0];
        if (!firstUrl.endsWith('...') && (content.length + firstUrl.length + 1) <= MESSAGE_MAX_LENGTH) {
            content = `${content} ${firstUrl}`;
        }
    }
    
    content = content
        // Handle channel mentions, replacing any colons in channel names
        .replace(/<#(\d+)>/g, (match, channelId) => {
            const mentionedChannel = message.guild.channels.cache.get(channelId);
            return mentionedChannel ? `#${mentionedChannel.name.replace(/:/g, COLON_REPLACEMENT)}` : match;
        })
        // Handle user mentions, replacing any colons in usernames
        .replace(/<@!?(\d+)>/g, (match, userId) => {
            const member = message.guild.members.cache.get(userId);
            return member ? `@${(member.user.globalName || member.user.username).replace(/:/g, COLON_REPLACEMENT)}` : match;
        })
        // Handle emoji, keeping the colon replacement
        .replace(/<a?:\w+:\d+>/g, (match) => {
            const emojiName = match.match(/<a?:(\w+):\d+>/)[1];
            return `${COLON_REPLACEMENT}${emojiName}${COLON_REPLACEMENT}`;
        })
        // Clean up multiple spaces and trim
        .replace(/\s+/g, ' ')
        .trim();

    if (message.attachments.size > 0) {
        const attachments = Array.from(message.attachments.values());
        const fileNames = attachments.map(attachment => {
            const lastDotIndex = attachment.name.lastIndexOf('.');
            const nameWithoutExt = lastDotIndex !== -1 ? attachment.name.slice(0, lastDotIndex) : attachment.name;
            // Also replace colons in attachment names
            const sanitizedName = nameWithoutExt.replace(/:/g, COLON_REPLACEMENT);
            return sanitizedName.length > 10 ? sanitizedName.slice(0, 10) + '...' : sanitizedName;
        }).join(', ');
        content = `[${fileNames}] ${content}`;
    }

    const finalMessage = `${prefix}${COLON_REPLACEMENT} ${content}`;

    let truncatedMessage = finalMessage;
    if (Buffer.byteLength(truncatedMessage) > MESSAGE_MAX_LENGTH) {
        while (Buffer.byteLength(truncatedMessage) > MESSAGE_MAX_LENGTH - 3) {
            truncatedMessage = truncatedMessage.slice(0, -1);
        }
        truncatedMessage += '...';
    }

    console.log('Adding to chat queue:', {
        from: message.author.username,
        channel: message.channel.name,
        messageLength: truncatedMessage.length
    });

    // Add to message queue using existing function
    addMessageToQueue('DC', truncatedMessage);
});

// Database wrapper class
class DatabaseWrapper {
    constructor() {
        this.db = null;
        this.connectionAttempts = 0;
        this.maxRetries = 5;
        this.retryDelay = 1000; // Start with 1 second delay
    }
 
    async connect() {
        while (this.connectionAttempts < this.maxRetries) {
            try {
                if (debugDb) {
                    this.db = new Database(dbConfig.filename);
                } else {
                    this.db = await mysqlPool.getConnection();
                }
                this.connectionAttempts = 0; // Reset on successful connection
                return;
            } catch (error) {
                this.connectionAttempts++;
                console.error(`Database connection attempt ${this.connectionAttempts} failed:`, error);
                
                if (this.connectionAttempts < this.maxRetries) {
                    // Exponential backoff
                    const delay = this.retryDelay * Math.pow(2, this.connectionAttempts - 1);
                    await new Promise(resolve => setTimeout(resolve, delay));
                } else {
                    throw new Error('Max connection retries reached');
                }
            }
        }
    }

    async execute(query, params = []) {
        if (debugDb) {
            // Convert MySQL syntax to SQLite
            query = query
                .replace(/NOW\(\)/g, "(DATETIME('now'))")
                .replace(/CURRENT_TIMESTAMP/g, "(DATETIME('now'))")
                .replace(/`/g, '"')
                .replace(/INT AUTO_INCREMENT PRIMARY KEY/g, 'INTEGER PRIMARY KEY AUTOINCREMENT')
                .replace(/BOOLEAN/g, 'INTEGER')
                .replace(/DATE_ADD\((.*?), INTERVAL (\?) MINUTE\)/g, "DATETIME($1, '+' || ? || ' minutes')")
                .replace(/DATE_ADD\(NOW\(\), INTERVAL (\?) MINUTE\)/g, "DATETIME('now', '+' || ? || ' minutes')");
            
            try {
                if (query.toLowerCase().trim().startsWith('select')) {
                    const stmt = this.db.prepare(query);
                    const result = stmt.all(params);
                    return [result || [], null];
                } else {
                    const stmt = this.db.prepare(query);
                    const result = stmt.run(params);
                    return [{ affectedRows: result.changes }, null];
                }
            } catch (error) {
                if (error.message.includes('no such table')) {
                    return [[], null];
                }
                throw error;
            }
        } else {
            return this.db.execute(query, params);
        }
    }

    async end() {
        if (debugDb) {
            this.db.close();
        } else {
            await this.db.end();
        }
    }
}

// 4. Database cleanup - add this function and interval
async function cleanupDatabase() {
    const db = new DatabaseWrapper();
    try {
        await db.connect();
        
        // Clean up expired bans
        await db.execute('DELETE FROM bans WHERE expires_at < NOW()');
        
        // Clean up expired mutes
        await db.execute('DELETE FROM mutes WHERE expires_at < NOW()');
        
        console.log('Database cleanup completed');
    } catch (error) {
        console.error('Error during database cleanup:', error);
    } finally {
        await db.end();
    }
}

// Initialize database
async function initializeDatabase() {
    if (!debugDb) {
        // MySQL setup
        const rootConnection = await mysql.createConnection({
            host: 'localhost',
            user: 'root'
        });
    
        await rootConnection.query(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database}`);
        await rootConnection.query(`CREATE USER IF NOT EXISTS '${dbConfig.user}'@'localhost' IDENTIFIED BY '${dbConfig.password}'`);
        await rootConnection.query(`GRANT ALL PRIVILEGES ON ${dbConfig.database}.* TO '${dbConfig.user}'@'localhost'`);
        await rootConnection.query('FLUSH PRIVILEGES');
        await rootConnection.end();
    }

    const db = new DatabaseWrapper();
    await db.connect();
    
    // Create tables with SQLite-compatible syntax
    if (debugDb) {
        await db.execute(`
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE,
                password_hash TEXT,
                is_operator INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT (DATETIME('now'))
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS nicknames (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT,
                nickname TEXT UNIQUE,
                is_active INTEGER DEFAULT 1,
                created_at DATETIME DEFAULT (DATETIME('now')),
                last_used DATETIME DEFAULT (DATETIME('now'))
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS nickname_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT,
                old_nickname TEXT,
                new_nickname TEXT,
                changed_by TEXT,
                reason TEXT,
                created_at DATETIME DEFAULT (DATETIME('now'))
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS bans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT,
                reason TEXT,
                expires_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS mutes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT,
                expires_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS motd (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message TEXT NOT NULL,
                created_by TEXT NOT NULL,
                created_at DATETIME DEFAULT (DATETIME('now')),
                is_active INTEGER DEFAULT 1
            )
        `);
    } else {
        await db.execute(`
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(16) UNIQUE,
                password_hash VARCHAR(64),
                is_operator BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS nicknames (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(32),
                nickname VARCHAR(16) UNIQUE,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS nickname_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(32),
                old_nickname VARCHAR(16),
                new_nickname VARCHAR(16),
                changed_by VARCHAR(32),
                reason VARCHAR(128),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS bans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(16),
                reason VARCHAR(128),
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS mutes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(16),
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS motd (
                id INT AUTO_INCREMENT PRIMARY KEY,
                message VARCHAR(512) NOT NULL,
                created_by VARCHAR(32) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT TRUE
            )
        `);
    }

    await db.end();
}

// Utility functions
function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// Different sanitization functions for different types of input
function sanitizeUsername(text) {
    // For usernames: only allow alphanumeric and basic symbols, NO spaces
    //return text.replace(new RegExp(`[^a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;'",.<>/?~\\\\]`, 'g'), '');

    // For usernames: only allow alphanumeric and basic symbols, NO spaces
    return text.replace(/[^a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;'",.<>/?~\\]/g, '');
}

function sanitizePassword(text) {
    // For passwords: allow most special chars but NO spaces
    //return text.replace(new RegExp(`[^a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;'",.<>/?~\\\\]`, 'g'), '');

    // For passwords: allow most special chars but NO spaces
    return text.replace(/[^a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;'",.<>/?~\\]/g, '');
}

function sanitizeNickname(text) {
    // For nicknames: allow spaces and common special chars
    // return text.replace(new RegExp(`[^a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;'",.<>/?~\\\\ ]`, 'g'), '');

    // For nicknames: allow spaces and common special chars
    return text.replace(/[^a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;'",.<>/?~\\ ]/g, '');
}

function sanitizeMessage(text) {
    // For messages: most permissive, allow spaces and common special chars
    //return text.replace(new RegExp(`[^a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;'",.<>/?~\\\\ ]`, 'g'), '');

    // For messages: most permissive, allow spaces, color codes, and common special chars
    //return text.replace(new RegExp(`[^\x01-\x10a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;'",.<>/?~\\\\ ]`, 'g'), '');

    // For messages: allow color codes (0x01-0x10), spaces, and common special chars
    //return text.replace(/[^\x01-\x10a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;'",.<>/?~\\ ]/g, '');

    // First replace real colons with our substitute
    text = text.replace(/:/g, COLON_REPLACEMENT);
    
    // Then apply the normal sanitization rules
    // For messages: allow color codes (0x01-0x10), spaces, and common special chars
    return text.replace(/[^\x01-\x10a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;'",.<>/?~\\ ꞉]/g, '');
}

function truncateString(str, maxLength) {
    return str.slice(0, maxLength);
}

// Update the decodeParam function
function decodeParam(param) {
    if (!param) return param;
    
    try {
        // First replace plus with space (must be done before decodeURIComponent)
        let decoded = param.replace(/\+/g, ' ');
        
        // Then decode percent-encoded characters
        decoded = decodeURIComponent(decoded);
        
        // Special handling for color codes - convert %01-%10 back to raw bytes
        decoded = decoded.replace(/%([0-9A-Fa-f]{2})/g, (match, p1) => {
            const code = parseInt(p1, 16);
            // Only convert codes in the color code range (0x01-0x10)
            if (code >= 0x01 && code <= 0x10) {
                return String.fromCharCode(code);
            }
            return match;
        });
        
        return decoded;
    } catch (e) {
        console.error('Error decoding parameter:', e);
        return param;
    }
}

// Add message to queue and update activity
function addMessageToQueue(nick, message, isSystem = false) {
    const truncatedNick = truncateString(nick || '', NICKNAME_MAX_LENGTH);
    const truncatedMessage = truncateString(message || '', MESSAGE_MAX_LENGTH);
    const timestamp = Date.now();
    
    // Filter out any identical system messages from the last 5 seconds
    if (isSystem) {
        messageQueue = messageQueue.filter(msg => 
            !(msg.nick === 'SRV' && 
              msg.message === truncatedMessage &&  
              timestamp - msg.timestamp < 5000)
        );
    }
    
    const entry = {
        nick: isSystem ? 'SRV' : truncatedNick,
        message: truncatedMessage,
        timestamp
    };
    
    console.log('Adding message to queue:', entry);
    messageQueue.push(entry);

    // If not a system message, update user's last active time
    if (!isSystem && userActivity.has(truncatedNick)) {
        const userData = userActivity.get(truncatedNick);
        userData.lastActive = timestamp;
        userActivity.set(truncatedNick, userData);
    }

    // Remove message after lifetime
    setTimeout(() => {
        messageQueue = messageQueue.filter(msg => msg !== entry);
    }, MESSAGE_LIFETIME);
}

// Activity check interval
setInterval(() => {
    const now = Date.now();
    const inactiveUsers = new Set();

    // Find users who have timed out
    Array.from(userActivity.entries()).forEach(([username, data]) => {
        if (now - data.lastActive >= OFFLINE_THRESHOLD) {
            console.log('User went offline:', username);
            addMessageToQueue(null, `${data.nickname}\\x15 has left`, true);
            userActivity.delete(username);
            inactiveUsers.add(username);
        }
    });

    // Clean up display order
    displayOrder.forEach((username, index) => {
        if (inactiveUsers.has(username)) {
            displayOrder.splice(index, 1);
        }
    });
}, 5000);

// Add helper function to check if user has a valid session
function hasValidSession(username) {
    const userData = userActivity.get(username);
    return userData && (Date.now() - userData.lastActive < OFFLINE_THRESHOLD);
}

async function checkUserRestrictions(username, db) {
   // Check bans first
   const [bans] = await db.execute(
       'SELECT * FROM bans WHERE username = ? AND expires_at > NOW()',
       [username]
   );
   if (bans.length > 0) {
       return { restricted: true, reason: 'BANNED', type: 'ban' };
   }

   // Check mutes (only affects posting)
   const [mutes] = await db.execute(
       'SELECT * FROM mutes WHERE username = ? AND expires_at > NOW()',
       [username]
   );
   if (mutes.length > 0) {
       return { restricted: true, reason: 'MUTED', type: 'mute' };
   }

   return { restricted: false };
}

// Modify the authenticate middleware to decode username and nickname
async function authenticate(req, res, next) {
    // Allow registration and unauthenticated get
    if (req.query.a === 'reg' || (req.query.a === 'get' && !req.query.u) || (req.query.a === 'version' && !req.query.u)) {
        return next();
    }

    // Decode auth parameters
    const username = decodeParam(req.query.u);
    const password = decodeParam(req.query.p);
    const nickname = decodeParam(req.query.n);

    // Check for required authentication fields
    if (!username || !password) {
        return res.send('AUTH_ERROR');
    }

    // Check if we need a nickname for chat-related actions
    if (['post'].includes(req.query.a) && !nickname) {
        return res.send('INVALID_PARAMS');
    }

    const db = new DatabaseWrapper();
    await db.connect();
    
    try {
        // Run credential check and restrictions check in parallel
        const [userRows, restrictions] = await Promise.all([
            db.execute(
                'SELECT * FROM users WHERE username = ? AND password_hash = ?',
                [username, hashPassword(password)]
            ),
            checkUserRestrictions(username, db)
        ]);
        
        if (userRows[0].length === 0) return res.send('AUTH_ERROR');
        req.user = userRows[0][0];
        // For admin endpoint, only check if user is operator
        //if (req.path === '/admin') {
        //    if (!req.user.is_operator) {
        //        return res.send('NOT_OPERATOR');
        //    }
        //    return next();
        //}
        req.userRestrictions = restrictions;

        // If user is banned or trying to post while muted, return the restriction status
        if ((restrictions.type === 'ban') || 
            (restrictions.type === 'mute' && req.query.a === 'post')) {
            return res.send(restrictions.reason);
        }

        // Check for valid session
        if ((req.query.a === 'list' || req.query.a === 'post') && !hasValidSession(username)) {
            return res.send('NO_SESSION');
        }

        // Update activity on GET requests if not banned
        if (req.query.a === 'get' && restrictions.type !== 'ban') {
            const activityResult = await updateUserActivity(
                username,
                nickname || username,
                req.query.a
            );
            
            if (!activityResult.success) {
                if (activityResult.error === 'NICKNAME_TAKEN') {
                    return res.send('NICKNAME_TAKEN');
                }
                return res.send('ERROR: ' + activityResult.error);
            }
        }

        next();
    } catch (error) {
        console.error('Auth error:', error);
        res.send('AUTH_ERROR: ' + error.message);
    } finally {
        await db.end();
    }
}

// Modify the registerNickname function to check for reserved nicknames
async function registerNickname(username, nickname, db) {
    try {
        // First check if nickname is reserved
        if (RESERVED_NICKNAMES.includes(nickname)) {
            return false;
        }

        // First check if this user is already using this nickname
        const [currentNick] = await db.execute(
            'SELECT id FROM nicknames WHERE username = ? AND nickname = ? AND is_active = 1',
            [username, nickname]
        );

        // If user already has this active nickname, just update last_used
        if (currentNick.length > 0) {
            await db.execute(
                debugDb ? 
                    "UPDATE nicknames SET last_used = DATETIME('now') WHERE id = ?" :
                    'UPDATE nicknames SET last_used = NOW() WHERE id = ?',
                [currentNick[0].id]
            );
            return true;
        }

        // Check if nickname is taken by someone else
        const [existing] = await db.execute(
            'SELECT username, is_active FROM nicknames WHERE nickname = ?',
            [nickname]
        );

        if (existing.length > 0) {
            // If nickname exists but is inactive, check if it belongs to the same user
            if (!existing[0].is_active && existing[0].username === username) {
                // Reactivate the nickname
                await db.execute(
                    debugDb ?
                        "UPDATE nicknames SET is_active = 1, last_used = DATETIME('now') WHERE nickname = ? AND username = ?" :
                        'UPDATE nicknames SET is_active = 1, last_used = NOW() WHERE nickname = ? AND username = ?',
                    [nickname, username]
                );
                return true;
            }
            // Nickname is taken by someone else
            if (existing[0].is_active) {
                return false;
            }
        }

        // Rest of the function remains the same...
        await db.execute(
            'UPDATE nicknames SET is_active = 0 WHERE username = ? AND is_active = 1',
            [username]
        );

        await db.execute(
            debugDb ?
                "INSERT INTO nicknames (username, nickname, created_at, last_used) VALUES (?, ?, DATETIME('now'), DATETIME('now'))" :
                'INSERT INTO nicknames (username, nickname, created_at, last_used) VALUES (?, ?, NOW(), NOW())',
            [username, nickname]
        );

        await db.execute(
            debugDb ?
                "INSERT INTO nickname_history (username, old_nickname, new_nickname, changed_by, reason, created_at) VALUES (?, ?, ?, ?, ?, DATETIME('now'))" :
                'INSERT INTO nickname_history (username, old_nickname, new_nickname, changed_by, reason, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
            [username, null, nickname, username, 'Self-selected']
        );

        return true;
    } catch (error) {
        console.error('Error in registerNickname:', error);
        return false;
    }
}

// Modify updateUserActivity to return success/failure instead of throwing
async function updateUserActivity(username, nickname, action = '') {
    const now = Date.now();
    const wasActive = userActivity.has(username);

    if (action === 'post' || action === 'get') {
        const db = new DatabaseWrapper();
        await db.connect();

        try {
            // Try to register the nickname
            const success = await registerNickname(username, nickname, db);
            if (!success) {
                return { success: false, error: 'NICKNAME_TAKEN' };
            }

            // Update or create activity entry
            userActivity.set(username, {
                lastActive: now,
                nickname
            });

            // Handle display order for new users or posts
            if (!wasActive && action === 'get') {
                // First time joining - add to front of display
                displayOrder.unshift(username);
                addMessageToQueue(null, `${nickname}\\x15 has joined`, true);
            } else if (action === 'post') {
                // Move to front of display on post
                const index = displayOrder.indexOf(username);
                if (index !== -1) {
                    displayOrder.splice(index, 1);
                }
                displayOrder.unshift(username);
            }

            // Trim display order to max length
            if (displayOrder.length > MAX_DISPLAYED_USERS) {
                displayOrder.splice(MAX_DISPLAYED_USERS);
            }

            return { success: true };
        } catch (error) {
            console.error('Error updating user activity:', error);
            return { success: false, error: error.message };
        } finally {
            await db.end();
        }
    }
    return { success: true };
}

// API Endpoints
app.get('/api/', authenticate, async (req, res) => {
    const action = req.query.a;
    const db = new DatabaseWrapper();
    await db.connect();

    try {
        let actionResult = 'OK';

        switch (action) {
            case 'version':
                // Version check doesn't require authentication
                return res.send(SERVER_VERSION);
            // Modify the registration endpoint in your app.get('/api/') handler
            case 'reg':
                if (!req.query.u || !req.query.p) {
                    actionResult = 'INVALID_PARAMS';
                    break;
                }

                // Decode and sanitize username
                const decodedRegUsername = decodeParam(req.query.u);
                const sanitizedRegUsername = sanitizeUsername(decodedRegUsername);
                
                // Check if username is reserved
                if (RESERVED_USERNAMES.includes(sanitizedRegUsername)) {
                    actionResult = 'USERNAME_TAKEN';
                    break;
                }
                
                // Validate username
                if (!sanitizedRegUsername || sanitizedRegUsername !== decodedRegUsername || 
                    sanitizedRegUsername.length > NICKNAME_MAX_LENGTH) {
                    actionResult = 'INVALID_USERNAME';
                    break;
                }

                try {
                    const [[existingUser], [operatorCount]] = await Promise.all([
                        db.execute(
                            'SELECT username FROM users WHERE username = ?',
                            [sanitizedRegUsername]
                        ),
                        db.execute('SELECT COUNT(*) as count FROM users WHERE is_operator = 1')
                    ]);

                    if (existingUser.length > 0) {
                        actionResult = 'USERNAME_TAKEN';
                        break;
                    }

                    const isFirstUser = operatorCount[0].count === 0;
                    const decodedPassword = decodeParam(req.query.p);
                    const sanitizedPassword = sanitizePassword(decodedPassword);
                    
                    await db.execute(
                        'INSERT INTO users (username, password_hash, is_operator) VALUES (?, ?, ?)',
                        [sanitizedRegUsername, hashPassword(sanitizedPassword), isFirstUser ? 1 : 0]
                    );
                } catch (error) {
                    console.error('Registration error:', error);
                    actionResult = 'REGISTRATION_FAILED';
                }
                break;

            case 'post':
                // First check restrictions (ban/mute)
                if (req.userRestrictions.restricted) {
                    actionResult = req.userRestrictions.reason;
                    break;
                }
            
                if (!req.query.n || !req.query.m) {
                    actionResult = 'INVALID_PARAMS';
                    break;
                }
            
                // Decode and sanitize inputs
                const decodedMessage = decodeParam(req.query.m);
                const decodedNickname = decodeParam(req.query.n);
                
                // Check if message is empty before sanitization
                if (!decodedMessage.trim()) {
                    actionResult = 'EMPTY_MESSAGE';
                    break;
                }
            
                // Length checks on raw decoded input first
                if (decodedNickname.length > NICKNAME_MAX_LENGTH || decodedMessage.length > MESSAGE_MAX_LENGTH) {
                    actionResult = 'MESSAGE_TOO_LONG';
                    break;
                }
            
                // Sanitize after length checks
                const sanitizedMessage = sanitizeMessage(decodedMessage);
                const sanitizedNickname = sanitizeNickname(decodedNickname);
            
                // Check if sanitized message is empty
                if (!sanitizedMessage.trim()) {
                    actionResult = 'EMPTY_MESSAGE';
                    break;
                }
            
                // Check message cooldown
                const lastMessageTime = userMessageTimers.get(req.user.username) || 0;
                const consecutiveCount = userConsecutiveMessages.get(req.user.username) || 0;
                const currentCooldown = consecutiveCount >= CONSECUTIVE_MESSAGE_LIMIT
                    ? Math.min(BASE_COOLDOWN * Math.pow(2, Math.floor((consecutiveCount - CONSECUTIVE_MESSAGE_LIMIT) / 2)), MAX_COOLDOWN)
                    : BASE_COOLDOWN;
            
                if (Date.now() - lastMessageTime < currentCooldown) {
                    actionResult = 'COOLDOWN';
                    break;
                }
            
                // Update activity
                const activityResult = await updateUserActivity(req.user.username, sanitizedNickname, req.query.a);
                if (!activityResult.success) {
                    actionResult = activityResult.error === 'NICKNAME_TAKEN' ? 'NICKNAME_TAKEN' : 'ERROR: ' + activityResult.error;
                    break;
                }
            
                // Add message to queue and update timers
                addMessageToQueue(sanitizedNickname, sanitizedMessage);
                userMessageTimers.set(req.user.username, Date.now());
                
                // Update consecutive message count
                if (Date.now() - lastMessageTime > BASE_COOLDOWN * 2) {
                    userConsecutiveMessages.set(req.user.username, 1);
                } else {
                    userConsecutiveMessages.set(req.user.username, consecutiveCount + 1);
                }
                
                actionResult = 'OK';
                break;

            case 'get':
                let messagesResponse = '';
                for (const msg of messageQueue) {
                    const messageStr = `${msg.nick}${SEPARATOR}${msg.message}`;
                    if (messagesResponse.length + messageStr.length + (messagesResponse ? SEPARATOR.length : 0) <= MAX_RESPONSE_BYTES) {
                        messagesResponse += (messagesResponse ? SEPARATOR : '') + messageStr;
                    }
                }
                actionResult = messagesResponse || 'NO_MESSAGES';
                break;
            
            // Modified list endpoint handler
            case 'list':
                const now = Date.now();
                // Use displayOrder to maintain chat activity order
                const activeUsers = displayOrder
                    // Filter to only include users who are still active
                    .filter(username => {
                        const userData = userActivity.get(username);
                        return userData && (now - userData.lastActive < OFFLINE_THRESHOLD);
                    })
                    // Map to nicknames
                    .map(username => userActivity.get(username).nickname);

                let usersResponse = activeUsers.length.toString();
                for (const nickname of activeUsers) {
                    const potentialResponse = usersResponse + SEPARATOR + nickname;
                    if (potentialResponse.length <= MAX_RESPONSE_BYTES) {
                        usersResponse = potentialResponse;
                    } else {
                        break;
                    }
                }
                
                actionResult = usersResponse || 'NO_USERS';
                break;

            case 'motd':
                // Get the latest active MOTD
                const [rows] = await db.execute(
                    'SELECT message, created_by, created_at FROM motd WHERE is_active = 1 ORDER BY created_at DESC LIMIT 1'
                );
    
                if (rows.length === 0) {
                    actionResult = 'NO_MOTD';
                    break;
                }
    
                actionResult = rows[0].message;
                break;

            case 'op':
                if (!req.user.is_operator) {
                    actionResult = 'NOT_OPERATOR';
                    break;
                }

                if (!req.query.c) {
                    actionResult = 'INVALID_COMMAND';
                    break;
                }

                // Decode the command string
                const decodedCommand = decodeParam(req.query.c);
                const [command, ...params] = decodedCommand.split(SEPARATOR);

                try {
                    switch (command) {
                        case 'kick':
                            const [kickNick] = params;
                            if (!kickNick) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }
                            messageQueue = messageQueue.filter(msg => msg.nick !== kickNick);
                            addMessageToQueue(null, `${kickNick}\\x15 was kicked`, true);
                            break;

                        case 'ban':
                            const [banNick, reason, duration] = params;
                            if (!banNick || !reason || !duration) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }

                            const banUserData = Array.from(userActivity.entries())
                                .find(([_, data]) => data.nickname === banNick);
                            
                            if (!banUserData) {
                                actionResult = 'USER_NOT_FOUND';
                                break;
                            }

                            await db.execute(
                                'INSERT INTO bans (username, reason, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
                                [banUserData[0], reason, parseInt(duration)]
                            );
                            messageQueue = messageQueue.filter(msg => msg.nick !== banNick);
                            addMessageToQueue(null, `${banNick}\\x15 was banned: ${reason}`, true);
                            break;

                        case 'unban':
                            const [unbanNick] = params;
                            if (!unbanNick) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }

                            const [unbanData] = await db.execute(
                                'SELECT username FROM nicknames WHERE nickname = ? ORDER BY last_used DESC LIMIT 1',
                                [unbanNick]
                            );

                            if (unbanData.length > 0) {
                                await db.execute(
                                    'DELETE FROM bans WHERE username = ?',
                                    [unbanData[0].username]
                                );
                                addMessageToQueue(null, `${unbanNick}\\x15 was unbanned`, true);
                            } else {
                                actionResult = 'USER_NOT_FOUND';
                            }
                            break;

                        case 'mute':
                            const [muteNick, muteDuration] = params;
                            if (!muteNick || !muteDuration) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }

                            const muteUserData = Array.from(userActivity.entries())
                                .find(([_, data]) => data.nickname === muteNick);
                            
                            if (!muteUserData) {
                                actionResult = 'USER_NOT_FOUND';
                                break;
                            }

                            await db.execute(
                                'INSERT INTO mutes (username, expires_at) VALUES (?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
                                [muteUserData[0], parseInt(muteDuration)]
                            );
                            addMessageToQueue(null, `${muteNick}\\x15 was muted`, true);
                            break;

                        case 'unmute':
                            const [unmuteNick] = params;
                            if (!unmuteNick) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }

                            const [unmuteData] = await db.execute(
                                'SELECT username FROM nicknames WHERE nickname = ? ORDER BY last_used DESC LIMIT 1',
                                [unmuteNick]
                            );

                            if (unmuteData.length > 0) {
                                await db.execute(
                                    'DELETE FROM mutes WHERE username = ?',
                                    [unmuteData[0].username]
                                );
                                addMessageToQueue(null, `${unmuteNick}\\x15 was unmuted`, true);
                            } else {
                                actionResult = 'USER_NOT_FOUND';
                            }
                            break;

                        case 'forcenick':
                            const [oldNick, newNick] = params;
                            if (!oldNick || !newNick) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }
                        
                            const forcenickUserData = Array.from(userActivity.entries())
                                .find(([_, data]) => data.nickname === oldNick);
                            
                            if (!forcenickUserData) {
                                actionResult = 'USER_NOT_FOUND';
                                break;
                            }
                        
                            try {
                                // Run deactivation and registration in parallel
                                const [deactivateResult, registerResult] = await Promise.all([
                                    db.execute(
                                        'UPDATE nicknames SET is_active = 0 WHERE nickname = ?',
                                        [oldNick]
                                    ),
                                    registerNickname(forcenickUserData[0], newNick, db)
                                ]);
                        
                                if (!registerResult) {
                                    actionResult = 'NICKNAME_TAKEN';
                                    break;
                                }
                        
                                // Update history and message queue
                                await Promise.all([
                                    db.execute(
                                        'INSERT INTO nickname_history (username, old_nickname, new_nickname, changed_by, reason) VALUES (?, ?, ?, ?, ?)',
                                        [forcenickUserData[0], oldNick, newNick, req.user.username, 'Forced by operator']
                                    ),
                                    Promise.resolve().then(() => {
                                        messageQueue.forEach(msg => {
                                            if (msg.nick === oldNick) msg.nick = newNick;
                                        });
                        
                                        if (userActivity.has(forcenickUserData[0])) {
                                            const userData = userActivity.get(forcenickUserData[0]);
                                            userData.nickname = newNick;
                                            userActivity.set(forcenickUserData[0], userData);
                                        }
                                    })
                                ]);
                        
                                addMessageToQueue(null, `${oldNick}\\x15 is now known as ${newNick}`, true);
                            } catch (error) {
                                console.error('Error in forcenick:', error);
                                actionResult = 'ERROR: ' + error.message;
                                break;
                            }
                            break;

                        case 'motd':
                            // If no params, clear the MOTD
                            if (params.length === 0) {
                                await db.execute(
                                    'UPDATE motd SET is_active = 0 WHERE is_active = 1'
                                );
                                addMessageToQueue(null, `Message of the Day cleared by ${req.user.username}`, true);
                            } else {
                                // Set new MOTD
                                // Deactivate current MOTD
                                await db.execute(
                                    'UPDATE motd SET is_active = 0 WHERE is_active = 1'
                                );
                
                                // Set new MOTD
                                await db.execute(
                                    'INSERT INTO motd (message, created_by) VALUES (?, ?)',
                                    [params[0], req.user.username]
                                );
                                addMessageToQueue(null, `Message of the Day updated by ${req.user.username}`, true);
                            }
                            break;

                        case 'announce':
                            const [announcement] = params;
                            if (!announcement) {
                                actionResult = 'INVALID_PARAMS';
                                break;
                            }
                            addMessageToQueue(null, `\\x03${announcement}`, true);
                            break;

                        case 'clear':
                            messageQueue = [];
                            addMessageToQueue(null, `\\x15Chat cleared by ${req.user.username}`, true);
                            break;

                        default:
                            actionResult = 'INVALID_COMMAND';
                    }
                } catch (error) {
                    console.error('Error in operator command:', error);
                    actionResult = 'ERROR: ' + error.message;
                }
                break;

            default:
                actionResult = 'INVALID_ACTION';
        }

        res.send(actionResult);
    } catch (error) {
        console.error('API error:', error);
        res.send('ERROR');
    } finally {
        await db.end();
    }
});

// Modify the admin endpoint to properly decode authentication params
app.get('/admin', authenticate, async (req, res) => {
    if (!req.user.is_operator) return res.send('NOT_OPERATOR');
   
    // HTML escape the decoded username and password for safe insertion into JavaScript
    const escapedUsername = JSON.stringify(decodeParam(req.user.username));
    const escapedPassword = JSON.stringify(decodeParam(req.query.p));
   
   res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Chat Admin</title>
            <style>
                body { font-family: sans-serif; margin: 20px; }
                #chatBox { height: 400px; overflow-y: scroll; border: 1px solid #ccc; margin-bottom: 10px; padding: 10px; }
                #userList { float: right; width: 200px; border: 1px solid #ccc; padding: 10px; }
                .controls { margin-bottom: 10px; }
                .user-controls { margin-top: 5px; }
                .error { color: red; }
                .server { color: #666; }
            </style>
            <script>
                const username = ${escapedUsername};
                const password = ${escapedPassword};
                let lastError = '';
                let messageHistory = [];
                const MAX_MESSAGES = 12;
                let currentNickname = 'admin'; // Start with admin as nickname
                const COLON_REPLACEMENT = '꞉'; // U+A789 MODIFIER LETTER COLON
                const REAL_SEPARATOR = ':';


                // Update the admin endpoint's escapeHtml function to handle the special colon
                function escapeHtml(text) {
                    const div = document.createElement('div');
                    // Replace the real separator with our substitute before setting content
                    text = text.replace(new RegExp(REAL_SEPARATOR, 'g'), COLON_REPLACEMENT);
                    div.textContent = text;
                    return div.innerHTML;
                }

                // Initialize session
                async function initializeSession() {
                    try {
                        // Make initial GET request to establish session
                        const response = await fetch(\`/api/?a=get&u=\${encodeURIComponent(username)}&p=\${encodeURIComponent(password)}&n=\${encodeURIComponent(currentNickname)}\`);
                        const text = await response.text();
                        
                        // Start the regular update intervals
                        setInterval(fetchMessages, 2000);
                        setInterval(fetchUsers, 5000);
                    } catch (error) {
                        console.error('Error initializing session:', error);
                        alert('Error connecting to chat. Please refresh the page.');
                    }
                }
                
                async function fetchMessages() {
                    try {
                        const response = await fetch(\`/api/?a=get&u=\${encodeURIComponent(username)}&p=\${encodeURIComponent(password)}&n=\${encodeURIComponent(currentNickname)}\`);
                        const text = await response.text();
                        if (text !== 'NO_MESSAGES' && text !== lastError) {
                            const messages = [];
                            const parts = text.split('${SEPARATOR}');
                            const timestamp = Date.now();
                            
                            // Parse current messages into pairs
                            for (let i = 0; i < parts.length; i += 2) {
                                if (i + 1 < parts.length) {
                                    messages.push({
                                        nick: parts[i],
                                        message: parts[i + 1]
                                    });
                                }
                            }

                            // Add new messages to history
                            for (const msg of messages) {
                                const lastMsg = messageHistory[messageHistory.length - 1];
                                if (!lastMsg || 
                                    lastMsg.nick !== msg.nick || 
                                    lastMsg.message !== msg.message || 
                                    (msg.nick === 'SRV' && msg.timestamp - lastMsg.timestamp >= 3000)) {
                                    messageHistory.push(msg);
                                }
                            }

                            // Keep only the latest MAX_MESSAGES
                            if (messageHistory.length > MAX_MESSAGES) {
                                messageHistory = messageHistory.slice(-MAX_MESSAGES);
                            }

                            // Update chat display with escaped content
                            const chatBox = document.getElementById('chatBox');
                            chatBox.innerHTML = messageHistory.map(msg => {
                                const isServer = msg.nick === 'SRV';
                                return \`<strong class="\${isServer ? 'server' : ''}">\${escapeHtml(msg.nick)}:</strong> \${escapeHtml(msg.message)}<br>\`;
                            }).join('');
                            chatBox.scrollTop = chatBox.scrollHeight;
                            lastError = '';
                        }
                    } catch (error) {
                        lastError = error.message;
                        console.error('Error fetching messages:', error);
                    }
                }

                async function fetchUsers() {
                    try {
                        const response = await fetch(\`/api/?a=list&u=\${encodeURIComponent(username)}&p=\${encodeURIComponent(password)}\`);
                        const text = await response.text();
                        const userListDiv = document.getElementById('userList');
                        
                        // Always set the header
                        let content = '<h3>Online Users:</h3>';
                        
                        // Add user list only if there are users
                        if (text !== 'NO_USERS') {
                            const [count, ...users] = text.split('${SEPARATOR}');
                            content += \`<div>Total Users: \${count}</div>\`;
                            content += users.map(user => \`
                                <div class="user-item">
                                    <div>\${escapeHtml(user)}</div>
                                </div>
                            \`).join('');
                        }
                        userListDiv.innerHTML = content;
                    } catch (error) {
                        console.error('Error fetching users:', error);
                    }
                }

                async function sendMessage() {
                    const input = document.getElementById('messageInput');
                    const message = input.value.trim();
                    if (!message) return;
                    
                    try {
                        if (message.startsWith('/')) {
                            // Handle commands
                            const [cmd, ...args] = message.slice(1).split(' ');
                            let params = '';
                            
                            switch (cmd) {
                                case 'announce':
                                    params = \`announce${SEPARATOR}\${args.join(' ')}\`;
                                    break;
                                case 'clear':
                                    params = 'clear';
                                    break;
                                case 'kick':
                                    if (!args[0]) throw new Error('Usage: /kick <nickname>');
                                    params = \`kick${SEPARATOR}\${args[0]}\`;
                                    break;
                                case 'ban':
                                    if (args.length < 3) throw new Error('Usage: /ban <nickname> <duration> <reason>');
                                    const [banNick, banDuration, ...banReason] = args;
                                    params = \`ban${SEPARATOR}\${banNick}${SEPARATOR}\${banReason.join(' ')}${SEPARATOR}\${banDuration}\`;
                                    break;
                                case 'unban':
                                    if (!args[0]) throw new Error('Usage: /unban <nickname>');
                                    params = \`unban${SEPARATOR}\${args[0]}\`;
                                    break;
                                case 'mute':
                                    if (args.length < 2) throw new Error('Usage: /mute <nickname> <duration>');
                                    params = \`mute${SEPARATOR}\${args[0]}${SEPARATOR}\${args[1]}\`;
                                    break;
                                case 'unmute':
                                    if (!args[0]) throw new Error('Usage: /unmute <nickname>');
                                    params = \`unmute${SEPARATOR}\${args[0]}\`;
                                    break;
                                case 'forcenick':
                                    if (args.length < 2) throw new Error('Usage: /forcenick <old_nick> <new_nick>');
                                    params = \`forcenick${SEPARATOR}\${args[0]}${SEPARATOR}\${args[1]}\`;
                                    // Update our own nickname if we're changing it
                                    if (args[0] === currentNickname) {
                                        currentNickname = args[1];
                                    }
                                    break;
                                case 'motd':
                                    if (args.length === 0) {
                                        params = 'motd';
                                    } else {
                                        params = \`motd${SEPARATOR}\${args.join(' ')}\`;
                                    }
                                    break;
                                case 'help':
                                    alert(\`Available commands:
/announce <message> - Send a server announcement
/motd <message> - Set or clear Message of the Day (no message = clear)
/clear - Clear all messages from chat
/kick <nickname> - Kick a user
/ban <nickname> <duration> <reason> - Ban a user
/unban <nickname> - Remove a user's ban
/mute <nickname> <duration> - Mute a user
/unmute <nickname> - Remove a user's mute
/forcenick <old_nick> <new_nick> - Force change a user's nickname\`);
                                    input.value = '';
                                    return;
                                default:
                                    throw new Error('Unknown command. Type /help for available commands.');
                            }
                            
                            const response = await fetch(\`/api/?a=op&u=\${encodeURIComponent(username)}&p=\${encodeURIComponent(password)}&c=\${encodeURIComponent(params)}\`);
                            const result = await response.text();
                            if (result !== 'OK') {
                                throw new Error(result);
                            }
                        } else {
                            // Regular chat message
                            const response = await fetch(\`/api/?a=post&u=\${encodeURIComponent(username)}&p=\${encodeURIComponent(password)}&n=\${encodeURIComponent(currentNickname)}&m=\${encodeURIComponent(message)}\`);
                            const result = await response.text();
                            if (result !== 'OK') {
                                throw new Error(result);
                            }
                        }
                        input.value = '';
                    } catch (error) {
                        console.error('Error sending message:', error);
                        alert(\`Error: \${escapeHtml(error.message)}\`);
                    }
                }

                // Handle Enter key in message input
                document.addEventListener('DOMContentLoaded', () => {
                    const input = document.getElementById('messageInput');
                    input.addEventListener('keypress', (e) => {
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            sendMessage();
                        }
                    });
                });

                // Initialize the session when the page loads
                initializeSession();
            </script>
        </head>
        <body>
            <div id="userList"></div>
            <div id="chatBox"></div>
            <div class="controls">
                <input type="text" id="messageInput" placeholder="Enter message or command (/help for commands)..." maxlength="${MESSAGE_MAX_LENGTH}">
                <button onclick="sendMessage()">Send</button>
            </div>
        </body>
        </html>
   `);
});

// Modify your startServer function
async function startServer() {
    await initializeDatabase();
    
    // Start Discord client first
    try {
        await discordClient.login('token-here');
        console.log('Discord client connected successfully');
    } catch (error) {
        console.error('Failed to connect Discord client:', error);
    }

    app.listen(port, () => {
        console.log(`Chat server running on port ${port}`);
        console.log(`Database mode: ${debugDb ? 'SQLite' : 'MySQL'}`);
    });
}

// Add graceful shutdown
process.on('SIGINT', async () => {
    console.log('Shutting down...');
    await discordClient.destroy();
    process.exit(0);
});

// Add cleanup interval (runs every hour)
setInterval(cleanupDatabase, 3600000);
startServer().catch(console.error);
