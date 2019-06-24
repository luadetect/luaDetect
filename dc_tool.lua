

producer = require("pool.dc_producer")
consumer = require("pool.dc_consumer")
core = require("core")

local function _modify_queue_size(queue_size)
	queue_size = queue_size or 50
end

local function delay_start(json_str, max_delay)
	require("socket")
	math.randomseed(os.time())
	socket.sleep(math.random(max_delay))
	start_producing(json_str)
end

function attach_observer(obsr)
	if not obsr then
		return
	end
	check_in = false
	for idx, obs in ipairs(total_observer) do
		if obs == obsr then
			check_in = true
			break
		end
	end
	if obsr and not check_in then
		table.insert(total_observer, obsr)
	end
end

function detach_observer(obsr)
	if not obsr then
		return
	end
	check_in = false
	for idx, obs in ipairs(total_observer) do
		if obs == obsr then
			check_in = true
			break
		end

	end
	if obsr and check_in then
		table.remove(total_observer, obsr)
	end
end

function start_detect(json_str, max_delay)
	max_delay = max_delay or 0
	if max_delay > 0 then
		delay_start(json_str, max_delay)
	else
		start_producing(json_str)
	end
end
