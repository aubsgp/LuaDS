local Bitwise = {}

function Bitwise.base(a, b, condition, bits)
    assert((-2^53 < a and a < 2^53) and (-2^53 < b and b < 2^53), "WARNING: Bitwise operation on too-large values.")
    bits = bits or 0
    local ret = 0
    local bitval = 1
    while (a > 0 or b > 0 or bits > 0) do
        local a_bit = a % 2
        local b_bit = b % 2
        bits = bits - 1
        if condition(a_bit, b_bit) then
            ret = ret + bitval
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitval = bitval * 2
    end
    return ret
end

function Bitwise.band(a, b)
    return Bitwise.base(a, b, function(a_bit, b_bit) return a_bit == 1 and b_bit == 1 end)
end

function Bitwise.bnand(a, b, size)
    if not size then
        size = 32
    end
    return Bitwise.base(a, b, function(a_bit, b_bit) return a_bit == 0 or b_bit == 0 end, size)
end

function Bitwise.bor(a, b)
    return Bitwise.base(a, b, function(a_bit, b_bit) return a_bit == 1 or b_bit == 1 end)
end

function Bitwise.bxor(a, b)
    return Bitwise.base(a, b, function(a_bit, b_bit) return a_bit ~= b_bit end)
end

function Bitwise.bnot(a, size)
    if not size then
        size = 32
    end
    return Bitwise.base(a, 0, function(a_bit, b_bit) return a_bit == 0 end, size)
end

function Bitwise.shift(a, dir, b)
    if dir == "<<" then
        return a * (2 ^ b)
    elseif dir == ">>" then
        return math.floor(a / (2 ^ b))
    end
end

return Bitwise