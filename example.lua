local KrissyUtil = require("KrissyUtil")
local LovenseSession = require "SessionAPI"

local Lovense = LovenseSession:new("xxxxxx")

local update_interval = 5
local prev_update = 0

function update_session()
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
for i = 0, 5 do
	update_session()
	Lovense:Vibrate(5) -- from 0 to 20 (max)
	print("Sent Initial Vibrate (5)")
	KrissyUtil:sleep(3)
	update_session()
	Lovense:Vibrate(0) -- stop vibration
	print("Sent Stop Vibrate")
	KrissyUtil:sleep(3)
end
update_session()
Lovense:Vibrate(0) -- stop vibration
Lovense:Disconnect("Client Disconnected")