local NoSoftFail = {}

function NoSoftFail.new()
    local self = setmetatable({}, { __index=NoSoftFail })
    self.failed = false
    return self
end

function NoSoftFail:Reset()
    self.failed = false
end

function NoSoftFail:GetCompletedObjectives()
    return {}
end

function NoSoftFail:Fail()
    self.failed = true
end

function NoSoftFail:IsOK()
    return not self.failed
end

return NoSoftFail
