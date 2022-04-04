local Obj1 = {State={X=5}}

local Obj2 = setmetatable({}, {__index=Obj1 })
local Obj3 = setmetatable({}, {__index=Obj2 })

function Obj1:Foo()
    print("Obj1 FOO " .. self.State.X)
end

function Obj2:Foo()
    Obj1.Foo(self)
    return self.State.X
end

function Obj3:SetX()
    self.State = {}
    self.State.X = 6
end

Obj3:SetX()

print(Obj1.State.X)

print(Obj3:Foo())

--local Tables = require("Common.Tables")
--
--local super = Tables.DeepCopy(require("KillConfirmed"))
--local CustomMode = setmetatable({}, {__index = super })
--
--CustomMode.Settings.RespawnCost.Value = 100000
--CustomMode.PlayerScoreTypes.CollateralDamage = {
--    Score = -250,
--    OneOff = false,
--    Description = 'Killed a non-combatant'
--}
--CustomMode.CollateralDamageDamageCount = 0
--
--function CustomMode:OnRoundStageSet(RoundStage)
--    if RoundStage == 'PreRoundWait' then
--        print("Setting attitudes")
--        --gamemode.SetTeamAttitude(1, 10, 'Neutral')
--        --gamemode.SetTeamAttitude(10, 1, 'Neutral')
--        --gamemode.SetTeamAttitude(10, 100, 'Friendly')
--        --gamemode.SetTeamAttitude(100, 10, 'Friendly')
--    end
--    super.OnRoundStageSet(self, RoundStage)
--end
--
--function CustomMode:OnCharacterDied(Character, CharacterController, KillerController)
--    local goodKill = true
--
--    if gamemode.GetRoundStage() == 'PreRoundWait' or gamemode.GetRoundStage() == 'InProgress'
--    then
--        if CharacterController ~= nil then
--            local killedTeam = actor.GetTeamId(CharacterController)
--            local killerTeam = nil
--            if KillerController ~= nil then
--                killerTeam = actor.GetTeamId(KillerController)
--            end
--            if killedTeam == 10 and killerTeam == 1 then
--                self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'CollateralDamage')
--                goodKill = false
--            end
--        end
--    end
--
--    if goodKill then
--        super.OnCharacterDied(self, Character, CharacterController, KillerController)
--    end
--end
--
--CustomMode:OnRoundStageSet('PreRoundWait')
--
--return CustomMode
