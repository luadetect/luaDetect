module("timer", package.seeall)
require "utils"
require "bit"


local incId = 0
local callbackList = {}


function registerTimer(callbackFunc, intervalS, times)
	if not callbackFunc or not intervalS or not times then return end
	incId = incId + 1
	local timerId = incId
	local realTimerId = nil
	local info = {
		func = callbackFunc,
		interval = intervalS,
		remain = times,
		_always = (times <= 0),
		realTimerId = 0,
	}
	callbackList[timerId] = info
	local timerKey = nil
	local function callback()
		xpcall(function()
			local timerInfo = callbackList[timerId]
			if not timerInfo then
				print("big mistake, pls check the info, just unRegisterTimer")
				cc.Director:getInstance():getScheduler():unscheduleScriptEntry(realTimerId)
				return
			end
			local realcallback = timerInfo.func
			if not timerInfo._always then
				timerInfo.remain = timerInfo.remain - 1
				if timerInfo.remain <= 0 then
					unRegisterTimer(timerId)
				end
			end
			if _G.NEED_OPEN_TIMER_PROFILE and timer_profile and timerKey then
				local timeBefore = socket.gettime()
				realcallback()
				local timeAfter = socket.gettime()
				timer_profile.AddCostTimeForTimer(timeKey, timeAfter-timeBefore)
			else
				realcallback()
			end
		end, __G__TRACKBACK__)
	end
	realTimerId = cc.Director:getInstance():getScheduler():scheduleScriptFunc(callback, intervalS, false)
	info.realTimerId = realTimerId
	return timerId
end


--取消一个定时器
function unRegisterTimer(timerId)
	if not callbackList[timerId]then
		return
	end
	local info = callbackList[timerId]
	callbackList[timerId] = nil
	cc.Director:getInstance():getScheduler():unscheduleScriptEntry(info.realTimerId)
end

function releaseAllTimers()
	print("releaseAllTimers", table.size and table.size(callbackList))
	for timerId, info in pairs(callbackList) do
		cc.Director:getInstance():getScheduler():unscheduleScriptEntry(info.realTimerId)
	end
	callbackList = {}
end

-- 单帧序列执行Timer
local FrameTimers = {}
local isFired = false
function registerSequenceFrameTimer(func)
	table.insert(FrameTimers, func)
	if not isFired then
		isFired = true
		registerTimer(function()
			for i, v in ipairs(FrameTimers) do
				v()
			end
			FrameTimers = {}
			isFired = false
		end, 0, 1)
	end
end



--增加一个延迟调用，调用check的基础控制
--只要有一个事件存在，就阻塞，默认是这种
MASK_TYPE_LEAST = 1
--只有所有事件存在才阻塞，
MASK_TYPE_MOST = 2
--事件以mask方式区分，请在这里加入新的事件MASK
LOGIN_EVENT_MASK = 1
MOVIE_PLAY_MASK = 2
SCENE_SWITCH_MASK = 4
MOVIE_CHAT_MASK = 8
RELOGIN_RES_MASK = 16
REALNAME_EVENT_MASK = 32 -- 如果需要实名认证则，则阻塞开场动画，直至关掉实名认证界面。


DelayOpsMap = {}
EventsTag = 0

function NewDelayOps(tag, masktype, func, ...)
	local arg = {...}
	local localarg = arg
	local function delayCall()
		func(unpack(localarg))
	end
	table.insert(DelayOpsMap, {delay = delayCall, tag = tag, masktype = masktype})
end


function NotifyEvent(tag)
	EventsTag = bit.bor(EventsTag, tag)
end

function CheckShouldCall(flag, masktype, tag)
	-- print("CheckShouldCall", flag, masktype, tag)
	if masktype == MASK_TYPE_MOST and flag ~= tag then
		return true
	elseif flag == 0 then
		return true
	else
		return false
	end
end


function ReleaseEvent(tag)
	if not tag then return end
	tag = math.floor(tag)
	EventsTag = bit.band(EventsTag, bit.bnot(tag))
	local delayops = DelayOpsMap
	DelayOpsMap = {}
	for idx, info in ipairs(delayops)do
		local flag = bit.band(EventsTag, info.tag)
		if CheckShouldCall(flag, info.masktype, info.tag) then
			-- print("ReleaseEvent and call func", info.tag, EventsTag, info.masktype, tostring(info.delay))
			info.delay()
		else
			table.insert(DelayOpsMap, info)
		end
	end
end

function DelayCheckCall(tag, masktype, delayornot, func, ...)
	local flag = bit.band(EventsTag, tag)
	if masktype == nil then masktype = MASK_TYPE_LEAST end
	if delayornot == nil then delayornot = true end
	if CheckShouldCall(flag, masktype, tag) then
		func(...)
	elseif delayornot then
		NewDelayOps(tag, masktype, func, ...)
	end
end

function SimpleDelayCheck(tag, func, ...)
	DelayCheckCall(tag, MASK_TYPE_LEAST, true, func, ...)
end

function SimpleCheckEvent(tag)
	local flag = bit.band(EventsTag, tag)
	if CheckShouldCall(flag, MASK_TYPE_LEAST, tag) then
		return true
	end
	return false
end
