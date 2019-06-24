
module(..., package.seeall)

require "ext.exttable"
require "ext.extstring"

CLOSE_DETAIL_TRACEBACK = false

function getCompactString(obj)
	if string.getCompactString then
		return string.getCompactString(obj)
	else
		return tostring(obj)
	end
end

--可以在这里加入全局信息
local function getGlobalInfo()
	local infoList = {}
	table.insert(infoList, "global info:")
	table.insert(infoList, "nil")
	return table.concat(infoList, "\n")
end

local function get_object_friend_string(obj, space)
	space = space or ""
	if type(obj) == "table" then
		if IsClass(obj) then
			return string.format("classid=%s", tostring(obj.TypeStr))
		elseif IsObj(obj) then
			local Id = "none"
			if obj.toString then
				return obj:toString()
			else
				return string.format("object=no_toString")
			end
		else
			--v = table.repr(v) --信息太多了
			-- 截断
			local objStr = table.serialize(obj, space)
			return "(table content):\n" .. space .. objStr
		end
	end
	return nil
end

local dbg = nil
local function ldb_debug(frame, Error)
	if frame == nil then
		require "traceback"
		frame = traceback.gettop() + 1
	end
	dbg:prepare(frame)
	--debug status
	local btinfo = dbg:get_backtrace(nil, true)
	dbg:do_quit()
	return btinfo
end

ldb = CObject:new{
	TypeStr = "ldb",
	fncache = {},	
	breaks = {},
	bplist = {},
	savedhook = {},
	stopframe = nil,
	returnframe = nil
}

function ldb:reset()
	--linecache.clear()
	self.breaks = {}
	self.bplist = {}	
end

function ldb:prepare(frame)
	if frame == nil then
		require "traceback"
		frame = -traceback.gettop() + 1
	end
	self.botframe = frame
	self:do_frame( 0 )
end

function ldb:get_backtrace( arg, PrintVar )
	require "traceback"
	local btinfo = {}
	--table.insert(btinfo, getGlobalInfo())
	table.insert(btinfo, 'traceback:')
	local top = traceback.gettop()
	local indicator = ' '	

	for frame = self.botframe, -1 do
		local level = ( top + 1 ) + frame
		local info = debug.getinfo(level,'nfSlu')
		if info == nil then 
			break
		end

		if frame == self.curframe then
			indicator = '<' 
		else
			indicator = ' ' 
		end

		local i = frame - self.botframe
		if info.what == 'C' then   -- is a C function?
			if info.name ~= nil then
				table.insert(btinfo, string.format('\t%s%2d[C] : in %s',indicator, i, info.name))
			else
				table.insert(btinfo, string.format('\t%s%2d[C] :',indicator, i))
			end
			--print(string.format('\t%s%2d[C]',indicator, i))
		else   -- a Lua function
			if info.name ~= nil then
				table.insert(btinfo , string.format('\t%s%2d %s : %d in %s',indicator, i, info.source, info.currentline, info.name))
			else
				table.insert(btinfo, string.format('\t%s%2d %s : %d',indicator, i, info.source, info.currentline))
			end
				
			if PrintVar then
				--打印变量
				local values, flags = self:getlocals( frame )
				for k,v in pairs(values) do
					local function SafeGetMsg()
						return get_object_friend_string(v, "\t\t\t") or ""
					end
					local _,Msg = xpcall(SafeGetMsg, function(Error) print("getmsg fatal error", Error, debug.traceback()) end)
					Msg = string.format("\t\t%s : %s   %s",k, getCompactString(v), getCompactString(Msg))
					table.insert(btinfo, Msg)
				end
			end
		end
	end
	return table.concat(btinfo, "\n")
end

function ldb:do_frame(arg)
	local _, _, frame = string.find( arg, '^(%d+)$')
	if frame == nil then return end
	self.curframe = self.botframe + frame
	if self.curframe >-1 then
		self.curframe = -1
	end
	--linecache.clear()
	require "traceback"
	local what, filename, lineno = traceback.getsource( self.curframe )
	self.curfilename = filename
	self.curlineno = lineno - 5
end

function ldb:getlocals( frame )
	local i = 1
	local values = {}
	local flags = {}
	require "traceback"
	frame = traceback.gettop() + 1 + frame
	local info = debug.getinfo(frame)
	if info == nil then return end

	if info.func then
		i = 1
		while true do 
			local name, value = debug.getupvalue(info.func,i)
			if not name then break end
			xpcall(function()
				if preload and preload.utils and preload.utils.TransName then
					name = preload.utils.TransName(name)
				end
			end,function(err)
				name = tostring(name) .. ":preload.utils.TransName error:" .. tostring(err)
				print(err)
			end) 
			flags[name] = true
			values[name] = value
			i = i + 1
		end
	end

	i = 1
	while true do
		local name, value = debug.getlocal( frame, i)
		if not name then break end
		flags[name] = true
		values[name] = value
		i = i + 1
	end

	return values, flags
end

function ldb:getglobals()
	local values = {}
	local flags = {}	
	for name, value in pairs(_G) do
		if not flags[name] then
			flags[name] = true
			values[name] = value
		end				
	end
	return values, flags
end

function ldb:do_quit( arg )
	self:reset()
	return true
end





local _coroutine = { create = coroutine.create }
local function on_coroutine_error( Error )
	debug.excepthook( Error )
end

function coroutine.create( func )
	print("this is my coroutine create")
	local _func = function(...)
		local tbl = {...}
		local ret = {xpcall(function() return func(unpack(tbl)) end, on_coroutine_error),}
		if ret[1] then
			table.remove (ret, 1)
			return unpack(ret)
		end
	end
	return _coroutine.create(_func)	
end

local function OnExcept( Error, n)
	require "traceback"
	local curframe = -traceback.gettop() --curframe
	--防止栈溢出
	if curframe < -100 then
		return "stack too deep!!\n" .. debug.traceback()
	end
	local botframe = curframe + 1 + (n or 1) -- trackback, caller
	local btinfo = ldb_debug(botframe, Error)
	return btinfo
end

function debug.detail_traceback_no_encrypt(extstrfunc)
	local btinfo = nil
	if CLOSE_DETAIL_TRACEBACK then
		btinfo = ""
	else
		local function Except() 
			btinfo = OnExcept(nil, 3)
			if not btinfo then
				btinfo = "no bt info "
			end
			dbg:do_quit()
		end
		xpcall(Except, function(Error) btinfo = "internal excepthook error " .. Error end)
	end
	if extstrfunc then
		local extstr = tostring(extstrfunc(btinfo))
		btinfo = btinfo .. "\n" .. extstr
	end
	return btinfo
end
function debug.detail_traceback(extstrfunc)
	local btinfo = debug.detail_traceback_no_encrypt(extstrfunc)
	local function trans()
		local info = btinfo
		local len = string.len(info)
		local infos = {}
		for i = 1, len do
			local d = string.byte(info, i)
			local char1 = string.char(97 + d % 16)
			table.insert(infos, char1 or '')
			local char2 = string.char(97 + math.floor(d / 16))
			table.insert(infos, char2 or '')
		end
		btinfo = table.concat(infos)
		local resVersion = "notinit"
		if gamedata and gamedata.GetResVersion then
			resVersion = gamedata.GetResVersion()
		end
		if CUtils:getInstance().getAndroidAvailableBytesDetail then
			btinfo = string.format("<Version>%s<Version/><Memory>%s<Memory/>\n%s",resVersion, CUtils:getInstance():getAndroidAvailableBytesDetail(), btinfo)
		else
			btinfo = string.format("<Version>%s<Version/>\n%s",resVersion, btinfo)
		end
	end
	if not _G.COCOS2D_DEBUG then
		xpcall(trans, function(Error) btinfo = "internal excepthook error " .. Error end)	
	end
	return btinfo
end

function SafeExcept(Error)
	if Error then
		print("Error: ", Error)
	end
	local btinfo = debug.detail_traceback_no_encrypt()
	-- local btinfo = debug.detail_traceback()
	string.fullprint(btinfo)
	return Error, btinfo
end

function init_dbg()
	if dbg == nil then
		dbg = ldb:create()
		dbg:reset()
		dbg:do_quit()
	end
end

init_dbg()

function debug.verbose_except_hook(Msg)
	local T = {}
	local M = function(s) table.insert(T, s) end
	M(Msg)
	M('trackback:')
	local finfo
	local l = 2
	while 1 do
		finfo = debug.getinfo(l)
		if not finfo then break end
		local s = string.format('[%d] %s : %d --> %s', l-1, finfo.short_src, finfo.currentline, finfo.name or '<noname>')
		M('\t' .. s)
		if finfo.what == 'Lua' then
			local rid = 1
			while 1 do
				local k, v = debug.getlocal(l, rid)
				if not k then break end
				local vardesc = string.format('\t\t %s => %s', k, getCompactString(v))
				M(vardesc)
				rid = rid + 1
			end
		end
		l = l + 1
	end
	print(table.concat(T, '\n'))
	return Msg
end

--一行表示完，只显示函数位置，可以设置从哪一帧的栈开始
function debug.dump_compact_traceback(err, Beg, End)
	local tb = {}
	table.insert(tb, err)
	local finfo
	local l = 2
	while 1 do
		if End and l - 1 > End then
			break
		end
		if not Beg or l - 1 >= Beg then
			finfo = debug.getinfo(l)
			if not finfo then break end
			local s = string.format('[%d]%s : %d(%s)', l-1, finfo.short_src, finfo.currentline, finfo.name or '<noname>')
			table.insert(tb, s)
		end
		l = l + 1
	end
	return tb
end

function debug.dump_compact_traceback_string(err, Beg, End)
	return table.concat(debug.dump_compact_traceback(err, Beg, End), ' --> ')
end

function debug.dump_traceback(err)
	local tb = {}
	table.insert(tb, err)
	local finfo
	local l = 2
	while 1 do
		finfo = debug.getinfo(l)
		if not finfo then break end
		local s = string.format('[%d] %s : %d --> %s', l-1, finfo.short_src, finfo.currentline, finfo.name or '<noname>')
		table.insert(tb, '\t' .. s)
		if finfo.what == 'Lua' then
			local rid = 1
			while 1 do
				local k, v = debug.getlocal(l, rid)
				if not k then break end
				local desc = get_object_friend_string(v) or getCompactString(v)
				local vardesc = string.format('\t\t %s => %s', k, desc)
				table.insert(tb, vardesc)
				rid = rid + 1
			end
		end
		l = l + 1
	end
	return tb
end

function debug.dump_traceback_string(err)
	return table.concat(debug.dump_traceback(err), '\n')
end

function debug.safe_dump_traceback_string(err)
	local Ok, Res = xpcall(function()
		return table.concat(debug.dump_traceback(err), '\n')
	end, debug.excepthook)
	return Res or "safe_dump_traceback_string error"
end

debug.excepthook = SafeExcept

function fullTraceback(Error)
	Error = Error or "full traceback:"
	return OnExcept(Error, 1)
end

