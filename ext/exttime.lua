
module(..., package.seeall)
require "localize"

local TIME_BASE = 1072886400 --2004年1月1日 0:00 星期四

--常用时间定义，秒数
mONE_WEEK = 604800
mONE_DAY = 86400
mONE_HOUR = 3600
mONE_YEAR = 3600 * 24 * 360 

function getBaseTime()
	return TIME_BASE
end

-- 返回Year Month有多少天
function getDayNumOfMonth(Year, Month)
	local CurTime = os.date("*t")
	Year = Year or CurTime.year
	Month = Month or CurTime.month

	local StartTime = { year = Year, month = Month, day = 1, hour = 0, min = 0, sec = 0, }

	local EndTime = nil
	if Month + 1 == 13 then
		EndTime = { year = Year + 1, month = 1, day = 1, hour = 0, min = 0, sec = 0, }
	else
		EndTime = { year = Year, month = Month + 1, day = 1, hour = 0, min = 0, sec = 0, }
	end

	local StartSecs = os.time(StartTime)
	local EndSecs = os.time(EndTime)

	local SubSecs = EndSecs - StartSecs
	assert(SubSecs > 0)

	return math.floor((SubSecs / 86400)) -- 理论上不会有小数
end
-- 从dayno转换成秒
function relayDayNo2Sec(DayNo)
	return TIME_BASE + (DayNo - 1) * 3600 * 24
end

-- 返回dayno, dayno是指Time是相对于2004年1月1日为第一天开始算起的的第几天
function getRelaDayNo(Time)
	local TotalDay = 0
	local Standard = TIME_BASE		--2004年1月1日 00:00
	if not Time then
		Time = os.time()
	end
	if Time > Standard then
		TotalDay = (Time - Standard)/3600/24
	else
		TotalDay = (Standard - Time )/3600/24
	end
	return math.floor(TotalDay) + 1
end

-- 返回weekno, weekno是指Time是相对于2004年1月1日为第一星期开始算起的的第几周，分割点是周一凌晨0:00
function getRelaWeekNo(Time)
	local TotalWeek = 0
	local Standard = TIME_BASE + 3600*24*4		--因为2004年1月1日 0:00是星期四早上0:00，要改成星期日24:00
	Time = Time or os.time()
	if Time > Standard then
		TotalWeek = (Time - Standard)/3600/24/7
	else
		TotalWeek = (Standard - Time )/3600/24/7
	end
	return math.floor(TotalWeek + 1)
end

-- 返回monthno, monthno是指Time是相对于2004年1月的第几个月，调用者保证 Time > TIME_BASE
function getRelaMonthNo(Time)
	Time = Time or os.time()
	local Base = os.date("*t", TIME_BASE)
	local BaseYear, BaseMonth = Base.year, Base.month
	local Current = os.date("*t", Time)
	local CurYear, CurMonth = Current.year, Current.month

	return ( (CurYear-BaseYear) * 12 + CurMonth )
end

--将"2005-06-01 00:00:00"格式的日期转换为time table形式
function date2Table(sDateTime)
	if type(sDateTime) ~= "string" or 
		string.match(sDateTime, "^%d+%-%d+%-%d+ %d+:%d+:%d+$") == nil then
		return nil
	end
	
	local MatchTable = {}
	
	for item in string.gmatch(sDateTime, "%d+") do
		table.insert(MatchTable, item)
	end
	
	local TimeTable = {}
	TimeTable.year = MatchTable[1]
	TimeTable.month = MatchTable[2]
	TimeTable.day = MatchTable[3]
	TimeTable.hour = MatchTable[4]
	TimeTable.min = MatchTable[5]
	TimeTable.sec = MatchTable[6]
	return TimeTable
end

--将"2006-06-01 10:00:00"这样的时间转换为秒，带容错
function date2SecStrict(sDateTime)
	local t = date2Table(sDateTime)
	if not t then return nil end
	return os.time(t)
end

--将"2006-06-01 10:00:00"这样的时间转换为秒，不带容错
function date2Sec(sDateTime)
	return os.time(date2Table(sDateTime))
end

--将秒数转成字符串 "2009-01-03 22:10:53"
function sec2DateTime( Sec, OnlyDate )
	if OnlyDate then
		return os.date("%Y-%m-%d", Sec)
	else
		return os.date("%Y-%m-%d %H:%M:%S", Sec)
	end
end

--将秒数转成字符串 "2009年01月03日 22时10分53秒"
function sec2DateTimeCn( Sec, OnlyDate )
	if OnlyDate then
		return os.date(LC('%Y年%m月%d日', 263), Sec)
	else
		return os.date(LC('%Y年%m月%d日 %H时%M分%S秒', 264), Sec)
	end
end

--把秒数转换成中文描述
function secToDes( Diff, DayDesc )
        local Day = math.floor(Diff / (3600*24))
        Diff = Diff % (3600*24)
        local Hour = math.floor(Diff / 3600)
        Diff = Diff % 3600
        local Min = math.floor(Diff / 60)
        Diff = Diff % 60
        local Sec = Diff % 60

        local Ret = ""
        if Day > 0 then
                Ret = Ret..Day..LC("天", 265)
        end
        if Hour > 0 then
                Ret = Ret..Hour..LC("小时", 266)
        end
        if Min > 0 then
                Ret = Ret..Min..LC("分钟", 267)
        end
        if Sec > 0 then
                Ret = Ret..Sec..LC("秒", 20)
        end

        DayDesc = DayDesc or " "
        return Ret, string.format("%s%02d:%02d:%02d", Day>0 and Day .. DayDesc or "", Hour, Min, Sec)
end

--把秒数转换成中文描述(只有分和秒)
function secToDesNoHour( Diff )
        local Min = math.floor(Diff / 60)
        Diff = Diff % 60
        local Sec = Diff % 60

        local Ret = ""
        if Min > 0 then
                Ret = Ret..Min..LC("分钟", 267)
        end
        if Sec > 0 then
                Ret = Ret..Sec..LC("秒", 20)
        end

        return Ret, string.format("%02d:%02d", Min, Sec)
end

--把秒数转换成中文描述(没有秒)
function secToDesMin( Diff )
	local Day = math.floor(Diff / (3600*24))
	Diff = Diff % (3600*24)
	local Hour = math.floor(Diff / 3600)
	Diff = Diff % 3600
	local Min = math.floor(Diff / 60)

	local Ret = ""
	if Day > 0 then
		Ret = Ret..Day..LC("天", 265)
	end
	if Hour > 0 then
		Ret = Ret..Hour..LC("小时", 266)
	end
	if Min > 0 then
		Ret = Ret..Min..LC("分", 268)
	end
	if Ret == "" then
		Ret = LC("0分", 269)
	end

	return Ret
end

--把秒数转换成中文描述(没有分秒)
function secToDesHour(Diff)
	local Day = math.floor(Diff / (3600*24))
	Diff = Diff % (3600*24)
	local Hour = math.floor(Diff / 3600)
	Diff = Diff % 3600
	local Min = math.floor(Diff / 60)

	local Ret = ""
	if Day > 0 then
		Ret = Ret..Day..LC("天", 265)
	end
	if Hour > 0 then
		Ret = Ret..Hour..LC("小时", 266)
	end
	return Ret
end

--两个时间差的描述
function timeDiffDes(Time1, Time2)
	return secToDes( math.abs(Time1-Time2) )
end

--检查年月日是否符合要求
local MONTH31TBL = {[1] = true,[3] = true,[5] = true,[7] = true,[8] = true,[10] = true,[12] = true}
function validDate (y,m,d)
	local nMaxDay = 30
	if m == 2 then
		if (y %4 == 0) and (y % 100 ~= 0) then
			nMaxDay = 29
		elseif y % 400 == 0 then
			nMaxDay = 29
		else
			nMaxDay = 28
		end
	end
	if MONTH31TBL[m] then
		nMaxDay = 31
	end
	
	if d < 1 or d > nMaxDay then
		return false
	end
	if m < 1 or m > 12 then
		return false
	end

	return true	
end

--参数和os.time的参数一样。
--直接使用数据转换的方法，比较简单一点~
function validDateTime(TimeTbl)
	if not TimeTbl.year or 
		not TimeTbl.month or
		not TimeTbl.day then
		return false
	end
	local Time = os.time(TimeTbl)
	local NewTimeTbl = {year = os.date("%Y", Time),
			month = os.date("%m", Time),
			day = os.date("%d", Time),
			hour = os.date("%H", Time),
			min = os.date("%M", Time),
			sec = os.date("%S", Time), }
	for k,v in pairs(TimeTbl) do
		if tonumber(v) ~= tonumber(NewTimeTbl[k]) then
			return false
		end	
	end
	return true
end
--把weekday变成中国人理解的星期n
function AdjustWDay(WDay)
	WDay = WDay - 1
	if WDay <= 0 then
		WDay = 7
	end
	return WDay
end

local function calDiff(SrcHour, SrcMin, SrcSec, DstHour, DstMin, DstSec)
	local SrcTimeSecs = SrcHour * 3600 + SrcMin * 60 + SrcSec
	local DstTimeSecs = DstHour * 3600 + DstMin * 60 + DstSec

	return (DstTimeSecs - SrcTimeSecs)
end

-- 返回第一个Date那个周的WeekDay Hour Min Sec 的 Date
function getTimeSecsByWeek(SrcTimeSecs, DstWDay, DstHour, DstMin, DstSec) 
	local Date = os.date("*t", SrcTimeSecs)
	local SrcWDay = AdjustWDay(Date.wday)
	local SrcHour = Date.hour
	local SrcMin = Date.min
	local SrcSec = Date.sec

	return SrcTimeSecs + ((DstWDay - SrcWDay) * 3600 * 24 + calDiff(SrcHour, SrcMin, SrcSec, DstHour, DstMin, DstSec))
end

local WDAY2CN_DESCTBL = { 
	[2] = LC("一", 270),
	[3] = LC("二", 271),
	[4] = LC("三", 272),
	[5] = LC("四", 273),
	[6] = LC("五", 274),
	[7] = LC("六", 275),
	[1] = LC("日", 276), --fck
}

local CNDESC2WDAY_TBL = { 
	[LC("一", 270)] = 2,
	[LC("二", 271)] = 3,
	[LC("三", 272)] = 4,
	[LC("四", 273)] = 5,
	[LC("五", 274)] = 6,
	[LC("六", 275)] = 7,
	[LC("日", 276)] = 1, --fck
}

--wday转中文
function wday2CnDesc( Wday )
	return WDAY2CN_DESCTBL[Wday]
end

--中文转wday
function cnDesc2Wday( CnDesc )
	return CNDESC2WDAY_TBL[CnDesc]
end

-- 返回按自然日算的天数差别
-- "2010-04-25 23:30:00"  "2010-04-26 09:10:00"   差1天 
function dayDiff( CurSec, PastSec )
	return getRelaDayNo(CurSec) - getRelaDayNo(PastSec)
end

--今天到目前为止的总分钟数，总秒数
function getRelaMinSec()
	local CurTime = os.date( "*t", os.time() )
	local CurHour = CurTime["hour"]
	local CurMin  = CurTime["min"]
	local CurSec  = CurTime["sec"]

	local RelativeMin = CurHour * 60 + CurMin
	local RelativeSec = RelativeMin * 60 + CurSec

	return RelativeMin, RelativeSec
end

--两个时间区间有无重叠
function isTimeOverlap(TimeBegin1, TimeEnd1, TimeBegin2, TimeEnd2)
	if TimeBegin1 > TimeEnd2 or TimeEnd1 < TimeBegin2 then
		return false
	else
		return true, math.max(TimeBegin1, TimeBegin2), math.min(TimeEnd1, TimeEnd2)
	end
end
-- 获得两个时间重叠区间
function getTimeOver(TimeBegin1, TimeEnd1, TimeBegin2, TimeEnd2)
	local Begin = TimeBegin1 > TimeBegin2 and TimeBegin1 or TimeBegin2
	local End = TimeEnd1 > TimeEnd2 and TimeEnd2 or TimeEnd1
	if End >= Begin then return Begin, End end
end

-- 获得今天0点0分0秒的时间
function getDayBeginTime(Time)
	Time = Time or os.time()
	local t = os.date("*t", Time)
	t.hour = 0
	t.min = 0
	t.sec = 0
	return os.time(t)
end

-- 获得今天23点59分59秒的时间
function getDayEndTime(Time)
	Time = Time or os.time()
	local t = os.date("*t", Time)
	t.hour = 23
	t.min = 59
	t.sec = 59
	return os.time(t)
end

-- 本周日的0点，周日作为一周的第一天
function getWeekBeginTime(Time)
	Time = Time or os.time()
	local t = os.date("*t", Time)
	local diff = t.sec + t.min * 60 + t.hour * 60 * 60 + (t.wday-1) * 60 * 60 * 24
	return Time - diff
end

--本周一的0点，中国的周一为一周第一天
function getWeekBeginTimeCN(Time)
	Time = Time or os.time()
	local WeekBeginEN = getWeekBeginTime(Time)
	if Time - WeekBeginEN >= mONE_DAY then
		return WeekBeginEN + mONE_DAY
	else
		return WeekBeginEN - mONE_WEEK + mONE_DAY
	end
end
--返回下一个星期几零点的os.time
--Wday = 2 星期一 
function getNextWeekdayBeginTime(Wday)
	local TimeTbl = os.date("*t")
	TimeTbl.hour = 0
	TimeTbl.min = 0
	TimeTbl.sec = 0
	local RetTime
	for i = 1, 7 do
		RetTime = os.time(TimeTbl)+i*mONE_DAY
		if os.date("*t", RetTime).wday == Wday then
			return RetTime
		end
	end
end

function getWeekdayDesc(time)
	local cfg = {
		[1] = LCById(130203),
		[2] = LCById(130204),
		[3] = LCById(130205),
		[4] = LCById(130206),
		[5] = LCById(130207),
		[6] = LCById(130208),
		[7] = LCById(130209),
	}
	local t = os.date("*t", time or os.time())
	return cfg[t.wday]
end

function getIntervalByData(Data)
	--优先顺序：日，时，分，秒
	--从“月”往上的周期就不固定了，忽略
	local ret = nil
	if Data.sec then
		ret = 60
	end
	if Data.min then
		ret = 3600
	end
	if Data.hour then
		ret = 24 * 3600
	end
	return ret
end

--返回Time的时间与Data融合后的时间，比如Time是2014.8.7 08:15:16，Data是{min=0,sec=0}，则返回2014.8.7 08:00:00的时间
function getTimeByData(Data, Time)
	Time = Time or os.time()
	local t = os.date("*t", Time)
	for k, v in pairs(Data) do
		t[k] = v
	end
	return os.time(t)
end

--返回从Time开始，下一个出现Data所描述规律的时间
--比如当前时间是2014.8.7 08:15:00，Data是{hour=10,min=0,sec=0}，则返回2014.8.7 10:00:00
function getNextTimeByData(Data, Time)
	local NextTime = getTimeByData(Data, Time)
	local Interval = getIntervalByData(Data)
	if NextTime < Time then
		NextTime = NextTime + Interval
		assert(NextTime >= Time) --Data传得有问题
	end
	return NextTime, Interval
end

--返回本月第一个星期几零点的os.time
--wday = 2	星期一
function firstWeekdayInCurMonth(wday)
	local TimeTbl = os.date("*t")
	TimeTbl.hour = 0
	TimeTbl.min = 0
	TimeTbl.sec = 0
	local RetTime
	for day = 1, 7 do
		TimeTbl.day = day
		RetTime = os.date("*t", os.time(TimeTbl))
		if RetTime.wday == wday then
			return os.time(RetTime)
		end
	end
end

-- 是否是闰年
function isLeapYear(year)
	assert(type(year) == "number")
	return ((year % 100 == 0 and year % 400 == 0) or (year % 100 ~= 0 and year % 4 == 0) )
end

local LASTDAY_OF_MONTH = {
	[1] = 31,
	[2] = isLeapYear(os.date("*t").year) and 29 or 28,	-- 默认取今年的吧。。。
	[3] = 31, [4] = 30, [5] = 31, [6] = 30, [7] = 31, [8] = 31, [9] = 30, [10] = 31, [11] = 30, [12] = 31,
}

function getLastDayOfMonth(month, year)
	if month ~= 2 or not year then
		return LASTDAY_OF_MONTH[month]
	end
	return isLeapYear(year) and 29 or 28
end

--将"2006-06-01 10:00:00"这样的东八区时间转换为当前时区的秒数
function GetUTC8TimeInCurrentZoneSec(sDateTime)
	--先算当前时区和东八区的时差
	local date = os.date("!*t", os.time())
	local timediff = os.time(date) - os.time() + 3600 * 8
	if os.date("*t",os.time()).isdst then
		--如果处于夏令时，需要减去1个小时
		timediff = timediff - 3600
	end
	--preload.utils.PrintdbgCompact("是否夏令时:", os.date("*t",os.time()).isdst, ",时差：", timediff)
	return os.time(date2Table(sDateTime)) - timediff
end

-- 将剩余时间格式化00:00
function secToHourMin(lefttime)
	local Day = math.floor(lefttime / (3600*24))
	lefttime = lefttime % (3600*24)
	local Hour = math.floor(lefttime / 3600)
	lefttime = lefttime % 3600
	local Min = math.floor(lefttime / 60)
	return string.format("%02d:%02d", Hour, Min)
end

-- 将剩余时间格式化00:00:00，大于24时的显示xx天
function secToHourMinSecond(lefttime)
	local Day = math.floor(lefttime / (3600*24))
	if Day >= 1 then
		return Day, string.format("%d天", Day)
	else
		lefttime = lefttime % (3600*24)
		local Hour = math.floor(lefttime / 3600)
		lefttime = lefttime % 3600
		local Min = math.floor(lefttime / 60)
		lefttime = lefttime % 60
		local Sec = lefttime % 60
		return Day, string.format("%02d:%02d:%02d", Hour, Min, Sec)
	end
end

function secToMinSecond(lefttime)
	local Min = math.floor(lefttime / 60)
	lefttime = lefttime % 60
	local Sec = lefttime % 60
	return string.format("%02d:%02d", Min, Sec)
end
