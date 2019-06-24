

module(..., package.seeall)
local bit = require("bit")

--删除空白前导空白字符或者指定字符集中的字符
function string.lstrip(str, chars)
	if chars then
		for k=1,#str do
			local sub = string.sub(str,k,k)
			--
			if not string.find(chars, sub, 1, true) then
				return string.sub(str, k)
			end
		end
	else
		return string.gsub(str, "^%s*", "")
	end
end

-- 格式化价格 三位加一个逗号分隔符
function string.price_format(price)
	local price = tostring(price)
	local dot = string.find(price,"[.]")
	local afterdot = nil
	if dot then
		afterdot = price.sub(price, dot)
		price = price.sub(price, 1, dot-1)
	end
	price = string.reverse(price)
	local len, str = #price, ""
	local lastChar = string.sub(price, len, -1)
	if lastChar == "-" then
		price = string.sub(price, 1, len - 1)
		len = #price
	end
	local space
	while true do
		space = math.floor(len/3)
		local endp = 0
		for k = 1, space do
			endp = (k-1)*3 + 3
			str = string.format("%s%s", string.reverse(string.sub(price, 1 + (k-1)*3, endp)), str)
			str = string.format(",%s", str)
		end
		local left = string.sub(price, endp + 1, -1)
		if #left > 0 then
			str = string.format("%s%s", string.reverse(left), str)
		else
			str = string.sub(str, 2, -1)
		end
		break
	end
	if lastChar == "-" then
		str = string.format("-%s", str)
	end
	if afterdot then 
		str = string.format("%s%s", str, afterdot)
	end
	return str
end

--删除空白后导空白字符或者指定字符集中的字符
function string.rstrip(str, chars)
	if chars then
		for k=#str,1 do
			local sub = string.sub(str,k,k)
			--
			if not string.find(chars, sub, 1, true) then
				return string.sub(str, 1, k)
			end
		end
	else
		return string.gsub(str, "%s*$", "")
	end
end

--删除空白前后空白字符或者指定字符集中的字符
function string.strip(str, chars)
	return string.rstrip(string.lstrip(str, chars), chars)
end

function string.split( str, sep, maxsplit )
        if string.len(str) == 0 then
                return {}
        end
        sep = sep or "."
        maxsplit = maxsplit or 0
        local retval = {}
        local pos = 1
        local step = 0
        while true do
                local from, to = string.find(str, sep, pos, true)
                step = step + 1
                if (maxsplit ~= 0 and step > maxsplit) or from == nil then
                        local item = string.sub(str, pos)
                        table.insert( retval, item )
                        break
                else
                        local item = string.sub(str, pos, from-1)
                        table.insert( retval, item )
                        pos = to + 1
                end
        end
        return retval
end


function string.rfind( str, pat )
	local rpat = string.format("%s[^%s]*$", pat, pat)
	return str:find(rpat)
end


function string.hex_print(str)
	local s = string.gsub(str,"(.)",
		function (c)
			return string.format("%02X%s ",string.byte(c), spacer or "")
		end)
	print(s)
end

--for utf-8 char counting maybe hava bug?
function string.calCharCount(str)
	local codes = {string.byte(str, 1, string.len(str))}
	local count = 0
	for i, code in ipairs(codes)do
		if code >= 0xC0 then
			count = count + 1
		elseif code < 128 then
			count = count + 1
		end
	end
	return count
end

function string.nextCharIndex(str, start)
	if start == nil then start = 1 end
	local codes = {string.byte(str, start, string.len(str))}
	for i, code in ipairs(codes)do
		if code < 128 or code >= 0xC0 then
			return start + i - 1
		end
	end
end

--for utf-8 char counting length
--ascii char counts for a half while chinese word counts for one
function string.calCharCountWithWeight(str, ascii, other)
	if ascii == nil then ascii = 0.5 end
	if other == nil then other = 1 end
	local codes = {string.byte(str, 1, string.len(str))}
	local count = 0
	for i, code in ipairs(codes)do
		if code >= 0xC0 then
			count = count + other
		elseif code < 128 then
			count = count + ascii
		end
	end
	return count
end

-- 判断utf8字符byte长度
-- 0xxxxxxx - 1 byte
-- 110yxxxx - 192, 2 byte
-- 1110yyyy - 225, 3 byte
-- 11110zzz - 240, 4 byte
local function chsize(char)
	if not char then
		print("not char")
		return 0
	elseif char > 240 then
		return 4
	elseif char > 225 then
		return 3
	elseif char > 192 then
		return 2
	else
		return 1
	end
end

-- 计算utf8字符串字符数, 各种字符都按一个字符计算
-- 例如utf8len("1你好") => 3
function string.utf8len(str)
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		len = len +1
	end
	return len
end

-- 截取utf8 字符串
-- str:         要截取的字符串
-- startChar:   开始字符下标,从1开始
-- numChars:    要截取的字符长度
function string.utf8sub(str, startChar, endChar)
	local numChars = endChar - startChar + 1
	local startIndex = 1
	while startChar > 1 do
		local char = string.byte(str, startIndex)
		startIndex = startIndex + chsize(char)
		startChar = startChar - 1
	end

	local currentIndex = startIndex

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		numChars = numChars -1
	end
	return str:sub(startIndex, currentIndex - 1)
end


local function getFirstUTF8Value()
	if math.random() > (0x7F - 0x01) / (0x7F - 0x01 + 0xF4 - 0xC2) then
		return math.random(0x01, 0x7F)
	else
		return math.random(0xC2, 0xF4)
	end
end

local function getTrailingUTF8Value()
	return math.random(0x80, 0xBF)
end

local function getRandomUTF8Char()
	first = getFirstUTF8Value()
	if first <= 0x7F then
		return string.char(first)
	elseif first <= 0xDF then
		return string.char(first, getTrailingUTF8Value())
	elseif first == 0xE0 then
		return string.char(first, math.random(0xA0, 0xBF), getTrailingUTF8Value())
	elseif first == 0xED then
		return string.char(first, math.random(0x80, 0x9F), getTrailingUTF8Value())
	elseif first <= 0xEF then
		return string.char(first, getTrailingUTF8Value(), getTrailingUTF8Value())
	elseif first == 0xF0 then
		return string.char(first, math.random(0x90, 0xBF), getTrailingUTF8Value(), getTrailingUTF8Value())
	elseif first <= 0xF3 then
		return string.char(first, getTrailingUTF8Value(), getTrailingUTF8Value(), getTrailingUTF8Value())
	elseif first == 0xF4 then
		return string.char(first, math.random(0x80, 0x8F), getTrailingUTF8Value(), getTrailingUTF8Value())
	end
end
--获取一个指定长度的随机utf8字符串
function getRandomUTF8String(len)
	local str = ""
	for i = 1, len do
		str = str .. getRandomUTF8Char()
	end
	return str
end

function getUtf8CheckErrorMsg(arr, errorIdx)
	if not arr or #arr < errorIdx then
		return
	end
	--GB2312
	--“高位字节”使用了0xA1-0xF7(把01-87区的区号加上0xA0)
	--“低位字节”使用了0xA1-0xFE(把01-94加上 0xA0)。
	local errorChar = arr[errorIdx]
	if errorChar and errorChar >= 0xA1 and errorChar <= 0xF7 then
		local nextChar = arr[errorIdx + 1]
		if nextChar and nextChar >= 0xA1 and nextChar <= 0xFE then
			return "GB2312 characters"
		end
	end
	return "error char:" .. string.format("%#x ", errorChar)
end

function checkUtf8String(str)
	if not str then
		return false
	end
	local arr = {string.byte(str, 1, string.len(str))}
	local i = 1
	local cnt = #arr
	local function checkNextByteInRange(minByte, maxByte)
		i = i + 1
		if i > cnt then
			return false
		end
		if arr[i] < minByte or arr[i] > maxByte then
			return false
		end
		return true
	end
	local errorIdx = i
	while i <= cnt do
		local first = arr[i]
		if first <= 0x7F then
		elseif first <= 0xDF then
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first == 0xE0 then
			if not checkNextByteInRange(0xA0, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first == 0xED then
			if not checkNextByteInRange(0x80, 0x9F) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first <= 0xEF then
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first == 0xF0 then
			if not checkNextByteInRange(0x90, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first <= 0xF3 then
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		elseif first == 0xF4 then
			if not checkNextByteInRange(0x80, 0x8F) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
			if not checkNextByteInRange(0x80, 0xBF) then
				return false, getUtf8CheckErrorMsg(arr, errorIdx)
			end
		else
			return false, getUtf8CheckErrorMsg(arr, errorIdx)
		end
		i = i + 1
		errorIdx = i
	end
	return true
end

function string.decodeURI(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function string.encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

-- fix bug: _ 不在转义成%5F
function string.encodeURI2(s)
    s = string.gsub(s, "([^%w%.%-%_ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

--cocos默认会对print截断，这个函数可以不截断
local MAX_STR_LEN = 10 * 1024
function string.fullprint(str)
	local splitStr = "\n"
	local arr = string.split(str, splitStr)
	local splitLen = string.len(splitStr)
	local curLen = 0
	local curBufArr = {}
	for _, v in ipairs(arr) do
		local len = string.len(v) + splitLen
		table.insert(curBufArr, v)
		curLen = curLen + len
		if curLen >= MAX_STR_LEN then
			print(table.concat(curBufArr, splitStr))
			curBufArr = {}
			curLen = 0
		end
	end
	print(table.concat(curBufArr, splitStr))
end

function string.endswith(str, tail)
	local pattern = string.format("%s$", tail)
	local x = string.find(str, pattern)
	return x ~= nil
end

function string.startswith(str, head)
	local pattern = string.format("^%s", head)
	local x = string.find(str, pattern)
	return x ~= nil
end


UNPACK_PATTERN = "#E%((.-)%)#G(.-)#e#l"
RAW_UNPACK_PATTERN = "#E%((.-)%)(.-)#e"
AT_UNPACK_PATTERN = "(@[^%s]+)"
AT_PREFIX = "@name_"
function string.unpackRichtext(txt, pattern, needRemovePattern, needUnpackAt)
	if txt == nil then
		return "", {}
	end
	if needUnpackAt == nil then
		needUnpackAt = (pattern == UNPACK_PATTERN or pattern == RAW_UNPACK_PATTERN)
	end
	local event_map = {}
	local event_cnt = {}
	local new_txt = string.gsub(txt, pattern or UNPACK_PATTERN, function(s1, s2) 
		if event_map[s2] == nil then
			event_cnt[s2] = 1
		else
			local cnt = (event_cnt[s2] or 0)--之所以要or0是因为玩家可以自己编辑richlabel，导致一个key有多个val
			event_cnt[s2] = cnt + 1
			s2 = string.sub(s2, 1, -2) .. cnt .. "]"
		end
		event_map[s2] = s1
		return s2
	end)
	if needUnpackAt then
		new_txt = string.gsub(new_txt, AT_UNPACK_PATTERN, function(s2) 
			local raws2 = s2
			s2 = AT_PREFIX
			local cnt = (event_cnt[s2] or 1)--之所以要or0是因为玩家可以自己编辑richlabel，导致一个key有多个val
			event_cnt[s2] = cnt + 1
			s2 = s2 .. cnt .. "@"
			event_map[s2] = raws2
			return s2
		end)
	end
	if needRemovePattern then
		local removed_txt = string.gsub(txt, pattern or UNPACK_PATTERN, function(s1, s2) 
			local cnt = 0
			if event_map[s2] == nil then
				event_cnt[s2] = 1
			else
				local cnt = (event_cnt[s2] or 1)--之所以要or0是因为玩家可以自己编辑richlabel，导致一个key有多个val
				event_cnt[s2] = cnt + 1
			end
			s2 = "[removed" .. cnt .. "]"
			event_map[s2] = s1
			return s2
		end)
		if needUnpackAt then
			removed_txt = string.gsub(removed_txt, AT_UNPACK_PATTERN, function(s2) 
				local raws2 = s2
				s2 = AT_PREFIX
				local cnt = (event_cnt[s2] or 1)--之所以要or0是因为玩家可以自己编辑richlabel，导致一个key有多个val
				event_cnt[s2] = cnt + 1
				s2 = "[removed" .. cnt .. "]"
				event_map[s2] = raws2
				return s2
			end)
		end
		return new_txt, event_map, removed_txt
	else
		return new_txt, event_map
	end
end


PACK_FMT_STR = "#E(%s)#G%s#e#l"
RAW_PACK_FMT_STR = "#E(%s)%s#e"
function string.packRichtext(txt, event_map, fmtStr, keepPercent, check_at_first)
	local atVPrefix = AT_PREFIX
	local new_txt = txt

	-- gzzsh: event_map是无序的，但有些事件有顺序依赖
	-- 通常@name这种类型直接替换没问题。但类似 #E(xxx)@name#e，这种类型，如果优先查找event，则会由于@name还没有匹配替换而找不到
	-- 所以这里如果传入check_at_first则先替换了@name，再替换event
	if check_at_first then
		-- 先替换name
		for k, v in pairs(event_map) do
			if string.sub(k, 1, #atVPrefix) == atVPrefix then
				--这个是at的情况
				new_txt = string.gsub(new_txt, k, v)
			end
		end
		-- 再替换event
		for k, v in pairs(event_map) do
			if string.sub(k, 1, #atVPrefix) == atVPrefix then
			else
				k = string.gsub(k, "%[", "%%[")
				k = string.gsub(k, "%]", "%%]")
				k = string.gsub(k, "%(", "%%(")
				k = string.gsub(k, "%)", "%%)")
				k = string.gsub(k, "%-", "%%-")
				k = string.gsub(k, "%*", "%%*")
				new_v = string.format(fmtStr or PACK_FMT_STR, v, k)
				new_txt = string.gsub(new_txt, k, function() 
					return new_v 
				end)
			end
		end
	else
		for k, v in pairs(event_map) do
			if string.sub(k, 1, #atVPrefix) == atVPrefix then
				--这个是at的情况
				new_txt = string.gsub(new_txt, k, v)
			else
				k = string.gsub(k, "%[", "%%[")
				k = string.gsub(k, "%]", "%%]")
				k = string.gsub(k, "%(", "%%(")
				k = string.gsub(k, "%)", "%%)")
				k = string.gsub(k, "%-", "%%-")
				k = string.gsub(k, "%*", "%%*")
				new_v = string.format(fmtStr or PACK_FMT_STR, v, k)
				new_txt = string.gsub(new_txt, k, function() 
					return new_v 
				end)
			end
		end
	end

	if not keepPercent then
		new_txt = string.gsub(new_txt, "%%", "")
	end
	return new_txt
end

function string.filterWord(str)
	local msg, event_map = string.unpackRichtext(str, RAW_UNPACK_PATTERN)
	msg = filter.filterWords(msg, filter.REPLACE_STR)
	if event_map then msg = string.packRichtext(msg, event_map, RAW_PACK_FMT_STR) end
	return msg
end


local CHINESE_CHAR_REF = {
	"一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
}

function getChineseNum(num)
	return CHINESE_CHAR_REF[num] or ""
end

----------------------BASE 64 coding-------------------------
-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function string.base64Encoding(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function string.base64Decoding(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function string.Utf8to32(utf8str)
	assert(type(utf8str) == "string")
	local res, seq, val = {}, 0, nil
	for i = 1, #utf8str do
		local c = string.byte(utf8str, i)
		if seq == 0 then
			table.insert(res, val)
			seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or
			      c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or
				  error("invalid UTF-8 character sequence")
			val = bit.band(c, 2^(8-seq) - 1)
		else
			val = bit.bor(bit.lshift(val, 6), bit.band(c, 0x3F))
		end
		seq = seq - 1
	end
	table.insert(res, val)
	table.insert(res, 0)
	return res
end
function string.containEmoji(utf8str)
	local arr = string.Utf8to32(utf8str)
	--U+1F300-1F5FF：查看
	--U+1F600-1F64F：查看
	--U+0023 - U+002A
	--U+0030 - U+0039
	--U+00A9 - U+00AE
	--U+1F004 - U+1F9C0
	--U+203C - U+3299
	--according to http://unicode.org/emoji/charts/full-emoji-list.html
	--U+1F300-1F5FF：查看
	--U+1F600-1F64F：查看
	--https://zh.wikipedia.org/wiki/%E7%B9%AA%E6%96%87%E5%AD%97
	for k, v in ipairs(arr) do
		if
			(v >= 0x1F300 and v <= 0x1F5FF) or
			(v == 0x1F004 or v == 0x1F0CF) or
			(v >= 0x1F600 and v <= 0x1F64F)
		then
			return true, k
			--[[
		elseif v >= 0x0023 and v <= 0x0039 then
			local nextv = arr[k+1]
			if nextv and nextv == 0x20E3 then
				return true, k
			end
		elseif v >= 0x1F1E6 and v <= 0x1F1FF then
			local nextv = arr[k+1]
			if nextv and nextv >= 0x1F1E6 and nextv <= 0x1F1FF then
				return true, k
			end
			]]
		end
	end
	return false
end

--屏蔽 800 到 810 的聊天彩蛋
function string.filterBannedEmote(str)
	if str ~= "" then
		local bpos, epos = string.find(str, "#+[8-9][0-9][0-9]")
		if bpos and epos then
			local i = 1
			local subs = string.sub(str, bpos, epos)
			while i < string.len(subs) do
				if string.sub(subs, i, i) ~= '#' then
					break
				end
				i = i + 1
			end
			if i % 2 == 0 then
				str = (string.gsub(str, "#[8-9][0-9][0-9]", ""))
			end
		end
		if string.len(str) == 0 then
			str = "#"
		end
	end
	return str
end

function string.getCompactString(obj)
	local str = tostring(obj)
	local ret = nil
	if string.len(str) > 500 then
		ret = string.sub(str, 1, 500) .. "..."
	else
		ret = str
	end
	local isUtf8, errmsg = checkUtf8String(ret)
	if isUtf8 then
		return ret
	else
		--非utf8 crashdump那边可能有问题，给一个特殊的值
		return "#BinaryData#"
	end
end

function string.lrc(filename)
	local json = require "json"
	local f, errstr1, err1 = io.open(filename, "rb")
	local lrc = {}
	local pat = "%[%d+:%d+:%d+%]*"
	if f then
		for lines in f:lines() do
			local s_pos, e_pos = string.find(lines, pat)
			if s_pos and e_pos then
				local str = string.sub(lines, s_pos+1, e_pos-1)
				local one = {}
				local filelds = string.split(str, ":")
				if 3 == #filelds then
					one.type = "time"
					one.prefix = str
					one.content = string.sub(lines, e_pos+1)
					one.after_sec = filelds[1] * 60 + filelds[2]
					table.insert(lrc, one)
				end
			end
		end
		f:close()
	end
	return lrc
end

function string.check_game_link(msg, need_remind_func)
	local flag = false
	local txt = nil
	local event_map = nil
	local remindFunc = function(err, param)
		local errtips = {
			["summon"] = "指定宠物发生变动，无法发送!",
			["item"] = "指定物品发生变动，无法发送!",
			["title"] = "链接已失效!",
		}
		local errmsg 
		if not err or not errtips[err] then
			errmsg = LC("发送失败", 1381)
		else
			errmsg = errtips[err]
		end
		view.message.ShowBubbleMessage(errmsg)
	end
	if need_remind_func then
		remindFunc = need_remind_func
	end 

	--用于检查是否是合法的title
	local pattern = "#E%(title_(.-)%)(.-)"
	local idx = 1
	local s = string.find(msg, pattern, idx)
	while s  and idx <= #msg do
		local remind_msg = string.sub(msg, s, #msg)
		flag = false
		txt, event_map = string.unpackRichtext(remind_msg, pattern)
		if not txt then return false end 
		local i = string.find(txt, "%[")
		local j = string.find(txt, "%]")
		if not i or not j then return false end 
		local titlename = string.sub(txt, i + 1, j - 1)
		print("=+= titlename ", titlename)
		require "view.dlgtitle"
		if not view.dlgtitle.GTitleList or not next(view.dlgtitle.GTitleList) then
			view.dlgtitle.C_REQ_TITLE_INFO()
		end
		for _, idx in pairs(event_map) do
			print("=+= title num ", #view.dlgtitle.GTitleList)
			for k, v in pairs(view.dlgtitle.GTitleList) do
				if v.titleidx == tonumber(idx) and string.match(titlename, v.titlename.."%d*$" ) then
					flag = true
					break
				end
			end
			if flag then break end
		end
		if not flag  and remindFunc then
			remindFunc("title", txt)
			return false
		end
		idx = s + string.find(remind_msg, "%]")
		if idx > #msg then break end
		s = string.find(msg, pattern, idx)
	end

	--用于检查是否有宠物
	pattern = "#E%(summon_(.-)%)(.-)"
	if string.find(msg, pattern) then
		txt, event_map = string.unpackRichtext(msg, pattern)
		require "view.beastinfo"
		for _, idx in pairs(event_map) do
			flag = false
			local index = string.split(idx, "_")
			for k,v in pairs(view.beastinfo.BEAST_LIST) do
				if v.npcnum == tonumber(index[1]) then
					flag = true
					break
				end
			end
			if not flag then break end
		end
		if not flag and remindFunc then
			remindFunc("summon", txt)
			return false
		end
	end

	--用于检查是否有此道具
	pattern = "#E%(item_(.-)%)(.-)"
	if string.find(msg, pattern) then
		txt, event_map = string.unpackRichtext(msg, pattern)
		require "view.dlgitem"
		for i, val in pairs(event_map) do
			flag = false
			local idx = string.split(val, "_")
			for _, itemData in ipairs({view.dlgitem.GEquipData, view.dlgitem.GItemData}) do
				for k, v in pairs(itemData) do
					if v.itemnum == tonumber(idx[2]) then
						flag = true
						break
					end
					if flag then break end
				end
				if flag then break end
			end
			if not flag then
				break
			end
		end
		if not flag and remindFunc then
			remindFunc("item", txt)
			return false
		end
	end
	return true
end

function string.check_invalid_link(msg)
	--用于检查是否是合法的
	local pattern = "#E%(itemsimpleinfo_(.-)%)(.-)"
	if string.find(msg, pattern) then
		local txt, event_map = string.unpackRichtext(msg, pattern)
		return txt		
	end
	return msg
end

function string.check_kuafu_link(msg, need_remind)
	local flag = false
	local txt = nil
	
	local patternTbl = {
		["#E%(trade_(.-)%)(.-)"] = "跨服聊天不能发送摆摊信息",
		["#E%(partner_(.-)%)(.-)"] = "跨服聊天不能发送助战信息",
		["#E%(title(.-)%)(.-)"] = "跨服聊天不能发送称谓信息",
		["#E%(fabao(.-)%)(.-)"] = "跨服聊天不能发送法宝信息",
		["#E%(taskassist(.-)%)(.-)"] = "跨服聊天不能发送任务求助信息",
	}

	for pattern, info in pairs(patternTbl) do
		if string.find(msg, pattern) then
			flag = true
			txt = info
			break
		end
	end
	if flag then
		if need_remind then view.message.ShowBubbleMessage(txt) end
		return false
	end
	return true
end

-- 将阿拉伯数字转换成中文
local NUM_CHINESE_TAB = {
	[0] = "零",
	[1] = "一",
	[2] = "二",
	[3] = "三",
	[4] = "四",
	[5] = "五",
	[6] = "六",
	[7] = "七",
	[8] = "八",
	[9] = "九",
	[10] = "十",
	[20] = "二十",
	[30] = "三十",
}
function string.num2Chinese(num, decimalism)
	local realNumStr = ""
	if not num then return realNumStr end

	local numStr = tostring(num)
	local numStrLen = #numStr
	local isBigTen = false

	if decimalism then
		isBigTen = num > 10
	end

	for k = 1, numStrLen, 1 do
		local oneNum = tonumber(string.sub(numStr, k, k))
		if isBigTen and k == 1 then
			oneNum = oneNum * 10
		end
		if NUM_CHINESE_TAB[oneNum] then
			realNumStr = realNumStr .. NUM_CHINESE_TAB[oneNum]
		end
	end

	return realNumStr
end
