--- @module bluenet
-- 

local modem = peripheral.find("modem") or error("No modem attached", 0)
local redrun  = require '.redrun'
local started = false
modem.open(0)

local urls = (function ()
    
    local function protocol (url)
        return (url:match("^(%a+[:][/][/])") or ""):lower();
    end
    
    local function parseWebUrl (parsed, url)
        url = url:sub(#parsed.protocol + 1, #url);
        parsed.hash = url:match("#.*$") or "";
        url = url:sub(1, #url - #parsed.hash);
        parsed.querystring = url:match("[?].*$") or "";
        url = url:sub(1, #url - (parsed.querystring and #parsed.querystring or ""));
        parsed.pathname = url:match("/.*$");
        url = url:sub(1, #url - (parsed.pathname and #parsed.pathname or ""));
        local portString = url:match(":%d%d?%d?%d?%d?");
        url = url:sub(1, #url - (portString and #portString or 0));
        if portString then
            parsed.port = tonumber(portString:sub(2, #portString));
        end
        parsed.host = url:match("@?([^@]*)$") or "";
        parsed.origin = parsed.protocol .. parsed.host;
        url = url:sub(1, #url - #parsed.host);
        parsed.user = url:match("^([^:@]+)");
        parsed.pass = url:match("[:]([^@]+)[@]");
        return parsed;
    end
    
    local function parse (url)
        local parsed = {
            url = url,
            protocol = protocol(url)
        };
        if
            parsed.protocol == "https://" or
            parsed.protocol == "http://" or
            parsed.protocol == "wss://" or
            parsed.protocol == "ssh://" or
            parsed.protocol == "ws://"
        then
            return parseWebUrl(parsed, url);
        else
            url = url:sub(#parsed.protocol + 1, #url);
            parsed.host = url:match("@?([^@]*)$") or "";
            parsed.origin = parsed.protocol .. parsed.host;
            url = url:sub(1, #url - #parsed.host);
            parsed.user = url:match("^([^:@]+)");
            parsed.pass = url:match("[:]([^@]+)[@]");
            return parsed;
        end
    end
    
    return {
        protocol = protocol,
        parse = parse,
    };
    
end)();


local bn = {}



--- bluenet handler function
-- should be run by redrun
function bn.run()
    _G._BN_Enabled = true
    if started then
        error("bluenet is already running", 2)
    end
    started = true
    while true do
        local event, modem, channel, reply_channel, message = os.pullEvent("modem_message")
        
        if channel == 0 then
            if type(message) == "table"
                and message.BLUENET
                and (message.host == tostring(os.getComputerID()) or (message.host == os.getComputerLabel()))
            then
                os.queueEvent("bluenet_message", message.origin, message.msg, message.protocol,message.user,message.pass)
            end
        end
    end
end

--- opens a bluenet connection
-- urls are to be layed out as protocol://hostname
-- a username and password can be put before the hostname
---@tparam string url
--@return BluenetConnection
function bn.open(url)
    local uri = urls.parse(url)

    --- a bluenet connection
    --@type BluenetConnection
    local connection = {}

    --- sends a bluenet message
    --- @tparam any msg
    function connection:send(msg)
        local packet = {
            BLUENET = true,
            protocol = uri.protocol,
            host = uri.host,
            origin = tostring(os.getComputerID()),
            msg = msg
        }
        if uri.user and uri.pass then
            packet.user = uri.user
            packet.pass = uri.pass
        end
        modem.transmit(0,0,packet)
    end

    --- receives a bluenet message
    ---@treturn any message
    function connection:receive()
        local event,origin,message,protocol
        while true do
            event,origin,message,protocol = os.pullEvent("bluenet_message")
            if origin == uri.host and protocol == uri.protocol then
                break
            end
        end
        return message
        
    end

    --- receives a bluenet message
    ---@treturn string username
    ---@treturn string password
    ---@treturn any message
    function connection:receiveWithAuth()
        local event,origin,message,protocol,usr,psw
        while true do
            event,origin,message,protocol,usr,psw = os.pullEvent("bluenet_message")
            if origin == uri.host and protocol == uri.protocol then
                break
            end
        end
        return usr,psw,message
        
    end
    return connection 
end

if not _G._BN_Enabled then
    redrun.start(bn.run,"bn")
end

return bn