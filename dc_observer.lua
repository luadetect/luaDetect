require("libs.baseobj")
clsDCBaseObserver = CObject:new{
	TypeStr = "clsDCBaseObserver"
}

function clsDCBaseObserver:init()
	Super(clsDCBaseObserver).init(self)
end

function clsDCBaseObserver:completionHandler(receive_data)
	print("receive data is ", receive_data)
end

clsDCObserver = clsDCBaseObserver:new{
	TypeStr = "clsDCObserver"
}

function clsDCObserver:init()
	Super(clsDCObserver).init(self)
end

function clsDCObserver:completionHandler(receive_data)
	print("dc_tool dc_observer receive data is ", receive_data)
	print("================================================================================")
end
