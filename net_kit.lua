local socket = require('socket')

local target_IP = nil

function access_connectivity(host, port)
	if host == nil or string.len(host) == 0 then
		return false
	end

	local c = socket.try((create or socket.tcp)())
	if not c then
		return false
	end
	local d = socket.try(c:settimeout(3))
	if not d then
		return false
	end
	d = socket.try(c:connect(host, port))
	if not d then
		return false
	end
	if c then
		socket.newtry(function() c:close() end)
	end
end

local function _resolve_ip(host, port)
	port = port or 6560
	print("net_kit resolving host: ", host)

	local target = nil

	local addrinfo, err = nil, nil
	if socket.dns.getaddrinfo then
		addrinfo, err = socket.dns.getaddrinfo(host)
	else
		addrinfo = {{family = "inet", addr = host}}
	end
	if not addrinfo then return nil, err end

	local conn, err
	for i, alt in ipairs(addrinfo) do
		target = alt.addr
		print("net_kit resolving protocol: ")
		if alt.family == "inet" then
			break
		end
	end

	if target == nil then
		print("net_kit resolving using gethostbyname")
		target = socket.dns.gethostbyname(host)
	else
		print("net_kit resolving using getaddrinfo")
	end
	print('net_kit resolved target: ', target)

	return target
end

function resolve_url(url)
	url = url or "nil"
	if url == "nil" or string.len(url) == 0 then
		return {protocol="", host=url, path="", port="0", ip=nil, error="url is nil"}
	end
	require("libs.urllib")
	local protocol, s1 = splittype(url)
	local host, path = splithost(s1)
	local host, port = splitport(host)
	local ip = _resolve_ip(host)
	return {protocol=protocol, host=host, path=path, port=port, ip=ip, error=""}
end