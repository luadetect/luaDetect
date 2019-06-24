
module(..., package.seeall)

require("socket")
require("bit")

local dest_addr = nil
local port = 6554
local timeout = 1
local maxhops = 20
local icmp_proto = 1
local udp_proto = 17

Tracer = CObject:new{
	TypeStr = "Tracer"
}

function Tracer:trace_init(port, maxhops, timeout)
	self.port = port or 6554
	self.maxhops = maxhops or 20
	self.timeout = timeout or 1
	self.dest_addr = nil
	self.icmp = 1
	self.udp = 17
end

function check_sum(source)
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

function Tracer:recv(self, sock, pid, ttl)
	--[[
    ICMP报文格式:
    ===============================================================================================
    合计：测试ICMP报文合计 64 字节(BYTE)
                    -------------------------------------------------------------------------------
                    | 类型(1) | 代码(1) | 校验和(2) | 标识符(2) | 序列号(2) | timestamp(8) + CHAR(48)  |
                    -------------------------------------------------------------------------------
                    | ICMP首部 8字节                                     | ICMP数据部分              |
    -----------------------------------------------------------------------------------------------
    | IP首部 20字节 | IP数据报的数据部分                                                              |
    -----------------------------------------------------------------------------------------------
    ]]
    local time_remaining = self.timeout
    local curr_addr = nil
    local curr_name = nil
    local delay = nil
    while true do
    	local start_time = os.time()
    	--[[
        select函数阻塞程序运行，sock，当其中有套接字满足可读的条件（第一个参数为可读，如果是第二个参数则为可写），则把这个套接字返回给rs，然后程序继续运行。
        至于套接字怎么才算可读呢？当套接字缓冲区大于1byte时，就被标记为可读。
        也就是说，当套接字收到客户端发来的数据，就变成可读，然后select就会把这个套接字取出来，进入下一步程序。
        ]]
        local readable = socket.select({sock}, {}, time_remaining)
        local time_spent = os.time() - start_time
        if readable[0] == nil then
        	break
        end
        time_remaining = time_remaining - time_spent
        if time_remaining <= 0 then
        	break
        end
        local time_received = os.time()
        local recvpacket, receip, receport = sock.receivefrom(512)
        local icmp_header = string.sub(recvpacket, 21, 28)
        local icmp_type, code, checksum, packet_id, sequence = string.unpack("bbHHh", icmp_header)
        curr_addr = receip
        curr_name = socket.dns.tohostname(curr_addr)
        if curr_name == nil then
        	curr_name = curr_addr
        end

        if packet_id == pid then
        	local bytes_in_double = string.packsize("d")
        	local time_sent = string.unpack("d", string.sub(recvpacket, 29, 28 + bytes_in_double))[0]
        	delay = time_received - time_sent
        	break
        else
        	delay = time_received - start_time
        	break
        end

        if delay ~= nil then
        	delay = delay * 1000
        else
        	delay = timeout * 1000
        end
        local curr_host = "*"
        if curr_addr ~= nil then
        	curr_host = string.format("%s (%s)", curr_name, curr_addr)
        end
        local content = string.format("%d.\t%s\t%0.3fms\n", ttl, curr_host, delay)
        print(string.format("Trace %d.\t%s\t%0.3fms", ttl, curr_host, delay))

        if curr_addr == dest_addr then
        	return content, true
        else
        	return content, false
        end
    end
end

function struct_unpack_bbHHh(content)
	local first = string.byte(content, 1)
	local second = string.byte(content, 2)
	local third = string.byte(content, 4) * 256 + string.byte(content, 3)
	local forth = string.byte(content, 6) * 256 + string.byte(content, 5)
	local fifth = string.byte(content, 8) * 256 + string.byte(content, 7)
	return first, second, third, forth, fifth
end

function send(sock, pid)
	pid = pid or 0
	local l_check_sum = 0
	local header = string.pack("bbHHh", 8, 0, l_check_sum, pid, 1)
	local bytes_in_double = string.packsize("d")
	local  data = ""
	for i=1, (56 - bytes_in_double) do data = data.."T" end
	data = string.pack("d", os.time())..data

	l_check_sum = check_sum(header..data)
	-- [zxf]socket.htons(l_check_sum)-->l_check_sum
	header = string.pack("bbHHh", 8, 0, l_check_sum, pid, 1)
	local packet = header..data
	sock.sendto(packet, dest_addr, port)
end

local function _trace_exec(ttl)
	local content = "*", false
	local recv_sock = nil
	local send_sock = nil
	recv_sock = socket
	return content
end

function get_target_ip(host, port)
	port = port or 6560
	local target = nil
	print('Trace resolving host: ', host)

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
		print("Trace resolving protocol: ")
		if alt.family == "inet" then
			break
		end
	end

	if target == nil then
		print("Trace resolving using gethostbyname")
		target = socket.dns.gethostbyname(host)
	else
		print("Trace resolving using getaddrinfo")
	end
	print('Trace resolved target: ', target)

	return target
end

function trace(dest)
	dest = dest or 'nil'
	dest_addr = get_target_ip(dest)
	print("Trace route: ", dest_addr, " start.")

	local ttl = 1
	local content = ""

	while true do
		local _trace, result = _trace_exec(ttl)
		content = content.._trace
		ttl = ttl + 1
		if result or ttl > maxhops then
			print("Trace route: ", dest_addr, " finish.")
			break
		end
	end
	return content
end
