-- PhoenixCastBars - UpdateCheck (Retail 11.2.7)
-- Peer-based version discovery (DBM/Details style).

local ADDON_NAME, PCB = ...
PCB.UpdateCheck = PCB.UpdateCheck or {}
local UC = PCB.UpdateCheck

UC.PREFIX = "PHX_PCB"

local BROADCAST_MIN_INTERVAL = 300  -- 5 minutes
local LOGIN_GRACE = 10

UC._lastBroadcast = 0
UC._highestSeen = nil
UC._notified = false
UC._inited = false

local function ParseVersion(v)
    if type(v) ~= "string" then return nil end
    local a,b,c = v:match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c)
end

local function IsNewer(remote, localv)
    local ra, rb, rc = ParseVersion(remote)
    local la, lb, lc = ParseVersion(localv)
    if not ra or not la then return false end
    if ra ~= la then return ra > la end
    if rb ~= lb then return rb > lb end
    return rc > lc
end

local function BestChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    if IsInGuild() then return "GUILD" end
    return nil
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d1ffPhoenixCastBars|r: " .. msg)
end

function UC:GetHighestSeen()
    return self._highestSeen
end

function UC:MaybeNotify(remoteVersion)
    if self._notified then return end
    if not remoteVersion then return end
    local localVersion = PCB.version or "0.0.0"
    if IsNewer(remoteVersion, localVersion) then
        self._notified = true
        Print(("Update available — you’re on |cffffff00%s|r, latest seen |cffffff00%s|r."):format(localVersion, remoteVersion))
        Print("Update via CurseForge / your addon manager.")
    end
end

function UC:Handle(prefix, message, channel, sender)
    if prefix ~= self.PREFIX or type(message) ~= "string" then return end
    local remote = message:match("^VER:(%d+%.%d+%.%d+)$")
    if not remote then return end

    if not self._highestSeen or IsNewer(remote, self._highestSeen) then
        self._highestSeen = remote
    end

    self:MaybeNotify(remote)
end

function UC:Broadcast(force)
    local now = GetTime()
    if not force and (now - self._lastBroadcast) < BROADCAST_MIN_INTERVAL then return end

    local ch = BestChannel()
    if not ch then return end

    self._lastBroadcast = now
    C_ChatInfo.SendAddonMessage(self.PREFIX, ("VER:%s"):format(PCB.version or "0.0.0"), ch)
end

function UC:Init()
    if self._inited then return end
    self._inited = true

    C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)

    local f = CreateFrame("Frame")
    self._frame = f
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:RegisterEvent("CHAT_MSG_ADDON")

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" then
            C_Timer.After(LOGIN_GRACE, function() UC:Broadcast(true) end)
            C_Timer.After(LOGIN_GRACE + 5, function() UC:Broadcast(true) end)
            return
        end

        if event == "GROUP_ROSTER_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
            UC:Broadcast(false)
            return
        end

        if event == "CHAT_MSG_ADDON" then
            local p, msg, ch, sender = ...
            UC:Handle(p, msg, ch, sender)
        end
    end)
end
