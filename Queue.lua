local Queue = {}
Queue.__index = Queue

function Queue:new()
    return setmetatable({head = 1, tail = 1}, self)
end

function Queue:is_empty()
    return self.head == self.tail
end

function Queue:peek()
    return self[self.head]
end

function Queue:add(element)
    self[self.tail] = element
    self.tail = self.tail + 1
end

function Queue:pop()
    if not self:is_empty() then
        local ret = self[self.head]
        self[self.head] = nil
        self.head = self.head + 1

        if self.head > 1000 and self.head > self.tail - self.head then
            self:clean_up()
        end
        return ret
    else
        return nil
    end
end

function Queue:clean_up()
    local size = self.tail - self.head
    for i = 0, size - 1 do
        self[1 + i] = self[self.head + i]
        self[self.head + i] = nil
    end
    self.head = 1
    self.tail = 1 + size
end

return Queue