dc_tool_manager = require("dc_tool_manager")
json = require("json")
dc_consumer = require("pool.dc_consumer")


local function lazy_diagnose(json_str)
	if not json_str then
		print("diagnose string is nil, please check!")
		return
	end
	diagnose(json_str)
	while true do
		dc_consumer_run()
	end
end

local data = {Scene=6, ProductName="opsys", GroupId="1003",
			 UserName="unisdk_test", ChannelName="unisdk",
			 UserId="123456", patch_url="https://www.sogou.com",
             server_port=443}

lazy_diagnose(json.encode(data))
