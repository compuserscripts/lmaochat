-- Token types enumeration
local TokenType = {
    LeftBrace = 1,
    RightBrace = 2,
    Flag = 3,
    String = 4,
    Name = 5
}

-- Token class
local Token = {}
Token.__index = Token

function Token.new(type, value)
    return setmetatable({
        type = type,
        value = value
    }, Token)
end

-- VguiObject class
local VguiObject = {}
VguiObject.__index = VguiObject

function VguiObject.new(name, value)
    local self = setmetatable({
        name = name,
        value = value,
        properties = {},
        _properties = {},
        flags = {}
    }, VguiObject)
    return self
end

function VguiObject:isValue()
    return self.value ~= nil
end

function VguiObject:get(name)
    return self.properties[name]
end

function VguiObject:getNameFlagKey()
    local flags = {}
    for k, v in pairs(self.flags) do
        flags[k] = v
    end
    return {name = self.name, flags = flags}
end

function VguiObject:compareFlags(other)
    for k, v in pairs(self.flags) do
        if other.flags[k] ~= v then
            return false
        end
    end
    return true
end

function VguiObject:mergeOrAddProperty(other)
    local key = other:getNameFlagKey()
    local existing = self._properties[key.name]
    
    if existing and not existing:isValue() and not other:isValue() then
        existing:tryMerge(other)
    else
        self._properties[key.name] = other
        self.properties[other.name] = other
    end
end

function VguiObject:tryMerge(other)
    if other.name ~= self.name or not self:compareFlags(other) or self:isValue() or other:isValue() then
        return false
    end
    
    for _, prop in pairs(other.properties) do
        self:mergeOrAddProperty(prop)
    end
    return true
end

-- Lexer class
local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(input)
    return setmetatable({
        input = input,
        index = 1,
        length = #input
    }, Lexer)
end

function Lexer:peek(n)
    n = n or 1
    local pos = self.index + n - 1
    if pos <= self.length then
        return self.input:sub(pos, pos)
    end
    return nil
end

function Lexer:advance(n)
    n = n or 1
    self.index = self.index + n
end

function Lexer:skipWhitespace()
    while self:peek() and string.match(self:peek(), "%s") do
        self:advance()
    end
end

function Lexer:skipLine()
    while self:peek() and self:peek() ~= "\n" and self:peek() ~= "\r" do
        self:advance()
    end
    while self:peek() and (self:peek() == "\n" or self:peek() == "\r") do
        self:advance()
    end
end

function Lexer:getStringToken()
    local str = ""
    while self:peek() and self:peek() ~= '"' do
        str = str .. self:peek()
        self:advance()
    end
    self:advance() -- consume closing quote
    return Token.new(TokenType.String, str)
end

function Lexer:getNameToken()
    local name = ""
    while self:peek() and string.match(self:peek(), "[%w]") do
        name = name .. self:peek()
        self:advance()
    end
    return Token.new(TokenType.Name, name)
end

function Lexer:getFlagToken()
    local flag = ""
    while self:peek() and self:peek() ~= "]" do
        flag = flag .. self:peek()
        self:advance()
    end
    self:advance() -- consume closing bracket
    return Token.new(TokenType.Flag, flag)
end

function Lexer:getTokens()
    local tokens = {}
    
    while self:peek() do
        self:skipWhitespace()
        
        -- Skip comments
        if self:peek() == "/" and self:peek(2) == "/" then
            self:skipLine()
            goto continue
        end
        
        -- Skip preprocessor directives
        if self:peek() == "#" then
            self:skipLine()
            goto continue
        end
        
        if self:peek() == '"' then
            self:advance()
            table.insert(tokens, self:getStringToken())
        elseif string.match(self:peek(), "[%w]") then
            table.insert(tokens, self:getNameToken())
        elseif self:peek() == "[" then
            self:advance()
            table.insert(tokens, self:getFlagToken())
        elseif self:peek() == "{" then
            table.insert(tokens, Token.new(TokenType.LeftBrace, "{"))
            self:advance()
        elseif self:peek() == "}" then
            table.insert(tokens, Token.new(TokenType.RightBrace, "}"))
            self:advance()
        else
            self:advance()
        end
        
        ::continue::
    end
    
    return tokens
end

-- Parser class 
local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
    return setmetatable({
        tokens = tokens,
        index = 1
    }, Parser)
end

function Parser:peek(n)
    n = n or 1
    return self.tokens[self.index + n - 1]
end

function Parser:eat(expectedType)
    local token = self:peek()
    if not token or token.type ~= expectedType then
        error(string.format("Expected %s but got %s", expectedType, token and token.type or "nil"))
    end
    self.index = self.index + 1
    return token
end

function Parser:parseValue()
    local name = self:eat(TokenType.String)
    
    if self:peek() and self:peek().type == TokenType.LeftBrace then
        self:eat(TokenType.LeftBrace)
        local values = self:parseValueList()
        self:eat(TokenType.RightBrace)
        return {
            name = name,
            string = nil,
            body = { values = values }
        }
    end
    
    return {
        name = name,
        string = self:eat(TokenType.String),
        body = nil
    }
end

function Parser:parseValueList()
    local values = {}
    while self:peek() and (self:peek().type == TokenType.String or self:peek().type == TokenType.Name) do
        table.insert(values, self:parseValue())
    end
    return values
end

function Parser:parseRoot()
    return {
        name = Token.new(TokenType.Name, "Root"),
        string = nil,
        body = { values = self:parseValueList() }
    }
end

-- Preprocessor class
local Preprocessor = {}
Preprocessor.__index = Preprocessor

function Preprocessor.new(sourceProvider)
    return setmetatable({
        sourceProvider = sourceProvider
    }, Preprocessor)
end

function Preprocessor:process(file)
    local lines = self.sourceProvider:readAllLines(file)
    local result = {}
    
    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed:sub(1, 6) == "#base " then
            local baseFile = trimmed:sub(7):match('"(.+)"')
            local preprocessor = Preprocessor.new(self.sourceProvider)
            local processed = preprocessor:process(baseFile)
            for _, processedLine in ipairs(processed) do
                table.insert(result, processedLine)
            end
        else
            table.insert(result, line)
        end
    end
    
    return result
end

-- VguiSerializer
local VguiSerializer = {}

function VguiSerializer.fromFile(rootPath, file)
    -- Create a source provider that uses Lmaobox's local filesystem API
    local sourceProvider = {
        readAllLines = function(self, filepath)
            local f = io.open(rootPath .. "/" .. filepath, "r")
            if not f then error("Could not open file: " .. filepath) end
            local lines = {}
            for line in f:lines() do
                table.insert(lines, line)
            end
            f:close()
            return lines
        end
    }
    
    local preprocessor = Preprocessor.new(sourceProvider)
    local processed = table.concat(preprocessor:process(file), "\n")
    local lexer = Lexer.new(processed)
    local tokens = lexer:getTokens()
    local parser = Parser.new(tokens)
    local root = parser:parseRoot()
    
    return VguiSerializer.fromValue(root)
end

function VguiSerializer.fromValue(value)
    if value.string then
        return VguiObject.new(value.name.value, value.string.value)
    end
    
    local obj = VguiObject.new(value.name.value)
    for _, subValue in ipairs(value.body.values) do
        obj:mergeOrAddProperty(VguiSerializer.fromValue(subValue))
    end
    
    return obj
end

-- Export the module
return {
    TokenType = TokenType,
    Token = Token,
    VguiObject = VguiObject,
    Lexer = Lexer,
    Parser = Parser,
    Preprocessor = Preprocessor,
    VguiSerializer = VguiSerializer
}