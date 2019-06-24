

module(..., package.seeall)

require "ext.extarray"

local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep

local function isEncodable(o)
	local t = type(o)
	return (t=='string' or t=='boolean' or t=='number' or t=='nil' or t=='table') or (t=='function' and o==null) 
end

function getCompactString(obj)
	if string.getCompactString then
		return string.getCompactString(obj)
	else
		return tostring(obj)
	end
end

function isArray(t)
	-- Next we count all the elements, ensuring that any non-indexed elements are not-encodable 
	-- (with the possible exception of 'n')
	if not t then
		return false
	end
	local len = #t
	for i = 1, len do
		if t[i] == nil then
			return false
		end
	end
	for k,v in pairs(t) do
		if type(k) == "number" then
			if math.floor(k)==k then
				--整数
				if k <= 0 or k > len then
					return false
				end
			else
				--非整数，一定不是arr
				return false
			end
		elseif k ~= "n" then
			--除了1,..,len和n以外，其他的key都不对
			return false
		end
	end
	return true
end

local function _normalize(value)
	local retval = ''
	if type(value) == 'function' then
		retval = '<' .. tostring(value) .. '>'
	elseif type(value) == 'table' then
		retval = '<' .. tostring(value) .. '>'
	elseif type(value) == 'string' then
		retval = getCompactString(string.format('%q',value))
	else
		retval = tostring(value)
	end
	return retval
end

function table.repr(value, split)
	split = split or ""
	local rettbl = {}
	if type(value) == 'table' then
		local visited = {}
		table.insert(rettbl, '{')
		for i, v in ipairs(value) do
			table.insert(rettbl, split .. _normalize(v))
			table.insert(rettbl, ',')
			visited[i] = 1
		end
		for k, v in pairs(value) do
			if not visited[k] then
				table.insert(rettbl, split .. '[')
				table.insert(rettbl, _normalize(k))
				table.insert(rettbl, '] = ')
				table.insert(rettbl, _normalize(v))
				table.insert(rettbl, ', ')
			end
		end
		table.insert(rettbl, '}')
	else
		table.insert(rettbl, _normalize(value))
	end
	return tconcat(rettbl)
end

function table.serialize(root, space, name, maxItemCnt)
	space = space or ""
	name = name or ""
	local cache = {  [root] = "." }
	local itemCnt = 0
	local MAX_ITEM_CNT = maxItemCnt or 10
	local function _dump(t, space, name)
		local temp = {}
		for k,v in pairs(t) do
			itemCnt = (itemCnt or 0) + 1
			if itemCnt >= MAX_ITEM_CNT then
				--too long
				if itemCnt == MAX_ITEM_CNT then
					tinsert(temp, "\n...\n")
				end
				break
			end
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" and not IsClsReservedVarName(key) then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v, space .. (next(t,k) and "|" or " " ).. srep(" ",#key), new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. getCompactString(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	return _dump(root, space, name)
end

function table.print(root)
	if _G.COCOS2D_DEBUG then
		string.fullprint("\n" .. table.serialize(root, nil, nil, 20000))
	end
end

NO_BLANK_PATTERN = "[^ \t\n\r]"
BLANK_AND_EQUAL_PATTERN = "[= \t\n\r]"
TERM_PATTERN = "[%]}, \t\n\r]"
function parseNumber(str, begIdx)
	local endIdx = string.find(str, TERM_PATTERN, begIdx)
	assert(endIdx, string.sub(str, 1, begIdx))
	local numStr = string.sub(str, begIdx, endIdx - 1)
	local num = tonumber(numStr)
	assert(num, string.sub(str, 1, endIdx))
	return num, endIdx
end
function parseBool(str, begIdx)
	local endIdx = string.find(str, TERM_PATTERN, begIdx)
	assert(endIdx, string.sub(str, 1, begIdx))
	local boolStr = string.sub(str, begIdx, endIdx - 1)
	if boolStr == "true" then
		return true, endIdx
	elseif boolStr == "false" then
		return false, endIdx
	else
		assert(false, string.sub(str, 1, endIdx))
	end
end
function parseString(str, begIdx)
	local len = #str
	local endIdx
	endIdx = string.find(str, NO_BLANK_PATTERN, begIdx)
	assert(endIdx and endIdx ~= len, string.sub(str, 1, begIdx))
	begIdx = endIdx
	local charStr = string.sub(str, begIdx, begIdx)
	local returnEndIdx
	if charStr == "\"" then
		begIdx = begIdx + 1
		endIdx = string.find(str, "\"", begIdx)
		returnEndIdx = endIdx + 1
	elseif charStr == "[" then
		begIdx = begIdx + 1
		--看看开头是不是[[
		if string.sub(str, begIdx, begIdx) ~= "[" then
			assert(false, string.sub(str, 1, begIdx))
		end
		--查找]]
		begIdx = begIdx + 1
		endIdx = string.find(str, "]]", begIdx)
		returnEndIdx = endIdx + 2
	else
		assert(false, string.sub(str, 1, begIdx))
	end
	if not endIdx then
		assert(false, string.sub(str, 1, begIdx))
	end
	if begIdx == endIdx then
		return "", returnEndIdx
	else
		return string.sub(str, begIdx, endIdx - 1), returnEndIdx
	end
end

function table.parseVal(str, begIdx)
	return parseVal(str, begIdx)
end

function parseVal(str, begIdx)
	local endIdx = string.find(str, NO_BLANK_PATTERN, begIdx)
	assert(endIdx, string.sub(str, 1, begIdx))
	begIdx = endIdx
	local charStr = string.sub(str, begIdx, begIdx)
	if charStr == "{" then
		--这是个table
		return parseTbl(str, begIdx)
	elseif charStr == "\"" then
		--这是个字符串
		return parseString(str, begIdx)
	elseif charStr == "[" then
		--这可能是字符串
		return parseString(str, begIdx)
	elseif charStr == "." or charStr == "+" or charStr == "-" or tonumber(charStr) then
		--这是个数字
		return parseNumber(str, begIdx)
	elseif charStr == "t" or charStr == "f" then
		--这可能是bool值
		return parseBool(str, begIdx)
	else
		--由于没有复杂的变量赋值，这里不会是变量名，只能是错误了
		assert(false, string.sub(str, 1, begIdx))
	end
end
function parseKeyVal(str, begIdx)
	local charStr = string.sub(str, begIdx, begIdx)
	local key
	if charStr == "[" then
		--找key
		begIdx = begIdx + 1
		local endIdx
		key, endIdx = parseVal(str, begIdx)
		assert(key ~= nil, string.sub(str, 1, begIdx))
		begIdx = endIdx
		--找]
		endIdx = string.find(str, "]", begIdx)
		assert(endIdx, string.sub(str, 1, begIdx))
		begIdx = endIdx
		begIdx = begIdx + 1
	else
		--把key抠出来
		local endIdx = string.find(str, BLANK_AND_EQUAL_PATTERN, begIdx)
		assert(endIdx, string.sub(str, 1, begIdx))
		key = string.sub(str, begIdx, endIdx - 1)
		begIdx = endIdx
	end
	--找等号
	local endIdx = string.find(str, "=", begIdx)
	assert(endIdx, string.sub(str, 1, begIdx))
	begIdx = endIdx
	begIdx = begIdx + 1
	--找value
	local val
	val, endIdx = parseVal(str, begIdx)
	assert(val ~= nil, string.sub(str, 1, begIdx))
	begIdx = endIdx
	return key, val, begIdx
end
--注意不支持语法不正确的str，不支持转义符，不支持注释
function parseTbl(str, begIdx)
	local oldBegIdx = begIdx
	begIdx = begIdx or 1
	local endIdx, charStr
	local ret = {}
	local len = #str
	local key
	--先找到{
	endIdx = string.find(str, NO_BLANK_PATTERN, begIdx)
	assert(endIdx, string.sub(str, 1, begIdx))
	begIdx = endIdx
	charStr = string.sub(str, begIdx, begIdx)
	if charStr == "{" then
		begIdx = begIdx + 1
	else
		assert(false, string.sub(str, 1, begIdx))
	end
	--begIdx开始是一个val，处理之
	local function procVal()
		local subval
		local curEndIdx
		subval, curEndIdx = parseVal(str, begIdx)
		assert(subval ~= nil, string.sub(str, 1, begIdx))
		begIdx = curEndIdx
		table.insert(ret, subval)
	end
	--begIdx开始是一个key=val，处理之
	local function procKeyVal()
		local val
		local curEndIdx
		key, val, curEndIdx = parseKeyVal(str, begIdx)
		assert(key ~= nil, string.sub(str, 1, begIdx))
		begIdx = curEndIdx
		ret[key] = val
	end
	while begIdx <= len do
		--找key或者array的item
		endIdx = string.find(str, NO_BLANK_PATTERN, begIdx)
		assert(endIdx, string.sub(str, 1, begIdx))
		begIdx = endIdx
		charStr = string.sub(str, begIdx, begIdx)
		--根据charStr来判断这是key=val还是val
		if charStr == "[" then
			--有可能是[[val]]，或者[key] = val
			if begIdx >= len then
				assert(false, string.sub(str, 1, begIdx))
			end
			charStr = string.sub(str, begIdx + 1, begIdx + 1)
			if charStr == "[" then
				--只可能是[[val]]
				procVal()
			else
				--只可能是[key] = val
				procKeyVal()
			end
		elseif charStr == "\"" then
			--只可能是val
			procVal()
		elseif charStr == "{" then
			--只可能是val
			procVal()
		elseif charStr == "}" then
			--就是个空表
			return ret, begIdx + 1
		elseif charStr == "." or charStr == "+" or charStr == "-" or tonumber(charStr) then
			--只可能是val
			procVal()
		elseif charStr == "t" or charStr == "f" then
			--可能是boolean val，也可能是key = value
			endIdx = string.find(str, TERM_PATTERN, begIdx)
			if endIdx then
				--可能是boolean val，也可能是key = value
				local maybeBooleanVal = string.sub(str, begIdx, endIdx - 1)
				if maybeBooleanVal == "true" or maybeBooleanVal == "false" then
					--只能是boolean
					procVal()
				else
					--只能是key=value
					procKeyVal()
				end
			else
				--只能是key = value
				procKeyVal()
			end
		else
			--由于不会有复杂的变量赋值，只可能是key=val
			procKeyVal()
		end
		--找下一个逗号或者}
		endIdx = string.find(str, NO_BLANK_PATTERN, begIdx)
		assert(endIdx, string.sub(str, 1, begIdx))
		begIdx = endIdx
		charStr = string.sub(str, begIdx, begIdx)
		if charStr == "," then
			--挪到下一个char，开始下一个keyval或者val的处理
			begIdx = begIdx + 1
		elseif charStr == "}" then
			--这个table结束了
			return ret, begIdx + 1
		else
			--除了逗号和}不会有别的分隔符
			assert(false, string.sub(str, 1, begIdx))
		end
	end
end

--由于我们引擎会禁止使用loadstring加载明文代码，这种反序列化的事情只能我们自己做了
function table.unserialize(str)
	--由于这个接口所使用的场景是我们先序列化一个数据，在需要的时候再需要反序列化，所以只要支持table.dump和json模块所产生的str
	--能正常反序列化就可以了
	return parseTbl(str)
end

--这个接口专门用于输出内容到文件去
function table.dump(root, name, descStr, filepath, orgTab)
	if descStr == nil then descStr = "" end
	if orgTab == nil then orgTab = 0 end
	local str = descStr
	if name ~= nil then 
		str = string.format("%s%s = ", str, name)
	end
	local validNormalType = {
		["number"] = true, ["string"] = true, ["boolean"] = true
	}
	local function appendWithTab(input, tabNum)
		local space = string.rep("    ", (tabNum or 0))
		str = string.format("%s%s%s", str, space, input)
	end

	local outputDict = function() end

	local function outputNormal(value, tabNum)
		local typeStr = type(value)
		assert(validNormalType[typeStr], typeStr)
		local repr = tostring(value)
		if typeStr == "string" then
			--这里会修改value的内容，严格来说是不允许的，但是我们目前对table.dump的使用都是
			--用来序列化玩家输入，玩家就是可能输入]]，所以必须转义，与其到处写检查和转义代码
			--还不如把它写到这里，以后如果有需要不能转义只能assert的情况就往table.dump加参数吧
			local oldvalue = value
			local invalidIdx = string.find(value, "]]")
			if invalidIdx then
				value = string.gsub(value, "]]", "］］")
			end
			invalidIdx = string.find(value, "]$")
			if invalidIdx then
				value = string.gsub(value, "]$", "］")
			end
			repr = string.format("[[%s]]", value)
			if _G.COCOS2D_DEBUG and oldvalue ~= value then
				__G__TRACKBACK__("table.dump input ]] or ]$")
			end
		end
		appendWithTab(string.format("%s,\n", repr), tabNum)
	end	

	local function outputArray(array, tabNum)
		appendWithTab("{\n", tabNum)
		for k, v in ipairs(array) do
			if type(v) == "table" and isArray(v) then
				outputArray(v, tabNum + 1)
				str = str..",\n"
			elseif type(v) == "table" then
				outputDict(v, tabNum + 1)
				str = str..",\n"
			else
				outputNormal(v, tabNum + 1)	
			end	
		end	
		appendWithTab("}\n", tabNum)
	end	

	outputDict =  function(dict, tabNum)
		appendWithTab("{\n", tabNum)
		for k, v in pairs(dict) do
			if type(k) == "string" then
				local keyStr = tostring(k)
				local invalidIdx = string.find(keyStr, "]]")
				assert(not invalidIdx)
				invalidIdx = string.find(keyStr, "]$")
				assert(not invalidIdx)
				appendWithTab(string.format("[ [[%s]] ] = ", keyStr), tabNum+1)
			elseif type(k) == "number" then
				appendWithTab(string.format("[%s] = ", tostring(k)), tabNum+1)
			else
				--不是string或者number的key会被认为是错误的，就算这里兼容了，恢复的时候也基本上会有问题，还不如直接报错
				assert(false)
			end
			if type(v) == "table" then
				appendWithTab("\n", 0)
				if isArray(v) then
					outputArray(v, tabNum + 1)
					str = str..",\n"
				else
					outputDict(v, tabNum + 1)
					str = str..",\n"
				end	
			else
				outputNormal(v, 0)
			end	
		end	
		appendWithTab("}", tabNum)
	end	

	if type(root) == "table" then
		if isArray(root) then
			outputArray(root, orgTab)
		else
			outputDict(root, orgTab)	
		end	
	else
		outputNormal(root, orgTab)	
	end	
	if filepath then
		local f, errstr1, err1 = io.open(filepath, "wb")
		if(f == nil) then
			print("table.dump to file failed")
			return false, str
		end	
		f:write(str)
		f:close()
	end	
	return true, str
end	

function table.delete(t, elem)
	for k, v in pairs(t) do
		if v == elem then
			table.remove(t, k)
			return k
		end
	end
	return -1
end

function table.max(t, cmp)
	if cmp == nil then
		cmp = function (x, y) return x<y end
	end	
	local tempdata = nil
	local tempkey = nil
	for key, value in pairs(t)do
		if tempdata == nil then 
			tempdata = value
		elseif cmp(tempdata, value) then
			tempdata = value
			tempkey = key
		end	
	end
	return tempkey, tempdata
end	

function table.min(t, cmp)
	if cmp == nil then
		cmp = function (x, y) return x<y end
	end	
	local realcmp = function(x, y)return not(cmp(x,y)) end
	return table.max(t, realcmp)
end	

function table.deep_copy(t)
	if type(t) ~= "table" then return nil end
	local ret = {}
	for k, v in pairs(t) do
		local cv = v
		if type(v) == "table" then
			cv = table.deep_copy(v)
		end
		ret[k] = cv
	end
	return ret
end

function table.copy(t)
	if type(t) ~= "table" then return nil end
	local ret = {}
	for k, v in pairs(t) do
		ret[k] = v
	end
	return ret
end

function table.empty(tbl)
	return nil == next(tbl)
end

function table.firstkey( tbl )
	local firstkey
	for k, _ in pairs(tbl) do
		firstkey = k
		break
	end

	return firstkey
end

function table.firstval( tbl )
	local firstkey = table.firstkey(tbl)
	local firstval
	if firstkey then
		firstval = tbl[firstkey]
	end
	return firstval
end

function table.first_keyvalue(Table)
	for k,v in pairs(Table) do
		return k,v
	end
end

function table.member_key(Table, Value)
	for k,v in pairs(Table) do
		if v == Value then
			return k
		end
	end

	return nil
end

--返回table的size
function table.size(Table)
	if Table then
		local Ret = 0
		for _,_ in pairs(Table) do
			Ret = Ret + 1
		end
		return Ret
	else
		return 0
	end
end

--判断两个table内容是否一样
function table.same_table(Tbl1, Tbl2, cascade)
	assert(type(Tbl1) == 'table')
	assert(type(Tbl2) == 'table')
	if table.size(Tbl1) ~= table.size(Tbl2) then
		return false
	end

	for k, v in pairs(Tbl2) do
		local v1 = Tbl1[k]
		if cascade then
			--级联检查就迭代调用same_table
			if type(v1) ~= type(v) then
				return false
			else
				if type(v1) == "table" then
					local ret = table.same_table(v1, v, cascade)
					if not ret then
						return false
					end
				elseif v1 ~= v then
					return false
				end
			end
		else
			--非级联检查就只查第一层
			if v1 ~= v then
				return false
			end
		end
	end
	return true
end

--treat as a dict
function table.hasvalue(tbl, value)
	for key, val in pairs(tbl)do
		if val == value then
			return key
		end
	end
end

--返回所有的key，作为一个数组，效率比较低，不建议频繁调用
function table.keys(Table)
	local Keys = {}
	for k,_ in pairs(Table) do
		table.insert(Keys, k)
	end

	return Keys
end

--返回所有的value，作为一个数组,效率比较低，不建议频繁调用
function table.values(Table)
	local Values = {}
	local Size = 0
	for _,v in pairs(Table) do
		table.insert(Values, v)
		Size = Size + 1
	end

	return Values, Size
end

--返回一个随机的key
function table.random_key(Table)
	local Keys = table.keys(Table)
	local n = #Keys
	if n <= 0 then
		return nil
	end
	return Keys[math.random(1,n)]
end

--返回一个随机的key，排除掉某一个key
function table.random_key_except(Table, except_func)
	local Keys = {}
	for k, v in pairs(Table) do
		if not except_func(k, v) then
			table.insert(Keys, k)
		end
	end
	local n = #Keys
	if n <= 0 then
		return nil
	end
	return Keys[math.random(1,n)]
end

--从table中随机返回n个value
function table.random_values(Table, n)
	local n = n or 1
	local Values = table.values(Table)
	return array.random_values(Values, n)
end

function table.random_all_values(Table)
	local Values, size = table.values(Table)
	return array.random_values(Values, size)
end

--从table中随机返回n个key
function table.random_keys(Table, n)
	local n = n or 1
	local Keys = table.keys(Table)
	return array.random_values(Keys, n)
end

--对Array(key)进行随机排序
--不改变参数Array的内容，排序的结果通过返回值返回, 并返回排序前后的key的对应关系
function table.random_sort (Array)
	local n = #Array

	local k = {}
	for i = 1, n do
		k[i] = i
	end 

	local o = {}
	local s = {}
	for i = 1, n do
		local j = math.random (n - i + 1)
		s[k[j]] = i 
		table.insert(o, Array[k[j]])
		table.remove (k, j)
	end

	return o, s 
end

--从一个mapping中随机出几个k,v对组成新的mapping
function table.random_kv(Table, n)
	local n = n or 1
	local Keys = table.keys(Table)
	if n > #Keys then
		return Table
	end
	local Ret = {}
	for i=1, n do
		local Rand = math.random(1, #Keys)
		local RandKey = Keys[Rand]
		--Ret[RandKey] = Table[RandKey]
		table.insert( Ret, Table[RandKey])
		table.remove(Keys, Rand)
	end
	return Ret
end

function table.random_kv2(Table, n)
	local n = n or 1
	local Keys = table.keys(Table)
	if n > #Keys then
		return Table
	end
	local Ret = {}
	for i=1, n do
		local Rand = math.random(1, #Keys)
		local RandKey = Keys[Rand]
		Ret[RandKey] = Table[RandKey]
		table.remove(Keys, Rand)
	end
	return Ret
end


--从table中随机返回1个value
function table.random_value(Table)
	local Values = table.values(Table)
	local n = #Values
	if n <= 0 then
		return nil
	end
	return Values[math.random(1,n)]
end

IS_FAST_PAIRS = (({pairs({1})})[3] ~= nil)
-- 有序遍历
function table.pairs_orderly(tbl, comp)
	local keys = {}
	for k, v in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys, comp)
	local keys_count = #keys
	local index = 0
	local next_orderly = function(tbl)
		index = index + 1
		if index > keys_count then return end
		if IS_FAST_PAIRS then
			return -1, keys[index], tbl[keys[index]]
		else
			return keys[index], tbl[keys[index]]
		end
	end
	if IS_FAST_PAIRS then
		return next_orderly, tbl, -1
	else
		return next_orderly, tbl
	end
end

-- 乱序遍历
function pairs_randomly(tbl)
	local keys = {}
	for k, v in pairs(tbl) do
		table.insert(keys, k)
	end
	keys = table.random_sort(keys)
	local keys_count = #keys
	local index = 0
	local next_randomly = function(tbl)
		index = index + 1
		if index > keys_count then return end
		if IS_FAST_PAIRS then
			return -1, keys[index], tbl[keys[index]]
		else
			return keys[index], tbl[keys[index]]
		end
	end
	if IS_FAST_PAIRS then
		return next_randomly, tbl, -1
	else
		return next_randomly, tbl
	end
end

function table.swap(tbl, i, j)
	local temp = tbl[i]
	tbl[i] = tbl[j]
	tbl[j] = temp
end

-- 过滤，返回新 table
-- is_in_func: bool function(key, value, table)
-- is_array: 填 true 表示 table 过滤前后都是纯数组
-- remove_cb (optional): function(key, value, table), 移除元素时回调。注意不一定按顺序移除
function table.filter(tbl, is_in_func, is_array, remove_cb)
	local new_tbl = {}
	if is_array then
		-- is array
		for k, v in ipairs(tbl) do
			if is_in_func(k, v, tbl) then
				table.insert(new_tbl, v)
			else
				if remove_cb then
					remove_cb(k, v, tbl)
				end
			end
		end
	else
		-- has hash part
		for k, v in pairs(tbl) do
			if is_in_func(k, v, tbl) then
				new_tbl[k] = v
			else
				if remove_cb then
					remove_cb(k, v, tbl)
				end
			end
		end
	end
	return new_tbl
end

-- 过滤，直接改原有 table
function table.filter_inplace(tbl, is_in_func, is_array, remove_cb)
	if is_array then
		-- is array
		for k = #tbl, 1, -1 do
			if not is_in_func(k, v, tbl) then
				if remove_cb then
					remove_cb(k, v, tbl)
				end
				table.remove(tbl, k)
			end
		end
	else
		-- has hash part
		for k, v in pairs(tbl) do
			if not is_in_func(k, v, tbl) then
				if remove_cb then
					remove_cb(k, v, tbl)
				end
				table.remove(tbl, v)
			end
		end
	end
	return tbl
end

--[[
author zzln1107
###### lua switcher usage: ######
local mySwitcher = 
switcher():
	case(0):
	case(1):
	case(2):
		run(func1):
	case({3,4,5}):
		run(function()
			-- blablabla
		end):
	default():
		run(defaultFunc):
endSwitcher()

mySwitcher.switch(0)
mySwitcher.switch(1)
mySwitcher.switch(2)

###### lua switch usage: ######
-- just create a switcher to switch
switch(i):
	case(0):
	case(1):
	case(2):
		run(func1):
	case({3,4,5}):
		run(function()
			-- blablabla
		end):
	default():
		run(defaultFunc):
endSwitch()

PS1:Do NOT forget ANY ":" !!!
PS2:It is necessary to endSwitch(), but not endSwitcher().
]]

_G.switcher = function()
	local switchBuilder = {}
	local map = {}
	local lastRun = {}
	local default = nil
	function switchBuilder:case(c)
		if type(c) == 'table' then
			for _, v in pairs(table_name) do
				if not map[v] then
					map[v] = lastRun
				end
			end
		else
			if not map[c] then
				map[c] = lastRun
			end
		end
		return switchBuilder
	end
	function switchBuilder:default()
		default = lastRun
		return switchBuilder
	end
	function switchBuilder:run(f)
		assert(type(f) == "function" or type(f) == "nil")
		lastRun.func = f
		lastRun = {}
		return switchBuilder
	end
	function switchBuilder:endSwitcher()
		return switchBuilder
	end
	function switchBuilder:switch(i, ...)
		if not i or not map[i] or not map[i].func then
			if not default or not default.func then return end
			return default.func(unpack(arg))
		end
		return map[i].func(unpack(arg))
	end
	return switchBuilder
end

_G.switch = function(i, ...)
	local switcher = switcher()
	local switchTarget = i
	function switcher:endSwitch()
		return self:switch(switchTarget, unpack(arg))
	end
	return switcher
end
