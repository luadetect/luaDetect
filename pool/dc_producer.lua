
require "global_type"
require "libs.json"
require("libs.queue")

dctoolQueue = clsQueue:create()

function limit_queue_size(queue_size)
	queue_size = queue_size or 50
	--table.setn(dctoolQueue, queue_size)
end

function start_producing(data)
	local timestamp = os.time()
	local jsonData = json.decode(data)
	jsonData[global_type.Forms.push_time] = timestamp
	require "dc_global_pipline"
	local device_info = json.decode(get_value("DCTOOL_DEVICEINFO", "{}"))
	print('Pool device_info = ', device_info)
	for key, value in ipairs(device_info) do
		jsonData[key] = value
		print('Pool Adding Product Device key:',key,', value: ', value)
	end
	print('Pool Adding Product:', jsonData)
	dctoolQueue:pushTail(jsonData)
	--table.insert(dctoolQueue, jsonData)
end
