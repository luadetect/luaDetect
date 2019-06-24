module(..., package.seeall)

local http = require('socket.http')
local ltn12 = require('ltn12')


WebKit = CObject:new{
	TypeStr = "WebKit"
}

function WebKit:head(data, url, timeout)
	timeout = timeout or 3
	url = url or ""
	print('web_kit url is ', url, ', length is ', string.len(url))
	if data == nil then
		data = {}
	end

	if url == "" or url == nil or url == "nil" then
		print('web_kit head url is empty')
		return {code=501, content='head url is nil'}
	end
	local headers = {["Content-type"]="application/json", ["User-Agent"]="detect", ["Accept"]="*/*"}
	local b, c, d = http.request{url=url, sink=ltn12.sink.table(headers), method='HEAD', source=ltn12.sink.table(data)}
	--[zxf]
	return {code=501, content="", error=""}
end

function WebKit:wrap_socket(self, httpsConn, SSLContext_Protocol, timeout, hose)
	sslSock = nil
	error_info = ""
	
end

function get(data, url, timeout, ignore_warning)
	if data == nil then
		data = {}
	end

	if string.len(url) == 0 or url == nil then
		return {code=501, content='', error='get url is nil'}
	end

	local headers = {["User-Agent"] = "detect", ["Accept"] = "*/*"}
	local body = urlencode(data)
	local uri = url..'?'..body
	print("web_kit GET url: ", url)
	--[zxf] urllib2.Request(uri, headers=headers)
	local req = {}
	--[zxf] urllib2.urlopen(req, timeout=timeout)
	local res = {}
	--[zxf] res.read()
	local content = ""
	local content, code, c, h = http.request(uri, nil)
	print("web_kit GET code: ", code, ", content: ", content)
	return {code=code, content=content, error=""}
end

function post(data, url, timeout)
	timeout = timeout or 3
	if string.len(timeout) == 0 or url == "nil" then
		return {code=501, content="", error="post url is nil"}
	end
	if data == nil then
		data = {}
	end
	local uri = tostring(url)
	local headers = {["Content-type"] = "application/json", ["User-Agent"] = "detect", ["Accept"] = "*/*"}
	local body = json.encode(data)
	print("web_kit POST url: ", uri, ", body: ", body)
	--[zxf] urllib2.Request(uri, data=body, headers=headers)
	local req = {}
	--[zxf] urllib2.urlopen(req, timeout=timeout)
	local res = {}
	--[zxf] res.read()
	local content = ""
	local content, code, c, h = http.request(uri, body)
	print("web_kit POST code: ", code, ", content: ", content)
	return {code=code, content=content, error=""}
end

function urlencode(data)
	local str_data = ''
	for key, value in ipairs(data) do
		one_str = key..'='..value
		if string.len(str_data) == 0 then
			str_data = one_str
		else
			str_data = str_data..'&'..one_str
		end
	end
	return str_data
end

function urldecode(data)
	date = {}
end


