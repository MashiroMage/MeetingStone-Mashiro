BuildEnv(...)

ADDON_TITLE = '集合石插件'

local L = LibStub('AceLocale-3.0'):NewLocale('MeetingStone', 'zhCN', true, true)
if not L then return end

L.CreateHelpRefresh = '点击刷新下方的申请列表'
L.CreateHelpList = '在此列出所有申请信息，团长或团队助理可以进行邀请等操作'
L.CreateHelpOptions = '创建活动时必选项，设置活动所属的类别、形式和拾取方式'
L.CreateHelpSummary = '创建活动时选填项，设置活动的最低装等、语音聊天、角色等级、PVP 等级和活动说明'
L.CreateHelpButtons = '团长可在此进行创建、更新或解散活动等操作'
L.ViewboardHelpOptions = '团员可以在此看到活动的类别、形式和拾取方式等信息'
L.ViewboardHelpSummary = '团员可以在此看到活动的队伍配置和队伍需求等信息'

