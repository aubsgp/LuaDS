-- OOP wrapper for slurped in data processing. Allows definition of some basic functions and removes the need to handle 1-indexing math.

local here = (...):match("(.-)[^%.]+$")
local Bitwise = require(here .. "Bitwise")
local Error = require(here .. "Error")
local Class = require(here .. "Class")

local Data = Class:extend()

function Data:new(bytes, start_offset, end_offset)
    if not bytes then
        Error("Data:new() requires bytes.")
    end

    start_offset = start_offset or 0
    end_offset = end_offset or #bytes
    if start_offset > end_offset or end_offset > #bytes then
        Error("Error in Data:new: start=%d, end=%d, #bytes=%d", start_offset, end_offset, #bytes)
    end

    return setmetatable({raw = bytes, start_offset = start_offset, end_offset = end_offset}, self)
end

function Data:blank(size)
    if not size then
        Error("Data:blank() requires a size.")
    end

    local t = {}
    for i = 1, size do
        t[i] = 0
    end
    return Data:new(t, 0, size)
end

function Data:slice(start_offset, end_offset)
    if start_offset > end_offset or end_offset > self.end_offset - self.start_offset then
        Error("Error in Data:slice: start=%d, end=%d, window size=%d", start_offset, end_offset, self.end_offset - self.start_offset)
    end

    return Data:new(self.raw, self.start_offset + start_offset, self.start_offset + end_offset)
end

function Data:access_check(addr, length)
    if (addr + length > self.end_offset - self.start_offset) then
        Error("Out-of-context error in Data handling: addr=%d, length=%d, window size=%d", addr, length, self.end_offset - self.start_offset)
    end
end

function Data:read(addr, length)
    self:access_check(addr, length)
    local ret = 0
    for i = length, 1, -1 do
        ret = ret * 0x100
        ret = ret + self.raw[self.start_offset + addr + i]
    end
    return ret
end
function Data:readbits(addr, bit_start, bit_end)
    local read_size = math.ceil(bit_end / 8)
    self:access_check(addr, read_size)
    local read = self:read(addr, read_size)
    read = read % (2 ^ bit_end)
    read = math.floor(read / (2 ^ bit_start))
    return read
end
function Data:readbyterange(addr, length) -- Length is number of bytes. Returns a 1-indexed table of the bytes in the range. Included more for completeness than any actual utility.    if (addr + length > self.end_offset - self.start_offset) then
    self:access_check(addr, length)
    return {unpack(self.raw, self.start_offset + addr + 1, self.start_offset + addr + length)} -- Deprecated in later versions of Lua, but Desmume stands for Dinosaur Emulator Smume, so we're on 5.1.
end

function Data:write(addr, length, val)
    self:access_check(addr, length)
    for i = 1, length do
        self.raw[self.start_offset + addr + i] = val % 0x100
        val = math.floor(val / 0x100)
    end
end
function Data:writebits(addr, bit_start, bit_end, value)
    local write_size = math.ceil(bit_end / 8)
    self:access_check(addr, write_size)
    local width = bit_end - bit_start

    local old = self:read(addr, write_size)
    local mask = ((2 ^ width) - 1) * (2 ^ bit_start)
    local cleared = old - Bitwise.band(old, mask)

    value = value % (2 ^ width)
    value = value * (2 ^ bit_start)
    self:write(addr, write_size, Bitwise.bor(cleared, value))
end
function Data:writebyterange(addr, byte_table)
    self:access_check(addr, #byte_table)
    for i, val in ipairs(byte_table) do
        self.raw[self.start_offset + addr + i] = val
    end
end

function Data.deep_copy(orig, memo)
    if type(orig) ~= "table" then 
        return orig
    end
    memo = memo or {}
    if memo[orig] then 
        return memo[orig] 
    end
    local copy = {}
    memo[orig] = copy
    for k, v in pairs(orig) do
        copy[Data.deep_copy(k, memo)] = Data.deep_copy(v, memo)
    end
    return setmetatable(copy, getmetatable(orig))
end

function Data.deep_compare(a, b, memo)
    if a == b then return true end
    if type(a) ~= type(b) or type(a) ~= "table" or getmetatable(a) ~= getmetatable(b) then 
        return false 
    end

    memo = memo or {}
    if memo[a] == b then 
        return true 
    end
    memo[a] = b

    for k, v in pairs(a) do
        if not Data.deep_compare(v, b[k], memo) then 
            return false 
        end
    end
    for k, v in pairs(b) do
        if a[k] == nil then 
            return false 
        end
    end

    return true
end

function Data:write_to_memory(addr, write_start, write_end)
    write_start = write_start or 0
    write_end = write_end or self.end_offset - self.start_offset
    local length = write_end - write_start
    local length_dwords = math.floor(length/4)
    for i = 1, length_dwords do
        local offset = (i-1)*4
        memory.writedword(addr + offset, self:read(write_start + offset, 4))
    end
    for i = length_dwords*4, length - 1 do
        memory.writebyte(addr + i, self:read(write_start + i, 1))
    end
    return true
end

return Data