# lmaochat
Custom chat system for LMAOBOX (Lua 5.1)

Requires vgui.lua https://github.com/compuserscripts/Lua-VGUI-Parser/

### Online Chat System
Chat with other lmaobox users regardless of which tf2 server they're on:
- Anonymous simple registration with just a password (no email needed)
- Freely change your nickname when you wish
- See who's currently online and chatting
- Use color codes and emoji to style your messages
- Discord integration for reading lmaobox discord messages

Open chat and type /help to see available commands

### Custom Chat Interface
The client features a completely redesigned chat window
- Mirrors the size and location of your normal chatbox
- Rich text editing capabilities:
  - Text selection with Ctrl+A
  - Copy/cut/paste support with Ctrl+C/X/V
  - Undo/redo with Ctrl+Z/Y
  - Word-by-word navigation using Ctrl+Arrow keys
  - Message history navigation with Up/Down arrows
- Emoji shortcode support :)
- Optional timestamps for all messages
- Character counter for long messages
- Class change notifications
- Chat modes can be accessed through default hotkeys:
  - Y - Regular chat
  - U - Team chat
  - I - Party chat
  - O - Online chat

### Standard Chat
Online chat system also supports regular ingame chat
- Class change notifications
- Color code support for online chat and nicknames

Config is stored in chat.cfg file inside your game folder

To disable the custom chatbox and use normal chat

```-- Custom Chat Configuration
local ChatConfig = {
    enabled = true, <--- change this to false
    config = nil,
    inputActive = false,
    ...
```
