
local port = 6553
local count = 4
local timeout = 1
local hostname = nil
local target_ip = nil
local loss = 0
local delay = 0

local function check_sum(source)
	local _sum = 0
	local max_count = math.floor(string.len(source)/2) * 2
	local count = 1
	while count <= max_count do
		local val = string.byte(source, count+1) * 256 + string.byte(source, count)
		_sum = _sum + val
		_sum = bit.band(_sum, 0xffffffff)
		count = count + 2
	end

	if max_count <= string.len(source) then
		_sum = _sum + string.byte(source, string.len(source))
		_sum = bit.band(_sum, 0xffffffff)
	end

	_sum = bit.rshift(_sum, 16) + bit.band(_sum, 0xffff)
	_sum = _sum + bit.rshift(_sum, 16)
	local answer = bit.bnot(_sum)
	answer = bit.band(answer, 0xffff)
	answer = bit.bor(bit.rshift(answer, 8), bit.band(bit.lshift(answer, 8), 0xff00))
	return answer

end

local function recv(sock, pid, timeout)
	pid = pid or 0
	timeout = timeout or 5
	local time_remaining = timeout
	while true do
		local start_time = os.time()
		local readable = socket.select({sock}, {}, time_remaining)
        local time_spent = os.time() - start_time
        if readable[0] == nil then
        	print("readable: []")
        	return
        end
        local time_received = os.time()
        local recvpacket, receip, receport = sock.receivefrom(512)
        local icmp_header = string.sub(recvpacket, 21, 28)
        local icmp_type, code, checksum, packet_id, sequence = string.unpack("bbHHh", icmp_header)
        if packet_id == pid then
        	local bytes_in_double = string.packsize("d")
        	local time_sent = string.unpack("d", string.sub(recvpacket, 29, 28 + bytes_in_double))[0]
        	return time_received - time_sent
        end
        return time_spent
    end
end

local function send(sock, pid)
	pid = pid or 0
	local l_check_sum = 0
	local header = string.pack("bbHHh", 8, 0, l_check_sum, pid, 1)
	local bytes_in_double = string.packsize("d")
	local  data = ""
	for i=1, (56 - bytes_in_double) do data = data.."P" end
	data = string.pack("d", os.time())..data

	l_check_sum = check_sum(header..data)
	-- [zxf]socket.htons(l_check_sum)-->l_check_sum
	header = string.pack("bbHHh", 8, 0, l_check_sum, pid, 1)
	local packet = header..data
	sock.sendto(packet, dest_addr, port)
end

local function ping_exec()
	local icmp_proto = 1
	local delay = nil
	local sock = nil
	
	sock = socket.udp()
	return 1.0
end

local function _get_target_ip(host, port)
	port = port or 6559
	local target = nil
	print('Ping resolving host: ', host)

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
		print("Ping resolving protocol: ")
		if alt.family == "inet" then
			break
		end
	end

	if target == nil then
		print("Ping resolving using gethostbyname")
		target = socket.dns.gethostbyname(host)
	else
		print("Ping resolving using getaddrinfo")
	end
	print('Ping resolved target: ', target)

	return target
end

function ping_ping(host)
	hostname = host
	target_ip = _get_target_ip(hostname)
	delay = 0.01
	loss = 0.0
	for i=1, count do
		local _delay = ping_exec()

		if _delay == 0 or _delay == nil then
			loss = loss + 1
			delay = delay + timeout * 1000
			print(string.format("Ping failed. (timeout within %ssec.)", timeout))
		else
			_delay = _delay * 1000
			delay = delay + _delay
			print(string.format("Ping Get pong in %sms", _delay))
		end
	end

	local _cost = delay/count
	local _rate = tostring(loss)..count
	local _loss = (loss/count) * 100
	print("Ping to...")
	return {host=hostname, ip=target_ip, cost=_cost, loss=_loss, rate=_rate}		
end