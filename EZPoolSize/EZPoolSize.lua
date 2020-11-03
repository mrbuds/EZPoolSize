local addonName, Addon = ...
local prefix = "["..addonName.."]"
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

f:RegisterEvent("ADDON_LOADED")

local secret = "MANGMONFIAK"

local function newButton(name)
    local button = CreateFrame("Button", name, UIParent, "InsecureActionButtonTemplate")
    button:SetAttribute('type', 'macro');
    button:SetWidth(150)
    button:SetHeight(20)
    button:SetNormalFontObject("GameFontNormal")

    local ntex = button:CreateTexture()
    ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up")
    ntex:SetTexCoord(0, 0.625, 0, 0.6875)
    ntex:SetAllPoints()
    button:SetNormalTexture(ntex)

    local htex = button:CreateTexture()
    htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight")
    htex:SetTexCoord(0, 0.625, 0, 0.6875)
    htex:SetAllPoints()
    button:SetHighlightTexture(htex)

    local ptex = button:CreateTexture()
    ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down")
    ptex:SetTexCoord(0, 0.625, 0, 0.6875)
    ptex:SetAllPoints()
    button:SetPushedTexture(ptex)

    return button
end

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
            self:RegisterEvent("PARTY_INVITE_REQUEST")
            self:RegisterEvent("GROUP_INVITE_CONFIRMATION")

            local button = newButton("LogoutButton")
            button:SetPoint("TOP", UIParent, "TOP", 0, -15)
            button:SetText("1: Logout")
            button:SetAttribute('macrotext', '/camp');
            SetOverrideBindingClick(self, true, "1", "LogoutButton")

            if UnitFactionGroup("player") == "Alliance" then
                local button2 = newButton("StuckButton")
                button2:SetPoint("TOP", UIParent, "TOP", 0, -40)
                button2:SetText("2: Character Unstuck")
                button2:SetAttribute('macrotext', '/click HelpFrameCharacterStuckStuck')
                SetOverrideBindingClick(self, true, "2", "StuckButton")
            end
        else
            C_ChatInfo.RegisterAddonMessagePrefix("poolsize")
            self:RegisterEvent("CHAT_MSG_ADDON")
            self:RegisterEvent("CHAT_MSG_WHISPER")
        end
    end
end

function f:CHAT_MSG_ADDON(event, addonprefix, msg)
    if addonprefix == "poolsize" and msg == secret then
      DB.count = (DB.count or 0) + 1
    end
end

function f:CHAT_MSG_WHISPER(event, text, playerName)
    print(text, playerName)
    if text == "!status" then
        SendChatMessage(DB.count or 0, "WHISPER", nil, playerName)
    end
end

function f:CINEMATIC_START()
    if InCinematic() then
        CinematicFrame_CancelCinematic()
    end
end

function f:PLAYER_DEAD()
    if self:IsEventRegistered("AUTOFOLLOW_BEGIN") then
        self:UnregisterEvent("AUTOFOLLOW_BEGIN")
    end
    RepopMe()
end

function f:GOSSIP_SHOW()
    SelectGossipOption(1)
    C_Timer.After(0.2, function()
        AcceptXPLoss()
    end)
end

function f:AUTOFOLLOW_BEGIN()
    self:UnregisterEvent("AUTOFOLLOW_BEGIN")
end

local now
function f:PLAYER_PVP_KILLS_CHANGED()
    if not now or now ~= GetTime() then
        local current = GetPVPSessionStats()
        if current and tonumber(current) then
            print(current, "kills")
            now = GetTime()
            if current == 15 then
                C_ChatInfo.SendAddonMessage("poolsize", secret, IsInRaid() and "RAID" or "PARTY")
            end
            if current >= 15 then
                for i = 1, 4 do
                    local frame = _G["StaticPopup"..i]
                    if frame:IsVisible() and frame.which == "CAMP" then
                        -- return -- don't leave party if logging out
                    end
                end
                LeaveParty()
            elseif current == 1 then
                f:nextNameDialog()
            end
        end
    end
end

function f:GROUP_INVITE_CONFIRMATION()
    local firstInvite = GetNextPendingInviteConfirmation()
    if not firstInvite then
        return
    end
    local confirmationType, name = GetInviteConfirmationInfo(firstInvite)
    if name then
        RespondToInviteConfirmation(firstInvite, true)
        for i = 1, 4 do
            local frame = _G["StaticPopup"..i]
            if frame:IsVisible() and frame.which == "GROUP_INVITE_CONFIRMATION" then
                StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
                UpdateInviteConfirmationDialogs()
                return
            end
        end
    end
end

function f:PARTY_INVITE_REQUEST()
    AcceptGroup()
    for i = 1, 4 do
        local frame = _G["StaticPopup"..i]
        if frame:IsVisible() and frame.which == "PARTY_INVITE" then
            frame.inviteAccepted = true
            StaticPopup_Hide("PARTY_INVITE")
            return
        elseif frame:IsVisible() and frame.which == "PARTY_INVITE_XREALM" then
            frame.inviteAccepted = true
            StaticPopup_Hide("PARTY_INVITE_XREALM")
            return
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
    if DB.followname then
        print(prefix, "Auto follow on", DB.followname)
        self:RegisterEvent("AUTOFOLLOW_BEGIN")
        f:autofollowLoop()
    end
    if UnitFactionGroup("player") == "Alliance" and UnitLevel("player") == 1 then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                if GetContainerItemID(bag, slot) == 6948 then -- Healthstone
                    PickupContainerItem(bag,slot)
                    DeleteCursorItem()
                end
            end
        end
    end
end

-- auto send for invite command
_G["SLASH_"..prefix:upper().."1"] = "/pool"
SlashCmdList[prefix:upper()] = function(input)
    if not input or input == "" then
        print(prefix, "usage: /pool <username for invite>")
        return
    end
    DB.name = input
    print(prefix, "Auto send 'inv' on", input, "set")
    SendChatMessage("inv", "WHISPER", nil, DB.name)
end

-- show next name dialog command
_G["SLASH_"..prefix:upper().."NAME1"] = "/name"
SlashCmdList[prefix:upper().."NAME"] = function()
    f:nextNameDialog()
end

function f:nextName()
    local name = UnitName("player"):lower()
    local lastletter = name:sub(#name)
    local prevletter = name:sub(#name-1, #name-1)

    local nextletter = {}
    for i = 0, 24 do
       nextletter[string.char(i + 97)] = string.char(i + 98)
    end
    nextletter["z"] = "a"

    if prevletter == "g" and lastletter == "l" then -- no name finishing by GM
        return name:sub(1, #name-2) .. "gn"
    end
    if lastletter < "z" then
       return name:sub(1, #name-1) .. nextletter[lastletter]
    else
       return name:sub(1, #name-2) .. nextletter[prevletter] .. "a"
    end
end

function f:nextNameDialog()
    StaticPopupDialogs["EZPOOLSIZENEXTNAME"] = {
        text = "Next Character Name",
        button1 = "Ok",
        timeout = 0,
        hasEditBox = true,
        hideOnEscape = true,
        OnShow = function (self, data)
            self.editBox:SetText(f:nextName())
            self.editBox:HighlightText()
            --self.editBox:Disable()
        end,
        OnHide = function()
            print("Next name is ".. f:nextName()..", type /name to re-open dialog.")
        end
      }
      StaticPopup_Show("EZPOOLSIZENEXTNAME")
end

-- auto follow command
_G["SLASH_"..prefix:upper().."FOLLOW1"] = "/autofollow"
SlashCmdList[prefix:upper().."FOLLOW"] = function(input)
    if not input or input == "" then
        print(prefix, "usage: /autofollow <name>")
        DB.followname = nil
        return
    end
    DB.followname = input
    print(prefix, "Auto follow on", input, "set")
    f:RegisterEvent("AUTOFOLLOW_BEGIN")
    f:autofollowLoop()
end

-- reset counter command
_G["SLASH_"..prefix:upper().."RESET1"] = "/reset"
SlashCmdList[prefix:upper().."RESET"] = function(input)
    DB.count = 0
    print(prefix, "Counter reset")
end

function f:autofollowLoop()
    if f:IsEventRegistered("AUTOFOLLOW_BEGIN") and DB.followname then
        FollowUnit(DB.followname)
        C_Timer.After(3, f.autofollowLoop)
    end
end