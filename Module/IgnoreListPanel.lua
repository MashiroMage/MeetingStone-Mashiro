BuildEnv(...)

local BrowsePanel = Addon:GetModule('BrowsePanel')
local MainPanel = Addon:GetModule('MainPanel')

IgnoreListPanel = Addon:NewModule(CreateFrame('Frame', nil, MainPanel), 'IgnoreListPanel')


function IgnoreListPanel:OnInitialize()
    GUI:Embed(self, 'Tab')
    MainPanel:RegisterPanel('屏蔽玩家列表', self, {after = '设置'})

    local IgnoreList = GUI:GetClass('DataGridView'):New(self)

    IgnoreList:SetAllPoints(self)
    IgnoreList:SetItemHighlightWithoutChecked(true)
    IgnoreList:SetItemHeight(32)
    IgnoreList:SetItemSpacing(1)
    IgnoreList:SetItemClass(Addon:GetClass('BrowseItem'))
    IgnoreList:SetSelectMode('RADIO')
    IgnoreList:SetScrollStep(9)
    self.checkBoxes = {}
    IgnoreList:InitHeader({
        {
            key = '@',
            text = '@',
            width = 30,
            enableMouse = true,
            class = Addon:GetClass('CheckBox'),
            formatHandler = function(grid,activity)
                grid:SetHeight(30)
                grid.Check:SetSize(32, 32)
                grid.Check:SetPoint('CENTER')
                grid.Check:SetChecked(activity.selected)
                grid:SetCallback('OnChanged', function ( data )
                    if activity then
                        activity.selected = data.Check:GetChecked()
                        self.checkBoxes[data] = true
                    end
                end)
            end,
        }, {
            key = 'Leader',
            text = '屏蔽的队长',
            style = 'LEFT',
            width = 200,
            showHandler = function(activity)
                return activity.leader, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
            end,
        },
        {
            key = 'Time',
            text = '屏蔽时间',
            width = 200,
            showHandler = function(activity)
                return activity.time
            end,
        },
        {
            key = 'Dep',
            text = '备注',
            width = 350,
            showHandler = function(activity)
                return activity.dep
            end,
        },
    })
    IgnoreList:SetHeaderPoint('BOTTOMLEFT', IgnoreList, 'TOPLEFT', -2, 2)
    IgnoreList:SetItemList(MEETINGSTONE_UI_DB.IGNORE_LIST)
    self.IgnoreList = IgnoreList

    self:SetScript('OnShow', function()
        -- BrowseFilter:OnInitialize 晚于本模块加载，首次登录时 IGNORE_LIST 可能尚未初始化
        -- 或后续新增屏蔽后列表引用需要同步，故每次显示时重新绑定并刷新
        self.IgnoreList:SetItemList(MEETINGSTONE_UI_DB.IGNORE_LIST)
        self.IgnoreList:Refresh()
    end)


    local RemoveIgnore = CreateFrame('Button', nil, self, 'UIPanelButtonTemplate')
    do
        RemoveIgnore:SetSize(120, 22)
        RemoveIgnore:SetPoint('BOTTOM', MainPanel, 'BOTTOM', 0, 4)
        RemoveIgnore:SetText('移除勾选玩家')
        RemoveIgnore:SetScript('OnClick', function()
            for i=#MEETINGSTONE_UI_DB.IGNORE_LIST,1,-1 do
                local tb = MEETINGSTONE_UI_DB.IGNORE_LIST[i]
                tb.data = nil
                if tb.selected then
                    tb.selected = nil
                    table.remove(MEETINGSTONE_UI_DB.IGNORE_LIST,i)
                    BrowsePanel.IgnoreWithLeader[tb.leader] = nil
                    BrowsePanel.IgnoreLeaderOnly[tb.leader] = nil
                end
            end
            for check,v in pairs(self.checkBoxes) do
                check.Check:SetChecked(false)
            end
            BrowsePanel.IgnoreWithTitle = {}
            self.IgnoreList:Refresh()
        end)
    end


    local ClearIgnore = CreateFrame('Button', nil, self) do
        ClearIgnore:SetNormalFontObject('GameFontNormalSmall')
        ClearIgnore:SetHighlightFontObject('GameFontHighlightSmall')
        ClearIgnore:SetSize(70, 22)
        ClearIgnore:SetPoint('BOTTOMLEFT', MainPanel, 30, 3)
        ClearIgnore:SetText('全选/取消全选')
        ClearIgnore:RegisterForClicks('anyUp')
        ClearIgnore:SetScript('OnClick', function()
            for i,v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
                v.selected = not v.selected
            end
            self.IgnoreList:Refresh()
        end)
    end
end
