local KrissyUtil = require("KrissyUtil")
local LovenseSession = require "SessionAPI"

local Lovense = LovenseSession:new("vq6yzxf0")

local update_interval = 5
local prev_update = 0

function update_buttplug()
	while (os.clock() < (prev_update + update_interval)) do
	end

	local err = Lovense:get_and_handle_message()
	if err ~= nil then
		print("[Lovense] Could not connect to server")
		return
	end

	prev_update = os.clock()
end

Lovense:Connect()
print("Connected")
for i = 0, 20 do
	update_buttplug()
	Lovense:Vibrate(i) -- from 0 to 20 (max)
	print("sent thing")
	KrissyUtil:sleep(3)
end
update_buttplug()
Lovense:Vibrate(0) -- stop vibration