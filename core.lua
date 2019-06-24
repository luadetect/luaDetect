require('global_type')
require('utility')
require("libs.queue")

total_observer = {}

local post_count = 0
local json_data = {}
local queue = clsQueue:create()
local region = -1
local scene = 0
local enable_post = true
local echo_server_done = false


function access_trans_id()
	require "dc_global_pipline"
	json_data[Forms.transid] = get_value("TRANS_ID", nil)
end

function inner_start()
	region = json_data["region"]
	region = region or -1
	scene = json_data["Scene"]
	local c_c = json_data[global_type.Forms.collection_condition]
	c_c = c_c or 0
	scene = scene or c_c
	json_data[global_type.Forms.collection_condition] = tostring(scene)
	json_data[global_type.Forms.product] = json_data["ProductName"] or "nil"
	json_data[global_type.Forms.channel_name] = json_data["ChannelName"] or json_data[global_type.Forms.channel_name] or "nil"
	json_data[global_type.Forms.group_id] = json_data["GroupId"] or json_data[global_type.Forms.group_id] or "nil"
	json_data[global_type.Forms.user_name] = json_data["UserName"] or json_data[global_type.Forms.user_name] or "nil"
	json_data[global_type.Forms.server_name] = json_data["ServerName"] or json_data[global_type.Forms.server_name] or "nil"
	json_data[global_type.Forms.server_ip] = json_data["ServerIP"] or json_data[global_type.Forms.server_ip] or "nil"
	json_data[global_type.Forms.server_port] = json_data["ServerPort"] or json_data[global_type.Forms.server_port] or "0"
	json_data[global_type.Forms.serverlist_url] = json_data["ServerListURL"] or json_data[global_type.Forms.serverlist_url] or "nil"
	json_data[global_type.Forms.patchlist_url] = json_data["PatchListURL"] or json_data[global_type.Forms.patchlist_url] or "nil"
	json_data[global_type.Forms.patch_url] = json_data["PatchURL"] or json_data[global_type.Forms.patch_url] or "nil"
	local keys = {"ProductName", "Scene", "ChannelName", "GroupId", "UserName", "ServerName", "ServerIP", "ServerPort", "ServerListURL", "PatchListURL", "PatchURL"}
	for idx, key in ipairs(keys) do
		if json_data[key] then
			json_data[key] = nil
		end
	end

	set_region(region)

	local timestamp = os.time()
	json_data[global_type.Forms.version] = DCTOOL_VERSION
	json_data[global_type.Forms.start_time] = tostring(math.floor(timestamp))

	post_count = 0
end

function is_pecial_scene()
	local services = get_service_scene_it_need()
	print('Core services = ', tostring(services))
	for idx, key in ipairs(services) do
		if tonumber(scene) == key then
			return true
		end
	end
	return false
end

local function echo_server_alive(url, status_name, index)
	index = index or -1
	web_kit = require("web_kit")
	local data = {["project"] = get_json_data(Forms.product, "nil"), 
					["gid"] = get_json_data(Forms.group_id, "0"),
					["name"] = status_name}
	local status = web_kit.get(data, url, 8, index~=2)
	local code = status["code"] or 501
	if tonumber(code) == 200 then
		print("Core Service Status success: ", status)
		local stats = get_service_status_normal()
		local content = status["content"] or "nil"
		local content_in = false
		for key, value in ipairs(stats) do
			if value == tostring(content) then
				content_in = true
				echo_server_done = true
				cache_status_name(status_name)
				break
			end
		end
		if index == 2 and (not content_in) then
			print("Core Service Status error: ", status)
			echo_server_done = true
		end
	elseif index == 2 then
		print("Core Service Status error: ", status)
		echo_server_done = true
	end
end

local function finish_load_data(data)
	print("Core finish load data, posting data...")
	if data == nil then
		return
	end
	local timestamp = os.time()
	data[global_type.Forms.finish_time] = tostring(math.floor(timestamp))

end

local function get_json_data(key, default_value)
	local data = json_data[key]
	data = data or default_value
	return data
end

local function read_status_name()
	local detect_cache = io.open("DETECT_Cache.cfg", "r")
	local content = detect_cache:read()
	detect_cache:close()
	json = require("json")
	local cont_table = json.decode(content)
	local detect_session = cont_table["DETECT_SESSION"]
	if detect_session == nil then
		print("Core add section DETECT_SESSION")
		detect_cache = io.open("DETECT_Cache.cfg", "w")
		cont_table["DETECT_SESSION"] = {}
		local new_content = json.encode(cont_table)
		detect_cache:write(new_content)
		detect_cache:close()
		return nil
	end
	local status_name = detect_session["status_name"]
	return status_name

end

local function has_section(section_name)
	local detect_cache = io.open("DETECT_Cache.cfg", "r")
	local content = detect_cache:read()
	detect_cache:close()
	json = require("json")
	local cont_table = json.decode(content)
	local detect_session = cont_table[section_name]
	if detect_session == nil then
		return false
	end
	return true
end

local function remove_option(section_name, opt_name)
	local detect_cache = io.open("DETECT_Cache.cfg", "r")
	local content = detect_cache:read()
	detect_cache:close()
	json = require("json")
	local cont_table = json.decode(content)
	local detect_session = cont_table[section_name]
	local status_name = detect_session[opt_name]
	if status_name then
		detect_session[opt_name] = nil
		detect_cache = io.open("DETECT_Cache.cfg", "w")
		local new_content = json.encode(cont_table)
		detect_cache:write(new_content)
		detect_cache:close()
	end

end

local function add_section(section_name)
	local detect_cache = io.open("DETECT_Cache.cfg", "r")
	local content = detect_cache:read()
	detect_cache:close()
	json = require("json")
	local cont_table = json.decode(content)
	local detect_session = cont_table[section_name]
	if detect_session == nil then
		detect_cache = io.open("DETECT_Cache.cfg", "w")
		cont_table["DETECT_SESSION"] = {}
		local new_content = json.encode(cont_table)
		detect_cache:write(new_content)
		detect_cache:close()
	end
end

local function set_option(section_name, opt_name)
	local detect_cache = io.open("DETECT_Cache.cfg", "r")
	local content = detect_cache:read()
	detect_cache:close()
	json = require("json")
	local cont_table = json.decode(content)
	local detect_session = cont_table[section_name]
	detect_session["status_name"] = opt_name
	detect_cache = io.open("DETECT_Cache.cfg", "w")
	local new_content = json.encode(cont_table)
	detect_cache:write(new_content)
	detect_cache:close()
end

local function cache_status_name(status_name)
	print(string.format("Core try to cache status name ", status_name))

	if 0 == string.len(status_name) and has_section("DETECT_SESSION") then
		print("Core status name is nil, delete it")
		remove_option("DETECT_SESSION", "status_name")
		return
	end

	if has_section("DETECT_SESSION") then
		print("Core has section DETECT_SESSION, set status_name = ", status_name)
		set_option("DETECT_SESSION", "status_name", status_name)
	else
		print("Core add section DETECT_SESSION")
		add_section("DETECT_SESSION")
		set_option("DETECT_SESSION", "status_name", status_name)
	end
end

local function query_region()
	print("Core query_region")
	web_kit = require("web_kit")
	if tonumber(region) ~= 2 then
		utility = require("utility")
		
		local url = get_region_url()
		local data = {}
		local res = get(data, url, 8)
		local code = res.code

		if code and tonumber(res.code) == 200 then
			local content = res.content
			if content and tonumber(content) == 0 and tonumber(region) < 0 then
				region = "0"
			elseif tonumber(region) < 0 then
				region = "1"
			end
			print("Core query_region result: ", region)
			set_region(region)
		else
			print("Core region is 2, No need to query again, will HEAD outsize website next.")
		end
	end
end

local function specific_url_connectivity(specific_url)
	if not specific_url then
		return
	end
	web_kit = require("web_kit")
	local res = web_kit.head(data, specific_url, 3)
	json_data[Forms.http_code] = res["code"] or 501
	json_data[Forms.patch_url] = specific_url
	ping = require("ping")
	--[zxf] protocol, s1 = dt_urllib2.splittype(specificURL)
    --host, path = dt_urllib2.splithost(s1)
    --host, port = dt_urllib2.splitport(host)
    local host = 'nil'
    local port = nil
    local ping_result = ping_ping(host)
    local cost = ping_result["cost"] or 1000.0
    local rate = ping_result['rate'] or "4/4"
    local ip = ping_result["ip"] or "127.0.0.1"
    json_data[Forms.ping] = string.format("%0.3f", cost)
    json_data[Forms.ping_lost] = rate
    json_data['Forms.server_ip'] = ip
    if port == nil then
    	port = json_data[Forms.server_port]
    end
    connect_to_server(port)
end

local function parse_patch_list_host()
	print("Core parse_patch_list_host")
	net_kit = require("net_kit")
	local data = resolve_url(tostring(json_data[global_type.Forms.patchlist_url]))
	print(data)
	json_data[global_type.Forms.url] = tostring(json_data[global_type.Forms.patchlist_url])
	json_data[global_type.Forms.server_list_host] = tostring((data["host"] or "nil"))
	json_data[global_type.Forms.ip_server_list_host] = tostring((data["ip"] or "nil"))
	json_data[global_type.Forms.domain_resolve_log] = tostring((data["error"] or "nil"))
end

local function parse_patch_host()
	print("Core parse_patch_host")
	net_kit = require("net_kit")
	local data = resolve_url(tostring(json_data[global_type.Forms.patch_url]))
	print(data)
	json_data[global_type.Forms.url] = tostring(json_data[global_type.Forms.patch_url])
	json_data[global_type.Forms.patch_host] = tostring((data["host"] or "nil"))
	json_data[global_type.Forms.ip_patch_host] = tostring((data["ip"] or "nil"))
	json_data[global_type.Forms.domain_resolve_log] = tostring((data["error"] or "nil"))
end

local function trace_to_patch()
	print("Core trace_to_patch")
	local host = tostring(get_json_data(global_type.Forms.ip_patch_host, "nil"))
	if host ~= "nil" then
		require("trace")
		local data = trace(host)
		json_data[global_type.Forms.tracert_patch] = tostring(data)
	end
	finish_load_data(json_data)
end

local function ping_patch()
	print("Core ping_patch")
	local host = tostring(get_json_data(global_type.Forms.ip_patch_host, "nil"))
	if host ~= "nil" then
		ping = require("ping")
		local data = ping_ping(host)
		print(data)
		local cost = data["cost"] or 1000.0
		local rate = data["rate"] or "4/4"
		json_data[global_type.Forms.ping_patch] = string.format("%0.3f", cost)
		json_data[global_type.Forms.ping_lost_patch] = string.format("%s", rate)
		trace_to_patch()
	else
		finish_load_data(json_data)
	end
end

local function head_to_patch()
	print("Core head_to_patch")
	web_kit = require("web_kit")
	local data = {}
	local url = tostring(json_data[global_type.Forms.patch_url])
	print("Core head_to_patch url is ", url)
	if url ~= "nil" then
		local res = head(data, url, 3)
		local code = res["code"] or 501
		local content = res["content"] or "nil"
		if tonumber(code) == 501 and tostring(content) == "ssl_error" then
			json_data[global_type.Forms.download_patch] = "false"
		else
			json_data[global_type.Forms.download_patch] = "true"
		end
	else
		json_data[global_type.Forms.download_patch] = "false"
	end
	ping_patch()
end

local function choose_scene()
	print("Core choose_scene")

	if tonumber(scene) == global_type.Scene.Delay or
	 tonumber(scene) == global_type.Scene.ConnectToServerFailed or
	 tonumber(scene) == global_type.Scene.UnexpextOffline or
	 tonumber(scene) == global_type.Scene.LostPackets or 
	 tonumber(scene) == global_type.Scene.CollectionNormal then
		ping_server()
	elseif tonumber(scene) == global_type.Scene.DownloadPatchListFailed then
		parse_patch_list_host()
		head_to_patch_list()
	elseif tonumber(scene) == global_type.Scene.DownloadServerListFailed then
		parse_server_list_host()
		head_to_server_list()
	elseif tonumber(scene) == global_type.Scene.DownloadPatchFailed or
		(tonumber(scene) >= global_type.Scene.PatchFailedExtendStart and 
			tonumber(scene) <= global_type.Scene.PatchFailedExtendEnd) then
		parse_patch_host()
		head_to_patch()
	else
		finish_load_data(json_data)
	end
end

local function ping_website()
	print("Core ping_website")
	local host = get_website1()
	ping = require("ping")
	local site1 = ping_ping(host)
	local host2 = get_website2()
	local site2 = ping_ping(host2)
	local host3 = get_website3()
	local site3 = ping_ping(host3)
	print(site1, site2, site3)

	if tonumber(region) < 1 then
		json_data[global_type.Forms.time_visit163] = string.format("%0.3f", (site1["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_163] = string.format("%s", (site1["rate"] or "4/4"))
		json_data[global_type.Forms.ip_163] = string.format("%s", (site1["ip"] or "127.0.0.1"))
		json_data[global_type.Forms.time_visitqq] = string.format("%0.3f", (site2["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_qq] = string.format("%s", (site2["rate"] or "4/4"))
		json_data[global_type.Forms.ip_qq] = string.format("%s", (site2['ip'] or "127.0.0.1"))
		json_data[global_type.Forms.time_visitbaidu] = string.format("%0.3f", (site3["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_baidu] = string.format("%s", (site3["rate"] or "4/4"))
		json_data[global_type.Forms.ip_baidu] = string.format("%s", (site3["ip"] or "127.0.0.1"))
	else
		json_data[global_type.Forms.time_visitgoogle] = string.format("%0.3f", (site1["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_google] = string.format("%s", (site1["rate"] or "4/4"))
		json_data[global_type.Forms.ip_google] = string.format("%s", (site1["ip"] or "127.0.0.1"))
		json_data[global_type.Forms.time_visitfacebook] = string.format("%0.3f", (site2["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_facebook] = string.format("%s", (site2["rate"] or "4/4"))
		json_data[global_type.Forms.ip_facebook] = string.format("%s", (site2['ip'] or "127.0.0.1"))
		json_data[global_type.Forms.time_visitbing] = string.format("%0.3f", (site3["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_bing] = string.format("%s", (site3["rate"] or "4/4"))
		json_data[global_type.Forms.ip_bing] = string.format("%s", (site3["ip"] or "127.0.0.1"))
	end
	choose_scene()

end

local function head_websit()
	print("Core head_websit")
	web_kit = require("web_kit")

	local url = get_website1()
	local data = {}
	local res = head(data, url, 3)
	local code = res["code"] or 501
	local content = res["content"] or "nil"
	local site1 = true
	if tonumber(code) == 501 and tostring(content) == "ssl_error" then
		site1 = false
	end
	url = get_website2()
	data = {}
	res = head(data, url, 3)
	code = res["code"] or 501
	content = res["content"] or "nil"
	site2 = true
	if tonumber(code) == 501 and tostring(content) == "ssl_error" then
		site2 = false
	end
	url = get_website3()
	data = {}
	res = head(data, url, 3)
	code = res["code"] or 501
	content = res["content"] or "nil"
	site3 = true
	if tonumber(code) == 501 and tostring(content) == "ssl_error" then
		site3 = false
	end
	if tonumber(region) < 1 then
		json_data[global_type.Forms.head_163] = tostring(site1)
		json_data[global_type.Forms.head_qq] = tostring(site2)
		json_data[global_type.Forms.head_baidu] = tostring(site3)
	else
		json_data[global_type.Forms.head_google] = tostring(site1)
		json_data[global_type.Forms.head_facebook] = tostring(site2)
		json_data[global_type.Forms.head_bing] = tostring(site3)
	end
	if site1 or site2 or site3 then
		ping_website()
	else
		choose_scene()
	end
end

local function ping_server()
	print("Core ping_server")

	if tostring(json_data[global_type.Forms.server_ip]) ~= 'nil' then
		ping = require("ping")
		local data = ping_ping(tostring(json_data[global_type.Forms.server_ip]))
		print(data)
		json_data[global_type.Forms.ping] = string.format("%0.3f", (data["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost] = string.format("%s", (data["rate"] or "4/4"))
		connect_to_server()
	else
		finish_load_data(json_data)
	end
end

local function head_to_app_host()
	print("Core head_to_app_host")
	require("web_kit")
	local data = {}
	local url = tostring(json_data[global_type.Forms.url])
	local res = web_kit.head(data, url, 3)
	local code = res["code"] or 501
	local content = res["content"] or "nil"
	if tonumber(code) == 501 and tostring(content) == "ssl_error" then
		json_data[global_type.Forms.head_result] = "false"
	else
		json_data[global_type.Forms.head_result] = "true"
	end
	ping_app_host()
end

local function ping_app_host()
	print("Core ping_add_host")
	local host = tostring(get_json_data(global_type.Forms.server_ip, "nil"))
	if host ~= "nil" then
		require("ping")
		local data = ping_ping(host)
		print(data)
		local cost = data["cost"] or 1000.0
		local rate = data["rete"] or "4/4"
		json_data[global_type.Forms.ping] = string.format("%0.3f", cost)
		json_data[global_type.Forms.ping_lost] = string.format("%s", rate)
		trace_to_app_host()
	else
		finish_load_data(json_data)
	end
end

local function trace_to_app_host()
	print("Core trace_to_app_host")
	local host = tostring(get_json_data(global_type.Forms.server_ip, "nil"))
	if host ~= "nil" then
		require("trace")
		local data = trace(host)
		json_data[global_type.Forms.tracert] = tostring(data)
	end
	finish_load_data(json_data)
end

local function head_to_server_list()
	print("Core head_to_server_list")
	local data = {}
	local url = tostring(json_data[global_type.Forms.serverlist_url])
	require(web_kit)
	local res = head(data, url, 3)
	if tonumber((res["code"] or 501)) == 501 and tostring((res["content"] or "nil")) == "ssl_error" then
		json_data[global_type.Forms.download_server_list] = "false"
	else
		json_data[global_type.Forms.download_server_list] = "true"
	end
	ping_server_list()
end

local function ping_server_list()
	print("Core ping_server_list")
	local host = tostring((json_data[global_type.Forms.ip_server_list_host] or "nil"))
	if host ~= "nil" then
		ping = require("ping")
		local data = ping_ping(host)
		print(data)
		json_data[global_type.Forms.ping_serverlist] = string.format("%0.3f", (data["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_serverlist] = (data["rate"] or "4/4")
		trace_to_server_list()
	else
		finish_load_data(json_data)
	end
end

local function trace_to_server_list()
	print("Core trace_to_server_list")
	local host = tostring((json_data[global_type.Forms.ip_server_list_host] or "nil"))
	if host ~= "nil" then
		trace = require("trace")
		local data = trace(host)
		json_data[global_type.Forms.tracert_serverlist] = tostring(data)
	end
	finish_load_data(json_data)
end

local function parse_server_list_host()
	print("Core parse_server_list_host")
	net_kit = require("net_kit")
	local data = resolve_url(tostring(json_data[global_type.Forms.serverlist_url]))
	print(data)
	json_data[global_type.Forms.url] = tostring(json_data[global_type.Forms.serverlist_url])
	json_data[global_type.Forms.server_list_host] = tostring((data["host"] or "nil"))
	json_data[global_type.Forms.ip_server_list_host] = tostring((data["ip"] or "nil"))
	json_data[global_type.Forms.domain_resolve_log] = tostring((data["error"] or "nil"))
end

local function head_to_patch_list()
	print("Core head_to_patch_list")
	local data = {}
	local url = tostring(json_data[global_type.Forms.patchlist_url])
	web_kit = require("web_kit")
	local res = head(data, url, 3)
	if tonumber((res["code"] or 501)) == 501 and tostring((res["content"] or "nil")) == "ssl_error" then
		json_data[global_type.Forms.download_patch_list] = "false"
	else
		json_data[global_type.Forms.download_patch_list] = "true"
	end
	ping_patch_list()
end

local function ping_patch_list()
	print("Core ping_patch_list")
	local host = tostring((json_data[global_type.Forms.ip_server_list_host] or nil))
	if host ~= "nil" then
		ping = require("ping")
		local data = ping_ping(host)
		print(data)
		json_data[global_type.Forms.ping_patchlist] = string.format("%0.3f", (data["cost"] or 1000.0))
		json_data[global_type.Forms.ping_lost_patchlist] = data["rate"] or "4/4"
		trace_to_patch_list()
	else
		finish_load_data(json_data)
	end
end

local function trace_to_patch_list()
	print("Core trace_to_patch_list")
	local host = tostring((json_data[global_type.Forms.ip_server_list_host] or "nil"))
	if host ~= "nil" then
		trace = require("trace")
		local data = trace(host)
		json_data[global_type.Forms.tracert_patchlist] = tostring(data)
	end
	finish_load_data(json_data)
end

local function connect_to_server(port)
	print("Core connect_to_server")
	if port == 0 then
		port = tonumber(json_data[global_type.Forms.server_port])
	end
	net_kit = require("net_kit")
	if access_connectivity(tostring(json_data[global_type.Forms.server_ip]), port) then
		json_data[global_type.Forms.port_connect] = "true"
	else
		json_data[global_type.Forms.port_connect] = "false"
	end
	trace_to_server()
end

local function trace_to_server()
	print("Core trace_to_server")
	trace = require("trace")
	local data = trace(tostring(json_data[global_type.Forms.server_ip]))
	json_data[global_type.Forms.tracert] = tostring(data)
	finish_load_data(json_data)
end

local function post_data_from_queue()
	while queue:getCnt() ~= 0 and enable_post do
		local data = queue:popHead()
		post(data)
	end
end

local function post(data)
	if data == nil then
		data = {}
	end
	local url = get_upload_url()
	web_kit = require("web_kit")
	local result = post(data, url, 10)
	if tonumber((result["code"] or 501)) == 501 then
		print("Core POST error: ", result)
		post_count = post_count + 1
		if post_count > 3 then
			enable_post = false
			retry_after(10)
		end
		queue:pushTail(data)
	else
		print("Core POST success: ", result)
		enable_post = true
		notify_observer(result)
	end
end

local function retry_after(time_delay)
	print("Core network status may be offline, please check device network connectivity!")
	print("Core Post operation will resume after 10s!")
	require("socket")
	socket.sleep(10)
	enable_post = true
	post_data_from_queue()
end

function notify_observer(data)
	if (not total_observer) or table.getn(total_observer) == 0 then
		print("Core DCTool has not any observer")
		return
	else
		print("Core DCTool has observer(s)")
	end

	for idx, observer in ipairs(total_observer) do
		print("Core Observer: ", observer)
		if observer ~= nil and observer.completionHandler then
			observer.completionHandler(data)
		else
			print("Core Observer must abide by the protocol of completionHandler")
		end
	end
end

local function choose_how_to_upload()
	print("Core choose_how_to_upload")
	local explicit_url = json_data[global_type.Forms.patch_url]
	if tonumber(scene) == global_type.Scene.URLConnectivityReachable or
	 tonumber(scene) == global_type.Scene.URLConnectivityUnreachable then
		query_region()
		specific_url_connectivity(explicit_url)
	elseif tonumber(scene) == global_type.Scene.Delay or tonumber(scene) == global_type.Scene.UnexpextOffline or
	 tonumber(scene) == global_type.Scene.LostPackets or tonumber(scene) == global_type.Scene.CollectionNormal or
	  tonumber(scene) == global_type.Scene.ConnectToServerFailed or
	  tonumber(scene) == global_type.Scene.DownloadPatchListFailed or
	  tonumber(scene) == global_type.Scene.DownloadServerListFailed or
	  tonumber(scene) == global_type.Scene.DownloadPatchFailed or
	  (tonumber(scene) >= global_type.Scene.PatchFailedExtendStart and tonumber(scene) <= global_type.Scene.PatchFailedExtendEnd) then
		query_region()
		head_websit()
	elseif tonumber(scene) == global_type.Scene.DownloadPatchListCanceled or
	 tonumber(scene) == global_type.Scene.DownloadPatchListSuccessed then
		parse_patch_list_host()
		finish_load_data(json_data)
	elseif tonumber(scene) == global_type.Scene.DownloadServerListCanceled or
	 tonumber(scene) == global_type.Scene.DownloadServerListSuccessed then
		parse_server_list_host()
		finish_load_data(json_data)
	elseif tonumber(scene) == global_type.Scene.DownloadPatchCanceled or
	 tonumber(self.scene) == global_type.Scene.DownloadPatchSuccessed then
	 	parse_patch_host()
	 	finish_load_data(json_data)
	elseif tonumber(scene) >= global_type.Scene.PatchSuccessedExtendStart and
	 tonumber(self.scene) <= global_type.Scene.PatchSuccessedExtendEnd then
        -- 解析设置的patch url的DNS
        parse_patch_host()
        finish_load_data(jsonData)
    elseif tonumber(scene) == global_type.Scene.PatchStart then
        -- 解析设置的patch url的DNS
        parse_patch_host()
        finish_load_data(jsonData)
    elseif tonumber(scene) == global_type.Scene.Payment then
        parse_payment()
        finish_load_data(jsonData)
    elseif tonumber(scene) == global_type.Scene.AppVisitSuccessed then
        parse_app_host()
        finish_load_data(self.jsonData)
    elseif tonumber(scene) == global_type.Scene.AppVisitFailed then
        parse_app_host()
        head_to_app_host()
    elseif tonumber(scene) == global_type.Scene.ConnectToServerSuccessed then
        parse_connect_success_host()
        finish_load_data(jsonData)
    else
        finish_load_data(jsonData)
    end
end

local function http_to_dns()
	print("Core http_to_dns")
	local url = get_dns_url()
	local data = {}
	web_kit = require("web_kit")
	local res = get(data, url, 8)
	if tonumber((res["code"] or 501)) == 200 then
		local gw_dns = nil
		local net_dns = nil
		local dns_info = tostring((res["content"] or "nil"))
		for dns in string.gmatch(dns_info, "[^\n]+") do
			if string.find(dns, "netdns=") then
				net_dns = string.sub(dns, 8)
			end
			if string.find(dns, "gwdns=") then
				gw_dns = string.sub(dns, 7)
			end
		end
		print("Core http_to_dns netdns: ", net_dns, ", gwdns: ", gw_dns)
		json_data[global_type.Forms.client_dns_ip] = net_dns
		json_data[global_type.Forms.client_dns_result] = gw_dns
	else
		json_data[global_type.Forms.nstool_log] = (res["error"] or "nil")
	end
	choose_how_to_upload()
end

-- 判断游戏服是否在维护/服务 [1,4,5,10,11]才需要判断！
local function is_serving()
	print("Core Checking the Servicing status.")
	echo_server_done = false

	if is_pecial_scene() then
		local url = get_service_url()
		local cache_status_name = read_status_name()
		local status_names = {"nil", "STATUS", "CLUSTER_STATUS", "GAME_STATUS"}

		print("!!!Core access cached status name is ", cache_status_name)
		local status_name_in = false
		for idx, status_name in ipairs(status_names) do
			if status_name == cache_status_name then
				status_names[idx] = nil
				status_names[0] = cache_status_name
				status_name_in = true
				break
			end
		end
		if not status_name_in and cache_status_name then
			status_names[0] = cache_status_name
		end

		print("Core status names is ", status_names)

		for idx, status in ipairs(status_names) do
			if echo_server_done then
				break
			end
			echo_server_alive(url, status, index)
		end
	else
		print("Core No need to check the Service Status on scene: ", scene, ", will resolve DNS next.")
		http_to_dns()
	end
end

function core_start(data)
	print("Core Consume: ", data)
	json_data = data
	access_trans_id()
	inner_start()
	is_serving()
end