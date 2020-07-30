local addonName, Addon = ...
local prefix = "["..addonName.."]"
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

f:RegisterEvent("ADDON_LOADED")

function f:ADDON_LOADED(_, loadedAddon)
    if loadedAddon == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        if type(DB) ~= "table" then
            DB = {}
        end
        if UnitLevel("player") == 1 then
            self:RegisterEvent("CINEMATIC_START")
            self:RegisterEvent("GOSSIP_SHOW")
            self:RegisterEvent("PLAYER_DEAD")
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            self:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")

            hooksecurefunc("StaticPopup_Show", function(sType)
                if sType == "DEATH" then
                    C_Timer.After(0.2, function()
                        StaticPopup_OnClick(StaticPopup1, 1)
                    end)
                end
                if sType == "PARTY_INVITE" then
                    C_Timer.After(0.2, function()
                        StaticPopup_OnClick(StaticPopup1, 1)
                    end)
                end
            end)
        end
    end
end

function f:CINEMATIC_START()
    if InCinematic() then
        CinematicFrame_CancelCinematic()
    end
end

function f:PLAYER_DEAD()
    C_Timer.After(0.5, function()
        StaticPopup_OnClick(StaticPopup1, 1)
    end)
end

function f:GOSSIP_SHOW()
    SelectGossipOption(1)
    C_Timer.After(0.2, function()
        StaticPopup_OnClick(StaticPopup1, 1)
    end)
    C_Timer.After(0.4, function()
        StaticPopup_OnClick(StaticPopup1, 1)
    end)
end

local now
function f:PLAYER_PVP_KILLS_CHANGED()
    if not now or now ~= GetTime() then
        local current = GetPVPSessionStats()
        if current and tonumber(current) then
            print(current, "kills")
            now = GetTime()
        end
    end
end

function f:PLAYER_ENTERING_WORLD()
    if DB.name then
        SendChatMessage("inv", "WHISPER", nil, DB.name)
    else
        print(prefix, "Type /pool <username for invite>")
    end
    SetPVP(1)
end

_G["SLASH_"..prefix:upper().."1"] = "/pool"
SlashCmdList[prefix:upper()] = function(input)
    if not input then
        print(prefix, "usage: /pool <username for invite>")
        return
    end
    DB.name = input
    print(prefix, "Auto send 'inv' on", input, "set")
    SendChatMessage("inv", "WHISPER", nil, DB.name)
end