-- Hooks.lua
-- LFG UI hook: replaces default role icons with class/spec icons.
-- Called via InitMeetingStoneClass() from Core/Main.lua after addon init.

BuildEnv(...)

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

--------------------------
-- Icon lookup tables
--------------------------
local RoleIconTextures = {
	[1] = "Interface/AddOns/MeetingStone/Media/SunUI/Tank.tga",
	[2] = "Interface/AddOns/MeetingStone/Media/SunUI/Healer.tga",
	[3] = "Interface/AddOns/MeetingStone/Media/SunUI/DPS.tga",
}
local classNameToSpecIcon = {}
local classNameToSpecId = {}
for classID = 1, 13 do
	local classFile = select(2, GetClassInfo(classID))
	if classFile then
		for specIndex = 1, 4 do
			local specId, localizedSpecName, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
			if specId and localizedSpecName and icon then
				classNameToSpecIcon[classFile..localizedSpecName] = icon
				classNameToSpecId[classFile..localizedSpecName] = specId
			end
		end
	end
end

--------------------------
-- NDui MOD: role/class icon replacement
--------------------------
local _G = _G
local wipe = wipe
local select = select
local sort = sort

local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local C_LFGList_GetSearchResultMemberInfo = C_LFGList.GetSearchResultMemberInfo
local hooksecurefunc = hooksecurefunc

local roleCache = {}
local roleOrder = {
    ["TANK"] = 1,
    ["HEALER"] = 2,
    ["DAMAGER"] = 3,
}
local roleAtlas = {
    [1] = "groupfinder-icon-role-large-tank",
    [2] = "groupfinder-icon-role-large-heal",
    [3] = "groupfinder-icon-role-large-dps",
}

local function sortRoleOrder(a, b)
    if a and b then
        return a[1] < b[1]
    end
end

local function GetPartyMemberInfo(index)
    local unit = "player"
    if index > 1 then unit = "party" .. (index - 1) end

    local class = select(2, UnitClass(unit))
    if not class then return end
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" then role = "DAMAGER" end
    return role, class
end

local function GetCorrectRoleInfo(frame, i)
    if frame.resultID then
        return C_LFGList_GetSearchResultMemberInfo(frame.resultID, i)
    elseif frame == ApplicationViewerFrame then
        return GetPartyMemberInfo(i)
    end
end

local function UpdateGroupRoles(self)
    wipe(roleCache)
    if not self.__owner then
        self.__owner = self:GetParent():GetParent()
    end

    local count = 0
    for i = 1, 5 do
        local role, class, classCN, spec = GetCorrectRoleInfo(self.__owner, i)

        local roleIndex = role and roleOrder[role]
        if roleIndex then
            count = count + 1
            if not roleCache[count] then roleCache[count] = {} end
            roleCache[count][1] = roleIndex
            roleCache[count][2] = class
            roleCache[count][3] = i == 1
            roleCache[count][4] = spec
        end
    end

    sort(roleCache, sortRoleOrder)
end

local function CheckShowIcons(frame)
    local isLFGList
    while true do
        if frame == LFGListFrame then
            isLFGList = true
            break
        -- There is no such frame named MeetingStoneFrame
        elseif frame == nil then
            isLFGList = false
            break
        end
        frame = frame:GetParent()
    end

    if not isLFGList then
        if not Profile:GetShowClassIco() then
            return "orig"
        elseif IsAddOnLoaded("ElvUI_WindTools") and Profile:GetShowWindClassIco() then
            -- Module LFGList does not initialize when PremadeGroupsFilter is loaded
            if not IsAddOnLoaded("PremadeGroupsFilter") and WindTools[3].private.WT.misc.lfgList.enable then
                return "wind"
            else
                return "orig"
            end
        else
            return "meet"
        end
    else
        if IsAddOnLoaded("PremadeGroupsFilter") then
            return "orig"
        elseif IsAddOnLoaded("ElvUI_WindTools") and WindTools[3].private.WT.misc.lfgList.enable then
            return "wind"
        elseif Profile:GetShowClassIco() and not Profile:GetClassIcoMsOnly() then
            return "meet"
        else
            return "orig"
        end
    end
end

local function ReplaceGroupRoles(self, numPlayers, _, disabled)
    local flagCheckShowIcons = CheckShowIcons(self)
    if flagCheckShowIcons == "orig" then
        return
    elseif flagCheckShowIcons == "wind" then
        return WindTools[1]:GetModule("LFGList"):UpdateEnumerate(self)
    end

	local flagCheckShowSpecIcon = Profile:GetShowSpecIco()
	local flagCheckShowSmRoleIcon = Profile:GetShowSmRoleIco()

    UpdateGroupRoles(self)
    for i = 1, 5 do
        local icon = self.Icons[i]
        if not icon.role then
            icon.role = self:CreateTexture(nil, "OVERLAY")
            icon.role:SetSize(24, 24)
            if i == 1 then
                icon.role:SetPoint("RIGHT", -5, -2)
            else
                icon.role:ClearAllPoints()
                icon.role:SetPoint("RIGHT", self.Icons[i - 1].role, "LEFT", 0, 0)
            end
            icon.leader = self:CreateTexture(nil, "OVERLAY")
            icon.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            icon.leader:SetRotation(rad(-15))
        end

        if i > numPlayers then
            icon.role:Hide()
        else
            icon.role:Show()
            icon.role:SetDesaturated(disabled)
            icon.role:SetAlpha(disabled and .5 or 1)
            icon.leader:SetDesaturated(disabled)
            icon.leader:SetAlpha(disabled and .5 or 1)
        end
        icon.leader:Hide()
    end

    local iconIndex = numPlayers
    for i = 1, #roleCache do
        local roleInfo = roleCache[i]
        if roleInfo then
            local icon = self.Icons[iconIndex]
            if flagCheckShowSmRoleIcon then
                icon:SetSize(15, 15)
                icon:SetPoint("TOPLEFT", icon.role, -4, 6)
                icon.leader:SetSize(13, 13)
                icon.leader:SetPoint("TOP", icon.role, 4, 8)
            else
                icon:SetSize(18, 18)
                icon:SetPoint("TOPLEFT", icon.role, -4, 5)
                icon.leader:SetSize(16, 16)
                icon.leader:SetPoint("TOP", icon.role, 4, 8)
            end

            if roleInfo[4] and flagCheckShowSpecIcon then
                local spec_id = classNameToSpecId[roleInfo[2] .. roleInfo[4]]
                if spec_id == nil then
                    icon.role:SetTexture(classNameToSpecIcon[roleInfo[2] .. roleInfo[4]])
                else
                    icon.role:SetTexture("Interface/AddOns/MeetingStone/Media/SpellIcon/circular_" .. spec_id)
                end
            else
                icon.role:SetTexture("Interface/AddOns/MeetingStone/Media/ClassIcon/" ..
                    string.lower(roleInfo[2]) .. "_flatborder2")
            end

            if roleInfo[1] and RoleIconTextures[roleInfo[1]] then
                icon.RoleIconWithBackground:SetAtlas(roleAtlas[roleInfo[1]])
            end
            icon.leader:SetShown(roleInfo[3])
            iconIndex = iconIndex - 1
        end
    end

    for i = 1, iconIndex do
        self.Icons[i].role:SetAtlas(nil)
    end
end

--------------------------
-- Public init (called from Core/Main.lua)
--------------------------
function InitMeetingStoneClass()
    local F = "LFGListGroupDataDisplayEnumerate_Update"
    Profile:OnInitialize()

    if not IsAddOnLoaded("ElvUI_WindTools") then
        hooksecurefunc(F, ReplaceGroupRoles)
    else
        local W, _, E = unpack(WindTools)
        local L = W:GetModule("LFGList")
        E:Delay(0, function ()
            if L:IsHooked(F) then L:Unhook(F) end
            L:SecureHook(F, ReplaceGroupRoles)
        end)
    end
end

--------------------------
-- Locale / region helpers
--------------------------
function GetPlayerRegion()
    local regionTable = { "US", "KR", "EU", "TW", "CN" }
    local playerAccountInfo = C_BattleNet.GetAccountInfoByGUID(UnitGUID("player"))
    local currentRegion = GetCurrentRegion()

    if not playerAccountInfo or not playerAccountInfo.gameAccountInfo or not playerAccountInfo.gameAccountInfo.regionID then
        return regionTable[currentRegion]
    else
        return regionTable[playerAccountInfo.gameAccountInfo.regionID]
    end
end

function GetPortalByLocale()
    local gameLocale = GetLocale()
    local portalVal
    if gameLocale == "zhTW" then
        portalVal = 'TW'
    elseif gameLocale == "zhCN" then
        portalVal = 'CN'
    else
        portalVal = 'US'
    end

    return portalVal
end

--------------------------
-- Score color helpers
--------------------------
function GetDungeonScoreRarityColor(score)
    return C_ChallengeMode.GetDungeonScoreRarityColor(score) or
        HIGHLIGHT_FONT_COLOR
end

function GetSpecificDungeonOverallScoreRarityColor(score)
    return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) or
        HIGHLIGHT_FONT_COLOR
end
