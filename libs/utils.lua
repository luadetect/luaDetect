module(..., package.seeall)

require "memory_profile"
require "preload.utils"
require "user_default"
memory_profile.regGlobalNilVar("hideAndroidNavigationBarTimerIdx")

-- 整包渠道名
ApkChannel = nil 

function getChannel()
	if not ApkChannel then 
		ApkChannel = SdkControllerDelegate:getInstance():getChannel()
	end 
	return ApkChannel
end  

function RunScene(scene)
	cc.Director:getInstance():runWithScene(scene)
end


function AddEventListener(obj, func)
	if not func then return end
	obj:addTouchEventListener(function(sender, flag)
		func()
	end)
end

function dirtree(dir, recursive)
	return preload.utils.dirtree(dir, recursive)
end

function CheckFileExist(filename)
	return preload.utils.CheckFileExist(filename)
end

function getDataFromSpecRoot(root, path)
	local instance = cc.FileUtils:getInstance()
	if instance.getDataFromSpecRoot then 
		return instance:getDataFromSpecRoot(root, path)
	end 
end

UI_SPRITEFRAME_CACHE = {}
--如果要检查文件在不在大纹理里面，注意不要带有res/
function CheckFileExistInFrameCache(filename)
	local ret = false
	if _G.UI_SPRITEFRAME_PREFIX and string.find(filename, _G.UI_SPRITEFRAME_PREFIX) then
		if UI_SPRITEFRAME_CACHE[filename] ~= nil then
			ret = UI_SPRITEFRAME_CACHE[filename]
		else
			ret = cc.SpriteFrameCache:getInstance():getSpriteFrame(filename) ~= nil
			UI_SPRITEFRAME_CACHE[filename] = ret
		end
	end
	return ret
end
--如果要检查文件在不在大纹理里面，注意不要带有res/
function CheckFileExistWithCache(filename)
	local ret = cc.FileUtils:getInstance():isFileExistWithCache(filename)
	-- print("CheckFileExistWithCache", filename, ret, _G.UI_SPRITEFRAME_PREFIX, cc.SpriteFrameCache:getInstance():getSpriteFrame(filename) ~= nil)
	--TODO implement it in c++ code
	if not ret then
		ret = CheckFileExistInFrameCache(filename)
	end
	return ret
end
function CheckLuaModuleExistWithCache(moduleName)
	local fileName = string.gsub(moduleName, "%.", "/") .. ".lua"
	local ret = cc.FileUtils:getInstance():isFileExistWithCache(fileName)
	return ret
end

function purge()
	fileExistCache = {}
	UI_SPRITEFRAME_CACHE = {}
end

--x, y, width, height
function RectUnion(rect1, rect2)
	if not rect1 and not rect2 then return end
	if not rect1 then return rect2 end
	if not rect2 then return rect1 end
	local left1, bottom1, right1, top1 = rect1.x, rect1.y, rect1.x + rect1.width, rect1.y + rect1.height
	local left2, bottom2, right2, top2 = rect2.x, rect2.y, rect2.x + rect2.width, rect2.y + rect2.height

	local left = math.min(left1, left2)
	local right = math.max(right1, right2)

	local bottom = math.min(bottom1, bottom2)
	local top = math.max(top1, top2)

	local width = math.max(right-left, 0)
	local height = math.max(top-bottom, 0)

	return {x=left, y=bottom, width=width, height=height}
end

--x, y, width, height
function RectIntersect(rect1, rect2)
	if not rect1 or not rect2 then
		return
	end
	local left1, bottom1, right1, top1 = rect1.x, rect1.y, rect1.x + rect1.width, rect1.y + rect1.height
	local left2, bottom2, right2, top2 = rect2.x, rect2.y, rect2.x + rect2.width, rect2.y + rect2.height

	local left = math.max(left1, left2)
	local right = math.min(right1, right2)

	local bottom = math.max(bottom1, bottom2)
	local top = math.min(top1, top2)

	local width = math.max(right-left, 0)
	local height = math.max(top-bottom, 0)

	return {x=left, y=bottom, width=width, height=height}
end

function IsPointInRect(p, rect)
	if rect.width<= 0 or rect.height <= 0 then return false end
	local left, bottom, right, top = rect.x, rect.y, rect.x + rect.width, rect.y + rect.height
	if p.x >= left and p.x < right and p.y >= bottom and p.y < top then
		return true
	end
	return false
end

--两个矩形是否相交
function IsRectCross(rect1, rect2)
	local halfWidth1, halfHeight1 = rect1.width / 2, rect1.height / 2
	local halfWidth2, halfHeight2 = rect2.width / 2, rect2.height / 2
	local centerX1, centerY1 = rect1.x + halfWidth1, rect1.y + halfHeight1
	local centerX2, centerY2 = rect2.x + halfWidth2, rect2.y + halfHeight2
	return (math.abs(centerX1 - centerX2) <= (halfWidth1 + halfWidth2) and math.abs(centerY1 - centerY2) <= (halfHeight1 + halfHeight2))
end

--filename, modulename, funcname

function CallModuleFunc(filename, modulename, funcname, ...)
	local arg = {...}
	local res = require(filename)
	if modulename == nil or modulename == "" then modulename = filename end
	if res and type(res)=="table" then
		if res[funcname] then 
			local callres = res[funcname](unpack(arg))
			local fret = callres
			if callres == nil then callres = true end
			return callres, fret
		end
	elseif res then
		modulelist = string.split(modulename)
		local mt = _G
		for i, name in ipairs(modulelist)do
			--failed
			if not mt[name]then return false end
			mt = mt[name]
		end
		if mt[funcname] and type(mt[funcname]) == "function" then
			local callres = mt[funcname](unpack(arg))
			local fret = callres
			if callres == nil then callres = true end
			return callres, fret
		end
	end
	return false
end

--[[
	程序同学请注意：
		win32版因为要在同一目录下双开甚至多开，所以
		这个接口在win32版上会自动根据uid创建一个目录
		返回，具体看代码。如果目录是可以共享的，里面
		的文件已经用uid进行区分了，那么请使用
		getShareUserDataPath 接口，如何使用全局搜索下
		代码即可获取

		目前这个接口只有 回流玩家和福利签到两个系统使用
  ]]
function getUserDataPath()
	if isWin32() or isMac() then
		local uid
		if gamedata.UserProp and gamedata.UserProp.myid then
			uid = gamedata.UserProp.myid
		end
		if uid then
			local dir = cc.FileUtils:getInstance():getWritablePath()..uid.."/"
			require "preload.utils"
			local wtattr = preload.utils.lfs_attributes(dir)
			if not wtattr then utils.lfs_mkdir(dir) end

			-- 这样做保险点
			if preload.utils.lfs_attributes(dir) then
				return dir
			else
				return cc.FileUtils:getInstance():getWritablePath()
			end
		else
			--assert(uid, "win32 getUserDataPath uid is nil")
			return cc.FileUtils:getInstance():getWritablePath()
		end
	else
		return cc.FileUtils:getInstance():getWritablePath()
	end
end

--[[
	程序同学请注意：
	不管什么平台，这个借口返回的都是根据uid生成的目录
  ]]
function getPrivateUserDataPath()
	require "gamedata"
	local uid
	if gamedata.UserProp and gamedata.UserProp.myid then
		uid = gamedata.UserProp.myid
	end
	if uid then
		local dir = cc.FileUtils:getInstance():getWritablePath()..uid.."/"
		require "preload.utils"
		local wtattr = preload.utils.lfs_attributes(dir)
		if not wtattr then utils.lfs_mkdir(dir) end

		-- 这样做保险点
		if preload.utils.lfs_attributes(dir) then
			return dir
		else
			return cc.FileUtils:getInstance():getWritablePath()
		end
	else
		return cc.FileUtils:getInstance():getWritablePath()
	end
end

function getShareUserDataPath()
	return cc.FileUtils:getInstance():getWritablePath()
end

function getExternalDirectory( ... )
	if isMac() then
		return cc.FileUtils:getInstance():getWritablePath()
	end
	if not CUtils:getInstance().getExternalDirectory then
		return cc.FileUtils:getInstance():getWritablePath()
	else
		return CUtils:getInstance():getExternalDirectory()
	end
end

function GetColorTableByNumber(number)
	local r = math.floor(number / 65536)
	number = number % 65536
	local g = math.floor(number / 256)
	local b = number % 256
	return {r=r, g=g, b=b}
end


function GetColorNumberByTable(rgb)
	return rgb.r*65536 + rgb.g*256 + rgb.b
end

function Shuffle(s, e)
	if not s then s = 1 end
	if not e then e = 1 end
	if s == e then return {s} end
	if s > e then 
		local temp = e
		local e = s
		s = temp
	end
	-- s = math.floor(s)
	-- e = math.floor(e)
	local number = s - e + 1
	local res = {}
	for i = s, e do
		table.insert(res, i)
	end
	array.shuffle(res)
	return res
end

--获取当前主线程id
function getMainThreadID()
	if _G.MAIN_THREADID == nil then
		if CUtils:getInstance().getCurrentThreadID then
			_G.MAIN_THREADID = CUtils:getInstance():getCurrentThreadID()
		end
	end
	return _G.MAIN_THREADID
end

-- 判断是否支持弹出unisdk提供的通用的用户协议窗口
function isSdkProtocolValid()
	if SdkControllerDelegate:getInstance().showProtocolView and (not utils.isWeb()) and (not utils.isMac()) then
		return true
	else
		return false
	end
end

local PLATFORM = cc.Application:getInstance():getTargetPlatform()
function isIos()
	return PLATFORM == cc.PLATFORM_OS_IPHONE or PLATFORM == cc.PLATFORM_OS_IPAD
end

function isAppStore()
	return isIos()
end

function isChannel()
	return getChannel() ~= "netease"
end

function isNetease()
	if getChannel() == "netease" then
		return true
	end
	if isDeskTop() and _G.login_channel == "netease"  then
		return true
	end
	return false
end

function isAndroid()
	return PLATFORM == cc.PLATFORM_OS_ANDROID
end

function isWin32()
	return PLATFORM == cc.PLATFORM_OS_WINDOWS
end

function canUseMouseFeature()
	return (isMac() or isWin32()) and ccui.Widget.addMouseEventListener ~= nil
end

function isMac()
	return PLATFORM == cc.PLATFORM_OS_MAC
end

function isMobile()
	return isIos() or isAndroid()
end

function isiPad()
	return misc.misc.getDetailDeviceModel() == 'iPad'
end

--check whether is web platform
--因为isWeb这个函数被用烂了，所以基本isWeb等效于isWin32()，所以这里不做变动
function isWeb()
	return SdkControllerDelegate:getInstance():getPlatform() == "web"
end

function isRealWeb()
	if SdkControllerDelegate:getInstance().getRunningType ~= nil and SdkControllerDelegate:getInstance():getRunningType() == "web" then
		return true
	end
	return false
end

function isIndependent()
	if SdkControllerDelegate:getInstance().getRunningType ~= nil and SdkControllerDelegate:getInstance():getRunningType() == "independent" then
		return true
	end
	return false
end

function isWinWeb()
	return isWin32() and isWeb()
end

function isDeskTop()
	return isWinWeb() or isMac()
end

function isVoiceUseFmod()
	return isWin32() or isMac() and (CSound ~= nil)
end

function isWebScannerIos()
	require "login.sdkcontroller"
	return isWeb() and _G.GWebClientType == login.sdkcontroller.WEB_CLIENT_TYPE_IOS
end

function isMacScannerIos()
	require "login.sdkcontroller"
	return isMac() and _G.GWebClientType == login.sdkcontroller.WEB_CLIENT_TYPE_IOS
end

function isWebScannerAndroid()
	require "login.sdkcontroller"
	return isWeb() and _G.GWebClientType == login.sdkcontroller.WEB_CLIENT_TYPE_ANDROID
end

function isMacScannerAndroid()
	require "login.sdkcontroller"
	return isMac() and _G.GWebClientType == login.sdkcontroller.WEB_CLIENT_TYPE_ANDROID
end

function isWebForIOS()
	if isWebScannerIos() then
		return true
	end
	return false
end

function isMacForIOS()
	if isMacScannerIos() then
		return true
	end
	return false
end

function isWebForAndroid()
	if isWebScannerAndroid() then
		return _G.login_channel == "netease"
	end
	return false
end

function isMacForAndroid()
	if isMacScannerAndroid() then
		return _G.login_channel == "netease"
	end
	return false
end

function isWebForAndOther()
	if isWebScannerAndroid() then
		return _G.login_channel ~= "netease"
	end
	return false
end

function isMacForAndOther()
	if isMacScannerAndroid() then
		return _G.login_channel ~= "netease"
	end
	return false
end

-- 是否是安卓平台，包括安卓移动端(官方、渠道)、安卓设备扫码
function isAndroidPlatform()
	return isAndroid() or isWebScannerAndroid()
end

-- 是否走uniserver 扫码支付方式进行充值
function isUnisdkQrcodeCharge()
	return (isWebForIOS() or (isWinWeb() and _G.login_channel ~= "netease")) or (isMacForIOS() or (isMac() and _G.login_channel ~= "netease"))
end

function isVoiceAvailiable()
	return isMobile() or isVoiceUseFmod()
end

function isHaveChannelScanner()
	return SdkControllerDelegate:getInstance().openQRScannerChannel
end

IS_FIRST_TIME = nil
function isFirstTimeLaunch()
	if IS_FIRST_TIME ~= nil then
		return IS_FIRST_TIME
	end
	IS_FIRST_TIME = cc.UserDefault:getInstance():getBoolForKey("IsFirstTime", true)
	if IS_FIRST_TIME == true then
		user_default.setBoolForKey("IsFirstTime", false)
	end
	return IS_FIRST_TIME
end

local _enableDistanceField = nil
function isEnableDistanceField()
	if _enableDistanceField == nil then
		_enableDistanceField = cc.Label:isEnableDistanceField()
	end
	return _enableDistanceField
end

function ShowWizard(flag)
	if flag == nil then flag = SHOW_WIZARD end
	if not flag then return end
	pcall(function()
		local wizard = ui_mgr.Open("wizard.wizardcmd.CWizardCmd")
		wizard:setPositionPercent({x=0, y=0})
	end)
end

function GetDegree(startPos, endPos)
	local deltaX = endPos.x - startPos.x
	local deltaY = endPos.y - startPos.y
	return math.atan2(deltaX, deltaY)*180/math.pi
end

function GetDegree2(startPos, endPos)
	local deltaX = endPos.x - startPos.x
	local deltaY = endPos.y - startPos.y
	return math.atan2(deltaY, deltaX)*180/math.pi
end

function rectContainsPoint( rect, point )
    local ret = false
    
    if (point.x >= rect.x) and (point.x <= rect.x + rect.width) and
       (point.y >= rect.y) and (point.y <= rect.y + rect.height) then
        ret = true
    end

    return ret
end

function isPointInRect( point, rect)
	--point is in rect, but not on the edge of rect
    local ret = false
    
    if (point.x > rect.x) and (point.x < rect.x + rect.width) and
       (point.y > rect.y) and (point.y < rect.y + rect.height) then
        ret = true
    end

    return ret
end

function isPointOnRect( point, rect)
	--point is on the edge of rect
    local ret = false
	local ret = rectContainsPoint(rect, point) and not isPointInRect(point, rect)    
    return ret
end

function lineKAndB(p1, p2)
	-- y = kx + b，计算k和b
	if math.abs(p1.x - p2.x) < 0.01 then
		return false
	end
	local k = (p2.y - p1.y) / (p2.x - p1.x)
	local b = p1.y - k * p1.x
	return true, k, b
end

function segmentIntersectRect(p1, p2, rect)
	require "Cocos2d"
	--p1, p2之间的线段与rect的交点
	if cc.pFuzzyEqual(p1, p2, 10) then
		return false
	end
	if isPointInRect(p1, rect) or isPointInRect(p2, rect) then
		return false
	end
	if isPointOnRect(p1, rect) and isPointOnRect(p2, rect) and (p1.x == p2.x or p1.y == p2.y) then
		--这两个点在同一条边上
		return false
	end
	if (math.abs(p1.x - p2.x) < 1 and math.abs(p1.x - rect.x) < 1) or (math.abs(p1.y - p2.y) < 1 and math.abs(p1.y - rect.y) < 1) or (math.abs(p1.x - p2.x) < 1 and math.abs(p1.x - (rect.x + rect.width)) < 1) or (math.abs(p1.y - p2.y) < 1 and math.abs(p1.y - (rect.y + rect.height)) < 1) then
		--在rect四条边的伸展线上
		return false
	end
	if math.max(p1.x, p2.x) <= rect.x or math.min(p1.x, p2.x) >= (rect.x + rect.width) or math.max(p1.y, p2.y) <= rect.y or math.min(p1.y, p2.y) >= (rect.y + rect.height) then
		return false
	end
	if math.abs(p1.x - p2.x) < 0.3 then
		--当做p1.x == p2.x的情况
		if math.min(p1.x, p2.x) < rect.x or math.max(p1.x, p2.x) > rect.x + rect.width then
			return false
		end
		return true, cc.p(p1.x, rect.y), cc.p(p2.x, rect.y + rect.height)
	end
	local _, k, b = lineKAndB(p1, p2)
	if not k then return false end
	local count = 0
	local leftY = k * rect.x + b
	local t = {}
	if leftY >= rect.y and leftY <= rect.y + rect.height then
		count = count + 1
		t[count] = cc.p(rect.x, leftY)
	end
	local rightY = k * (rect.x + rect.width) + b
	if rightY >= rect.y and rightY <= rect.y + rect.height then
		count = count + 1
		t[count] = cc.p(rect.x + rect.width, rightY)
		if count >= 2 then
			return true, t[1], t[2]
		end
	end
	local bottomX = (rect.y - b) / k
	local upX = (rect.y + rect.height - b) / k
	local tx = {{x = bottomX, y = rect.y,} , {x = upX, y = rect.y + rect.height,}, }
	for k, v in ipairs(tx) do
		if v.x >= rect.x and v.x <= rect.x + rect.width then
			local toAdd = true 
			for k1, v1 in ipairs(t) do
				if cc.pFuzzyEqual(v, v1, 10) then
					toAdd = false
					break
				end
			end
			if toAdd then
				count = count + 1
				t[count] = v
				if count >= 2 then
					return true, t[1], t[2]
				end
			end
		end
	end
	return false
end

function cleanRes(target_path)
	return preload.utils.cleanRes(target_path)
end

function cleanAbsRes(target_path)
	return preload.utils.cleanAbsRes(target_path)
end

function cleanResInWritablePath(target_path)
	return preload.utils.cleanResInWritablePath(target_path)
end

function lfs_attributes(filepath, attributename)
	return preload.utils.lfs_attributes(filepath, attributename)
end

function lfs_chdir(filepath)
	return preload.utils.lfs_chdir(filepath)
end

function lfs_currentdir()
	return preload.utils.lfs_currentdir()
end

function lfs_dir(filepath)
	return preload.utils.lfs_dir(filepath)
end

function lfs_mkdir(filepath)
	return preload.utils.lfs_mkdir(filepath)
end

function lfs_rmdir(filepath)
	return preload.utils.lfs_rmdir(filepath)
end

function lfs_touch(filepath, atime, ctime)
	return preload.utils.lfs_touch(filepath, atime, ctime)
end


hideAndroidNavigationBarTimerIdx = nil
function delayHideAndroidNavigationBar()
	if not utils.isAndroid() then
		return
	end
	require "timer"
	if hideAndroidNavigationBarTimerIdx then
		timer.unRegisterTimer(hideAndroidNavigationBarTimerIdx)
		hideAndroidNavigationBarTimerIdx = nil
	end
	hideAndroidNavigationBarTimerIdx = timer.registerTimer(function()
		CUtils:getInstance():hideAndroidNavigationBar()
	end, 3, 1)
end

function getShapeDirectionAmount(shape)
	if shape <= 50 then		-- only hero have 8 directions
		return 8
	end
	return 4
end


local CANNOT_EDIT_IMAGE_DEVICE = {
	["motorola/ME865"] = true,
	["Amazon/KFTHWI"] = true,
}
function cannotEditImageDevice()
	local model = misc.misc.getDeviceModel()
	return CANNOT_EDIT_IMAGE_DEVICE[model]
end

CANNOT_USE_NEW_CAMERA_DEVICE = {
	["Xiaomi/MI 5"] = true,
	["Xiaomi/MI 5c"] = true,
	["Xiaomi/MI 5C"] = true,
}
function useNewCamera()
	local model = misc.misc.getDeviceModel()
	return isNeox() and isMobile() and not CANNOT_USE_NEW_CAMERA_DEVICE[model]
end

function getImageFromDevice(typeId, outName, width, height, needEditing, signalType)
	if (isWeb() or isMac()) and typeId == 2 then
		if isWeb() then
			if isIndependent() then
				require "view.message"
				view.message.ShowBubbleMessage("桌面版不支持拍照上传哦!")
			else
				require "view.message"
				view.message.ShowBubbleMessage("网页版不支持拍照上传哦!")
			end
		elseif isMac() then
			require "view.message"
			view.message.ShowBubbleMessage("Mac版不支持拍照上传哦!")
		end
		return
	end

	if isMac() then
		require "view.message"
		view.message.ShowBubbleMessage("Mac版不支持照片上传哦!")
		return
	end

	require "view.dlgsetting"
	if view.dlgsetting.CURRENT_RECORD_STATUS ~= view.dlgsetting.RECORD_STATUS_NORMAL then
		view.message.ShowBubbleMessage("请先关掉录屏功能在来哦!")
		return
	end

	originNeedEditing = needEditing
	if needEditing then
		require "misc.misc"
		if cannotEditImageDevice() then
			needEditing = false
		end
	end
	-- 注意了：这里要修改代码，要区分清楚版本号和渠道，不要搞错了！！！！！
	local channel = SdkControllerDelegate:getInstance():getChannel()
	if typeId == 2 and useNewCamera() then
		-- 使用回传纹理实现的拍照
		require "cameralib"
		if width == 0 or height == 0 then
			originNeedEditing = false
		end
		cameralib.openImgPicker({outName = outName, width = width, height = height, needEditing = originNeedEditing})
	elseif isIos() and gamedata.GetIosApkVersionNumber() >= 10470 then
		require "view.zone"
		CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing, 2)
	elseif utils.isAndroid() then
		-- flyme 有个坑
		if channel == "flyme" then
			-- 1.55以后就可以用新接口了
			if gamedata.GetAndroidApkVersionNumber() >= 10550 then
				CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing, 0)
			else
				CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing)
			end
		-- 别的渠道
		else
			if gamedata.GetAndroidApkVersionNumber() >= 10510 then
				CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing, 0)
			else
				CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing)
			end
		end

	elseif isWeb() or isMac() then
		if CUtils:getInstance().getImageFromDeviceV2 then
			CUtils:getInstance():getImageFromDeviceV2(typeId, outName, width, height, needEditing, 0)
		else
			CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing, 0)
		end
	else
		CUtils:getInstance():getImageFromDevice(typeId, outName, width, height, needEditing)
	end
	
	require "application"
	application.setImageSignaltype(signalType) -- 设置回调信号(必须)
end

-------------------- jail break checker -------------------
function hasCydia()
	return cc.FileUtils:getInstance():isFileExist("/Applications/Cydia.app")
end

function hasAPT()
	return cc.FileUtils:getInstance():isFileExist("/private/var/lib/apt/")
end

function successCallSystem()
	require "os"
	local ret = os.execute("ls")
	return ret ~= -1
end

function testLibEnv()
	local env = os.getenv("DYLD_INSERT_LIBRARIES")
	return env ~= nil
end

function isJailBreak()
	local r1 = hasCydia()
	local r2 = hasAPT()
	--local r3 = successCallSystem()
	local r4 = testLibEnv()
	return r1 or r2 or r4
end

function compareVer(v1, v2, needsub)
	local function str2Ver(ver)
		local v = string.split(ver, ".")
		for idx, d in ipairs(v) do
			v[idx] = tonumber(d)
		end
		return v
	end
	if needsub == nil then needsub = true end
	if type(v1) == "string" then v1 = str2Ver(v1) end
	if type(v2) == "string" then v2 = str2Ver(v2) end
	local function cmp(n1, n2)
		if n1 == n2 then return 0 end
		if n1 > n2 then return 1 end
		if n1 < n2 then return -1 end
	end
	if v1[1] ~= v2[1] then return cmp(v1[1], v2[1]) end
	if v1[2] ~= v2[2] then return cmp(v1[2], v2[2]) end
	--ver3 is subver
	if v1[3] ~= v2[3] and needsub then return cmp(v1[3], v2[3]) end
	return 0
end

function len(op)
	if op == nil then return 0 end
	if type(op) == "string" then
		return string.len(op)      -- primitive string length
	else
		local mt = getmetatable(op)
		local h = mt and mt.__len
		if h then
			return (h(op))       -- call handler with the operand
		elseif type(op) == "table" then
			return #op              -- primitive table length
		else  -- no handler available: error
			return 0
		end
	end
end

function getFullPathForFilename(filepath)
	if cc.FileUtils:getInstance().realFullPathForFilename then 
		--[[
		if string.find(filepath, "^http") then
			--按照原来的语义，找不到应该返回filepath，但是realFullPathForFilename返回的是HashRes/filepath
			--http的地址，就不要转换了
			return filepath
		end
		]]
		local ret = cc.FileUtils:getInstance():realFullPathForFilename(filepath)
		--[[
		if isAndroid() and string.find(ret, "^HashRes") then
			--按照fullPathForFilename的语义，如果在android整包应该返回assets/xxx，现在直接返回xxx
			ret = "assets/" .. ret
		end
		]]
		return ret
	else
		return cc.FileUtils:getInstance():fullPathForFilename(filepath)
	end 
end

function getNetworkType()
	return CUtils:getInstance():getNetworkType()
end

function getISP()
	return CUtils:getInstance():getISP()
end

-- lua取整
function getIntPart(x)
	if x <= 0 then
	   return math.ceil(x)
	end

	if math.ceil(x) == x then
	   x = math.ceil(x)
	else
	   x = math.ceil(x) - 1;
	end

	return x
end

ENGINE_FEATURES = {}
function isEngineFeatureSupported(key, platform)
	local key_full = (key or "none") .. (platform or "")
	if ENGINE_FEATURES[key_full] == nil then
		if not CUtils:getInstance().isEngineFeatureSupported then
			ENGINE_FEATURES[key_full] = false
		else
			ENGINE_FEATURES[key_full] = CUtils:getInstance():isEngineFeatureSupported(key, platform)
		end
	end

	return ENGINE_FEATURES[key_full]
end

function showEmbeddedServiceView(show)
	if CUtils:getInstance().showEmbeddedServiceView then
		cc.UserDefault:getInstance():setBoolForKey("SHOW_EMBEDDED_SERVICE_VIEW", show)
		return CUtils:getInstance():showEmbeddedServiceView(show)
	end
end

IsSupportNpkm = nil
function supportNpkm()
	if IsSupportNpkm == nil then
		IsSupportNpkm = false
		if isAndroid() then
			require "gamedata"
			if gamedata.GetApkVersionNumber() >= 11230 then
				--1.123.0及以上的可以支持npkm
				IsSupportNpkm = true
			end
		end
	end
	return IsSupportNpkm
end

function isEngineSupportSetRectOffsetScale()
	return cc.AnimateWithNeoxNode.setOffsetInfoV2 and true
end

-- 是否启用合批优化
function isEnableBatchOptimize()
	return CUtils:getInstance().isEnableBatchOptimize and CUtils:getInstance():isEnableBatchOptimize()
end

function setEnableBatchOptimize(flag)
	if CUtils:getInstance().setEnableBatchOptimize then
		CUtils:getInstance():setEnableBatchOptimize(flag)
	end
end

-- NeoX 版需要在截屏时关闭合批优化，不然某些界面会出现层级问题
-- win32版的NeoX也需要
function needDisableBatchOptimizeWhenTakeScreenShot()
	return isNeox()
end

--[[
size, 
pos, --optional
wholescreen, --optional(强制全屏，除了外置聊天框，即把全屏缩放到size里面)
offset, --optional
ExtInst, -- optional
node_path, --optional
filename, --no suffix like .jpg or .png, just name
success_cb, --optional
fail_cb, --optional
pixel_format --optional
not_save_file, --optional, 不保存到文件
--]]
gSavePicTimer = nil
gSavePicTimeoutTimer = nil
SCREENSHOT_PATH = "Screenshot/"
DEBUG = false
function takeScreenShot(data)
	--save to utils.getShareUserDataPath() .. SCREENSHOT_PATH
	if gSavePicTimer or gSavePicTimeoutTimer then
		require "view.message"
		view.message.ShowBubbleMessage("操作太频繁")
		return
	end
	--local externalChat = false
	local externalChatWidth = 0
	if _G.ChatWindowLayout and _G.ChatWindowLayout ~= 0 then
		externalChatWidth = _G.CHATWIN_EXT_WIDTH
		--externalChat = true
		--require "game"
		--game.requestWinLayoutChange(0)
	end
	--创建RenderTexture并且设置合适的virtualviewpoint
	if utils.isAndroid() and cc.RenderTexture.setCheckSupportGL2 then
		cc.RenderTexture:setCheckSupportGL2(true)
	end
	local size = data.size
	local pixel_format = data.pixel_format or cc.TEXTURE2_D_PIXEL_FORMAT_RGB_A8888
	local renderer = cc.RenderTexture:create(size.width, size.height, pixel_format, gl.DEPTH24_STENCIL8_OES)
	if utils.isAndroid() and cc.RenderTexture.setCheckSupportGL2 then
		cc.RenderTexture:setCheckSupportGL2(false)
	end
	local pos = data.pos or { x = 0.5*(RealScreenWidth-size.width), y = 0.5*(RealScreenHeight-size.height), }
	local offset = data.offset
	if offset then
		pos.x = pos.x + offset.x
		pos.y = pos.y + offset.y
	end

	-- NeoX 版需要在截屏时关闭合批优化，不然某些界面会出现层级问题（关闭后需要手动恢复）
	local was_enable_batch_opt = isEnableBatchOptimize()
	local need_disable_batch_opt = needDisableBatchOptimizeWhenTakeScreenShot()
	if need_disable_batch_opt then
		setEnableBatchOptimize(false)
	end

	--效率较低版本begin
	renderer:setKeepMatrix(true)
		--如果whole screen就无视
	if data.wholescreen then
		if externalChatWidth and externalChatWidth > 0 then
			local rtBegin = {x=0, y=0}
			local fullRect = {x=0, y=0, width=size.width*(1+externalChatWidth/RealScreenWidth), height=size.height}
			local fullViewPort = fullRect
			renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
		end
	else
		local rtBegin = {x =  pos.x, y = pos.y, width = RealScreenWidth, height = RealScreenHeight} --相当于scene往左下角平移
		local fullRect = {x = 0, y = 0, width = RealScreenWidth, height = RealScreenHeight}
		local fullViewPort = {x = 0, y = 0, width = RealScreenWidth + externalChatWidth, height = RealScreenHeight}
		renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
	end
	renderer:begin()
	scene.Inst:visit()
	if data.ExtInst then
		data.ExtInst:visit()
	end
	renderer:endToLua()
	cc.Director:getInstance():getRenderer():render()
	timer.registerTimer(function()
		if renderer and renderer:isCCObjValid() and renderer.BackupDataForDeviceLost then
			renderer:BackupDataForDeviceLost()
		end
	end, 0, 1)
	--效率较低版本end

	--效率较高版本begin
	-- local rtBegin = {x =  0, y = 0, width = size.width, height = size.height,} --
	-- local fullRect = {x = 0, y = 0, width = size.width, height = size.height, }
	-- local fullViewPort = {x = 0, y = 0, width = size.width, height = size.height, }
	-- renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
	-- renderer:begin()
	-- scene.Inst:setPosition({x=-1*pos.x, y=-1*pos.y}) --在这里往坐下平移
	-- scene.Inst:visit()
	--if data.ExtInst then
	--	data.ExtInst:visit()
	--end
	-- renderer:endToLua()
	-- cc.Director:getInstance():getRenderer():render()
	-- scene.Inst:setPosition({x=0, y=0}) --绘制完恢复不然会有很奇怪的bug，好像整个游戏的viewport被改成size了
	--效率高版本end

	-- 还原合批优化选项
	if need_disable_batch_opt then
		setEnableBatchOptimize(was_enable_batch_opt)
	end

	if data.not_save_file then
		--如果不需要保存到文件
		return renderer
	end

	--保存到文件
	local useJpg = true
	local useHighQuality = (data.useHighQuality == true)
	require "share"
	if (utils.isAndroid() and platform ~= share.QQ_PLATFORM) or data.forcePng then
		--android的低版本系统图片分辨率低，所以用png
		--qq分享png会失败，所以不要用
		--除了家园，别的分享没有这种要求
		useJpg = false
	end
	local dirpath = getShareUserDataPath() .. (data.node_path or SCREENSHOT_PATH)
	local filename = useJpg and (data.filename .. ".jpg") or (data.filename .. ".png")

	saveRendererToFile(renderer, filename, dirpath, useJpg, useHighQuality, data.success_cb, data.fail_cb)

	return renderer
end
function takeScreenShot_temp_fix(data)
	--save to utils.getShareUserDataPath() .. SCREENSHOT_PATH
	if gSavePicTimer or gSavePicTimeoutTimer then
		require "view.message"
		view.message.ShowBubbleMessage("操作太频繁")
		return
	end
	--local externalChat = false
	local externalChatWidth = 0
	if _G.ChatWindowLayout and _G.ChatWindowLayout ~= 0 then
		externalChatWidth = _G.CHATWIN_EXT_WIDTH
		--externalChat = true
		--require "game"
		--game.requestWinLayoutChange(0)
	end
	--创建RenderTexture并且设置合适的virtualviewpoint
	if utils.isAndroid() and cc.RenderTexture.setCheckSupportGL2 then
		cc.RenderTexture:setCheckSupportGL2(true)
	end
	local size = data.size
	local pixel_format = data.pixel_format or cc.TEXTURE2_D_PIXEL_FORMAT_RGB_A8888
	local renderer = cc.RenderTexture:create(size.width, size.height, pixel_format, gl.DEPTH24_STENCIL8_OES)
	if utils.isAndroid() and cc.RenderTexture.setCheckSupportGL2 then
		cc.RenderTexture:setCheckSupportGL2(false)
	end
	local pos = data.pos or { x = 0.5*(FullScreenWidth-size.width), y = 0.5*(FullScreenHeight-size.height), }
	local offset = data.offset
	if offset then
		pos.x = pos.x + offset.x
		pos.y = pos.y + offset.y
	end

	-- NeoX 版需要在截屏时关闭合批优化，不然某些界面会出现层级问题（关闭后需要手动恢复）
	local was_enable_batch_opt = isEnableBatchOptimize()
	local need_disable_batch_opt = needDisableBatchOptimizeWhenTakeScreenShot()
	if need_disable_batch_opt then
		setEnableBatchOptimize(false)
	end

	--效率较低版本begin
	renderer:setKeepMatrix(true)
		--如果whole screen就无视
	if data.wholescreen then
		if externalChatWidth and externalChatWidth > 0 then
			local rtBegin = {x=0, y=0}
			local fullRect = {x=0, y=0, width=size.width*(1+externalChatWidth/ScreenWidth), height=size.height}
			local fullViewPort = fullRect
			renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
		end
	else
		local rtBegin = {x =  pos.x, y = pos.y, width = size.width, height = size.height} --相当于scene往左下角平移
		local fullRect = {x = 0, y = 0, width = size.width, height = size.height}
		local fullViewPort = {x = 0, y = 0, width = size.width + externalChatWidth, height = size.height}
		renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
	end
	renderer:begin()
	scene.Inst:visit()
	if data.ExtInst then
		data.ExtInst:visit()
	end
	renderer:endToLua()
	cc.Director:getInstance():getRenderer():render()
	timer.registerTimer(function()
		if renderer and renderer:isCCObjValid() and renderer.BackupDataForDeviceLost then
			renderer:BackupDataForDeviceLost()
		end
	end, 0, 1)
	--效率较低版本end

	--效率较高版本begin
	-- local rtBegin = {x =  0, y = 0, width = size.width, height = size.height,} --
	-- local fullRect = {x = 0, y = 0, width = size.width, height = size.height, }
	-- local fullViewPort = {x = 0, y = 0, width = size.width, height = size.height, }
	-- renderer:setVirtualViewport(rtBegin, fullRect, fullViewPort)
	-- renderer:begin()
	-- scene.Inst:setPosition({x=-1*pos.x, y=-1*pos.y}) --在这里往坐下平移
	-- scene.Inst:visit()
	--if data.ExtInst then
	--	data.ExtInst:visit()
	--end
	-- renderer:endToLua()
	-- cc.Director:getInstance():getRenderer():render()
	-- scene.Inst:setPosition({x=0, y=0}) --绘制完恢复不然会有很奇怪的bug，好像整个游戏的viewport被改成size了
	--效率高版本end

	-- 还原合批优化选项
	if need_disable_batch_opt then
		setEnableBatchOptimize(was_enable_batch_opt)
	end

	if data.not_save_file then
		--如果不需要保存到文件
		return renderer
	end

	--保存到文件
	local useJpg = true
	local useHighQuality = (data.useHighQuality == true)
	require "share"
	if (utils.isAndroid() and platform ~= share.QQ_PLATFORM) or data.forcePng then
		--android的低版本系统图片分辨率低，所以用png
		--qq分享png会失败，所以不要用
		--除了家园，别的分享没有这种要求
		useJpg = false
	end
	local dirpath = getShareUserDataPath() .. (data.node_path or SCREENSHOT_PATH)
	local filename = useJpg and (data.filename .. ".jpg") or (data.filename .. ".png")

	saveRendererToFile(renderer, filename, dirpath, useJpg, useHighQuality, data.success_cb, data.fail_cb)

	return renderer
end

function saveRendererToFile(renderer, filename, dirpath, useJpg, useHighQuality, success_cb, fail_cb)
	require "preload.utils"
	local att = preload.utils.lfs_attributes(dirpath)
	if not att then
		preload.utils.lfs_mkdir(dirpath)
	end

	local finalpath = dirpath .. filename
	print("====testShot finalpath: ", finalpath)
	local attr = preload.utils.lfs_attributes(finalpath)
	if attr then
		preload.utils.removeFile(finalpath)
	end
	local tmppath = cc.FileUtils:getInstance():getWritablePath() .. filename 
	attr = preload.utils.lfs_attributes(tmppath)
	if attr then
		preload.utils.removeFile(tmppath)
	end

	-- 锤子手机特殊处理
	local wasCheckSizeWhenSave = renderer.isCheckSizeWhenRTSaveImage and renderer:isCheckSizeWhenRTSaveImage() or false
	if utils.IsNeedCheckSizeWhenRTSaveImage() and renderer.setCheckSizeWhenRTSaveImage then
		renderer:setCheckSizeWhenRTSaveImage(true)
	end

	if useJpg then
		--1.53.0往后就都支持指定quality的saveToFile了
		if useHighQuality and gamedata.GetApkVersionNumber() > 10530 then
			renderer:saveToFile(filename, cc.IMAGE_FORMAT_JPEG, 85, true) 
		else
			renderer:saveToFile(filename, cc.IMAGE_FORMAT_JPEG) 
		end
	else
		renderer:saveToFile(filename, cc.IMAGE_FORMAT_PNG, false)
	end
	
	gSavePicTimer = timer.registerTimer(function()
		print("截图检测")
		if utils.CheckFileExist(tmppath) then
			print("截图检测 -- 截图成功")
			if gSavePicTimer then
				timer.unRegisterTimer(gSavePicTimer)
				gSavePicTimer = nil
			end
			if gSavePicTimeoutTimer then
				timer.unRegisterTimer(gSavePicTimeoutTimer)
				gSavePicTimeoutTimer = nil
			end
			local ret, err, errno = preload.utils.lfs_rename(tmppath, finalpath)
			print(ret and "截图检测 -- 移动文件成功" or "截图检测 -- 移动文件失败")
			if ret and utils.CheckFileExist(finalpath) then
				print("截图检测 -- 保存至Screenshot成功")
				if success_cb then
					success_cb(dirpath, filename)
				end
				print("=====save success")
			else
				print("截图检测 -- 保存至Screenshot失败")
				if fail_cb then
					fail_cb()
				end
			end
			--if externalChat then
				--require "game"
				--game.requestWinLayoutChange(1)
			--end
		end
	end, 0.5, 0)
	gSavePicTimeoutTimer = timer.registerTimer(function()
		gSavePicTimeoutTimer = nil
		if gSavePicTimer then
			timer.unRegisterTimer(gSavePicTimer)
			gSavePicTimer = nil
		end
		if not utils.CheckFileExist(tmppath) and not utils.CheckFileExist(finalpath) then
			print("截图超时 -- 失败")
			if fail_cb then
				fail_cb()
			end
		elseif utils.CheckFileExist(finalpath) then
			print("截图超时 -- 成功")
			if success_cb then
				success_cb(dirpath, filename)
			end
		elseif utils.CheckFileExist(tmppath) then
			local ret, err, errno = preload.utils.lfs_rename(tmppath, finalpath)
			print(ret and "截图超时 -- 移动文件成功" or "截图超时 -- 移动文件失败")
			if ret and utils.CheckFileExist(finalpath) then
				print("截图超时 -- 保存至Screenshot成功")
				if success_cb then
					success_cb(dirpath, filename)
				end
			else
				print("截图超时 -- 保存至Screenshot失败")
				if fail_cb then
					fail_cb()
				end
			end
		end
		--if externalChat then
			--require "game"
			--game.requestWinLayoutChange(1)
		--end
		print("=====save fail time out")
	end, 5, 1)
end

----------------------------------------
-- 通用调java和oc静态函数接口
----------------------------------------
-- 调用java函数
-- 例子: callJavaFunc("org.cocos2dx.lua.AppActivity",
--        "lua_ach_post_script_error", 
--        {identify, content}, -- 注意这里参数不能有key
--        "(Ljava/lang/String;Ljava/lang/String;)V")
function callJavaFunc(className, methodName, args, sig)
  	local luaj = require "luaj"

  	if not luaj.callStaticMethod then print("util luaj module not init") return end
  	local ok, ret = luaj.callStaticMethod(className, methodName, args, sig)
  	if ok then return ret end
  	return nil
end
-- 调用obj c函数
-- 例子: callOCFunc("AppController",
--        "luaChPostScriptError",
--        {identify = identify, content = content}) -- 注意这里参数要有key
function callOCFunc(className, methodName, args)
  	local luaoc = require "luaoc"

  	if not luaoc.callStaticMethod then print("util luaoc module not init") return end
  	local ok, ret = luaoc.callStaticMethod(className, methodName, args)
  	if ok then return ret end
  	return nil
end


-------------------------------------------------

function getUrlLoginOptions()
	local optionsStr = preload.utils.getOpenOptions()
	if isIos() then
		if string.find(optionsStr, "NSUserActivityTypeBrowsingWeb") == nil then
			return nil
		end
	else
		if string.find(optionsStr, "neteasemy") == nil then
			return nil
		end
	end
	local index = string.find(optionsStr, "?")
	if index == nil then
		return nil
	end
	local str = string.sub(optionsStr, index+1)
	local t = string.split(str, "&")
	local ret = {}


	for idx, info in ipairs(t) do
		local infotab = string.split(info, "=")
		ret[infotab[1]] = infotab[2]
	end
	return ret
end

function isInPortraitChatAddon()
	return ui_mgr.IsOpen("chat.chatspaddon.CChatSPAddonMain")
end

function isInPortraitModule()
	return ui_mgr.IsOpen("spview.spmain.CSPMain")
end

function isShowPortraitBtnInAndroid()
	if not isNeox() then return false end
	
	if PLATFORM == cc.PLATFORM_OS_ANDROID then
		require "misc.misc"
		if misc.misc.isEmu() == 1 then
			return false
		end
		return not misc.misc.isPad()
	end
	return false
end

-- 是否显示竖屏按钮 目前只对iOS手机开放
function isShowPortraitBtn()
	return PLATFORM == cc.PLATFORM_OS_IPHONE or isShowPortraitBtnInAndroid()
end

-- 竖屏模块间跳转前置状态
preSPModuleData = nil
function setSPPreModuleData(data)
	preSPModuleData = data
end

function getSPPreModuleData()
	return preSPModuleData
end

-- 获取保持横版比例的长宽
function getLandscapeSceneWAndH()
	local w = math.max(_G.FullScreenWidth, _G.FullScreenHeight)
	local h = math.min(_G.FullScreenWidth, _G.FullScreenHeight)
	return w, h
end

function getSafeAreaLandscapeSceneWAndH()
	local w = math.max(_G.ScreenWidth, _G.ScreenHeight)
	local h = math.min(_G.ScreenWidth, _G.ScreenHeight)
	return w, h
end

function getRealLandscapeSceneWAndH()
	local w = math.max(_G.RealScreenWidth, _G.RealScreenHeight)
	local h = math.min(_G.RealScreenWidth, _G.RealScreenHeight)
	return w, h
end

-- 横竖屏切换函数
function LandscapeSwitchToPortrait(isLandscape, force)
	if CUtils:getInstance().switchOrientation then
		if isLandscape then
			if force then
				CUtils:getInstance():switchOrientation(LANDSCAPE_ORI)
			else
				local orientation = CUtils:getInstance():getOrientation()
				if orientation == PORTRAIT_ORI then
					CUtils:getInstance():switchOrientation(LANDSCAPE_ORI)
				end
			end
		else
			CUtils:getInstance():switchOrientation(PORTRAIT_ORI)
		end
	end
end

-- 进行横竖屏切换函数调用
function gameLandscAndPortraiSwitch()
	-- 有些情况下，不允许进行横竖屏切换
	require "view.message"
	require "view.dlgsetting"
	require "login.sdkcontroller"

	if gamedata.UserProp.iGrade < 40 then
		view.message.ShowBubbleMessage("竖屏功能将于40级开启")
		return
	end

	if (view.dlgsetting.CURRENT_RECORD_STATUS ~= view.dlgsetting.RECORD_STATUS_NORMAL) or
	    login.sdkcontroller.CCVideoIsRecording() or
	    login.sdkcontroller.IsCCOpen()
	then
		view.message.ShowBubbleMessage("录屏功能中无法切换到竖屏界面")
		return
	end

	-- 钓鱼不能进行横竖屏切换
	if ui_mgr.IsOpen("view.fishing.CFishingMain") then
		view.message.ShowBubbleMessage("钓鱼玩法中无法切换到竖屏界面")
		return
	end

	-- 运镖状态不能进行横竖屏切换
	require "view.dlgyunbiao"
	if ui_mgr.IsOpen(view.dlgyunbiao.CDlgYunbiaoRunning.Tag) then
		view.message.ShowBubbleMessage("运镖玩法中无法切换到竖屏界面")
		return
	end

	-- 卡牌不能进行横竖版切换
	if ui_mgr.IsOpen("view.mhcard.CCardPlay") then
		view.message.ShowBubbleMessage("卡牌玩法中无法切换到竖屏界面")
		return
	end
	if ui_mgr.IsOpen("huodong.mayday18.CCardPlay") then
		view.message.ShowBubbleMessage("卡牌战斗中无法切换到竖屏界面")
		return
	end

	-- 剑会天下、武神坛等等pk赛限制
	require "view.jhtx"
	if view.jhtx.isInHallEx() then
		view.message.ShowBubbleMessage("剑会天下玩法中无法切换到竖屏界面")
		return
	end

	require "view.wpk_mgr"
	if view.wpk_mgr.isPKServer() then
		view.message.ShowBubbleMessage("跨服环境中无法切换到竖屏界面")
		return
	end

	if gamedata.isInterserverFightHost() then
		view.message.ShowBubbleMessage("跨服环境中无法切换到竖屏界面")
		return
	end

	-- 结拜、婚宴、迷阵、帮战
	require "world.scenemask"
	if world.scenemask.gIsInJieBai or world.scenemask.gIsInWedding or world.scenemask.gIsInOrgMizhen or
	   world.scenemask.gIsInOrgWar
	then
		view.message.ShowBubbleMessage("该场景无法切换到竖屏界面")
		return
	end

	-- 直播
	require "mhlive.dlglive"
	if mhlive.dlglive.isInLivePlay() then
		view.message.ShowBubbleMessage("直播中无法切换到竖屏界面")
		return
	end

	-- 2017嘉年华
	if world.scenemask.gIsInSnowBall then
		view.message.ShowBubbleMessage("该场景无法切换到竖屏界面")
		return
	end

	-- 九黎场景
	require "slgorg.main"
	if slgorg.main.isInJiuLi() then
		view.message.ShowBubbleMessage("九黎玩法中无法切换到竖屏界面")
		return
	end

	if CUtils:getInstance().switchOrientation then
		LandscapeSwitchToPortrait(false)
		return true
	else
		-- 引导玩家下载iOS新包
		local msg1 = {
			msg = "少侠当前客户端版本较低，前往#G应用商店#l更新客户端版本之后即可体验全新竖版功能！",
			actions = {
				{name = LC("取消", 301)},
				{name = "前往下载", action = function()
					require "view.ios_evaluate"
					CUtils:getInstance():openUrl("itms-apps://itunes.apple.com/app/id" .. view.ios_evaluate.APP_ID)
				end, keep =false},
			},
		}
		view.message.ShowConfirmMessage(msg1, false)
		return false
	end 
end

-- 根据当前平台、渠道、手机类型关闭竖屏逻辑
local openPortraitFlag = true
local closeSPFunAppChannelT = {
	["3k_sdk"] = true,
}
local closeSPFunModelT = {
	["HUAWEI/PRA-AL00"] = true,
}
function autoCloseSPFun()
	if isAndroid() then
		-- 3k玩渠道
		if login and login.sdkcontroller then
			local model = misc.misc.getDeviceModel()
			if closeSPFunAppChannelT[login.sdkcontroller.GAppChannel] then
				--if closeSPFunModelT[model] then
					if CUtils:getInstance().setAndroidEnablePortrait then
						CUtils:getInstance():setAndroidEnablePortrait(false)
					end
					openPortraitFlag = false
				--end
			end
		end
	end
end

function isShowPortraitBtnInSpecialAndroid()
	if PLATFORM == cc.PLATFORM_OS_ANDROID then
		return openPortraitFlag
	end

	return true
end

-- 自动关闭竖屏界面切换到横屏
function autoCloseSPMain()
	if isInPortraitModule() then
		if ui_mgr.closeAllSPExtPanel then
			ui_mgr.closeAllSPExtPanel()
		end
	end

	-- 如果这里界面加多了，再到closeAllSPExtPanel里面加吧
	ui_mgr.Close("chat.chatspaddon.CChatSPAddonMain")

	ui_mgr.Close("spview.sptrade.CConfirmSPTradeGood")
	ui_mgr.Close("spview.sptrade.CConfirmSPTradeGoodAssign")
	ui_mgr.Close("spview.sptrade.CSPChatChildDetailsV1")
	ui_mgr.Close("spview.sptrade.CSPChatChildDetailsV2")
	ui_mgr.Close("spview.sptrade.CSPChatChildDetailsV3")
	ui_mgr.Close("spview.sptrade.CSPChatBeastDetail")

	if isInPortraitModule() then
		ui_mgr.Close("spview.spmain.CSPMain")
		LandscapeSwitchToPortrait(true, true)
	else
		LandscapeSwitchToPortrait(true)
	end
end

CurHeroPos = {}

function isNeox()
	return nxworld ~= nil
end

function isNeoxMhe()
	return isEngineFeatureSupported("g18_neox_mhe")
end

function isSupportCloth()
	if not utils.isNeox() then
		return false
	end

	if CUtils:getInstance().getPatchTag then
		if CUtils:getInstance():getPatchTag() == 1 then
			return false
		end
	end

	return true
end

function DYE_CONV(val)
	local dye = bit.bor(bit.lshift(val, 24), bit.lshift(val, 16), bit.lshift(val, 8), val)
	return dye 
end

function Is3DFashion(access_str)
	local ifc = require "auto.infofashion_cloth"
	if access_str then
		local strs = string.split(access_str, "|")
		local mountFashions = {}
		for k, v in ipairs(strs) do
			if #v > 0 then
				local pair = string.split(v, ":")
				local itemtype = tonumber(pair[2])
				if ifc.ClothInfo[itemtype] then
					return true
				end
			end
		end
	end
	return false
end

-- 登录服hotfix执行完后，可以提前做一些初始化
function LoadResAfterLoginHotfix()
	initShaders()
end

-- 提前初始化3d角色所需shader
-- 注意不能早于登录服hotfix之前，否则这些shader无法热更修复
function initShaders()
	if not CUtils:getInstance().createEffectTechnique or not CUtils:getInstance().getOrCreateCustomGLProgramEx then return end
	local idx = 0

	local _initShader = nil
	local shaderNum = 0
	if isNeox() and isWin32() then
		_initShader = _initShaderWin32Neox
		shaderNum = 7
	elseif isNeox() and isIos() then
		_initShader = _initShaderIosNeox
		shaderNum = 7
	elseif isNeox() and isAndroid() then
		_initShader = _initShaderAndroidNeox
		shaderNum = 11
	else
		return
	end

	timer.registerTimer(function()
		xpcall(function()
			idx = idx + 1
			_initShader(idx)
		end,
		__G__TRACKBACK__)
	end, 0.2, shaderNum)
end

function _initShaderWin32Neox(idx)
	if idx == 1 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "ALPHA_TEST_ENABLE",  "v": "UnSupported"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "TRUE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 2 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 3 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "LIGHT_ATTR_ITEM_NUM",  "v": "LIGHT_ATTR_ITEM_NUM_5"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "FALSE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 4 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 5 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexShader", "g18_PositionTextureColor.vs", "g18_paltextrans.ps", [[{ "num": 0 }]])
	elseif idx == 6 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexMaskShader", "g18_PositionTextureColor.vs", "g18_paltexmasktrans.ps", [[{ "num": 0 }]])
	elseif idx == 7 then
		CUtils:getInstance():getOrCreateCustomGLProgramEx("ShaderWeaponMaskAlpha", "g18_weapon_mask.vs", "g18_weapon_mask.ps", [[{ "num": 0 }]])
	end
end

function _initShaderIosNeox(idx)
	if idx == 1 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "ALPHA_TEST_ENABLE",  "v": "UnSupported"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "TRUE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 2 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 3 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "LIGHT_ATTR_ITEM_NUM",  "v": "LIGHT_ATTR_ITEM_NUM_5"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "FALSE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 4 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 5 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexShader", "g18_PositionTextureColor.vs", "g18_paltextrans.ps", [[{ "num": 0 }]])
	elseif idx == 6 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexMaskShader", "g18_PositionTextureColor.vs", "g18_paltexmasktrans.ps", [[{ "num": 0 }]])
	elseif idx == 7 then
		CUtils:getInstance():getOrCreateCustomGLProgramEx("ShaderWeaponMaskAlpha", "g18_weapon_mask.vs", "g18_weapon_mask.ps", [[{ "num": 0 }]])
	end
end

function _initShaderAndroidNeox(idx)
	if idx == 1 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "ALPHA_TEST_ENABLE",  "v": "UnSupported"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "TRUE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 2 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 3 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech",
[[{ "num": 5, "macros": {
"1": {"k": "LIGHT_ATTR_ITEM_NUM",  "v": "LIGHT_ATTR_ITEM_NUM_5"},
"2": {"k": "ENABLE_MATCHCOLOR",  "v": "TRUE"},
"3": {"k": "CALCULATE_WORLD_NORM_VIEW",  "v": "FALSE"},
"4": {"k": "ENABLE_SPECULAR",  "v": "TRUE"},
"5": {"k": "ENABLE_FRESNEL",  "v": "TRUE"}
}}]])
	elseif idx == 4 then
		CUtils:getInstance():createEffectTechnique("shader\\shaderpuzzle\\nolight_specular_matchcolor_alpha.fx::NeoxTech", [[{ "num": -1 }]])
	elseif idx == 5 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexShader", "g18_PositionTextureColor.vs", "g18_paltextrans.ps", [[{ "num": 0 }]])
	elseif idx == 6 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexShaderETC", "g18_PositionTextureColor.vs", "g18_paltextrans_etc.ps", [[{ "num": 0 }]])
	elseif idx == 7 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexShaderNoAlphaETC", "g18_PositionTextureColor.vs", "g18_paltextrans_noalpha_etc.ps", [[{ "num": 0 }]])
	elseif idx == 8 then
		-- CUtils:getInstance():getOrCreateCustomGLProgramEx("PaletteTexMaskShader", "g18_PositionTextureColor.vs", "g18_paltexmasktrans.ps", [[{ "num": 0 }]])
	elseif idx == 9 then
		CUtils:getInstance():getOrCreateCustomGLProgramEx("ShaderWeaponMaskAlpha", "g18_weapon_mask.vs", "g18_weapon_mask.ps", [[{ "num": 0 }]])
	elseif idx == 10 then
		CUtils:getInstance():getOrCreateCustomGLProgramEx("ShaderWeaponMaskAlphaETC", "g18_weapon_mask.vs", "g18_weapon_mask_ETC.ps", [[{ "num": 0 }]])
	elseif idx == 11 then
		CUtils:getInstance():getOrCreateCustomGLProgramEx("ShaderWeaponMaskNoAlphaETC", "g18_weapon_mask.vs", "g18_weapon_mask_NoAlphaETC.ps", [[{ "num": 0 }]])
	end
end

function IsSmartisan()
	require "misc.misc"
	local device_model = misc.misc.getDeviceModel()
	return utils.isAndroid() and device_model and string.startswith(tostring(device_model), "smartisan") and true or false
end

_IS_NEED_CHECK_SMARTISAN = nil
_IS_SMARTISAN_SAVE_POWER_MODE = nil
_NEED_CHECK_SMARTISAN_VER_MAJOR = 3
_NEED_CHECK_SMARTISAN_VER_MINOR = 6
_NEED_CHECK_SMARTISAN_VER_MICRO = 0
-- 锤子手机省电模式下保存的图片尺寸有问题
function IsNeedCheckSizeWhenRTSaveImage()
	if _IS_NEED_CHECK_SMARTISAN ~= nil then return _IS_NEED_CHECK_SMARTISAN end

	if not IsSmartisan() then
		_IS_NEED_CHECK_SMARTISAN = false
		return false
	end

	local smartisanVersion = CUtils:getInstance().getAndroidProp and CUtils:getInstance():getAndroidProp("ro.smartisan.version")
	if smartisanVersion then
		local arr = string.split(tostring(smartisanVersion), "-")
		if arr and arr[1] then
			arr2 = string.split(tostring(arr[1]), ".")
			local a1, a2, a3 = tonumber(arr2[1]), tonumber(arr2[2]), tonumber(arr2[3])
			local b1, b2, b3 = _NEED_CHECK_SMARTISAN_VER_MAJOR, _NEED_CHECK_SMARTISAN_VER_MINOR, _NEED_CHECK_SMARTISAN_VER_MICRO
			if a1 and a2 and a3 and (a1 > b1 or (a1 == b1 and (a2 > b2 or (a2 == b2 and a3 >= b3)) )) then
				_IS_NEED_CHECK_SMARTISAN = true
				return true
			end
		end
	end

	_IS_NEED_CHECK_SMARTISAN = false
	return false
end

-- 锤子手机第一次截屏保存会有问题
function IsRendererNeedSaveTwice()
	return IsNeedCheckSizeWhenRTSaveImage()
end

-- 是否是锤子手机节电模式
-- 如果是第一次调用的话，因为需要异步判断，所以会返回nil
-- 如果不是第一次调用，就不执行callback了
function IsSmartisanSavePowerMode(callback)
	if _IS_SMARTISAN_SAVE_POWER_MODE ~= nil then return _IS_SMARTISAN_SAVE_POWER_MODE end

	if not IsNeedCheckSizeWhenRTSaveImage() then
		_IS_SMARTISAN_SAVE_POWER_MODE = false
		return false
	end

	local rsw, rsh = utils.getSafeAreaLandscapeSceneWAndH()

	local renderer
	local info = {
		size = {width = rsw, height = rsh},
		filename = "tmp",  -- not using
		pixel_format = cc.TEXTURE2_D_PIXEL_FORMAT_RG_B888,
		success_cb = function()
			_IS_SMARTISAN_SAVE_POWER_MODE = false
			if renderer and renderer:isCCObjValid() then
				if renderer.isSmallSize and renderer:isSmallSize() then
					_IS_SMARTISAN_SAVE_POWER_MODE = true  -- 认为是游戏省电模式
				end
				renderer:release()
			end
			if callback then
				callback(_IS_SMARTISAN_SAVE_POWER_MODE)
			end
		end,
		fail_cb = function()
			_IS_SMARTISAN_SAVE_POWER_MODE = false  -- 没法判断
			if renderer and renderer:isCCObjValid() then
				renderer:release()
			end
			if callback then
				callback(false)
			end
		end,
	}
	renderer = utils.takeScreenShot(info)
	if not (renderer and renderer.isSmallSize) then
		_IS_SMARTISAN_SAVE_POWER_MODE = false  -- 没法判断
		return false
	end

	renderer:retain()
	return nil
end

-- 修复 mhe 包 google pixel 2 分享微博返回闪退
function CheckGooglePixel2ShareWeibo()
	require "misc.misc"
	if isAndroid() and misc.misc.getDeviceModel() == "Google/Pixel 2" then
		if CUtils:getInstance().setIsPauseWhenAndroidAppSetWindow then
			CUtils:getInstance():setIsPauseWhenAndroidAppSetWindow(true)
		end
	end
end

-- 修复部分手机从微博分享返回后，裁剪有问题
FIX_CULL_AFTER_SHARE_LST = {
	["Xiaomi/MI 8 SE"] = true,
	["Xiaomi/MI 8"] = true,
}
function FixCullingAfterShare()
	require "misc.misc"
	if FIX_CULL_AFTER_SHARE_LST[misc.misc.getDeviceModel()] then
		timer.registerTimer(function()
			scene.Inst:visit()
			cc.Director:getInstance():getRenderer():render()
		end, 2, 2)
	end
end

-- 如果不能，就可能会有层级错误，错误的地方需要 enableGroupCmd
_CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT = nil
function needFixBatchForScreenshot()
	if _CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT ~= nil then
		return _CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT
	end

	if utils.isNeox() and (not CUtils:getInstance().setEnableBatchOptimize) then
		_CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT = true
	else
		_CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT = false
	end
	return _CACHE_NEED_FIX_BATCH_FOR_SCREENSHOT
end

function isExternalChatOpen()
	if utils.isIndependent() or utils.isMac() then
		if _G.ChatWindowLayout and _G.ChatWindowLayout ~= 0 then
			return true
		else
			return false
		end
	end
	return false
end
