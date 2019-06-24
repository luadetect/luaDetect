
module(..., package.seeall)

objMap = {}
objMapId = 0
typeCntMap = {}
moduleMap = {}
moduleIgnoreVarMap = {}
memoryStatMap = {}
setmetatable(objMap, {__mode = "k"})

local function getObjCntMap()
	collectgarbage("collect")
	collectgarbage("collect")
	local newTypeCntMap = {}
	for k, v in pairs(objMap) do
		if type(k) == "table" then
			newTypeCntMap[k._clsName or "notype"] = (newTypeCntMap[k._clsName or "notype"] or 0) + 1
		else
			newTypeCntMap[tostring(k)] = (newTypeCntMap[tostring(k)] or 0) + 1
		end
	end
	return newTypeCntMap
end

function regGlobalNilVar(moduleName, ...)
	if not _G.OPEN_MEMORY_PROFILE then
		return
	end
	if not moduleIgnoreVarMap[moduleName] then
		moduleIgnoreVarMap[moduleName] = {}
	end
	for _, varName in ipairs({...}) do
		moduleIgnoreVarMap[moduleName][varName] = true
	end
end

function markScriptObjMap()
	typeCntMap = getObjCntMap()
end
function markObjMap(id)
	require "mem_manager"
	mem_manager.applicationDidReceiveMemoryWarning()
	objMapId = id or 0
	markScriptObjMap()
	markMemSnapshot()
end
function getObjDiffMap()
	local newTypeCntMap = getObjCntMap()
	local res = {}
	for k, v in pairs(newTypeCntMap) do
		local cnt = v - (typeCntMap[k] or 0)
		if cnt ~= 0 then
			res[k] = cnt
		end
	end
	for k, v in pairs(typeCntMap) do
		local cnt = (newTypeCntMap[k] or 0) - v
		if cnt ~= 0 then
			res[k] = cnt
		end
	end
	return res
end
function dumpObjDiffMap()
	print('objcntdbg: lua obj cnt beg=========')
	local res = getObjDiffMap()
	for k, v in pairs(res) do
		print("objcntdbg: ", k, v)
	end
	print('objcntdbg: lua obj cnt end=========')
end

function addDbgObjInfo(o)
	if not _G.OPEN_MEMORY_PROFILE then
		return
	end
	objMap[o] = true
end

function dumpAllLuaContent()
	CUtils:getInstance():listAllLuaObj()
end


function markMemSnapshot()
	require "preload.utils"
	if preload.utils.GetApkVersionNumber() > 10960 then
		CUtils:getInstance():markObjCntSnapshot()
	end
	memoryStatMap.luaBytes = collectgarbage("count") * 1024
	memoryStatMap.cocosTextureCnt, memoryStatMap.cocosTextureBytes = preload.utils.getCocosStat()
end

function dumpMemSnapshotDiff()
	local ret = CUtils:getInstance():dumpObjCntDiff()
	for k,v in pairs(ret) do
		print(k,v)
	end
end


function clearModuleVar()
	if not _G.OPEN_MEMORY_PROFILE then
		return
	end
	moduleMap = {}
end
function markInitModuleVar(moduleName, moduleData)
	if not _G.OPEN_MEMORY_PROFILE then
		return
	end
	local varMap = {}
	for k, v in pairs(moduleData) do
		varMap[k] = true
	end
	moduleMap[moduleName] = varMap
end
local IGNORE_MODULE = {
	["socket.core"] = true,
}
function getModuleVarDiff()
	require "ext.extstring"
	require "ext.exttable"
	local res = {}
	for moduleName, v in pairs(moduleMap) do
		if not IGNORE_MODULE[moduleName] then
			local arr = string.split(moduleName, ".")
			local moduleRef = package.loaded
			for _, name in ipairs(arr) do
				moduleRef = moduleRef[name]
				if not moduleRef then
					break
				end
			end
			if not moduleRef then
				moduleRef = package.loaded[moduleName]
			end
			assert(moduleRef ~= package.loaded and moduleRef ~= nil)
			local leakVarTbl = {}
			for k, _ in pairs(moduleRef) do
				if not v[k] and (not moduleIgnoreVarMap[moduleName] or not moduleIgnoreVarMap[moduleName][k]) then
					leakVarTbl[k] = true
				end
			end
			if not table.empty(leakVarTbl) then
				for k, _ in pairs(leakVarTbl) do
					res[moduleName .. ":" .. k] = true
				end
			end
		end
	end
	return res
end
function dumpModuleVarDiff()
	local res = getModuleVarDiff()
	print('objcntdbg: module var beg=========')
	for k, _ in pairs(res) do
		print('objcntdbg:	maybe leak var:', k)
	end
	print('objcntdbg: module var end=========')
end
function dumpDiff()
	dumpObjDiffMap()
	dumpModuleVarDiff()
end

function uploadDiffToQAServer()
	require "mem_manager"
	mem_manager.applicationDidReceiveMemoryWarning()
	local objDiff = getObjDiffMap()
	local varDiff = getModuleVarDiff()
	local engineDiff = nil
	require "preload.utils"
	if preload.utils.GetApkVersionNumber() > 10960 then
		engineDiff = CUtils:getInstance():dumpObjCntDiff()
	end
	local luaBytesDiff = collectgarbage("count") * 1024 - memoryStatMap.luaBytes
	local cocosTextureCntDiff = 0
	local cocosTextureBytesDiff = 0
	local cnt, bytes = preload.utils.getCocosStat()
	if memoryStatMap.cocosTextureCnt and cnt then
		cocosTextureCntDiff = cnt - memoryStatMap.cocosTextureCnt
	end
	if memoryStatMap.cocosTextureBytes and bytes then
		cocosTextureBytesDiff = bytes - memoryStatMap.cocosTextureBytes
	end
	preload.utils.Printdbg("diff:lua:" .. luaBytesDiff .. ",texturecnt:" .. cocosTextureCntDiff .. ",texturebytes:" .. cocosTextureBytesDiff)
	local res = {
		objDiff = objDiff,
		varDiff = varDiff,
		engineDiff = engineDiff,
		luaBytesDiff = luaBytesDiff,
		cocosTextureCntDiff = cocosTextureCntDiff,
		cocosTextureBytesDiff = cocosTextureBytesDiff,
		id = objMapId
	}
	require "net"
	require "json"
	local jsondata = json.encode(res)
	net.sendDataToQAServer("MEMORY_PROFILE:" .. jsondata .. "#")
end

function testWin32Mem()
	require "auto.infoshapecombine"
	require "ui"
	require "uiext"
	local current = 0
	local serial = {}
	for key, value in pairs(infoshapecombine.ShapeCombineInfo) do
		table.insert(serial, key)
	end
	local subpart = {
		"",
		"90/",
		"91/"
	}
	local function test()
		print("testWin32Mem test", current)
		for i = 1, 10 do
			current = current + 1
			local shape = serial[current]
			if shape == nil then
				scene.GetInstance():unregisterTimer("test_mem")
			 	return false 
			end
			local info = infoshapecombine.ShapeCombineInfo[shape]
			local baseName = string.format("shape/%04d", shape)
			for i, sub in ipairs(subpart)do
				for i, name in ipairs(uiext.ActionNameRef) do
					local realBaseName = baseName .. "/"  .. sub .. name
					if cc.FileUtils:getInstance():isFileExist(realBaseName .. ".png") then
						print("testWin32Mem baseName", realBaseName)
						local base = ui.CreateAnimateBase(realBaseName, false)
						base:loadSpriteFrames()
					end
				end
			end
		end
		return true
	end
	timer.unRegisterTimer(ui.AnimatePeriodTimerId)
	scene.GetInstance():unregisterTimer("test_mem")
	scene.GetInstance():registerTimer("test_mem", test, 0.5, -1)
end

TestShapeChars = {}
function testWin32MemExt()
	require "auto.infoshapecombine"
	require "ui"
	require "uiext"
	local current = 0
	local serial = {}
	for key, value in pairs(infoshapecombine.ShapeCombineInfo) do
		table.insert(serial, key)
	end
	if _G.TestCharPanel ~= nil then
		_G.TestCharPanel:removeFromParent()
	end
	_G.TestCharPanel = ui.CLayer:create(scene.Inst)
	_G.TestCharPanel:setLocalZOrder(GAMEUIBOTTOM_PANEL_ZORDER - 1)
	_G.TestCharPanel:enableGroupCmd()

	local lastNeedToHide = {}
	local function test()
		for i, key in ipairs(lastNeedToHide) do
			if TestShapeChars[key] then
				print("setTestShapeAnim InVisible", key)
				TestShapeChars[key]:stopPlayAnimation()
				TestShapeChars[key]:setVisible(false)
			end
		end
		lastNeedToHide = {}
		for i = 1, 20 do
			current = current + 1
			local shape = serial[current]
			if shape == nil then
				scene.GetInstance():unregisterTimer("testWin32MemExt")
			 	return false 
			end
			local tag = 1
			local zorder = 10
			local access = nil
			local posx = ScreenWidth * i / 20
			local posy = 0
			for j, name in ipairs(uiext.ActionNameRef) do
				local baseName = string.format("shape/%04d/%s.png", shape, name)
				if cc.FileUtils:getInstance():isFileExist(baseName) then
					local key = string.format("%04d_%s", shape, name)
					print(string.format("testWin32MemExt shape:%04d, name:%s, posx=%f, posy=%f, clock=%f, key = %s", shape, name, posx, posy, os.clock(), key))	
					local charAnim = uiext.CCharaterAnimate:create(_G.TestCharPanel, tag, 1, shape, {asyncFlag = false, animation = name})
					charAnim:setPosition(posx, posy)
					posy = posy + 70
					TestShapeChars[key] = charAnim
					table.insert(lastNeedToHide, key)
				end
			end
		end
	end
	timer.unRegisterTimer(ui.AnimatePeriodTimerId)
	scene.GetInstance():unregisterTimer("testWin32MemExt")
	scene.GetInstance():registerTimer("testWin32MemExt", test, 5, -1)
end

function purgeUiBase()
	if _G.TestCharPanel then
		_G.TestCharPanel:removeFromParent()
		_G.TestCharPanel = nil
	end
	TestShapeChars = {}
	scene.GetInstance():unregisterTimer("testWin32MemExt")
	mem_manager.recycleAllUnusedMem(false, true, mem_manager.RECYCLE_TYPE_OTHER)
end




--lua profile模块内存
function testMemPreProc(moduleName)
	if not _G.MODULE_NAME_STACK then
		_G.MODULE_NAME_STACK = {}
	end
	local oldval = collectgarbage("count")
	local parentModule = _G.MODULE_NAME_STACK[#_G.MODULE_NAME_STACK]
	table.insert(_G.MODULE_NAME_STACK, moduleName)
	return { oldval = oldval, parentModule = parentModule}
end
function testMemPostProc(moduleName, hookRet, err)
	table.remove(_G.MODULE_NAME_STACK)
	local parentModule, oldval = hookRet.parentModule, hookRet.oldval
	local newval = collectgarbage("count")
	local delta = newval - oldval
	if not _G.LUA_MODULE_SUM_MEM then
		_G.LUA_MODULE_SUM_MEM = {}
	end
	if not _G.LUA_MODULE_SPLIT_MEM then
		_G.LUA_MODULE_SPLIT_MEM = {}
	end
	_G.LUA_MODULE_SUM_MEM[moduleName] = delta
	_G.LUA_MODULE_SPLIT_MEM[moduleName] = (_G.LUA_MODULE_SPLIT_MEM[moduleName] or 0) + delta
	if parentModule then
		_G.LUA_MODULE_SPLIT_MEM[parentModule] = (_G.LUA_MODULE_SPLIT_MEM[parentModule] or 0) - delta
	end
end

function openLuaModuleProfile()
	_G.REAL_REQUIRE_IN_HOOK = testMemPreProc
	_G.REAL_REQUIRE_ERR_HOOK = testMemPostProc
	_G.REAL_REQUIRE_OUT_HOOK = testMemPostProc
end
function closeLuaModuleProfile()
	_G.REAL_REQUIRE_IN_HOOK = nil
	_G.REAL_REQUIRE_ERR_HOOK = nil
	_G.REAL_REQUIRE_OUT_HOOK = nil
end

function printMemProfile(sum, order)
	local tbl = _G.LUA_MODULE_SPLIT_MEM
	if sum then
		tbl = _G.LUA_MODULE_SUM_MEM
	end
	for k, v in table.pairs_orderly(tbl or {}, function(k1, k2)
		if order then
			return tbl[k1] > tbl[k2]
		else
			return tbl[k1] < tbl[k2]
		end
	end) do
		print(k, " : ", v, "kb")
	end
end
