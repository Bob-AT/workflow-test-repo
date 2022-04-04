local AvoidFatality = {}

function AvoidFatality.new(objectiveName)
    local self = setmetatable({}, { __index=AvoidFatality })

    self.currentCount = 0
    self.objectiveName = objectiveName

    return self
end

function AvoidFatality:Reset()
    self.currentCount = 0
end

function AvoidFatality:GetCompletedObjectives()
    if self:IsOK() then
        return {self.objectiveName}
    end
    return {}
end

function AvoidFatality:ReportFatality()
    self.currentCount = self.currentCount + 1
end

function AvoidFatality:GetFatalityCount()
    return self.currentCount
end

function AvoidFatality:IsOK()
    return self.currentCount < 1
end

return AvoidFatality
