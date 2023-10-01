local KrissyUtil = require "KrissyUtil"

local LovenseSession = {}

do
    local baseUrl = "https://c.lovense-api.com"
    local wsUrl = "wss://c.lovense-api.com"
    --local request = syn and syn.request or request
    --local connect = syn and syn.websocket.connect or WebSocket.connect
    local pollnet = require("pollnet")
    local JSON = require("json")

    local mt = {
        __index = LovenseSession
    }
    local function poll_blocking(sock)
        while sock:poll() do
            if sock:last_message() then
                return sock:last_message()
            end
            pollnet.sleep_ms(20)
        end
        error("Socket closed?", sock:last_message())
        sock:close()
    end
    local function getCLID(shortCode)
        print(shortCode)
        local httpBoundary = "---------------------------" .. math.random(1, 1000000)
        local sock = pollnet.http_post(baseUrl .. "/anon/longtimecontrollink/init", "Content-Type: multipart/form-data; boundary=" .. httpBoundary, "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="shortCode"\r\n\r\n' .. shortCode .. "\r\n" .. "--" .. httpBoundary .. "--\r\n")
        local status = poll_blocking(sock)
        local headers = poll_blocking(sock)
        local body = poll_blocking(sock)
        sock:close()
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
        local sock = pollnet.http_post(baseUrl .. "/anon/controllink/join", "Content-Type: multipart/form-data; boundary=" .. httpBoundary, "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="id"\r\n\r\n' .. CLID .. "\r\n" .. "--" .. httpBoundary .. "\r\n" .. 'Content-Disposition: form-data; name="historyUrl"\r\n\r\n\r\n' .. "--" .. httpBoundary .. "--\r\n")
        local status = poll_blocking(sock)
        local headers = poll_blocking(sock)
        local body = poll_blocking(sock)
        sock:close()
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
        local ws = pollnet.open_ws(ws_url)
        
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
                        ws:send(tostring(self.wsData.pingCode))
                        KrissyUtil:sleep(self.wsData.pingInterval)
                    end
                end
            )
            self.ws:send('42["anon_open_control_panel_ts",{"linkId":"' .. self.sessionData.data.controlLinkData.linkId .. '"}]')
        elseif KrissyUtil:startsWith(msg, tostring(self.wsData.pongCode)) and self.initDone then
            self.ws:send('42["anon_open_control_panel_ts",{"linkId":"' .. self.sessionData.data.controlLinkData.linkId .. '"}]')
        elseif KrissyUtil:startsWith(msg, '42["anon_link_is_end_tc') then
            self:Disconnect("Control Link ended")
        end
        while not self.connected or not self.initDone do
            self:get_and_handle_message()
        end
    end
    function LovenseSession:get_and_handle_message()
        local happy, message = self.ws:poll()

        if not happy then
            return message
        end

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

        self.ws:send(
            '42["anon_command_link_ts",{"toyCommandJson":"{\\"cate\\":\\"id\\",\\"id\\":{\\"' ..
                self.toys[1].id ..
                    '\\":{\\"v\\":-1,\\"v1\\":' ..
                        strength ..
                            ',\\"v2\\":' ..
                                strength ..
                                    ',\\"p\\":-1,\\"r\\":-1}}}","linkId":"' ..
                                        self.sessionData.data.controlLinkData.linkId .. '","userTouch":false}]'
        )
    end
end

return LovenseSession