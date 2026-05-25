BuildEnv(...)

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

debug = IsAddOnLoaded('!!!!!tdDevTools') and print or nop

Addon = LibStub('AceAddon-3.0'):NewAddon('MeetingStone', 'AceEvent-3.0', 'LibModule-1.0', 'LibClass-2.0', 'AceHook-3.0')

GUI = LibStub('NetEaseGUI-2.0')

function Addon:OnInitialize()
    self:SecureHook('LFGListUtil_OpenBestWindow', function()
        HideUIPanel(PVEFrame)
        self:Toggle()
    end)

    self:RegisterMessage('MEETINGSTONE_FILTER_DATA_UPDATED')

    self.mountCache = setmetatable({}, {
        __index = function(t, k)
            for _, id in ipairs(C_MountJournal.GetMountIDs()) do
                local displayId = C_MountJournal.GetMountInfoExtraByID(id)
                if displayId == k then
                    local v = select(11, C_MountJournal.GetMountInfoByID(id))
                    t[k] = v
                    return v
                end
            end
        end
    })
    self:RegisterEvent('COMPANION_LEARNED', function()
        wipe(self.mountCache)
    end)

    local lfgTooManyDialog = _G.StaticPopupDialogs['LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS']
    if lfgTooManyDialog and lfgTooManyDialog.text and strlenutf8(lfgTooManyDialog.text) == #lfgTooManyDialog.text then
        lfgTooManyDialog.text = L['你的队伍成员已经达到当前活动的人数上限，活动已经自动解散。']
    end

    InitMeetingStoneClass()

    SlashCmdList['MeetingStone'] = function() self:Toggle() end
    SLASH_MeetingStone1 = '/ms'
    SLASH_MeetingStone2 = '/meetingstone'
end

function Addon:OnEnable()
    if IsAddOnLoaded('RaidBuilder') then
        DisableAddOn('RaidBuilder')
        GUI:CallWarningDialog(L.FoundRaidBuilder, true, nil, ReloadUI)
        return
    end

    Profile:SaveLastVersion()
end

function Addon:Toggle()
    if MainPanel:IsShown() then
        Addon:HideModule('MainPanel')
    else
        if ApplicantPanel:HasNewPending() or C_LFGList.HasActiveEntryInfo() then
            MainPanel:SelectPanel(ManagerPanel)
        end
        Addon:ShowModule('MainPanel')
    end
end

function Addon:FindMount(id)
    return id and self.mountCache[id]
end

function Addon:MEETINGSTONE_FILTER_DATA_UPDATED(_, data)
    ClearCheckContentCache()
    self.filterPinyin = #data.pinyin > 0 and data.pinyin or nil
    self.filterNormal = #data.normal > 0 and data.normal or nil
end

function Addon:GetFilterData()
    return self.filterPinyin, self.filterNormal
end
