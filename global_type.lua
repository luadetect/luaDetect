module(..., package.seeall)

--[[
Debug Level
]]

DCDEBUG_LEVEL = {
	DETECTLoggingMaskError = 1,
    DETECTLoggingMaskWarn = 2,
    DETECTLoggingMaskInfo = 4,
    DETECTLoggingMaskDebug = 8,
    DETECTLoggingMaskVerbose = 16
}

--[[
诊断场景。
该字段用来区分不同游戏阶段的诊断操作
]]

Scene = {
    SceneNone = 0, --<未设置收集场景
    Delay = 1, --<网络延时大于某个值
    DownloadPatchListFailed = 2, --<下载补丁列表失败
    DownloadServerListFailed = 3, --<下载服务器列表失败
    ConnectToServerFailed = 4, --<连接服务器失败
    UnexpextOffline = 5, --<异常掉线
    DownloadPatchFailed = 6, --<下载补丁失败
    Initial = 7, --<SDK联网初始化失败
    Sigin = 8, --<渠道登录失败
    Payment = 9, --<支付失败
    LostPackets = 10, --<丢包
    CollectionNormal = 11, --<正常收集
    DownloadPatchListCanceled = 12, --<补丁列表下载取消
    DownloadServerListCanceled = 13, --<服务器列表下载取消
    DownloadPatchCanceled = 14, --<补丁下载取消
    GameSlowness = 15, --<游戏卡顿
    DownloadPatchListSuccessed = 32, --<补丁列表下载成功
    DownloadServerListSuccessed = 33, --<服务器列表下载成功
    ConnectToServerSuccessed = 34, --<连接服务器成功
    DownloadPatchSuccessed = 36, --<补丁下载成功
    InitialSuccessed = 37, --<SDK联网初始化成功
    SiginSuccessed = 38, --<渠道登录成功
    PaymentSuccessed = 39, --<支付成功
    PatchStart = 46, --<补丁开始下载
    AppVisitSuccessed = 51, --<APP访问成功
    AppVisitFailed = 52, --<APP访问失败
    PatchingCanceled = 56, --<补丁下载中途取消
    PatchFailedExtendStart = 101, --<预留扩展场景，默认走Patch失败流程，101-199
    PatchFailedExtendEnd = 199, --<预留扩展场景，默认走Patch失败流程，100-199
    PatchSuccessedExtendStart = 201, --<预留扩展场景，默认走Patch成功流程，201-299
    PatchSuccessedExtendEnd = 299, --<预留扩展场景，默认走Patch成功流程，201-299
    URLConnectivityReachable = 207, --特定的URL可以连通
    URLConnectivityUnreachable = 107, -- 特定的URL不可达
}


--[[
表单字段DCTOOL_FORM_FIELD
]]

Forms = {
    collection_condition = 'collect_condition',
    product = 'product',
    channel_name = 'channel_name',
    group_id = 'group_id',
    user_name = 'user_name',
    server_name = 'server_name',
    server_ip = 'server_ip',
    server_port = 'server_port',
    serverlist_url = 'serverlist_url',
    patchlist_url = 'patchlist_url',
    patch_url = 'patch_url',
    client_dns_ip = 'client_dns_ip',
    client_dns_result = 'client_dns_result',
    head_163 = 'head_163',
    head_qq = 'head_qq',
    head_baidu = 'head_baidu',
    head_google = 'head_google',
    head_facebook = 'head_facebook',
    head_bing = 'head_bing',
    time_visit163 = 'time_visit163',
    ping_lost_163 = 'ping_lost_163',
    ip_163 = 'ip_163',
    time_visitqq = 'time_visitqq',
    ping_lost_qq = 'ping_lost_qq',
    ip_qq = 'ip_qq',
    time_visitbaidu = 'time_visitbaidu',
    ping_lost_baidu = 'ping_lost_baidu',
    ip_baidu = 'ip_baidu',
    time_visitgoogle = 'time_visitgoogle',
    ping_lost_google = 'ping_lost_google',
    ip_google = 'ip_google',
    time_visitfacebook = 'time_visitfacebook',
    ping_lost_facebook = 'ping_lost_facebook',
    ip_facebook = 'ip_facebook',
    time_visitbing = 'time_visitbing',
    ping_lost_bing = 'ping_lost_bing',
    ip_bing = 'ip_bing',
    ping = 'ping',
    ping_lost = 'ping_lost',
    port_connect = 'port_connect',
    tracert = 'tracert',
    download_patch_list = 'download_patch_list',
    download_server_list = 'download_server_list',
    download_patch = 'downloadpatch',
    ping_patchlist = 'ping_patchlist',
    ping_lost_patchlist = 'ping_lost_patchlist',
    ping_serverlist = 'ping_serverlist',
    ping_lost_serverlist = 'ping_lost_serverlist',
    ip_server_list_host = 'ip_server_list_host',
    server_list_host = 'server_list_host',
    tracert_patchlist = 'tracert_patchlist',
    tracert_serverlist = 'tracert_serverlist',
    patch_host = 'patch_host',
    ip_patch_host = 'ip_patch_host',
    ping_patch = 'ping_patch',
    ping_lost_patch = 'ping_lost_patch',
    tracert_patch = 'tracert_patch',
    head_result = 'head_result',
    url = 'url',
    os = 'os',
    os_version = 'os_version',
    network_type = 'network_type',
    apple_pay = 'apple_pay',
    version = 'version',
    start_time = 'start_time',
    finish_time = 'finish_time',
    push_time = 'push_time',
    user_id = 'user_id',
    device_id = 'device_id',
    domain_resolve_log = 'domain_resolve_log',
    nstool_log = 'nstool_log',
    transid = 'transid',
    statusname="statusname",
    explicit_url = "explicit_url",
    http_code = "http_code",
    time_cost="time_cost",
}



--[[
##############################################
#### 常量定义相关
##############################################
]]
-- 说明SDK的版本号
DCTOOL_VERSION = 'py3.1.1'





--[[
##############################################
#### 配置定义相关
##############################################
]]

-- 设置是否调用引擎中的日志记录方法
-- 默认为False，接入时需要游戏手动修改这个值为True
DCTOOL_ENABLE_ENGINE_LOGGER = false


--当前接入游戏是否messiah引擎
DCTOOL_MESSIAH_ENGINE_ENVIRONMENT = false

--当前接入游戏是否NeoX引擎
DCTOOL_NEOX_ENGINE_ENVIRONMENT = true



-- 设置是否从引擎中获取设备信息
-- 默认为False，接入时需要游戏手动修改这个值为True
DCTOOL_ENABLE_ENGINE_DEVICE = true
--print("Type DCTOOL_ENABLE_ENGINE_DEVICE is {0}".format(DCTOOL_ENABLE_ENGINE_DEVICE))
