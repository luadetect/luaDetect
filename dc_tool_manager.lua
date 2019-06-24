

dc_tool = require("dc_tool")
dc_engine_bridge = require("dc_engine_bridge")
dc_observer = require("dc_observer")
json = require("libs.json")
global_type = require("global_type")

local function add_observer(observer)
	if not observer then
		return
	end
	attach_observer(observer)
end

local function remove_observer(observer)
	if not observer then
		return
	end
	detach_observer(observer)
end

function diagnose(json_str, observer, max_delay)
	local json_data = json.decode(json_str)
	local scene = json_data["Scene"]
	print("dc_tool disgnosing time: ", os.time(), ", scene is ", scene, ", json string is ", json_str)
	if scene == nil or tonumber(scene) == global_type.Scene.SceneNone then
		print("cd_tool there is no scene")
		return
	end
	if not json_str then
		print("dc_tool diagnose json is nil, please check!")
		return
	end
	add_observer(observer)
	start_detect(json_str, max_delay)
end
