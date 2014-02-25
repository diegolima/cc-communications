-- Initializes Available Network Devices
-- Tries to initialize any modem connected to the computer. Optionally
-- accepts a side as a parameter. If provided only that side will be
-- initialized.
--
-- Parameters: modemside (string)
function init(modemside)
  local i = 0
  local side = {}
  
  if modemside then
    side[0] = modemside
  else  
    side[0] = "top"
    side[1] = "bottom"
    side[2] = "left"
    side[3] = "right"
    side[4] = "front"
    side[5] = "back"
  end
  
  for i = 0, table.getn(side) do
    if peripheral.isPresent(side[i]) then
      if peripheral.getType(side[i]) == "modem" then
        if rednet.isOpen(side[i]) == false then
          rednet.open(side[i])
        end
      end
    end
  end
end

-- Encodes Data using base64
-- Useful for transmitting (not confidential) data while preserving special characters
-- Also might serve as a (mild) deterrent to non-tech-inclined people from listening in
-- and/or meddling with your communication channels
--
-- Parameters: data (string)
-- Returns: string (base64 encoded data)
function b64Encode(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- Decodes Data using base64
-- Useful for transmitting (not confidential) data while preserving special characters
-- Also might serve as a (mild) deterrent to non-tech-inclined people from listening in
-- and/or meddling with your communication channels
--
-- Parameters: data (b64 encoded string)
-- Returns: string (decoded data)
function b64Decode(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- TODO: Implement proper cryptography; For now this is just a wrapper around base64 encoding/decoding
function encrypt(data,key)
  local a = ccc.b64Encode(data)
  return a
end
function decrypt(data,key)
  local a = ccc.b64Decode(data)
  return a
end


-- Messaging
-- Messaging is accomplished using 4 types of message:
--   nfo: Generic informational message. Intended to carry data to be displayed on the remote terminal
--   req: Request for data. The target host should reply to this message. Usually the response will be a string.
--   cmd: Command. The target host should run the command locally and reply whether or not it had success.
--   rep: Reply to a request or command. Replies to requests are strings and replies to commands are booleans.
--
-- The first 3 characters of a message determine what kind of message it is, while the following characters are 
-- the message itself. So in order to send a nfo containing the message "Hello World" you would send the following
-- string: "nfoHello World"
--
-- You can either use the function sendMessage to send the messages or use the ccc.sendNfo, ccc.sendReq, ccc.sendCmd
-- and ccc.sendRep wrappers to make things easier.
--
-- Receiving messages is accomplished by calling the function receiveMessage. It can be used without arguments or you
-- can check for a specific message type and/or specific sender. You may also choose to decode/decrypt the received message.

-- Sends a message to the network
-- Parameters:
--   target: target computer. If 0, the message will be broadcast accross the network
--   message: the message to be transmitted
--   crypto: Default is to send in cleartext / 1 - base64 encode message / 2 - encrypt message using the given key
--   key: key used to encrypt messages; ignored if crypto is not set to 2
function sendMessage(target,message,crypto,key)
  if crypto == 1 then
    message = ccc.b64Encode(message)
  elseif crypto == 2 then
    message = ccc.encrypt(message,key)
  end

  if target then
    rednet.send(target,message)
  else
    rednet.broadcast(message)
  end
end

-- Wrappers
function sendNfo(target,message,crypto,key)
  message = "nfo" .. message
  ccc.sendMessage(target,message,crypto,key)
end
function sendReq(target,message,crypto,key)
  message = "req" .. message
  ccc.sendMessage(target,message,crypto,key)
end
function sendCmd(target,message,crypto,key)
  message = "cmd" .. message
  ccc.sendMessage(target,message,crypto,key)
end
function sendRep(target,message,crypto,key)
  message = "rep" .. message
  ccc.sendMessage(target,message,crypto,key)
end


function receiveMessage(sender,mType,crypto,key)
    local match = 0
    local senderId, message, distance, mType, rmType = nil

    while match ~= 2 do
      senderId, message, distance = rednet.receive()

      -- Break down the received message
      if crypto == 1 then
        rmType  = string.sub(dec(message),1,3)
        message = string.sub(dec(message),4)
      elseif crypto == 2 then
        rmType  = string.sub(decrypt(message,key),1,3)
        message = string.sub(decrypt(message,key),4)
      else
        rmType  = string.sub(message,1,3) 
        message = string.sub(message,4)
      end
      
      -- Apply message filters
      if mType then
        if rmType == mType then
          match = 1
        end
      else
        match = 1
      end
      if sender then
        if senderId == sender then
          match = match + 1
        end
      else
        match = match + 1
      end
    end
    return senderId,rmType,message,distance
end



-- Sample Usage:

-- os.loadAPI("ccc")
-- function main()
--   ccc.init()
--   ccc.sendNfo(nil, os.getComputerID() .. " is online" )
--   while true do
--     print("Waiting for new messages...")
--     senderId,mType,message,distance = ccc.receiveMessage()
--     if mType == "nfo" then
--       print("Info received: " .. senderId .. ": "  .. message )
--     elseif mType == "req" then
--       print("Request received: " .. senderId .. ": " .. message)
--     elseif mType == "rep" then
--       print("Reply received: " .. senderId .. ": " .. message)
--     elseif cmdType == "cmd" then
--       print("Command Received: " .. senderId .. ": " .. message)
--     end
--   end
-- end
-- main()
