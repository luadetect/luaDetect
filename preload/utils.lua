module(..., package.seeall)

if not _G.oldfindwithbug then
	_G.oldfindwithbug = string.find
end
function correctStringFind(basestr, substr, oldpos, plain)
	if plain then
		if #substr == 1 then
			if substr == "%" or substr == "^" or substr == "$" or substr == "*" or substr == "+" or substr == "?" or substr == "." or substr == "(" or substr == "[" or substr == "-" then
				substr = "%" .. substr
			end
		else
			substr = string.gsub(substr, "%%", "%%%%")
			substr = string.gsub(substr, "%^", "%%%^")
			substr = string.gsub(substr, "%$", "%%%$")
			substr = string.gsub(substr, "%*", "%%%*")
			substr = string.gsub(substr, "%+", "%%%+")
			substr = string.gsub(substr, "%?", "%%%?")
			substr = string.gsub(substr, "%.", "%%%.")
			substr = string.gsub(substr, "%(", "%%%(")
			substr = string.gsub(substr, "%[", "%%%[")
			substr = string.gsub(substr, "%-", "%%%-")
		end
		plain = false
	end
	if substr and #substr > 0 and string.sub(substr,1,1) == "^" then
		return _G.oldfindwithbug(basestr, substr, oldpos, plain)
	end
	local substr1 = "[\n]?" .. substr
	local idx = {_G.oldfindwithbug(basestr, substr1, oldpos, plain)}
	if not idx[1] then
		return
	end
	local substr2 = "[\r]?" .. substr
	local dx = {_G.oldfindwithbug(basestr, substr2, oldpos, plain)}
	local isTheSame = true
	for i = 1, 10 do
		if idx[i] ~= dx[i] then
			isTheSame = false
			break
		end
	end
	if isTheSame then
		return unpack(dx)
	else
		local substr3 = "[\t]?" .. substr
		local cx = {_G.oldfindwithbug(basestr, substr3, oldpos, plain)}
		if cx[1] == dx[1] or cx[1] == idx[1] then
			return unpack(cx)
		end
	end
end
function isIndependent()
	if SdkControllerDelegate:getInstance().getRunningType ~= nil and SdkControllerDelegate:getInstance():getRunningType() == "independent" then
		return true
	end
	return false
end
function isMac()
	return cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_MAC
end

function getCocosStat()
	local str = cc.Director:getInstance():getTextureCache():getCachedTextureInfo()
	if str and #str > 0 then
		local arr = string.split(str, "\n")
		for i = #arr, 1, -1 do
			local value = arr[i]
			if string.find(value, "TextureCache dumpDebugInfo") then
				local cnt, bytes = string.match(value, ": (%d+) textures, for (%d+) KB")
				if cnt and bytes then
					return cnt, bytes * 1024, str
				else
					return
				end
			end
		end
	end
end
function CheckFileExist(filename)
	if not filename then return false end
	local ret = cc.FileUtils:getInstance():isFileExist(filename)
	--TODO implement it in c++ code
	if not ret and _G.UI_SPRITEFRAME_PREFIX and string.find(filename, _G.UI_SPRITEFRAME_PREFIX) then
		ret = cc.SpriteFrameCache:getInstance():getSpriteFrame(filename) ~= nil
	end
	return ret
end

function dirtree(dir, recursive)
	if not dir or lfs_attributes(dir) == nil then
		return function() end
	end
	if recursive == nil then recursive = true end
	assert(dir and dir ~= "", "directory parameter is missing or empty")
	if string.sub(dir, -1) == "/" then
		dir=string.sub(dir, 1, -2)
	end
	local function yieldtree(dir)
		for entry in lfs_dir(dir) do
			if entry ~= "." and entry ~= ".." then
				entry=dir.."/"..entry
				local attr=lfs_attributes(entry)
				if attr and attr.mode == "directory" and recursive == true then
					yieldtree(entry)
				end
				coroutine.yield(entry,attr)
			end
		end
	end
	return coroutine.wrap(function() yieldtree(dir) end)
end
local function isSoFile(path)
	local postfix = ".so"
	return string.sub(path, #path - #postfix + 1) == postfix
end
function isUsingNpkFileSys()
	local fileUtils = cc.FileUtils:getInstance()
	return fileUtils.clearPatch
end
function removeFileOrDir(path)
	local attr = lfs_attributes(path)
	if attr then
		if attr.mode == "file" then
			return removeFile(path)
		elseif attr.mode == "directory" then
			local fileUtils = cc.FileUtils:getInstance()
			if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS and fileUtils.deleteDirectory then
				local ret = fileUtils:deleteDirectory(path)
				if not ret then
					WARN("win32 deleteDirectory failed")
				end
				return ret
			else
				return lfs_rmdir(path)
			end
		end
	end
end
function removeFile(path, noWarn)
	local attr = lfs_attributes(path)
	if not attr then
		--根本没有这个文件
		return
	end
	local ret, err, errno
	local fileUtils = cc.FileUtils:getInstance()
	if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS and fileUtils.deleteFile then
		ret = fileUtils:deleteFile(path)
		if not ret then
			ret, err, errno = os.remove(path)
		end
		if not ret and not noWarn then
			__G__TRACKBACK__("remove file failed V1")
		end
	else
		ret, err, errno = os.remove(path)
		if not ret and not noWarn then
			__G__TRACKBACK__("remove file failed V2")
		end
	end
	return ret, err, errno
end
function removeDir(path, notDelSelf)
	local pathatt = lfs_attributes(path)
	if not pathatt or pathatt.mode ~= "directory" then
		return
	end
	local fileUtils = cc.FileUtils:getInstance()
	if cc.Application:getInstance():getTargetPlatform() ~= cc.PLATFORM_OS_WINDOWS and fileUtils.removeDirectory then
		--之所以win32不要用removeDirectory是因为win32的removeDirectory的实现是用另外一条进程做的
		--所以在remove之后究竟什么时候完成根本不知道
		if string.sub(path, #path) ~= "/" then
			path = path .. "/"
		end
		fileUtils:removeDirectory(path)
		if notDelSelf then
			lfs_mkdir(path)
		else
			removeFileOrDir(path)
		end
	elseif cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS and fileUtils.deleteDirectory then
		path = refineFilePath(path)
		path = string.gsub(path, "/", "\\")
		local ret = fileUtils:deleteDirectory(path)
		if notDelSelf then
			fileUtils:makeDirectory(path)
		end
		if not ret then
			WARN("win32 deleteDirectory failed")
		end
	else
		local dirs = {}
		for fn in dirtree(path) do
			local attr = lfs_attributes(fn)
			if attr then
				if attr.mode == "file" then
					removeFile(fn)
				elseif attr.mode == "directory" then
					table.insert(dirs, fn)
				end
			end
		end
		for idx, dir in ipairs(dirs) do
			lfs_rmdir(dir)
		end
		if not notDelSelf then
			removeFileOrDir(path)
		end
	end
end
function clearPatch(ignoreCachePath, clearQATools)
	_G.LAST_CHECK_NEED_PATCHING_DATA = nil
	require "preload.updating_proc"
	local arr = {
		--这里填手动清理的配置信息
		preload.updating_proc.UpdateResPath,
		preload.updating_proc.UpdateSubverPath,
		preload.updating_proc.DownloadsPath,
	}
	if not ignoreCachePath then
		table.insert(arr, preload.updating_proc.UpdateCachePath)
	end
	if clearQATools then
		table.insert(arr, "qatools")
	end
	local fileUtils = cc.FileUtils:getInstance()
	if isUsingNpkFileSys() then
		--注意这里必须保证没有其他地方正在使用文件系统，不然会出bug，未完待续
		fileUtils:clearPatch(ignoreCachePath)
		if clearQATools then
			--手动删除
			local path = cc.FileUtils:getInstance():getWritablePath()
			path = path.."qatools"
			xpcall(function()
				removeDir(path, true)
			end,
			__G__TRACKBACK__)
		end
		cleanRes(preload.updating_proc.DownloadsPath)
		for _, respath in ipairs(arr) do
			onCleanRes(respath)
		end
	else
		for _, respath in ipairs(arr) do
			cleanRes(respath)
		end
		cc.FileUtils:getInstance():purgeCachedEntries()
	end
end
function clearSpecPatchDir(target_path, removeFunc)
	require "preload.updating_proc"
	local fileUtils = cc.FileUtils:getInstance()
	local isSubver = (target_path == preload.updating_proc.UpdateSubverPath)
	if isUsingNpkFileSys() then
		--注意这里必须保证没有其他地方正在使用文件系统，不然会出bug，未完待续
		if isSubver then
			fileUtils:unloadSubverLoader()
		else
			fileUtils:unloadPatchLoader()
		end
	end
	local removepath = cc.FileUtils:getInstance():getWritablePath() .. target_path
	if removeFunc then
		removeFunc(removepath)
	else
		removeDir(removepath ,true)
	end
	if isUsingNpkFileSys() then
		if isSubver then
			fileUtils:reloadSubverLoader()
		else
			fileUtils:reloadPatchLoader()
		end
	end
	onCleanRes(target_path)
	cc.FileUtils:getInstance():purgeCachedEntries()
end
function onCleanRes(target_path)
	require "preload.updating_proc"
	if target_path == preload.updating_proc.UpdateResPath or target_path == preload.updating_proc.UpdateSubverPath then
		--可以认为每次清空资源，错误的lib就会被清除，这个时候可以告诉引擎下次用回patch的引擎了
		_G.ResetUsePatchLibTag()
		if target_path == preload.updating_proc.UpdateResPath then
			--清了pkres，检查pkres的md5记录就没任何意义了
			xpcall(function()require "md5list" end, __G__TRACKBACK__)
			if md5list and md5list.clearCheckMd5Cache then
				md5list.clearCheckMd5Cache()
			end
		end
	end
end
function cleanRes(target_path)
	--暂时不支持android更新引擎了，未完待续
	local path = cc.FileUtils:getInstance():getWritablePath()
	path = path..target_path
	xpcall(function()
		removeDir(path, true)
		onCleanRes(target_path)
	end,
	__G__TRACKBACK__)
end
function isFileExistInLoader(ispkres, path, forceFileDiscrete)
	local isFileExist = false
	local fileUtilsInst = cc.FileUtils:getInstance()
	if fileUtilsInst.isFileExistInNeoXRoot and not forceFileDiscrete then
		--正在使用neox的文件系统
		print('isFileExistInNeoXRoot====', path, ispkres)
		isFileExist = fileUtilsInst:isFileExistInNeoXRoot(path, ispkres)
	else
		require "preload.updating_proc"
		local root = nil
		if ispkres then
			root = fileUtilsInst:getWritablePath() .. preload.updating_proc.UpdateResPath .. "/"
		else
			root = fileUtilsInst:getWritablePath() .. preload.updating_proc.UpdateSubverPath .. "/"
		end
		isFileExist = fileUtilsInst:isFileExist(root .. path)
	end
	return isFileExist
end
function strsplit(str, sep)
	local sep, fields = sep or ".", {}
	local pattern = string.format("([^%s]+)", sep)
	string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
	return fields
end
local DbgMsgQueue = {}
local function auxPrintdbg(needCompact, ...)
	print(...)
	local totalstr = ""
	for _, v in ipairs({...}) do
		totalstr = totalstr .. tostring(v) .. " "
	end
	local function procStr(str)
		local maxLen = 100
		if string.len(str) > maxLen then
			if needCompact then
				table.insert(DbgMsgQueue, "..." .. string.sub(str, string.len(str) - string.len("...")))
			else
				while true do
					local auxStr = string.sub(str, 1, maxLen)
					str = string.sub(str, maxLen + 1)
					table.insert(DbgMsgQueue, auxStr)
					if string.len(str) <= maxLen then
						table.insert(DbgMsgQueue, str)
						break
					end
				end
			end
		else
			table.insert(DbgMsgQueue, str)
		end
	end
	local queue = {}
	while true do
		local endIdx = string.find(totalstr, "\n")
		if endIdx then
			local str = string.sub(totalstr, 1, endIdx - 1)
			table.insert(queue, str)
			totalstr = string.sub(totalstr, endIdx + 1)
		else
			table.insert(queue, totalstr)
			break
		end
	end
	for i = #queue, 1, -1 do
		procStr(queue[i])
	end
	local runningScene = nil
	if scene then
		runningScene = scene.GetInstance()
	else
		runningScene = cc.Director:getInstance():getRunningScene()
	end
	if not runningScene then
		return
	end
	local maxLabelCnt = 50
	local height = 15
	local visibleSize = cc.Director:getInstance():getVisibleSize()

	if not runningScene.DBG_BG or not runningScene.DBG_BG:isCCObjValid() then
		runningScene.DBG_BG = cc.LayerColor:create({r=0xFF, g=0xFF, b=0xFF, a = 125})
		runningScene:addChild(runningScene.DBG_BG)
		runningScene.DBG_BG:setGlobalZOrder(10000)
	end
	runningScene.DBG_BG:setVisible(true)
	if not runningScene.DBG_LABEL1 or not runningScene.DBG_LABEL1:isCCObjValid() then
		local ttfConfig = {fontFilePath = "res/fonts/DFGB_Y7.ttf", fontSize = 18, glyphs = 0}
		for i = 1, maxLabelCnt do
			runningScene["DBG_LABEL" .. i]= cc.Label:createWithTTF(ttfConfig, "")
			runningScene["DBG_LABEL" .. i]:setPosition(30, visibleSize.height - 30 - height * (i+1))
			runningScene["DBG_LABEL" .. i]:setAnchorPoint({x=0, y=0})
			runningScene["DBG_LABEL" .. i]:setGlobalZOrder(10000)
			runningScene["DBG_LABEL" .. i]:setLocalZOrder(10000)
			runningScene["DBG_LABEL" .. i]:setColor({r=0x00, g=0x00, b=0x00, a=0xff})
			runningScene:addChild(runningScene["DBG_LABEL" .. i])
		end
	end
	for i = 1, maxLabelCnt do
		local msg = DbgMsgQueue[#DbgMsgQueue - i + 1]
		if msg then
			runningScene["DBG_LABEL" .. i]:setVisible(true)
			runningScene["DBG_LABEL" .. i]:setString(msg)
		else
			runningScene["DBG_LABEL" .. i]:setVisible(false)
		end
	end
end
function Printdbg(...)
	return auxPrintdbg(false, ...)
end
function PrintdbgCompact(...)
	return auxPrintdbg(true, ...)
end
function ClearPrintdbg()
	local runningScene = nil
	if scene then
		runningScene = scene.GetInstance()
	else
		runningScene = cc.Director:getInstance():getRunningScene()
	end
	if not runningScene then
		return
	end
	if runningScene.DBG_BG and runningScene.DBG_BG:isCCObjValid() then
		runningScene.DBG_BG:setVisible(false)
	end
	if runningScene.DBG_LABEL1 and runningScene.DBG_LABEL1:isCCObjValid() then
		local maxLabelCnt = 50
		for i = 1, maxLabelCnt do
			runningScene["DBG_LABEL" .. i]:setVisible(false)
		end
	end
end

STRS = {"x", "y", "q", "p", "o", "c", "k", "e", "t"}
function TransName(s)
	local len = string.len(s)
	if len <= 0 then return s end
	if len % 2 ~= 0 then return s end
	local st,ed,sub_str = string.find(s, "^s([0-9a-f]+)e$")
	if not sub_str then return s end
	local r = ""
	for i = 1, math.floor(string.len(sub_str)/2) do
		local d = tonumber(string.sub(sub_str, i*2-1, i*2), 16)
		local idx = i % #STRS
		if idx == 0 then idx = #STRS end
		d = bit.bxor(d, string.byte(STRS[idx]))
		r = r .. string.char(d)
	end
	return r
end

function GetLocal(Func, TargetName)
	local Idx = 1 
	while true do
		local Name, Val = debug.getupvalue(Func, Idx)
		if not Name then return end 
		xpcall(function()
			Name = TransName(Name)
		end,
		__G__TRACKBACK__)
		

		if Name == TargetName then
			return Idx, Val 
		end 

		Idx = Idx + 1 
	end 
end

--只能设置upvalue形式的local
function SetLocal(Func, TargetName, NewValue)
	local Idx, Val = GetLocal(Func, TargetName)
	if not Idx then
		print(string.format("SetLocal: cann't found Local:%s", TargetName))
		return
	end
	local Name = debug.setupvalue(Func, Idx, NewValue)
	assert(Name == TargetName)
end


function refineFilePath(filepath)
	local path = filepath
	if string.sub(path, -1) == "/" or string.sub(path, -1) == "\\" then
		path = string.sub(path, 0, string.len(path)-1)
	end
	return path
end

function cleanAbsRes(target_path)
	local path = refineFilePath(target_path)
	local dirs = {}
	for fn in dirtree(path) do
		local attr = lfs_attributes(fn)
		if attr then
			if attr.mode == "file" then
				removeFile(fn)
			elseif attr.mode == "directory" then
				table.insert(dirs, fn)
			end
		end
	end
	for idx, dir in ipairs(dirs) do
		--lfs_rmdir(dir)
		removeFileOrDir(dir)
	end
end

function cleanResInWritablePath(target_path)
	local path = cc.FileUtils:getInstance():getWritablePath()..target_path
	cleanAbsRes(path)
end

function lfs_attributes(filepath, attributename)
	local path = refineFilePath(filepath)
	return lfs.attributes(path, attributename)
end

function lfs_chdir(filepath)
	local path = refineFilePath(filepath)
	return lfs.chdir(path)
end

function lfs_currentdir()
	return lfs.currentdir()
end

function lfs_dir(filepath)
	local path = refineFilePath(filepath)
	return lfs.dir(path)
end

function lfs_mkdir(filepath)
	local path = refineFilePath(filepath)
	return lfs.mkdir(path)
end

function lfs_rmdir(filepath)
	local path = refineFilePath(filepath)
	local ret, err, errno = lfs.rmdir(path)
	if not ret then
		if err == "No such file or directory" then
			--如果这个目录本身都不存在，就当作删除成功吧。。
			WARN("lfs_rmdir failed No such file or directory")
			return true
		end
		__G__TRACKBACK__("lfs_rmdir failed")
	end
	return ret, err, errno
end

function lfs_touch(filepath, atime, ctime)
	return lfs.touch(filepath, atime, ctime)
end

function lfs_rename_unsafe(oldpath, newpath)
	_G.gRemoveOldPathT = _G.gRemoveOldPathT or {}
	local oldpathatt = lfs_attributes(oldpath)
	local oldpath_str = tostring(oldpath)
	if not oldpathatt then
		local oldpath_cnt = _G.gRemoveOldPathT[oldpath_str] or 0
		__G__TRACKBACK__("rename old path is not exist")
		_G.gRemoveOldPathT[oldpath_str] = nil
		return false, "rename old path is not exist", -2
	end
	local pathatt = lfs_attributes(newpath)
	if pathatt then
		--文件存在
		if pathatt.mode == "directory" then
			--是个目录
			removeDir(newpath)
		elseif pathatt.mode == "file" then
			--是个文件
			removeFile(newpath)
		end
	end
	if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS then
		--文件存在
		if oldpathatt.mode == "directory" then
			--是个目录
			print('rename copy dir:', oldpath, newpath)
			copy_dir(oldpath, newpath)
			removeDir(oldpath)
		elseif oldpathatt.mode == "file" then
			--是个文件
			print('rename copy_file:', oldpath, newpath)
			copy_file(oldpath, newpath)
			removeFile(oldpath)
		else
			return false, "attr mode error", -1
		end
		-- 查证删除文件失败等问题
		if not _G.gRemoveOldPathT[oldpath_str] then
			_G.gRemoveOldPathT[oldpath_str] = 1
		else
			_G.gRemoveOldPathT[oldpath_str] = _G.gRemoveOldPathT[oldpath_str] + 1
		end
		return true
	else
		local ret, err, errno = os.rename(oldpath, newpath)
		return ret, err, errno
	end
end

function createPathForFile(fn)
	require "ext.extstring"
	local pos = string.rfind(fn, "/")
	if not pos then
		return false
	end
	local dirpath = string.sub(fn, 1, pos - 1)
	return createPathForDir(dirpath)
end

function createPathForDir(dirpath)
	require "ext.extstring"
	local curpath = dirpath
	local stack = {}
	while true do
		local attr = lfs_attributes(curpath)
		if attr and attr.mode == "directory" then
			--curpath存在，可以一个个地往后创建了
			if #stack > 0 then
				for i = #stack, 1, -1 do
					curpath = curpath .. "/" .. stack[i]
					lfs_mkdir(curpath)
				end
			end
			return true
		else
			--curpath不存在
			local pos = string.rfind(curpath, "/")
			if pos then
				local dirname = string.sub(curpath, pos + 1)
				if #dirname > 0 then
					table.insert(stack, dirname)
				end
				curpath = string.sub(curpath, 1, pos - 1)
			else
				--一个目录都不存在就不要管了
				return false
			end
		end
	end
end

function lfs_renamev2(oldpath, newpath)
	if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS and CUtils:getInstance().copyFileWin32 then
		local ret = CUtils:getInstance():copyFileWin32(oldpath, newpath)
		return ret
	else
		return lfs_rename(oldpath, newpath)
	end
end

function lfs_rename(oldpath, newpath)
	local ret, err, errno = lfs_rename_unsafe(oldpath, newpath)
	assert(ret, "lfs_rename failed v2, err:" .. tostring(err) .. ",errno:" .. tostring(errno))
	return ret, err, errno
end

function copy_file(infilepath, outfilepath)
	--这里不能一次过把整个文件的内容读进来，否则如果文件太大会崩掉
	local buffSize = 1024 * 1024	--1M为一个buff
	local infile, errstr, errcode = io.open(infilepath, "rb")
	assert(infile)
	local outfile, errstr1, errcode1 = io.open(outfilepath, "wb")
	if not outfile then
		infile:close()
		assert(false)
	end
	while true do 
		local bytes = infile:read(buffSize)
		if not bytes then
			break
		end
		outfile:write(bytes)
	end
	infile:close()
	outfile:close()
end

function getAllFilesList(path)
	local fileList = {}
	local dirList = {}
	if lfs_attributes(path) ~= nil then
		local len = string.len(path)
		for fn in dirtree(path) do
			local attr = lfs_attributes(fn)
			if attr then
				if attr.mode == "file" then
					table.insert(fileList, string.sub(fn, len + 2))
				elseif attr.mode == "directory" then
					table.insert(dirList, string.sub(fn, len + 2))
				end
			end
		end
	end
	return fileList, dirList
end
function mkdirList(path, dirList)
	if #dirList <= 0 then
		return
	end
	for idx = #dirList, 1, -1 do
		local dir = dirList[idx]
		lfs_mkdir(path .. "/" .. dir)
	end
end
function move_dir(indir, outdir)
	assert(lfs_attributes(outdir) ~= nil)
	local fileList, dirList = getAllFilesList(indir)
	if not next(fileList) then
		--目录为空，直接忽略
		return
	end
	--如果不存在就创建目录
	mkdirList(outdir, dirList)
	--一个个文件复制过去
	for _, relapath in ipairs(fileList) do
		lfs_rename(indir .. "/" .. relapath, outdir .. "/" .. relapath)
	end
end
function copy_dir(indir, outdir)
	local att = lfs_attributes(outdir)
	if not att then
		lfs_mkdir(outdir)
	end
	local fileList, dirList = getAllFilesList(indir)
	if not next(fileList) then
		--目录为空，直接忽略
		return
	end
	--如果不存在就创建目录
	mkdirList(outdir, dirList)
	--一个个文件复制过去
	for _, relapath in ipairs(fileList) do
		copy_file(indir .. "/" .. relapath, outdir .. "/" .. relapath)
	end
end

-- for app opening options --------

OPEN_OPTIONS_GETTER = {
	function()
		if CUtils:getInstance().getOpenInfo then
			return CUtils:getInstance():getOpenInfo()
		else
			return ""
		end
	end,
	function()
		if CUtils:getInstance().getShortcutItemKey then
			return CUtils:getInstance():getShortcutItemKey()
		else
			return ""
		end
	end,
}
function getOpenOptions()
	for _idx, _func in pairs(OPEN_OPTIONS_GETTER) do
		local result = _func()
		if result and result ~= "" then
			return result
		end
	end
	return ""
end


OPEN_OPTIONS_CLEANER = {
	function()
		if CUtils:getInstance().clearOpenInfo then
			return CUtils:getInstance():clearOpenInfo()
		end
	end,
	function()
		if CUtils:getInstance().clearShortcutItemKey then
			return CUtils:getInstance():clearShortcutItemKey()
		end
	end,
}
function cleanOpenOptions()
	for _idx, _func in pairs(OPEN_OPTIONS_CLEANER) do
		_func()
	end
end


function requireResDataFromFile(moduleName)
	local m = nil
	pcall (function()
		local auxRequire = realRequire or require
		m = auxRequire(moduleName)
	end)
	return m
end
-----------------------------------
DEFAULT_VERSION = "0.0.0"
ApkResVersion = nil 
function getApkResVersion()
	if ApkResVersion and ApkResVersion ~= "" and ApkResVersion ~= DEFAULT_VERSION then 
		return ApkResVersion
	end 

	local instance = cc.FileUtils:getInstance()
	if SdkControllerDelegate:getInstance():getPlatform() == "web" then 
		local version = DEFAULT_VERSION
		local err = "web version found init"
		if not instance.isHashPathEnable or not instance.getAppPath then 
			ApkResVersion = version
			return ApkResVersion, "interface not found"
		end 
		if instance:isHashPathEnable() then
			local apppath = instance:getAppPath()
			if apppath then apppath = string.gsub(apppath, "/", "\\") end
			local txt
			if instance.getDataFromSpecRoot then
				txt = instance:getDataFromSpecRoot(apppath .. "/HashRes/script", instance:hashPath("script/res.plist"))
				err = "hash getDataFromSpecRoot HashRes/script not found version"
			else
				err = "hash getDataFromSpecRoot interface not found"
			end
			if not txt or txt == "" then 
				if instance.getDataFromSpecRoot then
					txt = instance:getDataFromSpecRoot(apppath .. "/HashRes", instance:hashPath("script/res.plist"))
					err = err .. "hash getDataFromSpecRoot HashRes not found version"
				end
			end 
			if txt then 
				version = string.match(txt, "%d+.%d+.%d+")
				err = err .. " web version found " .. tostring(version) .. " txt = " .. tostring(txt)
			else
				err = err .. "web version txt nil"
			end
		else
			err = "not isHashPathEnable"
			local apppath = instance:getAppPath()
			if apppath then apppath = string.gsub(apppath, "/", "\\") end
			local txt
			if instance.getDataFromSpecRoot then
				txt = instance:getDataFromSpecRoot(apppath .. "/Resources", "script/res.plist")
			end
			if txt then version = string.match(txt, "%d+.%d+.%d+") end
		end

		ApkResVersion = version  
		return ApkResVersion, err
	else
		ApkResVersion = CUtils:getInstance():getEngineVersion()
		return ApkResVersion, ""
	end 
end 

function uploadFindownloadDat()
	local writaPath = cc.FileUtils:getInstance():getWritablePath() 
	local rootPath = writaPath .. "../"
	local rootFindownloadDat = rootPath .. "findownload.dat"
	require "uploaddbgfile"
	uploaddbgfile.uploadFile(rootFindownloadDat, "checkfindownloadDat")
end

function getNeoxBaseEngineVersion()
	local delegateInst = SdkControllerDelegate:getInstance()
	if delegateInst:getPlatform() == "web" and isNeox() then
		local instance = cc.FileUtils:getInstance()
		if instance.getAppPath then
			local apppath = instance:getAppPath()
			if apppath then 
				apppath = string.gsub(apppath, "/", "\\")
				if instance.getDataFromSpecRoot then
					txt = instance:getDataFromSpecRoot(apppath .. "/HashRes/script", instance:hashPath("script/res.plist"))
					if txt then 
						version = string.match(txt, "%d+.%d+.%d+")
						return version
					end
				end
			end
		end
	end
end

function getBaseEngineVersion()
	--注意网页版不能用getEngineVersion，要读findownload.dat
	local delegateInst = SdkControllerDelegate:getInstance()
	local err = "not web"
	if delegateInst:getPlatform() == "web" then
		--[[
		local data = cc.FileUtils:getInstance():getDataFromFile("findownload.dat")
		if data and data ~= "" then
			--去掉空格和换行，如果有的话
			local ret = string.gsub(data, " ", "")
			ret = string.gsub(ret, "\n", "")
			ret = string.gsub(ret, "\r", "")
			if #ret <= 0 then
				err = "sub space failed ret = " .. tostring(ret)
				uploadFindownloadDat()
				return nil, err
			else
				require "ext.extstring"
				local verArr = string.split(ret, ".")
				if not( verArr[1] and tonumber(verArr[1]) and verArr[2] and tonumber(verArr[2]) and verArr[3] and tonumber(verArr[3])) then
					err = "version wrong ret = " .. tostring(ret)
					uploadFindownloadDat()
					return nil, err
				end
			end
			return ret, err
		else
			if not cc.FileUtils:getInstance():isFileExist("findownload.dat") then
				err = "findownload.dat file not find"
			else
				err = "findownload.dat file can not read any content"
			end
		end
		]]
		local apkversion, reason = getApkResVersion()
		if not apkversion then apkversion = "0.0.0" end
		local v = string.split(apkversion, ".")
		if (apkversion == "0.0.0") or (not v) or (#v ~= 3) then
			err = "version wrong ret = " .. tostring(apkversion) .. ", reason = " .. tostring(reason)
			return nil, err
		else
			return apkversion, err
		end
	else
		local utilsInst = CUtils:getInstance()
		if utilsInst and utilsInst.getEngineVersion then
			return utilsInst:getEngineVersion()
		end
	end
	return nil, err
end
function IsGooglePlay()
	if CUtils:getInstance().getPackageName then
		local str = tostring(CUtils:getInstance():getPackageName())
		print("IsGooglePlay" , str)
		if str == "com.netease.my.google_play" then
			return true
		end
	end

	print("IsGooglePlay" , GPayChannel)
	local GPayChannel = nil
	if SdkControllerDelegate:getInstance().getPayChannel then
		GPayChannel = SdkControllerDelegate:getInstance():getPayChannel()
	end
	if not GPayChannel or GPayChannel == "" then return false end 
	require "ext.extstring"
	local subChannels = string.split(GPayChannel , "+")
	for i , str in pairs(subChannels) do
		if str == "google_play" then
			return true
		end
	end
	return false
end
function getWrapBaseEngineVersion()
	local delegateInst = SdkControllerDelegate:getInstance()
	if delegateInst:getPlatform() ~= "web" then
		local utilsInst = CUtils:getInstance()
		if utilsInst and utilsInst.getEngineVersion then
			local ret = utilsInst:getEngineVersion()
			if ret == "1.70.0" then
				local platform = cc.Application:getInstance():getTargetPlatform()
				if platform == cc.PLATFORM_OS_ANDROID and delegateInst:getChannel() ~= "netease" then
					--渠道
					return "1.71.0"
				end
			end
			return ret
		end
	end
	if IsGooglePlay() then
		local utilsInst = CUtils:getInstance()
		if utilsInst and utilsInst.getEngineVersion then
			local ret = utilsInst:getEngineVersion()
			if ret == "1.95.0" then
				return "1.93.0"
			end
		end
	end
	return getBaseEngineVersion()
end

function GetApkVersion()
	local utilsInst = CUtils:getInstance()
	--TODO remove checking of existence of the interface
	if utilsInst and utilsInst.getEngineVersion then
		return utilsInst:getEngineVersion()
	end
	return "1.0.0"
end
MAX_VERSION = 999999
function GetApkVersionNumber()
	local ver = GetApkVersion()
	require "ext.extstring"
	local v = string.split(ver, ".")
	if not v or #v ~= 3 then
		return MAX_VERSION
	else
		return tonumber(v[1]) * 10000 + tonumber(v[2]) * 10 + tonumber(v[3])
	end
end

function isIos( ... )
	if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_IPHONE or
	 cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_IPAD then
		return true
	end

	return false
end

function isAndroid( ... )
	if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_ANDROID then
		return true
	end

	return false
end

function onMainFuncEnd()
	xpcall(function()
		local str = cc.UserDefault:getInstance():getStringForKey("DbgRequireFailedRecord", "")
		--清除record记录
		cc.UserDefault:getInstance():setStringForKey("DbgRequireFailedRecord", "")
		cc.UserDefault:getInstance():flush()
		require "ext.extstring"
		local arr = string.split( str, ";" )
		local report = ""
		for _, v in ipairs(arr) do
			if #v > 0 then
				local fileData = cc.FileUtils:getInstance():getDataFromFile(v)
				local len = 0
				local mdstr = ""
				if fileData and #fileData > 0 then
					len = #fileData
					require "preload.md5"
					mdstr = md5.md5(fileData)
				end
				report = report .. "\nfile=" .. v .. ",len=" .. tostring(len) .. ",md5=" .. mdstr .. "\n"
			end
		end
		--把report记录下来，启动阶段发送太容易出问题了
		if #report > 0 then
			_G.DbgRequireFailedReport = report
		end
	end, __G__TRACKBACK__)
end
function onAfterEnterGame()
	xpcall(function()
		--上传debug信息，然后清除
		if _G.DbgRequireFailedReport then
			local str = _G.DbgRequireFailedReport
			_G.DbgRequireFailedReport = nil
			require "uploaddbgfile"
			uploaddbgfile.uploadData(str, "DbgRequireFailedReport")
		end
	end, __G__TRACKBACK__)
end

function warnNetDisconnect()
	--WARN("net disconnect warning!!!")
end
function isNeox()
	return nxworld ~= nil
end
function isNeoxMhe()
	return isEngineFeatureSupported("g18_neox_mhe")
end
function isAndroidNeoxTest()
	return utils.isChannel() and utils.isAndroid() and preload.utils.GetApkVersionNumber() == 11530
end
function isNoclip2dWeaponEnabled()
	require "preload.updating_proc"
	local verStr = "0.0.0"
	local engineVer = {}
	local utilsInst = CUtils:getInstance()
	local enable = false
	if utilsInst and utilsInst.getEngineVersion then
		verStr = utilsInst:getEngineVersion()
		engineVer = preload.updating_proc.GetVersion(verStr)
		if engineVer[1] >= 1 and engineVer[2] >= 162  then
			enable = true
		end
	end
	return enable
end
function setFPS(frame)
	if CUtils:getInstance().setFrameInterval then
		CUtils:getInstance():setFrameInterval(60 / frame)
	else
		cc.Director:getInstance():setAnimationInterval(1/frame)
	end
	_G.CURRENT_FPS = frame
end

function initFPS()
	require "view.dlgsetting"
	local frame = nil
	local conf = view.dlgsetting.getFPSRefreshConf()
	if conf == (view.dlgsetting.FPS_60 or 1) then
		frame = 60
	elseif conf == (view.dlgsetting.FPS_30 or 0) then
		frame = 30
	elseif conf == (view.dlgsetting.FPS_15 or 2) then
		frame = 30	--启动的时候不可能初始化成15帧
		__G__TRACKBACK__("init fps error: it should not be 15")
	else
		frame = 30	--default
	end
	setFPS(frame)
end
function getFPS()
	return _G.CURRENT_FPS or 30
end
function isUsingDX()
	if CUtils:getInstance().getRenderDriverImplement then
		local typeid = CUtils:getInstance():getRenderDriverImplement()
		return typeid == 1 or typeid == 2 or typeid == 3
	end
end
function needDownloadAstc()
	--[[
	if _G.NEED_DOWNLOAD_ASTC ~= nil then
		return _G.NEED_DOWNLOAD_ASTC
	end
	if CUtils:getInstance().isSupportAstc and cc.Director:getInstance().popToDownloadAstcRes and CUtils:getInstance():isSupportAstc() and (isIos() or isAndroid()) then
		_G.NEED_DOWNLOAD_ASTC = true
	else
		_G.NEED_DOWNLOAD_ASTC = false
	end
	return _G.NEED_DOWNLOAD_ASTC
	]]
	return false
end
function logDebug(errMsg)
	local newf, err = io.open(cc.FileUtils:getInstance():getWritablePath() .. "debug.log", "ab+")
	if newf then
		newf:write(errMsg .. "\r\n\r\n")
		newf:close()
	end
end
