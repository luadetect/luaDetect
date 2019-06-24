require("global_type")
require("libs.json")
require("dc_global_pipline")


local allow_access_engine = DCTOOL_ENABLE_ENGINE_DEVICE

function bridge_engine()
	access_device_info()
	access_trans_id()
end

function access_trans_id()
	local unisdk_trans_id = "null"
	if allow_access_engine then
		require("social")
		local trans_id = social.get_channel().get_prop_str("TRANS_ID")
		if trans_id == nil or trans_id == "" then
			unisdk_trans_id = "null"
		else
			unisdk_trans_id = trans_id
		end
	else
		unisdk_trans_id = "null"
		print("DCEngineBridge access trans id failed, error is ", error)
	end
	set_value("TRANS_ID", unisdk_trans_id)
end

function access_device_info()
	local unisdk_trans_id = nil
	if allow_access_engine then
		require("social")
		local info = social.get_channel().get_prop_str("DCTOOL_DEVICEINFO")
		if info == nil or info == "" then
			info = {os="Unknown device", device_error="NONE_DCTOOL_DEVICEINFO"}
			unisdk_trans_id = json.encode(info)
		else
			unisdk_trans_id = info
		end
	else
		print("Should open switch DCTOOL_ENABLE_ENGINE_DEVICE in Type.py of Dctool3")
		local info = {os='Unknown device', device_error='FALSE_DCTOOL_ENABLE_ENGINE_DEVICE'}
		unisdk_trans_id = json.encode(info)
	end
	set_value("DCTOOL_DEVICEINFO", unisdk_trans_id)
end
