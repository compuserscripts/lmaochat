--[[
    lmaochat
    by kmohgel34 on discord
    https://github.com/compuserscripts
]]

-- Load VGUI parser
local vgui = require('vgui')

local CLIENT_VERSION = "1.0.0"
local versionStatus = nil

-- Configuration
local API_URL = "https://chat.lmao.mx/api"
local CONFIG_FILE = "chat.cfg"
local NICKNAME_MAX_LENGTH = 16 
local MESSAGE_MAX_LENGTH = 127
local firstTimeUser = true
local timestamps = false -- Set to false to disable timestamps
local showClassChanges = false -- Toggle for class change notifications

-- Key constants
local DEFAULT_CHAT_KEY = KEY_Y
local DEFAULT_TEAM_CHAT_KEY = KEY_U
local DEFAULT_PARTY_CHAT_KEY = KEY_I
local DEFAULT_ONLINE_CHAT_KEY = KEY_O
local BACKSPACE_KEY = KEY_BACKSPACE
local RETURN_KEY = KEY_ENTER
local ESCAPE_KEY = KEY_ESCAPE
local TAB_KEY = KEY_TAB
local UP_KEY = KEY_UP
local DOWN_KEY = KEY_DOWN

-- Custom Chat Configuration
local ChatConfig = {
    enabled = true,
    config = nil,
    inputActive = false,
    inputBuffer = "",
    teamChat = false,
    partyChat = false,
    onlineChat = false,  -- Make sure this line exists
    _lastKey = nil
}

-- Custom Chat UI State
local ChatUI = {
    chatHistory = {},
    maxChatHistory = 100,
    font = nil,
    inputHistory = {},
    inputHistoryIndex = 0,
    clipboard = "",
    cursorPosition = 0,
    selectionStart = nil,
    selectionEnd = nil,
    inputHistoryPos = 0,
    cursorBlink = 0,
    maxVisibleMessages = 0,  -- Will be calculated based on chat height
    scrollOffset = 0,        -- Current scroll position
    lastScrollTime = 0,      -- For scroll throttling
    SCROLL_DELAY = 0.04,     -- Scroll throttle delay
    ARROW_KEY_DELAY = 0.5,  -- Initial delay before key repeat starts
    ARROW_REPEAT_RATE = 0.03,  -- How fast the key repeats after initial delay
    LastArrowPressTime = 0,  -- Track when arrow keys were first pressed
    CTRL_ARROW_DELAY = 0.1,
}

-- Add initialization state tracking
local InitState = {
    initialized = false,
    initAttempts = 0,
    maxAttempts = 999,
    checkInterval = 1, -- seconds between init attempts
    lastCheckTime = 0
}

-- VGUI Integration
local ChatVGUI = {
    config = nil,
    baseChatPath = nil,
    defaultConfig = {
        xpos = "10",
        ypos = "10", 
        wide = tostring(200 * 2.25), -- 2.25 is the SCALE_FACTOR, i guess this is needed for matching with tf2 dimensions? idk
        tall = tostring(100 * 2.25),
        visible = "1",
        enabled = "1",
        BgColor = "0 0 0 127"
    }
}

-- Voice menu data
local VOICE_MENU = {
    [0] = {
        [0] = "MEDIC!",
        [1] = "Thanks!",
        [2] = "Go! Go! Go!",
        [3] = "Move Up!",
        [4] = "Go Left",
        [5] = "Go Right",
        [6] = "Yes",
        [7] = "No"
    },
    [1] = {
        [0] = "Incoming",
        [1] = "Spy!",
        [2] = "Sentry Ahead!",
        [3] = "Teleporter Here",
        [4] = "Dispenser Here",
        [5] = "Sentry Here",
        [6] = "Activate Charge!",
        [7] = "MEDIC: ÜberCharge Ready"
    },
    [2] = {
        [0] = "Help!",
        [1] = "Cheers",
        [2] = "Jeers",
        [3] = "Positive",
        [4] = "Negative",
        [5] = "Nice Shot",
        [6] = "Good Job",
        [7] = "Battle Cry"
    }
}

-- Class name lookup table
local classNames = {
    [1] = "Scout",
    [2] = "Sniper", 
    [3] = "Soldier",
    [4] = "Demoman",
    [5] = "Medic",
    [6] = "Heavy",
    [7] = "Pyro",
    [8] = "Spy",
    [9] = "Engineer"
}

-- Emoji handling system
local EmojiSystem = {
    -- Store initialized textures
    textures = {},
    
    -- Map shortcodes to their base64 data
    shortcodeMap = {
        [":)"] = {
            base64 = "MDAxNjAwMTY=R3BMAEdwTABHcEwAR3BMAEdwTADk5/H/sr/K/4CWov98kJv/qLG7/9/g6f9HcEwAR3BMAEdwTABHcEwAR3BMAEdwTABHcEwAR3BMAOXo8/9plqn/VZKt/2amz/90tOf/ca/q/1yU0/86a6H/Q1x8/9/f6f9HcEwAR3BMAEdwTABHcEwAR3BMANLc6P9anLf/e8Po/5Hf//+Y6v//mez//5Xk//+P2///hcv//2Gb8P8lTY3/wsXT/0dwTABHcEwAR3BMAOTn8v9gpsP/kd///6X+//+n////sv///7b///+v////rf///5Db9f+S3f//a6X//yJJlf/b3en/R3BMAEdwTABspr7/kub//16PoP+DwL3/2f///7Hz8v9VdXf/0f///zhQUf8AAAD/UHaI/5Hc//9WifT/Mk6Q/0dwTADf5fH/a7TU/6H4//+N0ND/HiUn/6nR0f83SEz/c5OV/93///8LCxH/AAAA/y9ES/+g8///cqz//yxWvP/W2un/tMva/3rG6P+d8///wv///47Awv80RUf/dJKW/9v////T////qOHj/2iTlf+j+Pr/mev//3q7//9CcuT/mabL/4Ssvf+EzvD/nvP//7f////T////3P///9v////M////xv///8r////I////tf///5ns//99vf//U4H2/152sv+Fqbv/fsbn/6H2//+V397/ntna/8v////E////xv///8P///+9////vP///4nT1P+CxeT/fsH//09/9v9kfLb/s8XS/2muzP+c7v//e77F/x4nKP/S////wv///73///+6////u////73///8YIiP/cq3U/3i3//8+auP/n63R/+Hl7/9PjaL/hMjx/6v///88W2H/R2Zm/8X////H////xP///7r///87WFj/PVxw/5Db//9ilf//LFXC/9ve7v9HcEwAWX+P/2Kfu/+I0P//o/r//0Nlb/8jNTX/T3Rx/01ycP8hMDL/RGZ8/5Hd//9tpv//Qm7h/z9epP9HcEwAR3BMAOfp8/80YXD/ZJy+/4DD//+Z6v//hcr3/2GUt/9hkrj/gMP5/4vU//9rov//SnTi/yJGnP/l5/P/R3BMAEdwTABHcEwA19nj/yhNWf9Je5v/aaHd/3a0//99wf//e7z//22m//9aiez/N168/x4+hv/U1+b/R3BMAEdwTABHcEwAR3BMAEdwTADr6/X/X252/yFAU/8zV33/RGuh/0Fmpf8qTY7/GTZx/1dqjv/r6/X/R3BMAEdwTABHcEwAR3BMAEdwTABHcEwAR3BMAEdwTADs7PX/uLrC/4WLlP+Di5b/ur7J/+vr9f9HcEwAR3BMAEdwTABHcEwAR3BMAA=="
        },
        [":("] = {
            base64 = "MDAxNjAwMTY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/jK3//4yt//+Mrf//jK3//4yt//+Mrf//AAAA/wAAAP8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//AAAA/wAAAAAAAAAAAAAAAAAAAP+Mrf//jK3//wAAAP8AAAD/jK3//4yt//+Mrf//jK3//wAAAP8AAAD/jK3//4yt//8AAAD/AAAAAAAAAAAAAAD/jK3//wAAAP+Mrf///////4yt//+Mrf//jK3//4yt////////jK3//wAAAP+Mrf//AAAA/wAAAAAAAAD/jK3//wAAAP+Mrf//////////////////jK3//4yt//////////////////+Mrf//AAAA/4yt//8AAAD/AAAA/4yt//8AAAD//////4yt//+Mrf///////4yt//+Mrf///////4yt//+Mrf///////wAAAP+Mrf//AAAA/wAAAP+Mrf//jK3//4yt//8AAAD/AAAA/wAAAP+Mrf//jK3//wAAAP8AAAD/jK3//4yt//+Mrf//jK3//wAAAP8AAAD/jK3//4yt//+Mrf//AAAA/wAAAP8AAAD/jK3//4yt//8AAAD/AAAA/4yt//+Mrf//jK3//4yt//8AAAD/AAAA/4yt//+Mrf//jK3//4yt//8AAAD/jK3//4yt//+Mrf//jK3//wAAAP+Mrf//jK3//4yt//+Mrf//AAAA/wAAAP+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//jK3//wAAAP8AAAAAAAAA/4yt//+Mrf//AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP+Mrf//jK3//wAAAP8AAAAAAAAAAAAAAP+Mrf//AAAA/4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//AAAA/4yt//8AAAD/AAAAAAAAAAAAAAAAAAAA/4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//+Mrf//jK3//4yt//8AAAD/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/4yt//+Mrf//jK3//4yt//+Mrf//jK3//wAAAP8AAAD/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAAAAAAAAAAAAAAAAAAAAAAAAA=="
        },
        [">:)"] = {
            base64 = "MDAxNjAwMTY=qo3XyqqN17imhdMWAAAAAKaL0y2qjNeRqYzY1KqN2PSqjdj0qYzY1KmN15CkiNIsAAAAAKCKyheqjde4qYzXyamM2O2qjdj/qYzY6KqM18eqjtf9qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qYzW/amN2MapjNfpqo3Y/6mM2OyqjNe7qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+pjNi5qYvWVaqN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/p4zVU6aL0y2pjdf+qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qY3X/qiL0SuqjNeRqo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+qjdaOqY3X1aqN2P+liNP/k3bB/6CCzv+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6qN2P+ggs7/k3bB/6WI0/+qjdj/qo3Y06mM2POqjdj/oILO/3hbp/9lSZb/ZUqW/5d6xv+qjdj/qo3Y/5d6xv9mSZb/ZkmW/3hbp/+ggs7/qo3Y/6mN1/Kpjdfyqo3Y/6qN2P+qjdj/hmq2/1U5hv9bQIz/p4vW/6iL1f9cQIz/VTmG/4dqtv+qjdj/qo3Y/6qN2P+qjNfxqY3X1aqN2P+qjdj/qo3Y/4BksP9VOYb/eFun/6qN2P+qjdj/eFun/1U5hv+BZLH/qo3Y/6qN2P+qjdj/qo3Y06mN15Cqjdj/qo3Y/6qN2P+ihtH/eFyo/56Czf+qjdj/qo3Y/5+CzP94XKj/o4bR/6qN2P+qjdj/qo3Y/6mM1o2kiNIsqYzX/KqN2P+kh9L/h2u3/6iM1/+qjdj/qo3Y/6qN2P+qjdj/qIzX/4drt/+kh9L/qo3Y/6mM1/ymiNYqAAAAAKqM1pSqjdj/qo3Y/4Flsv9eQ5D/el2q/4hsuP+IbLj/el2q/15DkP+DZrL/qo3Y/6qN2P+qjNeRAAAAAAAAAACSbbYGqYzXvKqN2P+qjdj/lXnE/2xPnP9ZPYr/WT2K/2tQnP+XecX/qo3Y/6qN2P+qjNe7gICqBQAAAAAAAAAAAAAAAJJttgapjNiTqYzX/KqN2P+qjdj/qo3Y/6qN2P+qjdj/qo3Y/6mM1/yqjNeRgICqBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKiL0SuqjdaOqo3Y06mM2POpjNjzqo3Y06mM1o2miNYqAAAAAAAAAAAAAAAAAAAAAA=="
        },
    },

    -- Track if we've initialized
    initialized = false
}

-- Simplified version checking function
local function checkVersion()
    local response = http.Get(API_URL .. "/?a=version")
    if response then
        if response == CLIENT_VERSION then
            versionStatus = "\\x03You are up to date! (client version matches server)"
        else
            versionStatus = "\\x08Please update client! (client version mismatch with server)"
        end
    else
        versionStatus = "\\x02Could not check version (server unreachable)"
    end
end

-- Function to check if a character is a word boundary
local function isWordBoundary(char)
    -- Include punctuation and special characters as word boundaries
    return char == " " or char == "\t" or char == "\n" or char == nil or
           char:match("[%p%c]") -- punctuation or control characters
end

-- Modified UndoStack structure
local UndoStack = {
    undoStack = {},
    redoStack = {},
    maxSize = 100,
    lastSavedState = nil,
    currentWord = "",
    lastWord = "",  -- Initialize lastWord
    isTyping = false,
    typingTimeout = 0.5,
    lastTypeTime = 0
}

-- Function to create state snapshot
local function createStateSnapshot()
    return {
        buffer = ChatConfig.inputBuffer,
        cursorPos = ChatUI.cursorPosition,
        timestamp = globals.RealTime()
    }
end


-- Helper function to get next character based on shift state
local function getNextChar(chars, shiftPressed)
    if chars.normal:match("%a") then
        local useUpperCase = (capsLockEnabled and not shiftPressed) or 
                           (not capsLockEnabled and shiftPressed)
        return useUpperCase and chars.shift or chars.normal
    else
        return shiftPressed and chars.shift or chars.normal
    end
end

-- Update saveState to handle word boundaries better
local function saveState()
    local currentState = createStateSnapshot()
    
    -- Don't save if nothing has changed
    if UndoStack.lastSavedState and 
       UndoStack.lastSavedState.buffer == currentState.buffer and
       UndoStack.lastSavedState.cursorPos == currentState.cursorPos then
        return
    end
    
    -- Handle cut/paste operations immediately
    if ChatUI.selectionStart or ChatUI.selectionEnd then
        table.insert(UndoStack.undoStack, currentState)
        UndoStack.lastSavedState = currentState
        UndoStack.redoStack = {}
        return
    end
    
    -- For regular typing
    if UndoStack.isTyping then
        -- Only save if we have a real word
        if #UndoStack.currentWord > 0 then
            local lastChar = currentState.buffer:sub(-1)
            if isWordBoundary(lastChar) then
                table.insert(UndoStack.undoStack, currentState)
                UndoStack.lastSavedState = currentState
                UndoStack.redoStack = {}
            end
        end
    else
        -- Save state for new input sequences
        table.insert(UndoStack.undoStack, currentState)
        UndoStack.lastSavedState = currentState
        UndoStack.redoStack = {}
    end
    
    -- Maintain stack size
    while #UndoStack.undoStack > UndoStack.maxSize do
        table.remove(UndoStack.undoStack, 1)
    end
end

-- Function to find the start of the current word
local function findWordStart(text, pos)
    while pos > 0 and not isWordBoundary(text:sub(pos - 1, pos - 1)) do
        pos = pos - 1
    end
    return pos
end

-- Function to find the end of the current word
local function findWordEnd(text, pos)
    while pos <= #text and not isWordBoundary(text:sub(pos, pos)) do
        pos = pos + 1
    end
    return pos
end

-- Function to get the current word being typed
local function getCurrentWord()
    local text = ChatConfig.inputBuffer
    local pos = ChatUI.cursorPosition
    
    -- Find start of current word (going backwards)
    local wordStart = pos
    while wordStart > 0 and not isWordBoundary(text:sub(wordStart, wordStart)) do
        wordStart = wordStart - 1
    end
    
    -- Find end of word (going forwards)
    local wordEnd = pos
    while wordEnd <= #text and not isWordBoundary(text:sub(wordEnd, wordEnd)) do
        wordEnd = wordEnd + 1
    end
    
    -- Extract the word
    return text:sub(wordStart + 1, wordEnd - 1)
end

-- Function to check word completion
local function checkWordCompletion()
    if not UndoStack.isTyping then return end
    
    local currentTime = globals.RealTime()
    if currentTime - UndoStack.lastTypeTime > UndoStack.typingTimeout then
        local currentWord = getCurrentWord()
        
        -- Only save state if we've actually completed a word
        if #currentWord > 0 and currentWord ~= UndoStack.currentWord then
            UndoStack.isTyping = false
            saveState()
            UndoStack.currentWord = ""
        end
    end
end

-- Modified handleCharacterInput to only track word state
local function handleCharacterInput()
    local currentWord = getCurrentWord()
    local currentTime = globals.RealTime()
    
    if not UndoStack.isTyping then
        -- Starting a new word
        UndoStack.isTyping = true
        UndoStack.currentWord = currentWord
        UndoStack.lastWord = currentWord
        UndoStack.lastTypeTime = currentTime
        saveState()  -- Save state at start of word
        return
    end
    
    -- Check if we're at a word boundary
    local lastChar = ChatConfig.inputBuffer:sub(-1)
    if isWordBoundary(lastChar) then
        -- Complete current word and save state
        if #UndoStack.currentWord > 0 then  -- Only save if we actually have a word
            UndoStack.isTyping = false
            saveState()
            -- Start new word tracking
            UndoStack.isTyping = true
            UndoStack.currentWord = ""
            UndoStack.lastWord = ""
        end
        UndoStack.lastTypeTime = currentTime
    else
        -- Update current word state
        UndoStack.currentWord = currentWord
        UndoStack.lastWord = currentWord
        UndoStack.lastTypeTime = currentTime
    end
end


-- Function to perform undo
local function performUndo()
    if #UndoStack.undoStack > 1 then  -- Keep at least one state
        -- If we're currently typing, complete the current word first
        if UndoStack.isTyping then
            UndoStack.isTyping = false
            saveState()
        end
        
        -- Save current state to redo stack before modifying anything
        local currentState = createStateSnapshot()
        table.insert(UndoStack.redoStack, currentState)
        
        -- Remove current state and get previous state
        table.remove(UndoStack.undoStack)  -- Remove current state
        local prevState = UndoStack.undoStack[#UndoStack.undoStack]
        
        -- Apply the previous state
        ChatConfig.inputBuffer = prevState.buffer
        ChatUI.cursorPosition = prevState.cursorPos
        UndoStack.lastSavedState = prevState
        
        -- Reset word tracking
        UndoStack.isTyping = false
        UndoStack.currentWord = ""
        UndoStack.lastWord = ""
    end
end

-- Function to perform redo
local function performRedo()
    if #UndoStack.redoStack > 0 then
        -- Get and remove the last redo state
        local redoState = table.remove(UndoStack.redoStack)
        
        -- Save current state to undo stack
        local currentState = createStateSnapshot()
        table.insert(UndoStack.undoStack, currentState)
        
        -- Apply the redo state
        ChatConfig.inputBuffer = redoState.buffer
        ChatUI.cursorPosition = redoState.cursorPos
        UndoStack.lastSavedState = redoState
        
        -- Reset word tracking
        UndoStack.isTyping = false
        UndoStack.currentWord = ""
    end
end



-- Function to clear undo/redo stacks
local function clearUndoRedoStacks()
    UndoStack.undoStack = {createStateSnapshot()}  -- Keep current state
    UndoStack.redoStack = {}
    UndoStack.isTyping = false
    UndoStack.currentWord = ""
    UndoStack.lastSavedState = nil
end

-- ViewLockState implementation
local ViewLockState = {
    isLocked = false,
    pitch = 0,
    yaw = 0,
    roll = 0,
    renderPitch = 0, -- For visual lock
    renderYaw = 0,   -- For visual lock
    renderRoll = 0   -- For visual lock
}

-- Update initViewLock to store both network and render angles
local function initViewLock()
    local angles = engine.GetViewAngles()
    ViewLockState.pitch = angles.pitch
    ViewLockState.yaw = angles.yaw 
    ViewLockState.roll = angles.roll
    ViewLockState.renderPitch = angles.pitch
    ViewLockState.renderYaw = angles.yaw
    ViewLockState.renderRoll = angles.roll
    ViewLockState.isLocked = true
end

-- Also update releaseViewLock to ensure it's called when custom chat is disabled
local function releaseViewLock()
    ViewLockState.isLocked = false
    ViewLockState.pitch = 0
    ViewLockState.yaw = 0
    ViewLockState.roll = 0
    ViewLockState.renderPitch = 0
    ViewLockState.renderYaw = 0
    ViewLockState.renderRoll = 0
end

-- Update updateLockedView function
local function updateLockedView(cmd)
    if not ViewLockState.isLocked or not ChatConfig.enabled then return end
    
    -- Lock network angles
    cmd:SetViewAngles(ViewLockState.pitch, ViewLockState.yaw, ViewLockState.roll)
    engine.SetViewAngles(EulerAngles(ViewLockState.pitch, ViewLockState.yaw, ViewLockState.roll))
    
    -- Block all movement and input
    cmd.forwardmove = 0
    cmd.sidemove = 0
    cmd.upmove = 0
    cmd.buttons = 0
    cmd.mousedx = 0
    cmd.mousedy = 0
end

-- Base64 decoding function
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_decode(data)
    data = string.gsub(data, '[^' .. b .. '=]', '')
    local decoded = {}
    local padding = 0

    if string.sub(data, -2) == '==' then
        padding = 2
        data = string.sub(data, 1, -3)
    elseif string.sub(data, -1) == '=' then
        padding = 1
        data = string.sub(data, 1, -2)
    end

    for i = 1, #data, 4 do
        local n = (string.find(b, string.sub(data, i, i)) - 1) * 262144 +
                  (string.find(b, string.sub(data, i + 1, i + 1)) - 1) * 4096 +
                  (string.find(b, string.sub(data, i + 2, i + 2)) - 1) * 64 +
                  (string.find(b, string.sub(data, i + 3, i + 3)) - 1)
        table.insert(decoded, string.char(math.floor(n / 65536) % 256))
        table.insert(decoded, string.char(math.floor(n / 256) % 256))
        table.insert(decoded, string.char(n % 256))
    end

    if padding > 0 then
        decoded = {table.unpack(decoded, 1, #decoded - padding)}
    end

    return table.concat(decoded)
end

-- Function to find emoji in text
local function findEmoji(text, startPos)
    --print("[Emoji] Checking for emoji at position", startPos, "in text:", text:sub(startPos))
    for shortcode, _ in pairs(EmojiSystem.shortcodeMap) do
        local possibleMatch = text:sub(startPos, startPos + #shortcode - 1)
        --print("[Emoji] Checking if", possibleMatch, "matches", shortcode)
        if possibleMatch == shortcode then
            --print("[Emoji] Found match:", shortcode)
            return shortcode
        end
    end
    return nil
end

local function initializeEmojis()
    if EmojiSystem.initialized then return end
    
    --print("[Emoji] Starting initialization...")
    
    for shortcode, data in pairs(EmojiSystem.shortcodeMap) do
        -- Add validation for base64 data
        if not data.base64 or #data.base64 < 12 then
            --print("[Emoji] Invalid base64 data for shortcode:", shortcode)
            goto continue
        end
        
        -- Decode dimensions with error checking
        local dimension_encoded = string.sub(data.base64, 1, 12)
        local dimension_decoded = base64_decode(dimension_encoded)
        if #dimension_decoded < 8 then
            --print("[Emoji] Invalid dimension data for shortcode:", shortcode)
            goto continue
        end
        
        local width = tonumber(string.sub(dimension_decoded, 1, 4))
        local height = tonumber(string.sub(dimension_decoded, 5, 8))
        
        if not width or not height or width <= 0 or height <= 0 then
            --print("[Emoji] Invalid dimensions:", width, height)
            goto continue
        end
        
        local image_data = string.sub(data.base64, 13)
        local decoded_data = base64_decode(image_data)
        
        -- Create and verify texture immediately
        local texture = draw.CreateTextureRGBA(decoded_data, width, height)
        if not texture then
            --print("[Emoji] Failed to create texture for:", shortcode)
            goto continue
        end
        
        -- Store with immediate verification
        EmojiSystem.textures[shortcode] = {
            texture = texture,
            width = width,
            height = height
        }
        
        --print("[Emoji] Successfully created texture for:", shortcode, "dimensions:", width, "x", height)
        
        ::continue::
    end
    
    EmojiSystem.initialized = true
end

-- Word wrapping utilities
local function getLineWidth(text, font)
    draw.SetFont(font)
    return draw.GetTextSize(text)
end

-- Helper function to convert hex color to RGB
local function hexToRGB(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    end
    return 255, 255, 255 -- Default to white if invalid hex
end

local function drawColoredText(x, y, text, alpha)
    if not text or text == "" then return x end
    
    -- Initialize position
    local curX = x
    local segments = {}
    local currentColor = {255, 255, 255} -- Default color
    local currentText = ""
    local i = 1
    
    while i <= #text do
        local emoji = findEmoji(text, i)
        if emoji then
            -- If we have accumulated text, add it as a segment
            if currentText ~= "" then
                table.insert(segments, {
                    type = "text",
                    text = currentText,
                    color = {currentColor[1], currentColor[2], currentColor[3]}
                })
                currentText = ""
            end
            
            -- Add emoji segment
            table.insert(segments, {
                type = "emoji",
                emoji = emoji
            })
            
            i = i + #emoji
        else
            if text:sub(i, i) == "\x07" and i + 6 <= #text then
                -- If we have accumulated text, add it as a segment
                if currentText ~= "" then
                    table.insert(segments, {
                        type = "text",
                        text = currentText,
                        color = {currentColor[1], currentColor[2], currentColor[3]}
                    })
                    currentText = ""
                end
                
                -- Extract hex color
                local hexColor = text:sub(i + 1, i + 6)
                local r, g, b = hexToRGB(hexColor)
                currentColor = {r, g, b}
                i = i + 7
            else
                currentText = currentText .. text:sub(i, i)
                i = i + 1
            end
        end
    end
    
    -- Add any remaining text
    if currentText ~= "" then
        table.insert(segments, {
            type = "text",
            text = currentText,
            color = {currentColor[1], currentColor[2], currentColor[3]}
        })
    end
    
    -- Draw each segment
    for _, segment in ipairs(segments) do
        if segment.type == "text" then
            draw.Color(segment.color[1], segment.color[2], segment.color[3], alpha)
            draw.Text(curX, y, segment.text)
            curX = curX + draw.GetTextSize(segment.text)
        else -- emoji
            local emojiData = EmojiSystem.textures[segment.emoji]
            if emojiData then
                draw.Color(255, 255, 255, alpha)
                draw.TexturedRect(
                    emojiData.texture,
                    curX, 
                    y, 
                    curX + emojiData.width, 
                    y + emojiData.height
                )
                curX = curX + emojiData.width
            end
        end
    end
    
    return curX
end

local function validateEmojiSystem()
    --print("[Emoji] Validating system...")
    --print("[Emoji] Initialized:", EmojiSystem.initialized)
    --print("[Emoji] Number of shortcodes:", #EmojiSystem.shortcodeMap)
    --print("[Emoji] Number of textures:", #EmojiSystem.textures)
    
    for shortcode, data in pairs(EmojiSystem.shortcodeMap) do
        local textureData = EmojiSystem.textures[shortcode]
        if textureData then
            --print("[Emoji] Shortcode:", shortcode, "has texture:", textureData.texture ~= nil)
        else
            print("[Emoji] Missing texture for emoji shortcode:", shortcode)
        end
    end
end

local function getColoredTextWidth(text)
    if not text then return 0 end
    
    local width = 0
    local currentSegment = ""
    local i = 1
    
    while i <= #text do
        local emoji = findEmoji(text, i)
        if emoji then
            if #currentSegment > 0 then
                -- Measure accumulated text before emoji
                width = width + draw.GetTextSize(currentSegment)
                currentSegment = ""
            end
            
            local emojiData = EmojiSystem.textures[emoji]
            if emojiData then
                width = width + emojiData.width
            end
            i = i + #emoji
        else
            if text:sub(i, i) == "\x07" and i + 6 <= #text then
                -- Measure any accumulated text before color code
                if #currentSegment > 0 then
                    -- For Cyrillic text, measure character by character
                    if currentSegment:match("[\128-\255]") then
                        local tempWidth = 0
                        local j = 1
                        while j <= #currentSegment do
                            local byte = currentSegment:byte(j)
                            local charLen = 1
                            if byte >= 240 then charLen = 4
                            elseif byte >= 224 then charLen = 3
                            elseif byte >= 192 then charLen = 2 end
                            
                            local char = currentSegment:sub(j, j + charLen - 1)
                            tempWidth = tempWidth + draw.GetTextSize(char)
                            j = j + charLen
                        end
                        width = width + tempWidth
                    else
                        width = width + draw.GetTextSize(currentSegment)
                    end
                    currentSegment = ""
                end
                i = i + 7
            else
                currentSegment = currentSegment .. text:sub(i, i)
                i = i + 1
            end
        end
    end
    
    -- Handle any remaining text
    if #currentSegment > 0 then
        if currentSegment:match("[\128-\255]") then
            local tempWidth = 0
            local j = 1
            while j <= #currentSegment do
                local byte = currentSegment:byte(j)
                local charLen = 1
                if byte >= 240 then charLen = 4
                elseif byte >= 224 then charLen = 3
                elseif byte >= 192 then charLen = 2 end
                
                local char = currentSegment:sub(j, j + charLen - 1)
                tempWidth = tempWidth + draw.GetTextSize(char)
                j = j + charLen
            end
            width = width + tempWidth
        else
            width = width + draw.GetTextSize(currentSegment)
        end
    end
    
    return width
end

-- Helper function to get timestamp width
local function getTimestampWidth(font)
    if not timestamps then return 0 end
    draw.SetFont(font)
    return getColoredTextWidth("\x07666666[00:00] ")  -- Include space after timestamp
end

-- Helper function to get prefix width including team, RIP and chat mode indicators
local function getPrefixWidth(isTeamChat, isDead, team, font)
    draw.SetFont(font)
    local width = 0
    
    -- Add team indicator width if applicable
    if team then
        local teamPrefix = ""
        if team == 2 then  -- RED
            teamPrefix = "(\x07FF4444R\x07FFFFFF) "
        elseif team == 3 then  -- BLU
            teamPrefix = "(\x074444FFB\x07FFFFFF) "
        elseif team == 1 then  -- SPEC
            teamPrefix = "(\x07CCCCCCS\x07FFFFFF) "
        end
        width = width + getColoredTextWidth(teamPrefix)
    end
    
    -- Add RIP indicator width if applicable (using *RIP* not *DEAD*)
    if isDead and (team == 2 or team == 3) then
        width = width + getColoredTextWidth("\x07666666*RIP* \x07FFFFFF")
    end
    
    -- Add team chat indicator width if applicable (using (TM) not (TEAM))
    if isTeamChat then
        width = width + getColoredTextWidth("(TM) ")
    end
    
    return width
end

local function wrapText(text, maxWidth, font, isTeamChat, isDead, team)
    draw.SetFont(font)
    local lines = {}
    local currentWidth = 0
    local lastBreakPos = 1
    local colorStack = {"\x07FFFFFF"}
    
    -- Calculate total prefix width
    local prefixWidth = getPrefixWidth(isTeamChat, isDead, team, font)
    local firstLineMaxWidth = maxWidth - prefixWidth
    
    local function getCurrentColor()
        return colorStack[#colorStack] or "\x07FFFFFF"
    end
    
    local i = 1
    while i <= #text do
        -- Check for emoji first
        local emoji = findEmoji(text, i)
        if emoji then
            local emojiData = EmojiSystem.textures[emoji]
            if emojiData then
                local emojiWidth = emojiData.width
                
                -- Use appropriate max width based on line number
                local currentMaxWidth = #lines == 0 and firstLineMaxWidth or maxWidth
                
                if currentWidth + emojiWidth > currentMaxWidth then
                    -- Add current line before emoji
                    local lineText = text:sub(lastBreakPos, i-1)
                    table.insert(lines, lineText)
                    lastBreakPos = i
                    currentWidth = emojiWidth
                    i = i + #emoji
                else
                    currentWidth = currentWidth + emojiWidth
                    i = i + #emoji
                end
            else
                i = i + #emoji
            end
            goto continue
        end
        
        -- Handle color codes
        if text:sub(i, i) == "\x07" and i + 6 <= #text then
            local newColor = text:sub(i, i + 6)
            table.insert(colorStack, newColor)
            i = i + 7
            goto continue
        end
        
        -- Get complete UTF-8 character
        local byte = text:byte(i)
        local charLen = 1
        if byte >= 240 then charLen = 4
        elseif byte >= 224 then charLen = 3
        elseif byte >= 192 then charLen = 2 end
        
        local char = text:sub(i, i + charLen - 1)
        local charWidth = draw.GetTextSize(char)
        
        -- Use appropriate max width based on line number
        local currentMaxWidth = #lines == 0 and firstLineMaxWidth or maxWidth
        
        if currentWidth + charWidth > currentMaxWidth then
            -- Find last space or break opportunity
            local breakPos = text:sub(lastBreakPos, i-1):find("%s[%S]*$")
            
            if breakPos then
                breakPos = lastBreakPos + breakPos - 1
                local lineText = text:sub(lastBreakPos, breakPos)
                table.insert(lines, lineText)
                lastBreakPos = breakPos + 1
                currentWidth = 0
                i = lastBreakPos
            else
                local lineText = text:sub(lastBreakPos, i-1)
                table.insert(lines, lineText)
                lastBreakPos = i
                currentWidth = 0
            end
            
            -- Track colors at break point
            local activeColors = {}
            local tempText = text:sub(1, lastBreakPos)
            local pos = 1
            while pos <= #tempText do
                if tempText:sub(pos, pos) == "\x07" and pos + 6 <= #tempText then
                    table.insert(activeColors, tempText:sub(pos, pos + 6))
                    pos = pos + 7
                else
                    pos = pos + 1
                end
            end
            colorStack = #activeColors > 0 and activeColors or {"\x07FFFFFF"}
        else
            currentWidth = currentWidth + charWidth
        end
        
        i = i + charLen
        ::continue::
    end
    
    -- Add remaining text as last line
    if lastBreakPos <= #text then
        table.insert(lines, text:sub(lastBreakPos))
    end
    
    -- Process lines to maintain color codes
    for i = 1, #lines do
        local prefix = ""
        if i > 1 then
            -- Add active color codes for wrapped lines
            local activeColors = {}
            local tempText = text:sub(1, text:find(lines[i], 1, true))
            local pos = 1
            while pos <= #tempText do
                if tempText:sub(pos, pos) == "\x07" and pos + 6 <= #tempText then
                    table.insert(activeColors, tempText:sub(pos, pos + 6))
                    pos = pos + 7
                else
                    pos = pos + 1
                end
            end
            for _, color in ipairs(activeColors) do
                prefix = prefix .. color
            end
            lines[i] = prefix .. lines[i]
        end
    end
    
    return lines
end

-- Update the getModeDisplayWidth function to include onlineChat mode
local function getModeDisplayWidth(font, isTeamChat, isPartyChat, isOnlineChat)
    draw.SetFont(font)
    local modeText
    if isOnlineChat then
        modeText = "ONLINE"
    elseif isPartyChat then
        modeText = "PARTY"
    elseif isTeamChat then
        modeText = "TEAM"
    else
        modeText = "ALL"
    end
    return draw.GetTextSize(modeText)
end

local function getCountDisplayWidth(font, currentLength, maxLength, showThreshold)
    if currentLength <= (maxLength * showThreshold) then
        return 0
    end
    draw.SetFont(font)
    local countText = string.format("%d/%d", currentLength, maxLength)
    return draw.GetTextSize(countText)
end

local function getTextDisplayWidth(font, text)
    draw.SetFont(font)
    return draw.GetTextSize(text)
end

local function processInputText(text, availableWidth, baseX, fullTextWidth)
    if not text or text == "" then 
        return baseX, text, 0, 0
    end
    
    -- If text fits within available width, return as is with actual cursor position
    if fullTextWidth <= availableWidth then
        return baseX, text, fullTextWidth, ChatUI.cursorPosition
    end
    
    -- Calculate how much text we need to slide based on cursor position
    local beforeCursor = text:sub(1, ChatUI.cursorPosition)
    local beforeCursorWidth = draw.GetTextSize(beforeCursor)
    
    -- Calculate starting position based on cursor
    local startIndex = 1
    local currentWidth = 0
    
    -- If cursor is beyond visible area, calculate scroll position
    if beforeCursorWidth > availableWidth - 20 then  -- Leave some padding
        local offset = beforeCursorWidth - availableWidth + 40  -- More padding for sliding
        
        -- Find starting character position
        while startIndex <= #text and currentWidth < offset do
            currentWidth = currentWidth + draw.GetTextSize(text:sub(startIndex, startIndex))
            startIndex = startIndex + 1
        end
    end
    
    -- Find how many characters fit in the visible area
    local endIndex = startIndex
    currentWidth = 0
    
    while endIndex <= #text do
        local charWidth = draw.GetTextSize(text:sub(endIndex, endIndex))
        
        if currentWidth + charWidth > availableWidth - 20 then  -- Leave some padding
            break
        end
        
        currentWidth = currentWidth + charWidth
        endIndex = endIndex + 1
    end
    
    -- If cursor is at the very end, ensure it's visible
    if ChatUI.cursorPosition == #text then
        if endIndex <= ChatUI.cursorPosition then
            -- Adjust the window to show the end of the text
            local windowSize = endIndex - startIndex
            endIndex = ChatUI.cursorPosition + 1
            startIndex = math.max(1, endIndex - windowSize)
        end
    end
    
    -- Store the visible text boundaries for cursor navigation
    ChatUI.visibleTextStart = startIndex
    ChatUI.visibleTextEnd = endIndex - 1
    
    -- Calculate relative cursor position
    local relativePosition
    if ChatUI.cursorPosition < startIndex then
        relativePosition = 0
    elseif ChatUI.cursorPosition > endIndex - 1 then
        relativePosition = endIndex - startIndex
    else
        relativePosition = ChatUI.cursorPosition - startIndex + 1
    end
    
    -- Return visible portion with adjusted cursor position
    return baseX, text:sub(startIndex, endIndex - 1), currentWidth, relativePosition
end

-- Helper function to get next UTF-8 character
local function getNextUTF8Char(text, pos)
    local byte = text:byte(pos)
    local length = 1
    
    if byte >= 240 then length = 4
    elseif byte >= 224 then length = 3
    elseif byte >= 192 then length = 2 end
    
    return text:sub(pos, pos + length - 1)
end

-- Helper function to find last fully visible character
local function findLastVisibleChar(text, maxWidth)
    local currentWidth = 0
    local lastValidPos = 1
    local pos = 1
    
    while pos <= #text do
        local char = getNextUTF8Char(text, pos)
        local charWidth = draw.GetTextSize(char)
        
        if currentWidth + charWidth > maxWidth then
            break
        end
        
        currentWidth = currentWidth + charWidth
        lastValidPos = pos + #char - 1
        pos = pos + #char
    end
    
    return lastValidPos
end

-- Helper function to calculate max visible messages
local function calculateMaxVisibleMessages(height)
    local messageHeight = 15
    return math.floor((height - 40) / messageHeight)
end

-- Helper function to split color string into RGBA
local function parseColor(colorStr)
    -- Default fallback color if parsing fails
    if not colorStr then
        return {r = 0, g = 0, b = 0, a = 127}
    end
    
    local r, g, b, a = colorStr:match("(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
    -- Ensure we have valid numbers and convert to integers
    r = math.floor(tonumber(r) or 0)
    g = math.floor(tonumber(g) or 0)
    b = math.floor(tonumber(b) or 0)
    a = math.floor(tonumber(a) or 255)
    
    return {
        r = r,
        g = g,
        b = b,
        a = a
    }
end

-- File attribute constants
local FILE_ATTRIBUTES = {
    FILE_ATTRIBUTE_READONLY = 0x1,
    FILE_ATTRIBUTE_HIDDEN = 0x2,
    FILE_ATTRIBUTE_SYSTEM = 0x4,
    FILE_ATTRIBUTE_DIRECTORY = 0x10,
    FILE_ATTRIBUTE_ARCHIVE = 0x20,
    FILE_ATTRIBUTE_DEVICE = 0x40,
    FILE_ATTRIBUTE_NORMAL = 0x80,
    FILE_ATTRIBUTE_TEMPORARY = 0x100,
    FILE_ATTRIBUTE_SPARSE_FILE = 0x200,
    FILE_ATTRIBUTE_REPARSE_POINT = 0x400,
    FILE_ATTRIBUTE_COMPRESSED = 0x800,
    FILE_ATTRIBUTE_OFFLINE = 0x1000,
}

-- Function to find basechat.res recursively
function ChatVGUI.findBaseChatRes()
    local customPath = "tf/custom"
    
    local function searchDir(dir)
        local result = nil
        filesystem.EnumerateDirectory(dir .. "/*", function(filename, attributes)
            if result then return end -- Already found
            
            -- Check if it's a directory using direct & operation
            if (attributes & FILE_ATTRIBUTES.FILE_ATTRIBUTE_DIRECTORY) ~= 0 then
                if filename ~= "." and filename ~= ".." then
                    local subResult = searchDir(dir .. "/" .. filename)
                    if subResult then
                        result = subResult
                    end
                end
            elseif filename:lower() == "basechat.res" then
                result = dir .. "/" .. filename
            end
        end)
        return result
    end
    
    local path = searchDir(customPath)
    if not path then
        --print("[ChatVGUI] Could not find basechat.res!")
        return nil
    end
    
    --print("[ChatVGUI] Found basechat.res at:", path) -- Add debug output
    ChatVGUI.baseChatPath = path
    return path
end

-- Modified function to parse VGUI file and extract chat configuration with debug
-- Helper function to clamp alpha values
local function clampAlpha(alpha)
    return math.max(2, math.min(255, math.floor(alpha)))
end

-- Add debug flag at the top of the ChatVGUI table
ChatVGUI.hasDebuggedOnce = false

function ChatVGUI.parseConfig()
    if not ChatVGUI.baseChatPath then
        if not ChatVGUI.findBaseChatRes() then
            --print("[DEBUG] Could not find basechat.res")
            return ChatVGUI.defaultConfig
        end
    end

    -- Get directory containing basechat.res
    local rootPath = string.match(ChatVGUI.baseChatPath, "(.*/).*%.res$")
    local relativeFile = string.match(ChatVGUI.baseChatPath, ".*/(.*)$")
    
    -- Read and preprocess the files manually
    local function readFile(filepath)
        --print("[DEBUG] Attempting to read:", filepath)
        local f = io.open(rootPath .. "/" .. filepath, "r")
        if not f then
            --print("[DEBUG] Failed to open file:", filepath)
            return nil
        end
        local content = f:read("*all")
        f:close()
        return content
    end

    -- Clean up a line of text
    local function cleanLine(line)
        line = line:gsub("//.*$", "")
        line = line:match("^%s*(.-)%s*$") or ""
        line = line:gsub("\"(%s*[^\"]+%s*)\"", function(inside)
            return '"' .. inside:gsub("%s+", " "):match("^%s*(.-)%s*$") .. '"'
        end)
        return line
    end

    -- Process #base directives manually
    local function processBaseDirectives(content)
        local result = {}
        for line in content:gmatch("[^\r\n]+") do
            line = cleanLine(line)
            if #line > 0 then
                if line:match("^#base%s+\"(.+)\"") then
                    local baseFile = line:match("^#base%s+\"(.+)\"")
                    local baseContent = readFile(baseFile)
                    if baseContent then
                        local processed = processBaseDirectives(baseContent)
                        for _, l in ipairs(processed) do
                            table.insert(result, l)
                        end
                    end
                else
                    if line:match("^[A-Za-z][A-Za-z0-9_]*%s*{") then
                        line = line:gsub("^([A-Za-z][A-Za-z0-9_]*)(%s*{)", '"%1"%2')
                    elseif line:match("^[A-Za-z]") and not line:match('^"') then
                        line = '"' .. line
                    end
                    if line:match('^"[^"]+$') then
                        line = line .. '"'
                    end
                    table.insert(result, line)
                end
            end
        end
        return result
    end

    -- Read and process the main file
    local content = readFile(relativeFile)
    if not content then
        --print("[DEBUG] Failed to read main file")
        return ChatVGUI.defaultConfig
    end

    -- Process all base directives
    local processedLines = processBaseDirectives(content)
    --print("[DEBUG] Processed lines:", #processedLines)

    -- Cleanup and normalize the content
    local processed = table.concat(processedLines, "\n")
    processed = processed:gsub("{%s*([^}])", "{\n%1")
    processed = processed:gsub("([^{])%s*}", "%1\n}")
    processed = processed:gsub("\n%s*\n", "\n")
    
    --print("[DEBUG] Final processed content:")
    --print(processed)

    -- Parse the processed content directly
    local lexer = vgui.Lexer.new(processed)
    local tokens = lexer:getTokens()
    local parser = vgui.Parser.new(tokens)
    local success, obj = pcall(function() 
        return vgui.VguiSerializer.fromValue(parser:parseRoot())
    end)

    if not success then
        --print("[DEBUG] Parse error:", obj)
        return ChatVGUI.defaultConfig
    end

    --print("[DEBUG] Parse successful, checking properties")

    -- Process the parsed object
    if not obj or not obj.properties then
        --print("[DEBUG] No valid obj or properties")
        return ChatVGUI.defaultConfig
    end

    local baseChat = obj.properties["Resource/UI/BaseChat.res"]
    if not baseChat or not baseChat.properties then
        --print("[DEBUG] No valid BaseChat.res")
        return ChatVGUI.defaultConfig
    end

    local hudChat = baseChat.properties["HudChat"]
    if not hudChat or not hudChat.properties then
        --print("[DEBUG] No valid HudChat")
        return ChatVGUI.defaultConfig
    end

    --print("[DEBUG] Found HudChat properties:")
    for k, v in pairs(hudChat.properties) do
        --print("  -", k, "=", v.value)
    end

    -- Scale factors for dimensions
    local SCALE_FACTOR = 2.25
    local function scaleValue(value)
        if type(value) == "string" and tonumber(value) then
            return tostring(math.floor(tonumber(value) * SCALE_FACTOR))
        end
        return value
    end

    local chatConfig = {
        xpos = hudChat.properties["xpos"] and scaleValue(hudChat.properties["xpos"].value),
        ypos = hudChat.properties["ypos"] and scaleValue(hudChat.properties["ypos"].value),
        wide = hudChat.properties["wide"] and scaleValue(hudChat.properties["wide"].value),
        tall = hudChat.properties["tall"] and scaleValue(hudChat.properties["tall"].value),
        visible = hudChat.properties["visible"] and hudChat.properties["visible"].value,
        enabled = hudChat.properties["enabled"] and hudChat.properties["enabled"].value,
        paintbackground = hudChat.properties["paintbackground"] and hudChat.properties["paintbackground"].value,
        bgcolor_override = hudChat.properties["bgcolor_override"] and hudChat.properties["bgcolor_override"].value
    }

    -- Fall back to defaults for missing values
    chatConfig.xpos = chatConfig.xpos or ChatVGUI.defaultConfig.xpos
    chatConfig.ypos = chatConfig.ypos or ChatVGUI.defaultConfig.ypos
    chatConfig.wide = chatConfig.wide or ChatVGUI.defaultConfig.wide
    chatConfig.tall = chatConfig.tall or ChatVGUI.defaultConfig.tall
    chatConfig.visible = chatConfig.visible or ChatVGUI.defaultConfig.visible
    chatConfig.enabled = chatConfig.enabled or ChatVGUI.defaultConfig.enabled

    --print retrieved basechat.res values
    --print("[DEBUG] Final config values:")
    --for k, v in pairs(chatConfig) do
    --    print("  -", k, "=", v)
    --end

    ChatVGUI.config = chatConfig
    return chatConfig
end

-- Function to parse special TF2 HUD values
local function parseHudValue(str, parentSize, defaultVal)
    if not str then 
        --print("parseHudValue: nil string, using default:", defaultVal)
        return defaultVal 
    end
    
    -- Convert to string if number
    str = tostring(str)
    --print("parseHudValue: parsing", str, "with parent size", parentSize)
    
    -- Handle special TF2 HUD formats
    if str:sub(1,1) == "f" then
        -- "f0" means full parent size minus number
        local subtract = tonumber(str:sub(2)) or 0
        local result = parentSize - subtract
        --print("parseHudValue: f-format:", str, "->", result)
        return result
    elseif str:sub(1,2) == "rs" then
        -- "rs1-2" means relative to parent size, from the end, minus 2
        local parts = str:split("-")
        local scale = tonumber(parts[1]) or 1
        local subtract = tonumber(parts[2]) or 0
        local result = (parentSize * scale) - subtract
        --print("parseHudValue: rs-format:", str, "->", result)
        return result
    end
    
    -- Direct number value
    local result = tonumber(str) or defaultVal
    --print("parseHudValue: direct value:", str, "->", result)
    return result
end

-- Modified function to get dimensions with debug output
function ChatVGUI.getCurrentDimensions()
    if not ChatVGUI.config then
        ChatVGUI.config = ChatVGUI.parseConfig()
    end
    
    local screenW, screenH = draw.GetScreenSize()
    local config = ChatVGUI.config
    
    --print("Screen dimensions:", screenW, "x", screenH)
    
    -- Base position
    local x = parseHudValue(config.xpos, screenW, 2)
    local y = parseHudValue(config.ypos, screenH, 17)
    
    -- Size values from basechat.res
    local width = parseHudValue(config.wide, screenW, 260)
    local height = parseHudValue(config.tall, screenH, 120)
    
    --print("Calculated dimensions:")
    --print("  Position:", x, y)
    --print("  Size:", width, height)
    
    -- Parse bgcolor_override if available
    local bgColor
    if config.bgcolor_override then
        bgColor = parseColor(config.bgcolor_override)
        --print("Using bgcolor_override:", config.bgcolor_override)
    else
        bgColor = {r = 0, g = 0, b = 0, a = 200}
        --print("Using default bgcolor")
    end
    
    --print("Background color:", bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    
    -- Ensure we don't go off screen
    x = math.max(0, math.min(x, screenW - width))
    y = math.max(0, math.min(y, screenH - height))
    
    --print("Final position after bounds check:", x, y)
    
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        bgColor = bgColor,
        visible = config.visible == "1",
        enabled = config.enabled == "1"
    }
end

-- Color system
-- Format: Basic colors (01-0F), Bright variants (10-1F), Special (20)
local COLOR_MAP = {
    -- Basic Colors (01-0F)
    ["\x01"] = "FFFFFF", -- White
    ["\x02"] = "FF0000", -- Red
    ["\x03"] = "00FF00", -- Green
    ["\x04"] = "0000FF", -- Blue
    ["\x05"] = "FFFF00", -- Yellow
    ["\x06"] = "FF00FF", -- Magenta
    ["\x07"] = "00FFFF", -- Cyan
    ["\x08"] = "FF8000", -- Orange
    ["\x09"] = "8000FF", -- Purple
    ["\x0A"] = "0080FF", -- Light Blue
    ["\x0B"] = "FF0080", -- Pink
    ["\x0C"] = "00FF80", -- Mint
    ["\x0D"] = "80FF00", -- Lime
    ["\x0E"] = "804000", -- Brown
    ["\x0F"] = "408040", -- Forest Green

    -- Bright Variants (10-1F)
    ["\x10"] = "FF8080", -- Light Red
    ["\x11"] = "80FF80", -- Light Green
    ["\x12"] = "8080FF", -- Light Blue
    ["\x13"] = "FFFF80", -- Light Yellow
    ["\x14"] = "FF80FF", -- Light Magenta
    ["\x15"] = "80FFFF", -- Light Cyan
    ["\x16"] = "FFB380", -- Light Orange
    ["\x17"] = "B380FF", -- Light Purple
    ["\x18"] = "80B3FF", -- Very Light Blue
    ["\x19"] = "FF80B3", -- Light Pink
    ["\x1A"] = "80FFB3", -- Light Mint
    ["\x1B"] = "B3FF80", -- Light Lime
    ["\x1C"] = "B38040", -- Light Brown
    ["\x1D"] = "808080", -- Gray
    ["\x1E"] = "404040", -- Dark Gray
    ["\x1F"] = "000000", -- Black

    -- Special (20)
    ["\x20"] = "666666", -- Default Gray for system messages
}

-- Convert special color codes to lmaobox RGB format
local function convertColorCodes(text)
    -- Handle nil input
    if not text then return "" end
    
    -- First convert any escaped codes like \x04 to actual bytes
    text = text:gsub("\\x(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    
    -- Split text into segments at spaces, preserving the spaces
    local segments = {}
    for segment in text:gmatch("[^ ]+") do
        table.insert(segments, segment)
    end
    
    -- Process each segment for color codes
    local result = ""
    for i, segment in ipairs(segments) do
        local processed = ""
        local j = 1
        while j <= #segment do
            local byte = segment:sub(j,j)
            local byte_val = byte:byte()
            
            if byte_val >= 0x01 and byte_val <= 0x20 then
                if COLOR_MAP[byte] then
                    processed = processed .. "\x07" .. COLOR_MAP[byte]
                else
                    processed = processed .. "\x07FFFFFF"
                end
            else
                processed = processed .. byte
            end
            j = j + 1
        end
        
        -- Add processed segment with space if not the last segment
        result = result .. processed
        if i < #segments then
            result = result .. " "
        end
    end
    
    return result
end

-- Original formatMessageRaw function modified for Discord support
local function formatMessageRaw(nick, msg)
    -- Convert \x sequences to TF2 RGB format using our color map
    local converted_msg = msg:gsub("\\x(%x%x)", function(hex)
        local byte = string.char(tonumber(hex, 16))
        if COLOR_MAP[byte] then
            return "\x07" .. COLOR_MAP[byte]  -- Convert to TF2's \x07RRGGBB format
        end
        return byte
    end)
    local converted_nick = nick:gsub("\\x(%x%x)", function(hex)
        local byte = string.char(tonumber(hex, 16))
        if COLOR_MAP[byte] then
            return "\x07" .. COLOR_MAP[byte]  -- Convert to TF2's \x07RRGGBB format
        end
        return byte
    end)
    
    -- Handle different message types
    if nick == "DC" then
        -- Discord messages use pink color and [DC] prefix
        --return "\x07FF69B4[DC] " .. converted_msg
        --return "\x01[\x07FF69B4DC\x01] " .. converted_msg
        return "\x07FF69B4[DC] " .. converted_msg
    elseif nick == "" or nil then
        -- Discord messages use pink color and [DC] prefix
        --return "\x07FF69B4[DC] " .. converted_msg
        --return "\x01[\x07FF69B4DC\x01] " .. converted_msg
        return converted_msg
    elseif nick == "SRV" then
        -- Server messages use regular chat prefix
        return "\x01[\x07FF1122Chat\x01] \x01" .. converted_msg
    else
        -- Regular chat messages
        return "\x01[\x07FF1122Chat\x01] " .. converted_nick .. "\x01: " .. converted_msg
    end
end

-- Modified formatMessage function
local function formatMessage(nick, msg)
    -- Convert all color codes while preserving spaces
    msg = convertColorCodes(msg)
    
    -- Handle different message types with appropriate formatting
    if nick == "DC" then
        -- Discord messages use pink color and [DC] prefix
        return "\x07FFFFFF[\x07FF69B4DC\x07FFFFFF] \x07FF69B4" .. msg
    elseif nick == "SRV" then
        -- Server messages use regular chat prefix and gray color
        return "\x07FFFFFF[\x07FF1122Chat\x07FFFFFF] \x07666666" .. msg
    else
        -- Regular chat messages
        return "\x07FFFFFF[\x07FF1122Chat\x07FFFFFF] " .. nick .. "\x07FFFFFF: " .. msg
    end
end

-- Add this helper function at the top of your script, before ChatConfig
local function replaceColonPlaceholder(text)
    if not text then return text end
    return text:gsub("꞉", ":")  -- Replace U+A789 with regular colon
end

-- Update the addChatMessage function
local function addChatMessage(text, playerName, lineHeight, maxWidth, font, isOnlineChatMessage, team, isDead, isTeamChat)
    -- Replace colon placeholders before processing
    text = replaceColonPlaceholder(text)
    playerName = replaceColonPlaceholder(playerName)
    
    local coloredText = convertColorCodes(text)
    local coloredTextName = playerName and convertColorCodes(playerName) or nil
    
    draw.SetFont(font)
    
    -- Format the message properly
    local formattedText = coloredText
    
    -- Calculate standard padding
    local basePadding = 16
    local extraPadding = 8
    
    -- Calculate prefix and name widths
    local prefix
    if playerName == "DC" then
        prefix = "\x07FFFFFF[\x07FF69B4DC\x07FFFFFF] "
        formattedText = "\x07FF69B4" .. coloredText  -- Make the message pink for Discord
    else
        prefix = "\x07FFFFFF[\x07FF1122Chat\x07FFFFFF] "
    end
    
    local prefixWidth = isOnlineChatMessage and getColoredTextWidth(prefix) or 0
    local nameWidth = 0
    local timestampWidth = getTimestampWidth(font)  -- Get timestamp width
    
    if playerName and coloredTextName and playerName ~= "DC" then
        nameWidth = getColoredTextWidth(coloredTextName .. "\x07FFFFFF: ")
    end
    
    -- Total width reduction includes all components including timestamp
    local totalPadding = basePadding + extraPadding + prefixWidth + nameWidth + timestampWidth
    
    -- Get wrapped lines with full width awareness
    local wrappedLines = wrapText(formattedText, maxWidth - totalPadding, font, isTeamChat, isDead, team)
    local currentTime = globals.RealTime()
    
    -- Rest of the function remains the same...
    -- Add first line with proper formatting
    if #wrappedLines > 0 then
        table.insert(ChatUI.chatHistory, 1, {
            text = wrappedLines[1],
            playerName = coloredTextName,
            time = currentTime,
            isWrapped = false,
            isServer = playerName == "SRV",
            isDiscord = playerName == "DC",
            isOnlineChatMessage = isOnlineChatMessage,
            team = team,
            isDead = isDead,
            isTeamChat = isTeamChat
        })
    end
    
    -- Add continuation lines
    for i = 2, #wrappedLines do
        table.insert(ChatUI.chatHistory, 1, {
            text = wrappedLines[i],
            time = currentTime,
            isWrapped = true,
            isServer = playerName == "SRV",
            isDiscord = playerName == "DC",
            isOnlineChatMessage = isOnlineChatMessage,
            team = team,
            isDead = isDead,
            isTeamChat = isTeamChat
        })
    end
    
    -- Maintain maximum history
    while #ChatUI.chatHistory > ChatUI.maxChatHistory do
        table.remove(ChatUI.chatHistory)
    end
end

-- Updated chatMessage function that respects chat state
local function chatMessage(msg)
    local dims = ChatVGUI.getCurrentDimensions()
    local isOnlineChatMessage = true
    
    if type(msg) == "string" then
        if ChatConfig.enabled then
            addChatMessage(msg, "SRV", 15, dims.width, ChatUI.font, isOnlineChatMessage, nil, nil, false)
        else
            local formatted = formatMessageRaw("SRV", msg)
            client.ChatPrintf(formatted)
        end
    elseif type(msg) == "table" and msg.nick and msg.message then
        if ChatConfig.enabled then
            addChatMessage(msg.message, msg.nick, 15, dims.width, ChatUI.font, isOnlineChatMessage, nil, nil, false)
        else
            local formatted = formatMessageRaw(msg.nick, msg.message)
            client.ChatPrintf(formatted)
        end
    end
end

-- Modified timestamp formatting function
local function formatTimestamp(timestamp)
    -- If no timestamp provided, use current time
    if not timestamp then
        timestamp = os.time()
    -- If timestamp is from RealTime, convert it to epoch time
    elseif type(timestamp) == "number" and timestamp < 1000000000 then
        -- Add to current epoch time to convert relative time to absolute time
        timestamp = os.time() - globals.RealTime() + timestamp
    end
    
    -- Ensure we have an integer and format without seconds
    timestamp = math.floor(timestamp)
    return "\x07666666[" .. os.date("%H:%M", timestamp) .. "]"
end

function ChatVGUI.drawChat(ChatConfig, ChatUI)
    -- Handle mouse and view angle locking when chat is active
    if ChatConfig.inputActive then
        -- Store mouse state if not already stored
        if mousePrevEnabled == nil then
            mousePrevEnabled = input.IsMouseInputEnabled()
        end
        
        -- Disable mouse input while chat is open
        input.SetMouseInputEnabled(false)
        
        -- Lock view angles if we have them
        if lockedViewangles then
            local cmd = globals.GetUserCmd()
            if cmd then
                cmd.viewangles = lockedViewangles
            end
        end
    else
        -- Restore previous mouse state when chat closes
        if mousePrevEnabled ~= nil then
            input.SetMouseInputEnabled(mousePrevEnabled)
            mousePrevEnabled = nil
        end
        -- Clear locked viewangles
        lockedViewangles = nil
    end

    -- Get current dimensions with minimum sizes
    local dims = ChatVGUI.getCurrentDimensions()
    if not dims.visible or not dims.enabled then return end
    
    -- Set font
    if ChatUI.font then
        draw.SetFont(ChatUI.font)
        
        -- Only draw background when input is active
        if ChatConfig.inputActive then
            -- Draw chat background
            draw.Color(dims.bgColor.r, dims.bgColor.g, dims.bgColor.b, clampAlpha(127 * 1.25))
            draw.FilledRect(
                math.floor(dims.x), 
                math.floor(dims.y), 
                math.floor(dims.x + dims.width), 
                math.floor(dims.y + dims.height)
            )
        end
        
        -- Calculate visible messages
        ChatUI.maxVisibleMessages = calculateMaxVisibleMessages(dims.height)
        local totalMessages = #ChatUI.chatHistory
        local maxScroll = math.max(0, totalMessages - ChatUI.maxVisibleMessages)
        
        -- Handle scrolling (matching visual movement)
        if ChatConfig.inputActive then
            local currentTime = globals.RealTime()
            if currentTime - ChatUI.lastScrollTime >= ChatUI.SCROLL_DELAY then
                if input.IsButtonPressed(MOUSE_WHEEL_UP) and ChatUI.scrollOffset > 0 then
                    ChatUI.scrollOffset = ChatUI.scrollOffset - 1
                    ChatUI.lastScrollTime = currentTime
                elseif input.IsButtonPressed(MOUSE_WHEEL_DOWN) and ChatUI.scrollOffset < maxScroll then
                    ChatUI.scrollOffset = ChatUI.scrollOffset + 1
                    ChatUI.lastScrollTime = currentTime
                end
            end
        else
            -- Reset scroll to top when input is closed
            ChatUI.scrollOffset = 0
        end
        
        -- Draw scrollbar if needed and chat is active
        local hasScrollbar = totalMessages > ChatUI.maxVisibleMessages and ChatConfig.inputActive
        local scrollbarWidth = 4  -- Made thinner to match aesthetic
        
        if hasScrollbar then
            -- Calculate scrollbar dimensions (adjusted to fit perfectly)
            local scrollbarX = dims.x + dims.width - scrollbarWidth - 1  -- Slight offset from edge
            local scrollbarTop = dims.y + 1  -- Almost flush with top
            local scrollbarHeight = dims.height - 32  -- Adjusted to stop at input box
            
            -- Draw scrollbar background
            draw.Color(0, 0, 0, 100)  -- More subtle background
            draw.FilledRect(
                math.floor(scrollbarX), 
                math.floor(scrollbarTop), 
                math.floor(scrollbarX + scrollbarWidth), 
                math.floor(scrollbarTop + scrollbarHeight)
            )
            
            -- Calculate and draw thumb
            local thumbHeight = math.max(20, (ChatUI.maxVisibleMessages / totalMessages) * scrollbarHeight)
            local thumbPosition = ((maxScroll - ChatUI.scrollOffset) / maxScroll) * (scrollbarHeight - thumbHeight)
            
            -- More subtle thumb color to match chat aesthetic
            draw.Color(255, 255, 255, 50)
            draw.FilledRect(
                math.floor(scrollbarX),
                math.floor(scrollbarTop + thumbPosition),
                math.floor(scrollbarX + scrollbarWidth),
                math.floor(scrollbarTop + thumbPosition + thumbHeight)
            )
        end
        
        -- Draw chat history with scroll offset
        -- Calculate the line height based on current font
        local padding = 8  -- Base padding
        local _, lineHeight = draw.GetTextSize("TEST")
        -- Make input box height larger with double padding
        local inputBoxHeight = lineHeight + (padding * 3)  -- More space for input box
        -- Start messages higher up to account for larger input box
        local messageY = dims.y + dims.height - (inputBoxHeight + padding)
        local visibleWidth = dims.width - (hasScrollbar and scrollbarWidth + padding or padding)
        
        for i = 1, ChatUI.maxVisibleMessages do
            local msgIndex = i + ChatUI.scrollOffset
            local msg = ChatUI.chatHistory[msgIndex]
            if msg and messageY >= dims.y + padding then
                local age = globals.RealTime() - msg.time
                local alpha = 255
                
                if not ChatConfig.inputActive and age > 10 then
                    alpha = math.floor(255 * (1 - (age - 10) / 5))
                    alpha = math.max(2, alpha)
                    -- Skip drawing if alpha is minimum and chat isn't active
                    if alpha <= 2 and not ChatConfig.inputActive then
                        goto continue
                    end
                elseif ChatConfig.inputActive then
                    -- When chat is active, show all messages at full alpha
                    alpha = 255
                end
                
                -- Then update the message drawing section in ChatVGUI.drawChat
                if alpha >= 2 then  -- Only draw if alpha is valid
                    local timestamp = formatTimestamp() .. " "  -- Add space after timestamp
                    if msg.isWrapped then
                        -- Continuation line - indented properly
                        drawColoredText(dims.x + padding, messageY, msg.text, alpha)
                    else
                        -- First line - needs full formatting
                        local curX = dims.x + padding

                        -- Only draw timestamp if enabled
                        if timestamps then
                            curX = drawColoredText(curX, messageY, timestamp, alpha)
                        end
                    
                        -- Show colored prefix only for actual online chat messages
                        if msg.isOnlineChatMessage and msg.playerName then
                            local prefix
                            if msg.isDiscord then
                                prefix = "\x07FFFFFF[\x07FF69B4DC\x07FFFFFF] "
                            else
                                prefix = "\x07FFFFFF[\x07FF1122Chat\x07FFFFFF] "
                            end
                            curX = drawColoredText(curX, messageY, prefix, alpha)
                        end
                    
                        if msg.isDiscord then
                            -- Discord messages get pink coloring
                            drawColoredText(curX, messageY, "\x07FF69B4" .. msg.text, alpha)
                        elseif msg.isServer then
                            -- Server messages get lightblue coloring
                            drawColoredText(curX, messageY, "\x077FFFFF" .. msg.text, alpha)
                        elseif msg.playerName then
                            local teamPrefix = ""
                            if msg.team == 2 then  -- RED team
                                teamPrefix = "\x07FFFFFF(\x07FF4444R\x07FFFFFF) "
                            elseif msg.team == 3 then  -- BLU team
                                teamPrefix = "\x07FFFFFF(\x074444FFB\x07FFFFFF) "
                            elseif msg.team == 1 then  -- SPEC team
                                teamPrefix = "\x07FFFFFF(\x07CCCCCCS\x07FFFFFF) "
                            end
                            
                            -- Add team prefix first if any
                            if teamPrefix ~= "" then
                                curX = drawColoredText(curX, messageY, teamPrefix, alpha)
                            end
                        
                            -- Add TM after team color
                            if msg.isTeamChat then
                                curX = drawColoredText(curX, messageY, "(TM) ", alpha)
                            end
                        
                            -- Add RIP last if dead
                            if msg.isDead and (msg.team == 2 or msg.team == 3) then
                                curX = drawColoredText(curX, messageY, "\x07666666*RIP* \x07FFFFFF", alpha)
                            end
                            
                            curX = drawColoredText(curX, messageY, msg.playerName, alpha)
                            curX = drawColoredText(curX, messageY, "\x07FFFFFF: ", alpha)
                            drawColoredText(curX, messageY, msg.text, alpha)
                        else
                            -- Regular messages just get shown as is
                            drawColoredText(curX, messageY, msg.text, alpha)
                        end
                    end
                    messageY = messageY - 15
                end
            end
            ::continue::
        end
        
        -- Draw input line if active
        if ChatConfig.inputActive then
            local dims = ChatVGUI.getCurrentDimensions()
            local inputY = dims.y + dims.height - 30
            local basePadding = 8
            local textPadding = 4
            
            -- Draw input box background
            draw.Color(0, 0, 0, clampAlpha(127))
            draw.FilledRect(
                math.floor(dims.x), 
                math.floor(inputY), 
                math.floor(dims.x + dims.width), 
                math.floor(dims.y + dims.height)
            )

            ChatUI.cursorBlink = ChatUI.cursorBlink + globals.FrameTime()
            
            -- Set font for consistent measurements
            draw.SetFont(ChatUI.font)
            
            -- Calculate mode text width first
            local modeText = ChatConfig.onlineChat and "ONLINE" or 
                        (ChatConfig.partyChat and "PARTY" or 
                        (ChatConfig.teamChat and "TEAM" or "ALL"))
            local modeWidth = draw.GetTextSize(modeText) + (textPadding * 4)
            
            -- Calculate character count width if needed
            local countWidth = 0
            local charCount = #ChatConfig.inputBuffer
            if charCount > MESSAGE_MAX_LENGTH * 0.7 then
                local countText = string.format("%d/%d", charCount, MESSAGE_MAX_LENGTH)
                countWidth = draw.GetTextSize(countText) + (textPadding * 2)
            end
            
            -- Calculate text area boundaries
            local textStartX = dims.x + basePadding
            local textEndX = dims.x + dims.width - (modeWidth + countWidth + basePadding + textPadding)
            local availableWidth = textEndX - textStartX
            
            -- Process input text
            local prefix = ChatConfig.teamChat and "" or ""
            local displayText = prefix .. ChatConfig.inputBuffer
            local fullTextWidth = getTextDisplayWidth(ChatUI.font, displayText)
            
            -- Drawing code inside your main draw function:
            -- Calculate text position and get processed text
            local textX, finalText, textWidth, relativePosition = processInputText(
                displayText,
                availableWidth,
                textStartX,
                fullTextWidth
            )
            
            -- Replace the selection drawing section in your chat drawing code:
            if ChatUI.selectionStart and ChatUI.selectionEnd then
                local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
                local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
                
                -- Calculate visible portion of text based on current scroll position
                local visibleStartIndex = #ChatConfig.inputBuffer - #finalText + 1
                local visibleEndIndex = visibleStartIndex + #finalText - 1
                
                -- Clamp selection to visible area
                local visibleStart = math.max(start, visibleStartIndex - 1)
                local visibleEnd = math.min(finish, visibleEndIndex)
                
                -- Only draw if selection is within visible area
                if visibleStart < visibleEndIndex and visibleEnd >= visibleStartIndex then
                    -- Calculate selection position relative to visible text
                    local beforeVisibleSelection = finalText:sub(1, math.max(0, visibleStart - visibleStartIndex + 1))
                    local visibleSelection = finalText:sub(
                        math.max(1, visibleStart - visibleStartIndex + 1),
                        math.max(1, visibleEnd - visibleStartIndex + 1)
                    )
                    
                    local selStartX = textX + draw.GetTextSize(beforeVisibleSelection)
                    local selWidth = draw.GetTextSize(visibleSelection)
                    
                    -- Clamp selection bounds to text area
                    selStartX = math.max(textX, selStartX)
                    local selEndX = math.min(textX + availableWidth, selStartX + selWidth)
                    
                    -- Draw selection background
                    draw.Color(50, 100, 150, 150)
                    draw.FilledRect(
                        math.floor(selStartX),
                        inputY + 2,
                        math.floor(selEndX),
                        inputY + 20
                    )
                end
            end
            
            -- Draw the input text
            draw.Color(255, 255, 255, 255)
            draw.Text(math.floor(textX), inputY + 5, finalText)

            -- Draw cursor if input is active
            if ChatUI.cursorBlink % 1 > 0.5 then
                local visibleTextBeforeCursor = finalText:sub(1, relativePosition)
                local cursorX = textX + draw.GetTextSize(visibleTextBeforeCursor)
                
                if cursorX >= textX and cursorX < textX + availableWidth then
                    draw.Color(255, 255, 255, 255)
                    draw.Text(math.floor(cursorX), inputY + 5, "|")
                end
            end
            
            -- Draw character count if needed
            if charCount > MESSAGE_MAX_LENGTH * 0.7 then
                draw.Color(
                    charCount >= MESSAGE_MAX_LENGTH and 255 or 200,
                    charCount >= MESSAGE_MAX_LENGTH and 50 or 200,
                    50,
                    255
                )
                local countText = string.format("%d/%d", charCount, MESSAGE_MAX_LENGTH)
                draw.Text(
                    math.floor(textEndX + textPadding), 
                    inputY + 5, 
                    countText
                )
            end
            
            -- Draw chat type indicator
            draw.Color(
                ChatConfig.onlineChat and 255 or (ChatConfig.partyChat and 255 or (ChatConfig.teamChat and 255 or 128)),
                ChatConfig.onlineChat and 128 or (ChatConfig.partyChat and 255 or (ChatConfig.teamChat and 128 or 255)),
                ChatConfig.onlineChat and 255 or (ChatConfig.partyChat and 0 or 128),
                255
            )
            -- Draw mode text aligned to right with proper spacing
            draw.Text(
                math.floor(dims.x + dims.width - modeWidth - textPadding),
                inputY + 5,
                modeText
            )
        end
    end
end

-- State
local authenticated = false
local username = nil
local password = nil
local nickname = nil
local lastFetch = 0
local lastMessage = nil
local lastMessageTime = 0
local messageHistory = {}
local MAX_HISTORY = 12
local LastKeyStates = {} -- Initialize this globally
-- Input handling improvements
local LastKeyState = {}
local lockedViewangles = nil
local mousePrevEnabled = input.IsMouseInputEnabled()
local LastKey = nil
local BackspaceStartTime = 0
local LastKeyPressTime = 0
local BACKSPACE_DELAY = 0.5  -- Initial delay before rapid backspace
local BACKSPACE_REPEAT_RATE = 0.03  -- How fast characters are deleted when holding
local capsLockEnabled = false
local lastShiftState = false
local lastChatOpenTime = 0
local CHAT_OPEN_COOLDOWN = 0.2 -- 200ms cooldown

-- Extended input map with shift characters
local InputMap = {
    -- Numbers
    [KEY_0] = {normal = "0", shift = ")"},
    [KEY_1] = {normal = "1", shift = "!"},
    [KEY_2] = {normal = "2", shift = "@"},
    [KEY_3] = {normal = "3", shift = "#"},
    [KEY_4] = {normal = "4", shift = "$"},
    [KEY_5] = {normal = "5", shift = "%"},
    [KEY_6] = {normal = "6", shift = "^"},
    [KEY_7] = {normal = "7", shift = "&"},
    [KEY_8] = {normal = "8", shift = "*"},
    [KEY_9] = {normal = "9", shift = "("},
    
    -- Letters (will handle case separately)
    [KEY_A] = {normal = "a", shift = "A"},
    [KEY_B] = {normal = "b", shift = "B"},
    [KEY_C] = {normal = "c", shift = "C"},
    [KEY_D] = {normal = "d", shift = "D"},
    [KEY_E] = {normal = "e", shift = "E"},
    [KEY_F] = {normal = "f", shift = "F"},
    [KEY_G] = {normal = "g", shift = "G"},
    [KEY_H] = {normal = "h", shift = "H"},
    [KEY_I] = {normal = "i", shift = "I"},
    [KEY_J] = {normal = "j", shift = "J"},
    [KEY_K] = {normal = "k", shift = "K"},
    [KEY_L] = {normal = "l", shift = "L"},
    [KEY_M] = {normal = "m", shift = "M"},
    [KEY_N] = {normal = "n", shift = "N"},
    [KEY_O] = {normal = "o", shift = "O"},
    [KEY_P] = {normal = "p", shift = "P"},
    [KEY_Q] = {normal = "q", shift = "Q"},
    [KEY_R] = {normal = "r", shift = "R"},
    [KEY_S] = {normal = "s", shift = "S"},
    [KEY_T] = {normal = "t", shift = "T"},
    [KEY_U] = {normal = "u", shift = "U"},
    [KEY_V] = {normal = "v", shift = "V"},
    [KEY_W] = {normal = "w", shift = "W"},
    [KEY_X] = {normal = "x", shift = "X"},
    [KEY_Y] = {normal = "y", shift = "Y"},
    [KEY_Z] = {normal = "z", shift = "Z"},
    
    -- Special characters
    [KEY_SPACE] = {normal = " ", shift = " "},
    [KEY_MINUS] = {normal = "-", shift = "_"},
    [KEY_EQUAL] = {normal = "=", shift = "+"},
    [KEY_LBRACKET] = {normal = "[", shift = "{"},
    [KEY_RBRACKET] = {normal = "]", shift = "}"},
    [KEY_BACKSLASH] = {normal = "\\", shift = "|"},
    [KEY_SEMICOLON] = {normal = ";", shift = ":"},
    [KEY_APOSTROPHE] = {normal = "'", shift = "\""},
    [KEY_COMMA] = {normal = ",", shift = "<"},
    [KEY_PERIOD] = {normal = ".", shift = ">"},
    [KEY_SLASH] = {normal = "/", shift = "?"},
    [KEY_BACKQUOTE] = {normal = "`", shift = "~"}
}

-- Define valid commands
local VALID_COMMANDS = {
    ["register"] = true,
    ["login"] = true,
    ["logout"] = true,
    ["nick"] = true, ["n"] = true,
    ["chat"] = true, ["c"] = true,
    ["users"] = true, ["u"] = true,
    ["help"] = true, ["h"] = true,
    ["colors"] = true -- New command to show color codes
}

local defaultTextChat = client.GetConVar("cl_enable_text_chat") or "1"
local defaultSayTime = client.GetConVar("hud_saytext_time") or "12"

-- Add this check to the updateChatVisibility function
local function updateChatVisibility()
    if ChatConfig.enabled then
        client.Command("cl_enable_text_chat 0")
        client.Command("hud_saytext_time 0")
    else
        releaseViewLock() -- Release view lock when disabling custom chat
        client.Command("cl_enable_text_chat " .. defaultTextChat) 
        client.Command("hud_saytext_time " .. defaultSayTime)
    end
end

-- Input helper functions
-- Initialize LastKeyState for all used keys
for key, _ in pairs(InputMap) do
    LastKeyState[key] = false
end
LastKeyState[KEY_ENTER] = false
LastKeyState[KEY_ESCAPE] = false
LastKeyState[KEY_BACKSPACE] = false
LastKeyState[KEY_CAPSLOCK] = false

-- Simple string hash function
local function simpleHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash << 5) + hash) + str:byte(i)
        hash = hash & 0xFFFFFFFF
    end
    local hex = string.format("%08x", hash)
    while #hex < 16 do
        hex = hex .. hex:sub(1, 16 - #hex)
    end
    return hex:sub(1, 16)
end

-- Configuration handling
local function saveConfig()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        if authenticated then
            file:write(string.format("username=%s\n", username or ""))
            file:write(string.format("password=%s\n", password or ""))
            file:write(string.format("nickname=%s\n", nickname or ""))
        else
            file:write("username=\npassword=\nnickname=\n")
        end
        file:close()
    end
end

local function loadConfig()
    local file = io.open(CONFIG_FILE, "r")
    if file then
        firstTimeUser = false
        local content = file:read("*all")
        file:close()
        
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("([^=]+)=(.*)")
            if key and value and value ~= "" then
                if key == "username" then username = value
                elseif key == "password" then password = value
                elseif key == "nickname" then nickname = value
                end
            end
        end
        
        if username and password then
            return true
        end
    end
    return false
end

-- Input validation
--local function validateInput(text)
--    -- Only allow standard alphabet and basic symbols, excluding separator
--    return text:gsub("[^a-zA-Z0-9!@#$%%^&*()_+\\-=\\[\\]{}|;'\",.<>/?~\\\\]", "")
--end

-- Get hashed SteamID
local function getHashedSteamID()
    local me = entities.GetLocalPlayer()
    if not me then return nil end
    
    local info = client.GetPlayerInfo(me:GetIndex())
    if not info or not info.SteamID then return nil end
    
    return simpleHash(info.SteamID)
end

-- HTTP Request helper
local function makeRequest(action, params)
    local function urlencode(str)
        return str
    end    

    local url = API_URL .. "/?a=" .. action
    for k, v in pairs(params) do
        if v then
            url = url .. "&" .. k .. "=" .. urlencode(v)
        end
    end
    
    return http.Get(url)
end

-- Message deduplication
local function shouldShowMessage(nick, msg, timestamp)
    if nick ~= "SRV" then
        for _, hist in ipairs(messageHistory) do
            if hist.nick == nick and hist.message == msg then
                return false
            end
        end
        table.insert(messageHistory, {
            nick = nick,
            message = msg,
            timestamp = timestamp
        })
        return true
    end
    
    for i = #messageHistory, 1, -1 do
        local hist = messageHistory[i]
        if hist.nick == "SRV" and hist.message == msg then
            if timestamp - hist.timestamp < 5000 then
                return false
            end
            table.remove(messageHistory, i)
        end
    end
    
    table.insert(messageHistory, {
        nick = nick,
        message = msg,
        timestamp = timestamp
    })
    
    while #messageHistory > MAX_HISTORY do
        table.remove(messageHistory, 1)
    end
    
    return true
end

-- Update the fetchMessages function
local function fetchMessages()
    local dims = ChatVGUI.getCurrentDimensions()
    
    local params = {}
    if authenticated then
        params.u = username
        params.p = password
        if nickname then
            params.n = nickname
        end
    end
    
    local response = makeRequest("get", params)
    if response and response ~= "NO_MESSAGES" then
        local parts = {}
        for part in response:gmatch("[^:]+") do
            table.insert(parts, part)
        end
        
        local numPairs = math.floor(#parts / 2)
        local timestamp = globals.RealTime() * 1000
        
        for i=1, numPairs do
            local nickIndex = (i-1)*2 + 1
            local msgIndex = nickIndex + 1
            
            local nick = parts[nickIndex]
            local msg = parts[msgIndex]
            
            -- Replace colon placeholders before processing the message
            if nick and msg then
                nick = replaceColonPlaceholder(nick)
                msg = replaceColonPlaceholder(msg)
                
                if shouldShowMessage(nick, msg, timestamp) then
                    -- Flag this as an online chat message since it came from the API
                    local isOnlineChatMessage = true
                    
                    -- Send to vanilla chat
                    client.ChatPrintf(formatMessageRaw(nick, msg))
                    
                    -- Send to custom chat with proper flag
                    addChatMessage(msg, nick, 15, dims.width, ChatUI.font, isOnlineChatMessage)
                    
                    lastMessage = {nick = nick, message = msg}
                    lastMessageTime = timestamp
                end
            end
        end
    end
end

-- Show available colors
local function showColorList()
    chatMessage("\\x03Available color codes:")
    chatMessage("Basic Colors (use \\x followed by the code):")
    local msg = ""
    -- Show basic colors
    for i = 1, 15 do
        local code = string.format("%02X", i)
        msg = msg .. string.format("\\x%s%s ", code, code)
    end
    chatMessage(msg)
    
    msg = ""
    -- Show bright variants
    chatMessage("Bright Variants:")
    for i = 16, 31 do
        local code = string.format("%02X", i)
        msg = msg .. string.format("\\x%s%s ", code, code)
    end
    chatMessage(msg)
    
    chatMessage("Example: \\x01Hello \\x02Red \\x03Green \\x04Blue")
    --chatMessage("The \\x01quick \\x02brown \\x03fox \\x04jumps \\x05over \\x06the \\x07lazy \\x08dog \\x09is \\x0Aan \\x0BEnglish-language \\x0Cpangram \\x0D– \\x0Ea \\x0Fsentence \\x01that \\x02contains \\x03all \\x04the \\x05letters \\x06of \\x07the \\x08alphabe")
end

-- Command handling
local function handleCommand(cmd, args, isRawMessage)
    if not VALID_COMMANDS[cmd] then
        if authenticated and nickname then
            local message = isRawMessage and cmd or table.concat(args, " ")
            local response = makeRequest("post", {
                u = username,
                p = password,
                n = nickname,
                m = message
            })
            
            if response ~= "OK" then
                chatMessage("Failed to send message: " .. tostring(response))
            end
            return
        else
            if not authenticated then
                chatMessage("Please register or login first!")
            elseif not nickname then
                chatMessage("Please set your nickname first with /nick <nickname>")
            end
            return
        end
    end

    if cmd == "register" or cmd == "r" then
        if #args < 1 then
            chatMessage("Usage: /register <password>")
            return
        end
        
        local hashedID = getHashedSteamID()
        if not hashedID then
            chatMessage("Failed to get SteamID. Are you in-game?")
            return
        end
        
        username = hashedID
        password = args[1]

        chatMessage("Attempting registration with hashed SteamID: " .. username)
        
        local response = makeRequest("reg", {
            u = username,
            p = password
        })
        
        if response == "OK" then
            authenticated = true
            saveConfig()
            chatMessage("Successfully registered!")
            chatMessage("Use /nick or /n <nickname> to set your nickname")
        elseif response == "USERNAME_TAKEN" then
            chatMessage("This SteamID is already registered. Please use /login <password> instead.")
        elseif response == "INVALID_PARAMS" then
            chatMessage("Registration failed - invalid parameters. Got username: " .. tostring(username) .. " and password: " .. tostring(password))
        else
            chatMessage("Registration failed: " .. tostring(response))
        end
    
    elseif cmd == "login" then
        if #args < 1 then
            chatMessage("Usage: /login <password>")
            return
        end
        
        if not username then
            username = getHashedSteamID()
            if not username then
                chatMessage("Failed to get SteamID. Are you in-game?")
                return
            end
        end
        
        password = args[1]
        
        local response = makeRequest("get", {
            u = username,
            p = password
        })
        
        if response and response ~= "AUTH_ERROR" then
            authenticated = true
            
            local listResponse = makeRequest("list", {
                u = username,
                p = password
            })
            
            local userCount = "0"
            if listResponse and listResponse ~= "NO_USERS" then
                userCount = listResponse:match("^(%d+)")
            end
            
            chatMessage("Successfully logged in as: " .. username .. " (\\x03" .. userCount .. "\\x01 users online)")
            if not nickname then
                chatMessage("Use /nick or /n <nickname> to set your nickname")
            else
                chatMessage("You're all set! Use /chat or /c <message> to chat")
                chatMessage("Use /users or /u to see who's online")
            end
            
            saveConfig()
        else
            chatMessage("Login failed. Please check your password.")
        end
    
    elseif cmd == "nick" or cmd == "n" then
        if not authenticated then
            chatMessage("Please register or login first!")
            return
        end
        
        -- Join all arguments with spaces to support nicknames with spaces
        local newNickname = table.concat(args, " ")
        if newNickname == "" then
            chatMessage("Usage: /nick <nickname>")
            chatMessage("Your current nickname is " .. nickname)
            return
        end
        
        -- Trim any leading/trailing whitespace
        newNickname = newNickname:match("^%s*(.-)%s*$")
        
        -- Optional: Add length check if needed
        if #newNickname > NICKNAME_MAX_LENGTH then
            chatMessage("Nickname too long! Maximum length is " .. NICKNAME_MAX_LENGTH .. " characters.")
            return
        end
        
        nickname = newNickname
        saveConfig()
        chatMessage("Nickname set to: " .. nickname)
        chatMessage("You can now chat with /chat or /c <message>")
        chatMessage("View online users with /users or /u")
    
    elseif cmd == "chat" or cmd == "c" then
        if not authenticated then
            chatMessage("Please register or login first!")
            return
        end
        
        if not nickname then
            chatMessage("Please set your nickname first with /nick <nickname>")
            return
        end
        
        if #args < 1 then
            chatMessage("Usage: /chat <message>")
            return
        end
        
        local message = table.concat(args, " ")
        local response = makeRequest("post", {
            u = username,
            p = password,
            n = nickname,
            m = message
        })
        
        if response ~= "OK" then
            chatMessage("Failed to send message: " .. tostring(response))
        end
    
    elseif cmd == "users" or cmd == "u" then
        if not authenticated then
            chatMessage("Please register or login first!")
            return
        end
        
        local response = makeRequest("list", {
            u = username,
            p = password
        })
        
        if response and response ~= "NO_USERS" then
            local parts = {}
            for part in response:gmatch("[^:]+") do
                table.insert(parts, part)
            end
            
            local count = tonumber(parts[1])
            chatMessage("Online users (\\x03" .. count .. "\\x01):")
            
            local users = {}
            for i=2, #parts do
                table.insert(users, parts[i])
            end
            chatMessage("\\x01" .. table.concat(users, "\\x01, "))
        else
            chatMessage("No users online")
        end
    
    elseif cmd == "colors" then
        showColorList()
    
    elseif cmd == "logout" or cmd == "l" then
        authenticated = false
        username = nil
        password = nil
        nickname = nil
        saveConfig()
        chatMessage("Successfully logged out!")
    
    elseif cmd == "help" or cmd == "h" then
        chatMessage("\\x03Available commands:")
        chatMessage("/register or /r <password> - Create new account")
        chatMessage("/login <password> - Login to existing account")
        chatMessage("/nick or /n <nickname> - Set your nickname")
        chatMessage("/chat or /c <message> - Send a message (or just use /)")
        chatMessage("/users or /u - List online users")
        chatMessage("/colors - Show available colors")
        chatMessage("/logout or /l - Logout")
        chatMessage("/help or /h - Show this help")
    end
end

-- Update 2: In the player connect/disconnect handlers
callbacks.Register("FireGameEvent", "chat_player_connect", function(event)
    local dims = ChatVGUI.getCurrentDimensions()

    if event:GetName() == "player_connect_client" then
        local name = event:GetString("name")
        local index = event:GetInt("index")
        local bot = event:GetInt("bot")
        
        if bot == 0 or (bot == 1 and engine.GetServerIP() == "loopback") then
            if ChatConfig.enabled then
                local message = name .. "\\x15 joined the game"
                addChatMessage(message, nil, 15, dims.width, ChatUI.font, false, nil, nil, false)
            end
        end
    elseif event:GetName() == "player_disconnect" then
        local name = event:GetString("name")
        local bot = event:GetInt("bot")
        
        if bot == 0 or (bot == 1 and engine.GetServerIP() == "loopback") then
            if ChatConfig.enabled then
                local message = name .. "\\x15 left the game"
                addChatMessage(message, nil, 15, dims.width, ChatUI.font, false, nil, nil, false)
            end
        end
    end
end)

-- Class change event handler
callbacks.Register("FireGameEvent", "class_change_handler", function(event)
    if event:GetName() ~= "player_changeclass" or not showClassChanges then return end
    
    local player = entities.GetByUserID(event:GetInt("userid"))
    if not player or not player:IsValid() then return end

    local team = player:GetTeamNumber()
    local teamPrefix = ""
    if team == 2 then  -- RED
        teamPrefix = "\\x01(\\x02R\\x01) "
    elseif team == 3 then  -- BLU
        teamPrefix = "\\x01(\\x0AB\\x01) "
    end
    
    local classID = event:GetInt("class")
    if not classNames[classID] then return end
    
    local dims = ChatVGUI.getCurrentDimensions()
    local teamColor = team == 2 and "\\x16" or (team == 3 and "\\x16" or "\\x16")
    
    -- Sanitize player name to handle UTF-8/Cyrillic characters
    local playerName = player:GetName()
    playerName = playerName:gsub("[\128-\255][\128-\191]*", function(c)
        return c -- Keep UTF-8 sequences intact
    end)

    -- Combine message parts with explicit concatenation
    local message = teamPrefix .. teamColor .. playerName .. "\\x01 changed class to " .. teamColor .. classNames[classID]
    
    if ChatConfig.enabled then
        addChatMessage(message, "SRV", 15, dims.width, ChatUI.font, false, team, false, false)
    else
        local teamColor = team == 2 and "\\x02" or (team == 3 and "\\x0A" or "\\x16")
        -- Use explicit concatenation here as well
        local message = teamColor .. playerName .. "\\x01 changed class to " .. teamColor .. classNames[classID]
        local formatted = formatMessageRaw("", message)
        client.ChatPrintf(formatted)
    end
end)

-- Keep the existing SendStringCmd callback but make it check ChatConfig.enabled
callbacks.Register("SendStringCmd", "chat_commands", function(cmd)
    -- Only intercept commands if custom chat is disabled
    if not ChatConfig.enabled then
        local cmdStr = cmd:Get()
        
        if cmdStr:match("^say[_ ]") then
            local fullText = cmdStr:sub(cmdStr:find(" ") + 1):gsub('"', '')
            
            if fullText:sub(1,1) == "/" then
                cmd:Set("")  -- Cancel the original chat message
                
                local message = fullText:sub(2)  -- Remove leading slash
                
                if message == "" then
                    chatMessage("Please enter a message or command after the /")
                    return
                end
                
                -- Get first word to check if it's a command
                local firstWord = message:match("^(%S+)")
                if VALID_COMMANDS[firstWord] then
                    -- It's a command, handle it normally
                    local args = {}
                    for arg in message:sub(#firstWord + 2):gmatch("%S+") do
                        table.insert(args, arg)
                    end
                    handleCommand(firstWord, args)
                else
                    -- Not a command, send as chat message with full content
                    handleCommand(message, {}, true)
                end
            end
        end
    end
end)

-- Update RenderView callback
callbacks.Register("RenderView", "chat_view_lock", function(view)
    if ChatConfig.inputActive and ViewLockState.isLocked and ChatConfig.enabled then
        -- Lock the view angles for rendering
        view.angles = EulerAngles(
            ViewLockState.renderPitch,
            ViewLockState.renderYaw,
            ViewLockState.renderRoll
        )
    end
end)

-- Helper function to read null-terminated strings from community server chat messages
local function readNullTerminatedString(bf)
    local result = ""
    while true do
        local byte = bf:ReadByte()
        if byte == 0 or byte == nil then break end
        result = result .. string.char(byte)
    end
    return result
end

-- Helper function to print values with hex
local function debugPrint(str)
    if not str then return end
    local hex = ""
    for i = 1, #str do
        hex = hex .. string.format("%02X ", str:byte(i))
    end
    print("String: '" .. str .. "'")
    print("Hex: " .. hex)
end

local function handleChatMessage(msg)
    if msg:GetID() ~= 4 then return end  -- SayText2

    local bf = msg:GetBitBuffer()
    if not bf then return end

    -- Store original position
    local originalPos = bf:GetCurBit()
    
    --print("\n--- New Chat Message ---")
    
    -- First try Valve matchmaking format
    local entityIndex = bf:ReadByte()
    local chatType = bf:ReadByte()  -- chatType == 2 means team chat
    local content = bf:ReadString(256)
    local name = bf:ReadString(256)
    local message = bf:ReadString(256)

    --print("Valve Format Debug:")
    --print("Entity Index:", entityIndex)
    --print("Chat Type:", chatType)
    --print("Content:")
    --debugPrint(content)
    --print("Name:")
    --debugPrint(name)
    --print("Message:")
    --debugPrint(message)

    -- Get entity info
    local speaker = entities.GetByIndex(entityIndex)
    local team = speaker and speaker:GetTeamNumber() or 0
    --print("Team:", team)
    local isDead = (team == 2 or team == 3) and speaker and not speaker:IsAlive()
    local isTeamChat = (chatType == 2)
    
    local dims = ChatVGUI.getCurrentDimensions()

    -- Try Valve matchmaking format first
    if name and message and name ~= "" and message ~= "" then
        -- Check if it's team chat based on the content string for Valve servers
        local isTeamChat = (content:match("TF_Chat_Team") ~= nil) or (content:match("TF_Chat_Spec") ~= nil)
        
        -- Add team prefix for Valve servers if it's team chat
        --if isTeamChat then
        --    name = "(TEAM) " .. name
        --end
        -- !redundant!
        
        name = name:gsub("%*DEAD%*", "")
            :gsub("%*SPEC%*", "")
            :gsub("%(TEAM%)", "")  -- Changed to empty string
            :gsub("%(Spectator%)", "")
            :gsub("^%s*(.-)%s*$", "%1")
        
        addChatMessage(message, name, 15, dims.width, ChatUI.font, nil, team, isDead, isTeamChat)
        return
    end

    -- If Valve format didn't work, try community server format
    print("\nTrying community server format...")
    bf:SetCurBit(originalPos)
    entityIndex = bf:ReadByte()
    chatType = bf:ReadByte()
    
    -- Read the full chat string
    local fullString = readNullTerminatedString(bf)
    print("Full string:")
    debugPrint(fullString)
    
    local playerName, chatText = fullString:match("([^:]+): (.+)")
    
    -- Replace colon placeholders if found
    if playerName then
        playerName = replaceColonPlaceholder(playerName)
    end
    if chatText then
        chatText = replaceColonPlaceholder(chatText)
    end

    -- If Valve format didn't work, try community server format...
    if playerName and chatText then
        -- For community servers, check for team chat by looking for (TEAM) tag
        local isTeamChat = playerName:match("%(TEAM%)") ~= nil or playerName:match("%(Spectator%)") ~= nil
        
        -- Strip Source engine RGB color codes from name
        playerName = playerName:gsub("\x07%x%x%x%x%x%x", "")
        
        playerName = playerName:gsub("%*DEAD%*", "")
                            :gsub("%*SPEC%*", "")
                            :gsub("%(TEAM%)", "")
                            :gsub("%(Spectator%)", "")
                            :gsub("^%s*(.-)%s*$", "%1")
        chatText = chatText:gsub("^%s*(.-)%s*$", "%1")
        
        -- Add team prefix for community servers if it's team chat
        --if isTeamChat then
        --    playerName = "(TEAM) " .. playerName
        --end
        -- !redundant!
        
        addChatMessage(chatText, playerName, 15, dims.width, ChatUI.font, nil, team, isDead, isTeamChat)
    end
end

callbacks.Register("DispatchUserMessage", "ChatHandler", handleChatMessage)

-- Handle voice messages
callbacks.Register("DispatchUserMessage", "voice_message_handler", function(msg)
    if msg:GetID() ~= 25 then return end  -- Voice menu messages have ID 25

    local bf = msg:GetBitBuffer()
    if not bf then return end

    local entityIndex = bf:ReadByte()
    local iMenu = bf:ReadByte()
    local iItem = bf:ReadByte()

    local player = entities.GetByIndex(entityIndex)
    if not player then return end

    local playerName = player:GetName() or "Unknown"
    local team = player:GetTeamNumber()
    local isDead = (team == 2 or team == 3) and not player:IsAlive()
    local voiceCommand = VOICE_MENU[iMenu] and VOICE_MENU[iMenu][iItem] or "Unknown Command"
    
    local dims = ChatVGUI.getCurrentDimensions()
    if ChatConfig.enabled then
        -- Create message with VC prefix after team prefix but before player name
        local message = voiceCommand
        addChatMessage(message, "(VC) " .. playerName, 15, dims.width, ChatUI.font, false, team, isDead, false)
    end
end)

local function handleCapsLockToggle()
    if input.IsButtonPressed(KEY_CAPSLOCK) and not LastKeyState[KEY_CAPSLOCK] then
        capsLockEnabled = not capsLockEnabled
    end
    LastKeyState[KEY_CAPSLOCK] = input.IsButtonDown(KEY_CAPSLOCK)
end

-- Modify the input handling in handleBackspace
local function handleBackspace(currentTime, inputBuffer)
    -- Special handling for online chat mode
    if ChatConfig.onlineChat then
        -- Always preserve the starting slash
        if #inputBuffer <= 1 then
            return "/"  -- Never allow complete deletion of the slash
        end
    end
    
    if input.IsButtonDown(KEY_BACKSPACE) then
        if not LastKeyState[KEY_BACKSPACE] then
            -- Single press backspace
            if not (ChatConfig.onlineChat and #inputBuffer <= 1) then
                inputBuffer = inputBuffer:sub(1, -2)
            end
            BackspaceStartTime = currentTime
        else
            -- Held backspace with repeat
            local timeSinceStart = currentTime - BackspaceStartTime
            if timeSinceStart > BACKSPACE_DELAY then
                if currentTime - LastKeyPressTime >= BACKSPACE_REPEAT_RATE then
                    if not (ChatConfig.onlineChat and #inputBuffer <= 1) then
                        inputBuffer = inputBuffer:sub(1, -2)
                    end
                    LastKeyPressTime = currentTime
                end
            end
        end
        LastKeyState[KEY_BACKSPACE] = true
    else
        LastKeyState[KEY_BACKSPACE] = false
        BackspaceStartTime = 0
    end
    
    return inputBuffer
end

-- Key repeat control state
local KeyRepeatState = {
    INITIAL_DELAY = 0.5,    -- Delay before repeating starts
    REPEAT_RATE = 0.05,     -- Time between repeats
    pressStartTimes = {},   -- When each key started being held
    lastRepeatTimes = {},   -- Last repeat time for each key
    isRepeating = {},       -- Track if key is in repeat mode
    enabled = true,         -- Global repeat state
    LastPressedKey = nil,
    frameInitialized = false,
    lastFrameKeys = {},
    keyPressCount = {}      -- Track key press counts
}

-- Modified resetAllKeyStates to handle KeyRepeatState.LastPressedKey
local function resetAllKeyStates()
    KeyRepeatState.pressStartTimes = {}
    KeyRepeatState.lastRepeatTimes = {}
    KeyRepeatState.isRepeating = {}
    KeyRepeatState.LastPressedKey = nil
    for key in pairs(LastKeyState) do
        LastKeyState[key] = false
    end
end

-- Modified resetKeyRepeatState to handle KeyRepeatState.LastPressedKey
local function resetKeyRepeatState(key)
    KeyRepeatState.pressStartTimes[key] = nil
    KeyRepeatState.lastRepeatTimes[key] = nil
    KeyRepeatState.isRepeating[key] = nil
    if KeyRepeatState.LastPressedKey == key then
        KeyRepeatState.LastPressedKey = nil
    end
end

-- Modified handleKeyInput to properly handle key transitions
local function handleKeyInput(inputBuffer)
    local shiftPressed = input.IsButtonDown(KEY_LSHIFT) or input.IsButtonDown(KEY_RSHIFT)
    local currentTime = globals.RealTime()
    local keyPressed = false

    -- First check if any key is being pressed
    for key, chars in pairs(InputMap) do
        if input.IsButtonDown(key) then
            keyPressed = true
            if key ~= KeyRepeatState.LastPressedKey then
                -- New key pressed, reset all other key states
                resetAllKeyStates()
                KeyRepeatState.LastPressedKey = key
            end
            break
        end
    end

    -- If no keys are pressed, reset all states
    if not keyPressed then
        resetAllKeyStates()
        KeyRepeatState.LastPressedKey = nil
    end

    if not KeyRepeatState.frameInitialized then
        KeyRepeatState.lastFrameKeys = {}
        KeyRepeatState.frameInitialized = true
    end

    -- Now handle key input
    for key, chars in pairs(InputMap) do
        if input.IsButtonDown(key) then
            -- Initialize count for this key if not exists
            if not KeyRepeatState.keyPressCount[key] then
                KeyRepeatState.keyPressCount[key] = 0
            end

            local shouldAddChar = false
            local wasPressed = KeyRepeatState.lastFrameKeys[key]
            
            -- Only add character if this is a new press or valid repeat
            if not wasPressed then
                -- This is a new key press
                shouldAddChar = true
                KeyRepeatState.pressStartTimes[key] = currentTime
                KeyRepeatState.lastRepeatTimes[key] = currentTime
                KeyRepeatState.keyPressCount[key] = 1
            else
                -- Key was already pressed, check for repeat
                local timeHeld = currentTime - KeyRepeatState.pressStartTimes[key]
                if timeHeld >= KeyRepeatState.INITIAL_DELAY then
                    local timeSinceLastRepeat = currentTime - KeyRepeatState.lastRepeatTimes[key]
                    if timeSinceLastRepeat >= KeyRepeatState.REPEAT_RATE then
                        shouldAddChar = true
                        KeyRepeatState.lastRepeatTimes[key] = currentTime
                    end
                end
            end

            -- Mark key as pressed for next frame
            KeyRepeatState.lastFrameKeys[key] = true

            -- Add character if conditions are met
            if shouldAddChar then
                local nextChar
                if chars.normal:match("%a") then
                    local useUpperCase = (capsLockEnabled and not shiftPressed) or 
                                       (not capsLockEnabled and shiftPressed)
                    nextChar = useUpperCase and chars.shift or chars.normal
                else
                    nextChar = shiftPressed and chars.shift or chars.normal
                end

                if (#inputBuffer + #nextChar) <= MESSAGE_MAX_LENGTH then
                    inputBuffer = inputBuffer .. nextChar
                    handleCharacterInput()
                end
            end
        else
            -- Reset individual key state when released
            resetKeyRepeatState(key)
        end
        
        LastKeyState[key] = input.IsButtonDown(key)
    end

    return inputBuffer
end

-- Helper functions for input handling
local function isCtrlPressed()
    return input.IsButtonDown(KEY_LCONTROL) or input.IsButtonDown(KEY_RCONTROL)
end

local function getWordBoundaries(text, curPos)
    -- Get boundaries of current word
    local start = text:sub(1, curPos):match(".*()%s") or 0
    local finish = text:sub(curPos + 1):find("%s") or #text
    finish = finish + curPos
    return start, finish
end

local function addToHistory(text)
    -- Don't add empty text or duplicates
    if text == "" or text == ChatUI.inputHistory[1] then return end
    
    -- Add to front of history
    table.insert(ChatUI.inputHistory, 1, text)
    
    -- Keep only last 50 entries
    while #ChatUI.inputHistory > 50 do
        table.remove(ChatUI.inputHistory)
    end
    
    -- Reset history index
    ChatUI.inputHistoryIndex = 0
end

-- Helper function to get next character length (UTF-8 aware)
local function getNextCharLength(text, pos)
    if pos > #text then return 0 end
    local byte = text:byte(pos)
    if byte >= 240 then return 4
    elseif byte >= 224 then return 3
    elseif byte >= 192 then return 2
    else return 1 end
end

-- Helper function to get previous character length (UTF-8 aware)
local function getPrevCharLength(text, pos)
    if pos <= 1 then return 0 end
    local byte = text:byte(pos - 1)
    if byte >= 128 and byte < 192 then
        -- This is a continuation byte, need to look back further
        if pos >= 4 and text:byte(pos - 4) >= 240 then return 4
        elseif pos >= 3 and text:byte(pos - 3) >= 224 then return 3
        elseif pos >= 2 and text:byte(pos - 2) >= 192 then return 2
        end
    end
    return 1
end

local function handleInput(ChatConfig, currentTime)
    -- Helper functions for UTF-8 character handling
    local function getNextCharLength(text, pos)
        if pos > #text then return 0 end
        local byte = text:byte(pos)
        if byte >= 240 then return 4
        elseif byte >= 224 then return 3
        elseif byte >= 192 then return 2
        else return 1 end
    end

    local function getPrevCharLength(text, pos)
        if pos <= 1 then return 0 end
        local byte = text:byte(pos - 1)
        if byte >= 128 and byte < 192 then
            if pos >= 4 and text:byte(pos - 4) >= 240 then return 4
            elseif pos >= 3 and text:byte(pos - 3) >= 224 then return 3
            elseif pos >= 2 and text:byte(pos - 2) >= 192 then return 2
            end
        end
        return 1
    end

    -- Handle Caps Lock toggle
    handleCapsLockToggle()
    local ctrlCommandExecuted = false
    
    -- History navigation with up/down arrows
    if input.IsButtonPressed(KEY_UP) and not LastKeyState[KEY_UP] then
        if ChatUI.inputHistoryIndex < #ChatUI.inputHistory then
            ChatUI.inputHistoryIndex = ChatUI.inputHistoryIndex + 1
            ChatConfig.inputBuffer = ChatUI.inputHistory[ChatUI.inputHistoryIndex]
            if ChatConfig.onlineChat and ChatConfig.inputBuffer:sub(1,1) ~= "/" then
                ChatConfig.inputBuffer = "/" .. ChatConfig.inputBuffer
            end
            ChatUI.cursorPosition = #ChatConfig.inputBuffer
            clearUndoRedoStacks()
        end
        LastKeyState[KEY_UP] = true
    elseif input.IsButtonPressed(KEY_DOWN) and not LastKeyState[KEY_DOWN] then
        if ChatUI.inputHistoryIndex > 0 then
            ChatUI.inputHistoryIndex = ChatUI.inputHistoryIndex - 1
            if ChatUI.inputHistoryIndex == 0 then
                ChatConfig.inputBuffer = ChatConfig.onlineChat and "/" or ""
            else
                ChatConfig.inputBuffer = ChatUI.inputHistory[ChatUI.inputHistoryIndex]
                if ChatConfig.onlineChat and ChatConfig.inputBuffer:sub(1,1) ~= "/" then
                    ChatConfig.inputBuffer = "/" .. ChatConfig.inputBuffer
                end
            end
            ChatUI.cursorPosition = #ChatConfig.inputBuffer
            clearUndoRedoStacks()
        end
        LastKeyState[KEY_DOWN] = true
    else
        LastKeyState[KEY_UP] = input.IsButtonDown(KEY_UP)
        LastKeyState[KEY_DOWN] = input.IsButtonDown(KEY_DOWN)
    end

    -- Handle cursor movement
    local isCtrlHeld = isCtrlPressed()

    if isCtrlHeld then
        local currentTime = globals.RealTime()
        
        -- Word navigation with prefix protection
        if input.IsButtonPressed(KEY_LEFT) and not LastKeyState[KEY_LEFT] and 
        (currentTime - (ChatUI.lastCtrlArrowTime or 0) >= ChatUI.CTRL_ARROW_DELAY) then
            
            ChatUI.lastCtrlArrowTime = currentTime
            local pos = ChatUI.cursorPosition
            local minPos = ChatConfig.onlineChat and 1 or 0
            
            -- Skip any whitespace before cursor
            while pos > minPos and ChatConfig.inputBuffer:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            -- Skip to start of current/previous word
            while pos > minPos and not ChatConfig.inputBuffer:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            -- Skip any trailing whitespace
            while pos > minPos and ChatConfig.inputBuffer:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            ChatUI.cursorPosition = pos
            ChatUI.selectionStart = nil
            ChatUI.selectionEnd = nil
            
        elseif input.IsButtonPressed(KEY_RIGHT) and not LastKeyState[KEY_RIGHT] and
            (currentTime - (ChatUI.lastCtrlArrowTime or 0) >= ChatUI.CTRL_ARROW_DELAY) then
            
            ChatUI.lastCtrlArrowTime = currentTime
            local pos = ChatUI.cursorPosition
            
            -- Skip any whitespace after cursor
            while pos < #ChatConfig.inputBuffer and ChatConfig.inputBuffer:sub(pos + 1, pos + 1):match("%s") do
                pos = pos + 1
            end
            
            -- Skip to end of current/next word
            while pos < #ChatConfig.inputBuffer and not ChatConfig.inputBuffer:sub(pos + 1, pos + 1):match("%s") do
                pos = pos + 1
            end
            
            ChatUI.cursorPosition = pos
            ChatUI.selectionStart = nil
            ChatUI.selectionEnd = nil
        end
    else
        -- Regular character navigation with prefix protection
        if input.IsButtonDown(KEY_LEFT) then
            if not LastKeyState[KEY_LEFT] then
                local minPos = ChatConfig.onlineChat and 1 or 0
                ChatUI.cursorPosition = math.max(minPos, ChatUI.cursorPosition - 1)
                ChatUI.LastArrowPressTime = currentTime
                LastKeyPressTime = currentTime
            else
                local timeHeld = currentTime - ChatUI.LastArrowPressTime
                if timeHeld > ChatUI.ARROW_KEY_DELAY then
                    if currentTime - LastKeyPressTime >= ChatUI.ARROW_REPEAT_RATE then
                        local minPos = ChatConfig.onlineChat and 1 or 0
                        ChatUI.cursorPosition = math.max(minPos, ChatUI.cursorPosition - 1)
                        LastKeyPressTime = currentTime
                    end
                end
            end
            ChatUI.selectionStart = nil
            ChatUI.selectionEnd = nil
        elseif input.IsButtonDown(KEY_RIGHT) then
            if not LastKeyState[KEY_RIGHT] then
                ChatUI.cursorPosition = math.min(#ChatConfig.inputBuffer, ChatUI.cursorPosition + 1)
                ChatUI.LastArrowPressTime = currentTime
                LastKeyPressTime = currentTime
            else
                local timeHeld = currentTime - ChatUI.LastArrowPressTime
                if timeHeld > ChatUI.ARROW_KEY_DELAY then
                    if currentTime - LastKeyPressTime >= ChatUI.ARROW_REPEAT_RATE then
                        ChatUI.cursorPosition = math.min(#ChatConfig.inputBuffer, ChatUI.cursorPosition + 1)
                        LastKeyPressTime = currentTime
                    end
                end
            end
            ChatUI.selectionStart = nil
            ChatUI.selectionEnd = nil
        else
            ChatUI.LastArrowPressTime = 0
        end
    end

    -- Update LastKeyState for arrow keys
    LastKeyState[KEY_LEFT] = input.IsButtonDown(KEY_LEFT)
    LastKeyState[KEY_RIGHT] = input.IsButtonDown(KEY_RIGHT)

    -- Handle clipboard operations
    if isCtrlHeld then
        -- Handle ctrl+z (undo)
        if input.IsButtonPressed(KEY_Z) and not LastKeyState[KEY_Z] then
            performUndo()
            ctrlCommandExecuted = true
        end
        
        -- Handle ctrl+y (redo)
        if input.IsButtonPressed(KEY_Y) and not LastKeyState[KEY_Y] then
            performRedo()
            ctrlCommandExecuted = true
        end

        -- Handle ctrl+a (select all) with prefix protection
        if input.IsButtonDown(KEY_A) and not LastKeyState[KEY_A] then
            if ChatConfig.onlineChat then
                ChatUI.selectionStart = 1
                ChatUI.selectionEnd = #ChatConfig.inputBuffer
                ChatUI.cursorPosition = 1
            else
                ChatUI.selectionStart = 0
                ChatUI.selectionEnd = #ChatConfig.inputBuffer
                ChatUI.cursorPosition = 0
            end
            LastKeyState[KEY_A] = true
            ctrlCommandExecuted = true
        end

        -- Handle ctrl+x (cut) with prefix protection
        if input.IsButtonDown(KEY_X) and not LastKeyState[KEY_X] then
            if ChatUI.selectionStart and ChatUI.selectionEnd then
                local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
                local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
                
                -- Protect prefix in online chat
                if ChatConfig.onlineChat and start == 0 then
                    start = 1
                end
                
                -- Store cut text in clipboard
                ChatUI.clipboard = ChatConfig.inputBuffer:sub(start + 1, finish)
                
                -- Save state before modification
                local snapshot = createStateSnapshot()
                table.insert(UndoStack.undoStack, snapshot)
                UndoStack.redoStack = {}
                
                -- Perform cut with prefix protection
                if ChatConfig.onlineChat then
                    ChatConfig.inputBuffer = "/" .. ChatConfig.inputBuffer:sub(finish + 1)
                    ChatUI.cursorPosition = 1
                else
                    ChatConfig.inputBuffer = ChatConfig.inputBuffer:sub(1, start) ..
                                        ChatConfig.inputBuffer:sub(finish + 1)
                    ChatUI.cursorPosition = start
                end
                ChatUI.selectionStart = nil
                ChatUI.selectionEnd = nil
            end
            LastKeyState[KEY_X] = true
            ctrlCommandExecuted = true
        end

        -- Handle ctrl+c (copy)
        if input.IsButtonDown(KEY_C) and not LastKeyState[KEY_C] then
            if ChatUI.selectionStart and ChatUI.selectionEnd then
                local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
                local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
                if ChatConfig.onlineChat and start == 0 then
                    start = 1
                end
                ChatUI.clipboard = ChatConfig.inputBuffer:sub(start + 1, finish)
            end
            LastKeyState[KEY_C] = true
            ctrlCommandExecuted = true
        end

        -- Handle ctrl+v (paste)
        if input.IsButtonDown(KEY_V) and not LastKeyState[KEY_V] then
            if ChatUI.clipboard and ChatUI.clipboard ~= "" then
                if ChatUI.selectionStart and ChatUI.selectionEnd then
                    local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
                    local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
                    
                    if ChatConfig.onlineChat and start == 0 then
                        start = 1
                    end
                    
                    local before = ChatConfig.inputBuffer:sub(1, start)
                    local after = ChatConfig.inputBuffer:sub(finish + 1)

                    if #before + #ChatUI.clipboard + #after <= MESSAGE_MAX_LENGTH then
                        ChatConfig.inputBuffer = before .. ChatUI.clipboard .. after
                        ChatUI.cursorPosition = start + #ChatUI.clipboard
                    end
                else
                    local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition)
                    local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)
                
                    if #before + #ChatUI.clipboard + #after <= MESSAGE_MAX_LENGTH then
                        ChatConfig.inputBuffer = before .. ChatUI.clipboard .. after
                        ChatUI.cursorPosition = ChatUI.cursorPosition + #ChatUI.clipboard
                        handleCharacterInput()
                    end
                end
                ChatUI.selectionStart = nil
                ChatUI.selectionEnd = nil
            end
            LastKeyState[KEY_V] = true
            ctrlCommandExecuted = true
        end
    end

    -- Regular character input
    local shiftPressed = input.IsButtonDown(KEY_LSHIFT) or input.IsButtonDown(KEY_RSHIFT)

    for key, chars in pairs(InputMap) do
        if input.IsButtonDown(key) and not LastKeyState[key] then
            if ctrlCommandExecuted and (key == KEY_Z or key == KEY_Y or Key == KEY_X or key == KEY_C or key == KEY_V or key == KEY_A) then
                goto continue
            end

            local nextChar
            if chars.normal:match("%a") then
                local useUpperCase = (capsLockEnabled and not shiftPressed) or (not capsLockEnabled and shiftPressed)
                nextChar = useUpperCase and chars.shift or chars.normal
            else
                nextChar = shiftPressed and chars.shift or chars.normal
            end

            if ChatUI.selectionStart and ChatUI.selectionEnd then
                local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
                local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
                
                if ChatConfig.onlineChat and start == 0 then
                    start = 1
                end
                
                local before = ChatConfig.inputBuffer:sub(1, start)
                local after = ChatConfig.inputBuffer:sub(finish + 1)

                if (#before + #nextChar + #after) <= MESSAGE_MAX_LENGTH then
                    ChatConfig.inputBuffer = before .. nextChar .. after
                    ChatUI.cursorPosition = start + #nextChar
                end
                ChatUI.selectionStart = nil
                ChatUI.selectionEnd = nil
            else
                local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition)
                local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)

                if (#before + #nextChar + #after) <= MESSAGE_MAX_LENGTH then
                    ChatConfig.inputBuffer = before .. nextChar .. after
                    ChatUI.cursorPosition = ChatUI.cursorPosition + #nextChar
                
                    if isWordBoundary(nextChar) then
                        if UndoStack.isTyping then
                            UndoStack.isTyping = false
                            if #UndoStack.lastWord > 0 then
                                local snapshot = createStateSnapshot()
                                table.insert(UndoStack.undoStack, snapshot)
                                UndoStack.lastWord = ""
                            end
                        end
                    else
                        handleCharacterInput()
                    end
                end
            end
            ::continue::
        end
        LastKeyState[key] = input.IsButtonDown(key)
    end

    -- Handle backspace with prefix protection
    if input.IsButtonDown(KEY_BACKSPACE) then
        if ChatUI.selectionStart and ChatUI.selectionEnd then
            local start = math.min(ChatUI.selectionStart, ChatUI.selectionEnd)
            local finish = math.max(ChatUI.selectionStart, ChatUI.selectionEnd)
            
            if ChatConfig.onlineChat then
                if start == 0 then start = 1 end
                if #ChatConfig.inputBuffer > 1 then
                    ChatConfig.inputBuffer = ChatConfig.inputBuffer:sub(1, start) ..
                                        ChatConfig.inputBuffer:sub(finish + 1)
                end
            else
                ChatConfig.inputBuffer = ChatConfig.inputBuffer:sub(1, start) ..
                                    ChatConfig.inputBuffer:sub(finish + 1)
            end
            ChatUI.cursorPosition = start
            ChatUI.selectionStart = nil
            ChatUI.selectionEnd = nil
        elseif ChatUI.cursorPosition > 0 then
            if not LastKeyState[KEY_BACKSPACE] then
                -- For online chat, prevent deleting the starting slash
                if ChatConfig.onlineChat then
                    if ChatUI.cursorPosition > 1 then
                        local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition - 1)
                        local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)
                        ChatConfig.inputBuffer = before .. after
                        ChatUI.cursorPosition = ChatUI.cursorPosition - 1
                        handleCharacterInput()
                    end
                else
                    if ChatUI.cursorPosition > 0 then
                        local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition - 1)
                        local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)
                        ChatConfig.inputBuffer = before .. after
                        ChatUI.cursorPosition = ChatUI.cursorPosition - 1
                        handleCharacterInput()
                    end
                end
                BackspaceStartTime = currentTime
            else
                local timeSinceStart = currentTime - BackspaceStartTime
                if timeSinceStart > BACKSPACE_DELAY then
                    if currentTime - LastKeyPressTime >= BACKSPACE_REPEAT_RATE then
                        if ChatConfig.onlineChat then
                            if ChatUI.cursorPosition > 1 then
                                local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition - 1)
                                local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)
                                ChatConfig.inputBuffer = before .. after
                                ChatUI.cursorPosition = ChatUI.cursorPosition - 1
                                handleCharacterInput()
                            end
                        else
                            if ChatUI.cursorPosition > 0 then
                                local before = ChatConfig.inputBuffer:sub(1, ChatUI.cursorPosition - 1)
                                local after = ChatConfig.inputBuffer:sub(ChatUI.cursorPosition + 1)
                                ChatConfig.inputBuffer = before .. after
                                ChatUI.cursorPosition = ChatUI.cursorPosition - 1
                                handleCharacterInput()
                            end
                        end
                        LastKeyPressTime = currentTime
                    end
                end
            end
        end
        LastKeyState[KEY_BACKSPACE] = true
    else
        LastKeyState[KEY_BACKSPACE] = false
        BackspaceStartTime = 0
    end

    -- Update remaining key states
    if not isCtrlHeld then
        LastKeyState[KEY_Z] = input.IsButtonDown(KEY_Z)
        LastKeyState[KEY_Y] = input.IsButtonDown(KEY_Y)
        LastKeyState[KEY_A] = input.IsButtonDown(KEY_A)
        LastKeyState[KEY_X] = input.IsButtonDown(KEY_X)
        LastKeyState[KEY_C] = input.IsButtonDown(KEY_C)
        LastKeyState[KEY_V] = input.IsButtonDown(KEY_V)
    end

    return ChatConfig
end

-- Modified handleChatInput function
local function handleChatInput(cmd)
    if not ChatConfig.enabled then
        return
    end
    -- Check if chat was just closed this frame
    if ChatConfig.inputActive and (
        (input.IsButtonPressed(KEY_ENTER) and not LastKeyState[KEY_ENTER]) or 
        (input.IsButtonPressed(KEY_ESCAPE) and not LastKeyState[KEY_ESCAPE])
    ) then
        -- Handle chat closing with Enter
        if input.IsButtonPressed(KEY_ENTER) and ChatConfig.inputBuffer ~= "" then
            -- Add to history before sending
            addToHistory(ChatConfig.inputBuffer)
            if ChatConfig.enabled then
                -- Check if this is a command (starts with /)
                if ChatConfig.inputBuffer:sub(1,1) == "/" then
                    -- Get command and args
                    local message = ChatConfig.inputBuffer:sub(2)  -- Remove leading slash
                    
                    if message == "" then
                        chatMessage("Please enter a message or command after the /")
                    else
                        -- Get first word to check if it's a command
                        local firstWord = message:match("^(%S+)")
                        if VALID_COMMANDS[firstWord] then
                            -- It's a command, handle it normally
                            local args = {}
                            for arg in message:sub(#firstWord + 2):gmatch("%S+") do
                                table.insert(args, arg)
                            end
                            handleCommand(firstWord, args)
                        else
                            -- Not a command, send as chat message with full content
                            handleCommand(message, {}, true)
                        end
                    end
                else
                    -- Not a command, send as regular chat message
                    if ChatConfig.partyChat then
                        client.Command('tf_party_chat "' .. ChatConfig.inputBuffer .. '"', true)
                    elseif ChatConfig.teamChat then
                        client.ChatTeamSay(ChatConfig.inputBuffer)
                    else
                        client.ChatSay(ChatConfig.inputBuffer)
                    end
                end
            else
                -- Custom chat is disabled, just send the message normally
                if ChatConfig.teamChat then
                    client.ChatTeamSay(ChatConfig.inputBuffer)
                else
                    client.ChatSay(ChatConfig.inputBuffer)
                end
            end
        end

        clearUndoRedoStacks()

        resetAllKeyStates()
        KeyRepeatState.LastPressedKey = nil
        
        -- Release view lock
        releaseViewLock()
        
        -- Re-enable game UI escape handler
        client.Command("gameui_allowescapetoshow", true)
        
        -- Clear chat state
        ChatConfig.inputActive = false
        ChatConfig.teamChat = false
        ChatConfig.partyChat = false
        ChatConfig.onlineChat = false
        ChatConfig.inputBuffer = ""
        
        -- Restore previous mouse state
        input.SetMouseInputEnabled(mousePrevEnabled)
        
        -- Update key states
        LastKeyState[KEY_ENTER] = input.IsButtonDown(KEY_ENTER)
        LastKeyState[KEY_ESCAPE] = input.IsButtonDown(KEY_ESCAPE)
        
        return
    end
    
    -- Update key states
    LastKeyState[KEY_ENTER] = input.IsButtonDown(KEY_ENTER)
    LastKeyState[KEY_ESCAPE] = input.IsButtonDown(KEY_ESCAPE)
    
    -- If chat isn't active, don't modify movement
    if not ChatConfig.inputActive then
        return
    end
    
    -- Block movement while chat is active
    cmd.forwardmove = 0
    cmd.sidemove = 0
    cmd.upmove = 0
    cmd.buttons = 0
    
    -- Handle all input
    ChatConfig = handleInput(ChatConfig, globals.RealTime())
end

-- Modified CreateMove callback to ensure proper key repeat state
callbacks.Register("CreateMove", "chat_input", function(cmd)
    -- If chat was just opened, reset all key states
    if ChatConfig.inputActive and not ChatConfig.wasActive then
        resetAllKeyStates()
        ChatConfig.wasActive = true
    elseif not ChatConfig.inputActive then
        ChatConfig.wasActive = false
    end
    
    -- Apply view lock first if active
    if ChatConfig.inputActive and not engine.IsGameUIVisible() then
        updateLockedView(cmd)  -- Single firm lock, no deviation checking
    end

    -- Check if we're in main menu and chat is active
    if engine.IsGameUIVisible() and ChatConfig.inputActive then
        ChatConfig.inputActive = false
        ChatConfig.teamChat = false
        ChatConfig.partyChat = false
        ChatConfig.onlineChat = false
        ChatConfig.inputBuffer = ""
        releaseViewLock()
        client.Command("gameui_allowescapetoshow", true)
        input.SetMouseInputEnabled(mousePrevEnabled)
        return
    end
    
    -- Only open chat if it's not already active
    if not ChatConfig.inputActive then
        if input.IsButtonPressed(DEFAULT_CHAT_KEY) and (globals.RealTime() - lastChatOpenTime) > CHAT_OPEN_COOLDOWN then
            initViewLock()
            ChatConfig.inputActive = true
            ChatConfig.teamChat = false
            ChatConfig.partyChat = false
            ChatConfig.onlineChat = false
            ChatConfig.inputBuffer = ""
            ChatUI.cursorPosition = 0  -- Reset cursor position
            ChatUI.selectionStart = nil  -- Clear any existing selection
            ChatUI.selectionEnd = nil
            lastChatOpenTime = globals.RealTime()
            mousePrevEnabled = input.IsMouseInputEnabled()
            input.SetMouseInputEnabled(false)
            
            -- Force the chat open key to be marked as already processed
            LastKeyState[DEFAULT_CHAT_KEY] = true
            
            -- Reset other key states properly
            for k in pairs(LastKeyState) do
                if k ~= DEFAULT_CHAT_KEY then
                    LastKeyState[k] = input.IsButtonDown(k)
                end
            end
            
            client.Command("gameui_preventescapetoshow", true)
            return
        elseif input.IsButtonPressed(DEFAULT_TEAM_CHAT_KEY) and (globals.RealTime() - lastChatOpenTime) > CHAT_OPEN_COOLDOWN then
            initViewLock()
            ChatConfig.inputActive = true
            ChatConfig.teamChat = true
            ChatConfig.partyChat = false
            ChatConfig.onlineChat = false
            ChatConfig.inputBuffer = ""
            ChatUI.cursorPosition = 0  -- Reset cursor position
            ChatUI.selectionStart = nil  -- Clear any existing selection
            ChatUI.selectionEnd = nil
            lastChatOpenTime = globals.RealTime()
            mousePrevEnabled = input.IsMouseInputEnabled()
            input.SetMouseInputEnabled(false)
            
            -- Force the team chat key to be marked as already processed
            LastKeyState[DEFAULT_TEAM_CHAT_KEY] = true
            
            -- Reset other key states properly
            for k in pairs(LastKeyState) do
                if k ~= DEFAULT_TEAM_CHAT_KEY then
                    LastKeyState[k] = input.IsButtonDown(k)
                end
            end
            
            client.Command("gameui_preventescapetoshow", true)
            return
        elseif input.IsButtonPressed(DEFAULT_PARTY_CHAT_KEY) and (globals.RealTime() - lastChatOpenTime) > CHAT_OPEN_COOLDOWN then
            initViewLock()
            ChatConfig.inputActive = true
            ChatConfig.teamChat = false
            ChatConfig.partyChat = true
            ChatConfig.onlineChat = false
            ChatConfig.inputBuffer = ""
            ChatUI.cursorPosition = 0  -- Reset cursor position
            ChatUI.selectionStart = nil  -- Clear any existing selection
            ChatUI.selectionEnd = nil
            lastChatOpenTime = globals.RealTime()
            mousePrevEnabled = input.IsMouseInputEnabled()
            input.SetMouseInputEnabled(false)
            
            -- Force the party chat key to be marked as already processed
            LastKeyState[DEFAULT_PARTY_CHAT_KEY] = true
            
            -- Reset other key states properly
            for k in pairs(LastKeyState) do
                if k ~= DEFAULT_PARTY_CHAT_KEY then
                    LastKeyState[k] = input.IsButtonDown(k)
                end
            end
            
            client.Command("gameui_preventescapetoshow", true)
            return
        elseif input.IsButtonPressed(DEFAULT_ONLINE_CHAT_KEY) and (globals.RealTime() - lastChatOpenTime) > CHAT_OPEN_COOLDOWN then
            initViewLock()
            ChatConfig.inputActive = true
            ChatConfig.teamChat = false
            ChatConfig.partyChat = false
            ChatConfig.onlineChat = true
            ChatConfig.inputBuffer = "/"  -- Initialize with forward slash for online chat
            ChatUI.cursorPosition = #ChatConfig.inputBuffer  -- Place cursor after the slash
            ChatUI.selectionStart = nil  -- Clear any existing selection
            ChatUI.selectionEnd = nil
            lastChatOpenTime = globals.RealTime()
            mousePrevEnabled = input.IsMouseInputEnabled()
            input.SetMouseInputEnabled(false)
            
            -- Force the online chat key to be marked as already processed
            LastKeyState[DEFAULT_ONLINE_CHAT_KEY] = true
            
            -- Reset other key states properly
            for k in pairs(LastKeyState) do
                if k ~= DEFAULT_ONLINE_CHAT_KEY then
                    LastKeyState[k] = input.IsButtonDown(k)
                end
            end
            
            client.Command("gameui_preventescapetoshow", true)
            return
        end
    end

    -- If chat is active, handle input
    if ChatConfig.inputActive then
        if (globals.RealTime() - lastChatOpenTime) > 0.25 then  -- Increased delay to 250ms
            handleChatInput(cmd)
        end
    end
end)

local function fetchAndDisplayMOTD(username, password)
    local response = makeRequest("motd", {
        u = username,
        p = password
    })
    
    if response and response ~= "NO_MOTD" and response ~= "AUTH_ERROR" and response ~= "ERROR" then
        -- Display MOTD
        chatMessage(response)
    end
end

-- Move all initialization code here
local function initializeChat()
    -- Check if we can access required game functions
    if not entities or not entities.GetLocalPlayer then
        return false
    end
    
    -- Only initialize if we're in a game
    if not entities.GetLocalPlayer() then
        return false
    end
    
    -- Initialize VGUI
    ChatVGUI.parseConfig()
    
    -- Initialize font
    ChatUI.font = draw.CreateFont("Verdana", 18, 400, FONTFLAG_ANTIALIAS)
    
    -- Initialize emoji system
    initializeEmojis()
    validateEmojiSystem()
    
    -- Check version
    checkVersion()
    chatMessage(versionStatus)
    
    -- Load config and handle login
    loadConfig()
    if firstTimeUser then
        chatMessage("\\x0AWelcome to chat!")
        chatMessage("Use \\x02/register\\x01 or \\x02/r\\x01 <password> to create an account")
    elseif username and password then
        -- Attempt auto-login
        local response = makeRequest("get", {
            u = username,
            p = password
        })
        
        if response and response ~= "AUTH_ERROR" then
            authenticated = true
            
            local listResponse = makeRequest("list", {
                u = username,
                p = password
            })
            
            local userCount = "0"
            if listResponse and listResponse ~= "NO_USERS" then
                userCount = listResponse:match("^(%d+)")
            end
            chatMessage("\\x01Welcome back " .. username .. "! (" .. "\\x03" .. userCount .. "\\x01 users online)")
            
            -- Fetch and display MOTD if available
            fetchAndDisplayMOTD(username, password)
            
            if not nickname then
                chatMessage("Use \\x02/nick\\x01 or \\x02/n\\x01 <nickname> to set your nickname")
            else
                chatMessage("You're all set! Start chatting with /<message>")
                chatMessage("Use /users or /u to see who's online")
            end
        else
            chatMessage("Previous login expired. Please login again with /login <password>")
        end
    else
        chatMessage("Please login with /login <password>")
    end
    
    -- Update chat visibility
    updateChatVisibility()
    
    InitState.initialized = true
    return true
end

-- Add initialization check to Draw callback
local function checkInitialization()
    if InitState.initialized then return true end
    
    local currentTime = globals.RealTime()
    if currentTime - InitState.lastCheckTime < InitState.checkInterval then
        return false
    end
    
    InitState.lastCheckTime = currentTime
    InitState.initAttempts = InitState.initAttempts + 1
    
    if InitState.initAttempts > InitState.maxAttempts then
        print("[Chat] Failed to initialize after " .. InitState.maxAttempts .. " attempts")
        return false
    end
    
    return initializeChat()
end

-- Modify the Draw callback to use safe initialization
callbacks.Register("Draw", function()
    -- Check initialization first
    if not checkInitialization() then
        return
    end
    
    -- Rest of the draw code...
    checkWordCompletion()
    
    local now = globals.RealTime()
    if now - lastFetch >= 2 then
        lastFetch = now
        fetchMessages()
    end
    
    if not ChatConfig.enabled or engine.Con_IsVisible() or engine.IsGameUIVisible() then 
        return 
    end
    
    ChatVGUI.drawChat(ChatConfig, ChatUI)
end)

-- Main unload callback
callbacks.Register("Unload", function()
    -- 1. Clean up emoji textures
    for shortcode, data in pairs(EmojiSystem.textures) do
        if data.texture then
            draw.DeleteTexture(data.texture)
        end
    end
    EmojiSystem.textures = {}
    EmojiSystem.initialized = false

    -- 2. Reset chat configuration
    ChatConfig.enabled = false
    ChatConfig.inputActive = false
    ChatConfig.inputBuffer = ""
    ChatConfig.teamChat = false
    ChatConfig.partyChat = false
    ChatConfig.onlineChat = false

    -- 3. Reset chat UI state
    ChatUI.chatHistory = {}
    ChatUI.inputHistory = {}
    ChatUI.inputHistoryIndex = 0
    ChatUI.clipboard = ""
    ChatUI.cursorPosition = 0
    ChatUI.selectionStart = nil
    ChatUI.selectionEnd = nil
    ChatUI.scrollOffset = 0
    ChatUI.lastScrollTime = 0

    -- 4. Clear undo/redo stacks
    UndoStack.undoStack = {}
    UndoStack.redoStack = {}
    UndoStack.lastSavedState = nil
    UndoStack.currentWord = ""
    UndoStack.isTyping = false

    -- 5. Reset view lock state
    if ViewLockState.isLocked then
        releaseViewLock()
    end

    -- 6. Reset key states
    for key in pairs(LastKeyState) do
        LastKeyState[key] = false
    end
    KeyRepeatState.pressStartTimes = {}
    KeyRepeatState.lastRepeatTimes = {}
    KeyRepeatState.isRepeating = {}
    KeyRepeatState.LastPressedKey = nil

    -- 7. Restore game settings
    client.Command("cl_enable_text_chat " .. defaultTextChat)
    client.Command("hud_saytext_time " .. defaultSayTime)
    client.Command("gameui_allowescapetoshow", true)

    -- 8. Restore mouse state
    if mousePrevEnabled ~= nil then
        input.SetMouseInputEnabled(mousePrevEnabled)
        mousePrevEnabled = nil
    end

    -- 9. Save current configuration
    saveConfig()

    -- 10. Unregister all chat-related callbacks
    callbacks.Unregister("Draw", "chat_draw")
    callbacks.Unregister("CreateMove", "chat_input")
    callbacks.Unregister("FireGameEvent", "chat_player_connect")
    callbacks.Unregister("FireGameEvent", "class_change_handler")
    callbacks.Unregister("SendStringCmd", "chat_commands")
    callbacks.Unregister("RenderView", "chat_view_lock")
    callbacks.Unregister("DispatchUserMessage", "ChatHandler")
    callbacks.Unregister("DispatchUserMessage", "voice_message_handler")

    -- 11. Clear message history and authentication state
    messageHistory = {}
    authenticated = false
    username = nil
    password = nil
    nickname = nil
    lastFetch = 0
    lastMessage = nil
    lastMessageTime = 0

    -- 12. Clean up VGUI state
    ChatVGUI.config = nil
    ChatVGUI.baseChatPath = nil

    print("Chat client successfully unloaded and cleaned up")
end)
