local KrissyUtil = require "KrissyUtil"

local LovenseSession = {}

local baseUrl = "https://c.lovense-api.com"
local wsUrl = "wss://c.lovense-api.com"
--local request = syn and syn.request or request
--local connect = syn and syn.websocket.connect or WebSocket.connect
local JSON = require("json")

local mt = {
    __index = LovenseSession
}
local function getCLID(shortCode)
    print(shortCode)
    local httpBoundary = "---------------------------" .. math.random(1, 1000000)
    local response = http.post(baseUrl .. "/anon/longtimecontrollink/init", "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="shortCode"\r\n\r\n' .. shortCode .. "\r\n" .. "--" .. httpBoundary .. "--\r\n",  {["Content-Type"] = "multipart/form-data; boundary=" .. httpBoundary})
    local status = response.getResponseCode()
    local headers = response.getResponseHeaders()
    local body = response.readAll()
    if JSON.decode(body).message then
        error("[LOVENSE] " .. JSON.decode(body).message)
    end
    print(JSON.decode(body).data.id)
    return {
        Status = status,
        Headers = headers,
        Body = body
    }
end
local function getSessionData(accessCode) -- to be fixed
    local httpBoundary = "---------------------------" .. math.random(1, 1000000)
    local CLID = JSON.decode(getCLID(accessCode).Body).data.id
    local response = http.post(baseUrl .. "/anon/controllink/join", "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="id"\r\n\r\n' .. CLID .. "\r\n" .. "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="historyUrl"\r\n\r\n\r\n' .. "--" .. httpBoundary .. "--\r\n", {["Content-Type"] = "multipart/form-data; boundary=" .. httpBoundary})
    local status = response.getResponseCode()
    local headers = response.getResponseHeaders()
    local body = response.readAll()
    return {
        Status = status,
        Headers = headers,
        Body = body
    }
end
function LovenseSession:new(accessCode)
    local self = setmetatable({}, mt)
    self.debuggingOn = true -- you can change this
    self.accessCode = accessCode
    return self
end
function LovenseSession:Connect()
    local data = JSON.decode(getSessionData(self.accessCode).Body)
    if data.message then
        if self.debuggingOn then
            print("[LOVENSE] " .. data.message)
        end
        return false
    end
    local ws_url =
        data.data.wsUrl:gsub("https://", "wss://"):gsub("%.com%?", ".com/anon.io/?") .. "&EIO=3&transport=websocket"
    if self.debuggingOn then
        print("[LOVENSE] Access code is valid! Attempting to connect..")
    end
    local ws = assert(http.websocket(ws_url))
    
    self.active = true
    self.ws = ws
    self.sessionData = data
    
    self.connected = false
    self.initDone = false
    self.hbStarted = false

    return true
end
function LovenseSession:handle_message(msg)
    if KrissyUtil:startsWith(msg, "0") then
        if self.debuggingOn then
            print("[LOVENSE] Init payload received")
        end
        local wsData = JSON.decode(msg:sub(2))
        self.wsData = wsData
        self.initDone = true
    elseif KrissyUtil:startsWith(msg, "40") and self.initDone and not self.hbStarted then
        if self.debuggingOn then
            print("[LOVENSE] Connected!")
        end
        print(self.sessionData.data.controlLinkData.creator.toys[1].type)
        self.toys = self.sessionData.data.controlLinkData.creator.toys
        self.connected = true
        self.hbStarted = true
        local c = coroutine.create(
            function()
                while self.active do
                    ws.send(tostring(self.wsData.pingCode))
                    KrissyUtil:sleep(self.wsData.pingInterval)
                end
            end
        )
        self.ws.send('42["anon_open_control_panel_ts",{"linkId":"' .. self.sessionData.data.controlLinkData.linkId .. '"}]')
    elseif KrissyUtil:startsWith(msg, '42') then
        if KrissyUtil:startsWith(msg, '42["anon_link_is_end_tc') then
            self:Disconnect("Control Link ended")
        elseif KrissyUtil:startsWith(msg, '42["which_app_page_open_now_tc"') then
            local msgData = JSON.decode(JSON.decode(msg:sub(3))[2])
            self.ws.send('42["app_open_this_page_now_ts",{"pepsiId":"' .. msgData.pepsiId .. '","webPage":"control_link"}]')
        end
    end
    while not self.connected or not self.initDone do
        self:get_and_handle_message()
    end
end
function LovenseSession:get_and_handle_message()
    local message = assert(self.ws.receive())

    if message and string.len(message) > 1 then
        print("< " .. message)
        self:handle_message(message)
    end
end
function LovenseSession:Disconnect(cause)
    self.active = false
    self.connected = false
    self.ws:close()
    print("[LOVENSE] Disconnected: " .. cause)
end
function LovenseSession:Vibrate(strength)
    if not self.connected then
        print("[LOVENSE] Not connected!")
        return
    end

    self.ws.send(
        '42["anon_command_link_ts",{"toyCommandJson":"{\\"version\\":5,\\"cate\\":\\"id\\",\\"id\\":{\\"' ..
            self.toys[1].id ..
                '\\":{\\"v\\":' .. strength .. ',\\"v1\\":-1,\\"v2\\":-1,\\"v3\\":-1,\\"s\\":-1,\\"p\\":-1,\\"r\\":-1,\\"f\\":-1,\\"t\\":-1}}}","linkId":"' ..
                                    self.sessionData.data.controlLinkData.linkId .. '","userTouch":false}]'
    )
end

return LovenseSession