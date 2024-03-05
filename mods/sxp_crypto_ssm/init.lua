-- changes to server side
-- in /words folder add/edit world.mt
--   load_mod_sxp_crypto_ssm = true
--   creative_mode = true
-- In minetest.conf add this mod to the list of secure.http_mods
--      secure.http_mods = sxp_crypto_ssm

-- Random Notes
-- to get list of all players that have registered
-- for player_name in minetest.get_authentication_handler().iterate() do
--end


local modname = assert(minetest.get_current_modname())

local player_channels = {} -- Mod Channel object for communication with CSM

-- request http access.
local http_api = minetest.request_http_api()
if not http_api then
    minetest.log("error", "ERROR in minetest.conf. Mod " .. modname .. " must be included in secure.http_mods section")
    print("ERROR in minetest.conf. Mod " .. modname .. " must be included in secure.http_mods section")
end



-- ====================================================================================
-- When player joins the server create a mod channel for communication with the Client Side Mod
-- The modchannel name is "crypto" .. the players name
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    player_channels[name] = minetest.mod_channel_join("crypto" .. name)
    local writeable = player_channels[name]:is_writeable()
end)

-- ====================================================================================
-- Cleanup Mod Channel memory when player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    player_channels[name]:leave()
    player_channels[name] = nil
end)

-- ====================================================================================
-- This callback handles all the received Mod Channel messages.
--
minetest.register_on_modchannel_message(function(channel_name, sender, message)
    -- ========================
    -- handler for Mod Channel = "crypto" .. playername
    local i, j = string.find(channel_name, "crypto")
    if (i == 1) then
        local length = string.len(channel_name)
        local y = string.sub(channel_name, 7, length)
        if (y ~= sender) then
            print("channel name does not match sender")
            return
        else
            local msg = minetest.deserialize(message) or {}
            if (msg.cmd and msg.msg) then
                --minetest.debug(modname .. " Received deserialized crypto message: " .. dump(msg))
                --minetest.debug(modname .. " command: " .. msg.cmd)
                -- minetest.debug(modname .. " message: " .. msg.msg)


                -- ========================
                -- Fetch wallet balance and nonce from blockchain and send response to client
                if (msg.cmd == "wallet") then
                    minetest.debug(modname .. " Fetching Solar Wallet")
                    http_api.fetch({
                        method = "GET",
                        --url = "https://api.solar.org/api/wallets/" .. msg.msg,
                        url = "https://tapi.solar.org/api/wallets/" .. msg.msg,
                        timeout = 4
                    }, function(res)
                        if res.code ~= 200 then
                            minetest.log("error", modname .. " Solar API server error. Message: " .. res.data)
                            return
                        end

                        local jsondata = minetest.parse_json(res.data) or {}
                        if (jsondata.data.balance and jsondata.data.nonce and jsondata.data.votingFor) then
                            local message = {}
                            message.msg = {}
                            message.cmd = "wallet"
                            message.msg.balance = jsondata.data.balance / 100000000
                            message.msg.nonce = tonumber(jsondata.data.nonce)
                            -- message.msg.votingFor = jsondata.data.votingFor
                            player_channels[sender]:send_all(minetest.serialize(message))
                            --minetest.debug(modname .. " Sending wallet Crypto msg: " .. dump(message))
                            return
                        else
                            minetest.log("error", modname .. " invalid JSON returned")
                            return
                        end
                    end)

                    -- ========================
                    -- Submit the received serialized transaction to the blockchain
                elseif (msg.cmd == "send_tx") then
                    local post_data = '{"transactions":[' .. msg.msg .. ']}'
                    --minetest.debug(modname .. " post data: " .. post_data)
                    minetest.debug(modname .. " Posting Solar Tx ")
                    http_api.fetch({
                        method = "POST",
                        --url = "https://api.solar.org/api/transactions",
                        url = "https://tapi.solar.org/api/transactions",
                        data = post_data,
                        --data = '{"transactions":[{"id":"ef598cfa88169d15c10d6273e160f76e9f5742cd7b1c62da8f6784c8d4d08e5c","version":3,"type":6,"typeGroup":1,"nonce":1,"asset":{"transfers":[{"amount":"100000000","recipientId":"SPqYhLcL8zVChSoC6hQb42ux2mbG2tctAV"}]},"fee":2500000,"senderPublicKey":"022bcee076006120b24f145d495686d2afc880079daf2eb20d8be9bf0e434ca3e1","memo":"Welcome to Solar!","signature":"5af30df0d5ae4dd01595688642ff2f296c6919fb6b3818fd8d003de3cc2a415fb6511fff59cad498cf572f0cc515a83150f402c276510406a885b8c643e855a4"}]}',
                        extra_headers = { "accept: */*", "Content-Type: application/json" },
                        timeout = 4
                    }, function(res)
                        local message = {}
                        message.cmd = "tx_response"
                        message.succeeded = false
                        message.msg = res.data
                        if (res.succeeded and res.code == 200) then
                            local jsondata = minetest.parse_json(res.data) or {}
                            --minetest.debug(modname .. " jsondata.data.accept: " .. dump(jsondata.data.accept[1]))
                            if (jsondata.data.accept[1] ~= nil) then
                                message.succeeded = true
                                player_channels[sender]:send_all(minetest.serialize(message))
                                --minetest.debug(modname .. " Sending tx_response msg: " .. res.data)
                                return
                            else
                                minetest.log("error", modname .. " Solar API server error. Message: " .. res.data)
                                player_channels[sender]:send_all(minetest.serialize(message))
                                return
                            end
                        else
                            minetest.log("error", modname .. " Solar API server error. Message: " .. res.data)
                            player_channels[sender]:send_all(minetest.serialize(message))
                            return
                        end
                    end)
                    return

                    -- ========================
                    -- fetch the status of the submitted transaction from the blockchain and send response to client
                elseif (msg.cmd == "confirm") then
                    minetest.debug(modname .. " Fetching Solar Transaction Confirmation")
                    http_api.fetch({
                        method = "GET",
                        --url = "https://api.solar.org/api/wallets/" .. msg.msg,
                        url = "https://tapi.solar.org/api/transactions/" .. msg.msg,
                        timeout = 4
                    }, function(res)
                        if res.code ~= 200 then
                            minetest.log("error", modname .. " Solar API server error. Message: " .. res.data)
                            return
                        end

                        local jsondata = minetest.parse_json(res.data) or {}
                        if (jsondata.data.confirmations) then
                            local message = {}
                            message.cmd = "tx_confirm"
                            message.msg = {}
                            message.msg.confirmations = jsondata.data.confirmations
                            message.msg.txid = jsondata.data.id
                            --print("tx confirmation",dump(message))
                            player_channels[sender]:send_all(minetest.serialize(message))
                            return
                        else
                            minetest.log("error", modname .. " invalid JSON returned")
                            return
                        end
                    end)

                    return
                end


                return
            else
                minetest.debug(modname .. " Received invalid crypto message: " .. dump(message))
                return
            end
        end
    end
end)


--minetest.register_globalstep(function(dtime)

--end)


-- ====================================================================================
-- Right Click on Another Player Event Handler
-- mods using right clicker
-- https://github.com/zeuner/structured_communication
-- https://github.com/runsy/pickp
-- Note: It did not work well to use the auxilary key in addtion to right clicking.  The Auxilary key remains pressed after the formspec is opened and the aux characters are inputted into text box.
minetest.register_on_rightclickplayer(function(player, clicker)
    local keys = clicker:get_player_control()
    --if keys.aux1 then -- 
    --minetest.chat_send_player(clicker:get_player_name(), "Right Clicked " .. tostring(player:get_player_name()))
    print(clicker:get_player_name(), "clicked on", player:get_player_name())
    local message = {}
    message.msg = {}
    message.cmd = "on_rightclickplayer"
    message.msg = player:get_player_name()
    player_channels[clicker:get_player_name()]:send_all(minetest.serialize(message))
    --   return
    --end
end)
