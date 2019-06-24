
core = require("core")
dc_producer = require("pool.dc_producer")

local function _consume(product)
	print("Pool start consuming ", product)
	core_start(product)
end

function dc_consumer_run()
	while true do
		if dctoolQueue:getCnt() ~= 0 then
			local product = nil
			product = dctoolQueue:popHead()
			_consume(product)
		end
	end
end
