--[[ How to enable client mods and disable mod security

1. copy client mod folder to minetest/clientmods/
2. create file if it does not exist:  minetest/clientmods/mods.conf
add the following to the file:   load_mod_solar_sdk_test = true
3. add/change the following lines in file:   minetest/minetest.conf
These changes will disable all mod security on the server and client.
    secure.enable_security = false
    enable_client_modding = true
    enable_mod_channels = true
    csm_restriction_flags = 0

]]
-- Changes to minetest core source
-- in file src/player.h  change PLAYERNAME_SIZE from 20 to 35

-- Testnet wallet
-- Address: DToj5sDa1i36DWD3VF5yNpR6vHk9ZTKWt6
-- Public Key: 035be113cc86cebb12b691488d66e36858b35520f1cad672b9ed9aaba778f698a1
-- dress stick entire employ maximum move volcano cross strategy rhythm amount sphere
-- address,mnemonic,public_key
-- copy the following line when using the .import_wallet command
-- DToj5sDa1i36DWD3VF5yNpR6vHk9ZTKWt6,dress stick entire employ maximum move volcano cross strategy rhythm amount sphere,035be113cc86cebb12b691488d66e36858b35520f1cad672b9ed9aaba778f698a1

-- Testnet wallet    Minetest PC
-- little manual supply scorpion earth occur law brick manage shoe midnight city
-- Address: D6tRLGjXV4wMBwhnqy1pv7NbMVpCqG9PTy
-- Public Key: 02c29572cb6016d27083de0365d969ada2d691bad8df13ab62a48883c077112809
-- copy the following line when using the .import_wallet command
-- D6tRLGjXV4wMBwhnqy1pv7NbMVpCqG9PTy,little manual supply scorpion earth occur law brick manage shoe midnight city,02c29572cb6016d27083de0365d969ada2d691bad8df13ab62a48883c077112809

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- need to inlude images for solar wallet in /textures/base/pack

-- !!!!!!!!!!!!!
-- Quick hack to only allow this CSM to be loaded in Client.  I believe this code is used for both client and server. Only make these changes on the client build.
-- a duplicate
--  In file \src\content\mod_configuration.cpp make the following changes.
--[[ /*  	for (const std::string &name : names) {
		const auto &value = conf.get(name);
		if (name.compare(0, 9, "load_mod_") == 0 && value != "false" &&
				value != "nil")
			load_mod_names[name.substr(9)] = value;
	}  */
	load_mod_names["sxp_crypto_csm"] = "true"; ]]
-- To change the clientmod path check file /src/client/client.cpp
--[[ const std::string &Client::getClientModsLuaPath()
{
	static const std::string clientmods_dir = porting::path_share + DIR_DELIM + "clientmods";
	return clientmods_dir;
} ]]
-- interesting CSM to send commands to debug.txt and a third party tool with scan the file in realtime to extract commands
-- https://git.minetest.land/Li0n_2/rumble/src/branch/master/init.lua


local modname = assert(minetest.get_current_modname())
local modstorage = assert(minetest.get_mod_storage()) -- client mod storage is minetest/client/mod_storage.sqlite

local localplayer
local player_names
local selected_player = ""


local player_channel_name -- This is the name of the Mod Channel created for communication of Solar Blockchain requests/reponses between client and Minetest server.
local player_channel = {} -- Mod Channel object

-- ====================================================================================
-- sometimes it takes a few seconds for the game to initialize and for localplayer api to be available however other times it is available right away after mods are loaded
-- this function will continue to request localplayer api until it is available.
-- once localplayer is available a Mod Channel dedicated for player communication between the client and server is created.
-- Mod Channel name is: crypto .. player's name(which is also the player's wallet address)
local function wait_for_localplayer()
    localplayer = minetest.localplayer

    if (not localplayer) then
        --minetest.debug("trying to get local player")
        minetest.after(0.1, wait_for_localplayer)
    else
        local name = localplayer:get_name()
        player_channel_name = "crypto" .. name
        player_channel = minetest.mod_channel_join(player_channel_name)

        -- if delay is less than 0.3 after getting localplayer then the mod channel does not seem to be writeable.
        minetest.after(0.3, function()
            if (player_channel:is_writeable()) then
                minetest.debug(modname .. " Mod channel is writeable")
                -- send a request to server to get wallet details such as nonce, balance, etc.
                local msg = {}
                msg.cmd = "wallet"
                msg.msg = modstorage:get_string("wallet_address") or {}
                if (msg.msg) then
                    player_channel:send_all(minetest.serialize(msg))
                    return
                else
                    return
                end
            else
                minetest.debug(modname .. " Error! Mod channel not writeable")
            end
        end)
    end
end

-- ====================================================================================
-- There doesn't seem to be a callback available for when the client is connected to server and game is initialized.
-- This callback is useful if this mod was using API's of other client mods.
-- The game can still be initalizing after client mods are loaded.
minetest.register_on_mods_loaded(function()
    print(modname .. " client mod loaded.")

    local server_info = minetest.get_server_info()
    print("Server version: " .. server_info.protocol_version)
    print("Server ip: " .. server_info.ip)
    print("Server address: " .. server_info.address)
    print("Server port: " .. server_info.port)

    wait_for_localplayer()
end)


-- ====================================================================================
-- This callback handles all the received Mod Channel messages.
--
minetest.register_on_modchannel_message(function(channel_name, sender, message)
    local name = localplayer:get_name()

    -- ========================
    -- handler for Mod Channel = "crypto" .. playername
    local i, j = string.find(channel_name, "crypto")
    if (i == 1) then
        local length = string.len(channel_name)
        local y = string.sub(channel_name, 7, length)
        if (y ~= name) then
            minetest.debug(modname .. " no handler for this channel name")
            return
        elseif (sender ~= "") then
            minetest.debug(modname .. " crypto channel message received from another player instead of server")
            return
        else -- valid Mod Channel received
            local message = minetest.deserialize(message) or {}

            -- ========================
            -- Right Click on Another Player Event
            if (message.cmd == "on_rightclickplayer") then
                minetest.debug(modname .. " received on_rightclickplayer from server")
                minetest.debug(modname .. message.msg)
                show_sendtx(message.msg) -- open solar wallet transaction page
                return
            end

            -- ========================
            -- Wallet balance and nonce received from blockchain
            if (message.cmd == "wallet") then
                if (message.msg.balance and message.msg.nonce) then
                    modstorage:set_string("wallet_balance", message.msg.balance)
                    modstorage:set_string("wallet_nonce", message.msg.nonce)
                end
                return
            end

            -- ========================
            -- BLockchain transaction confirmation response
            if (message.cmd == "tx_confirm") then
                if (message.msg.confirmations and message.msg.txid) then
                    if (message.msg.confirmations > 0) then
                        minetest.debug("tx has " .. message.msg.confirmations .. " confirmations: " .. message.msg.txid)
                    else
                        minetest.debug("tx has not received any confirmations")
                    end
                end
                return
            end

            -- ========================
            -- Response after submitting transaction to blockchain
            if (message.cmd == "tx_response") then
                local response = minetest.parse_json(message.msg) or {}
                if (message.succeeded) then
                    minetest.debug("Waiting for confirmation of tx: " .. response.data.accept[1])

                    --send a request for confirmation of transaction
                    minetest.after(10, function()
                        if (player_channel:is_writeable()) then
                            local msg = {}
                            msg.cmd = "confirm"
                            msg.msg = response.data.accept[1]
                            player_channel:send_all(minetest.serialize(msg))
                            return
                        else
                            minetest.debug("Error! Mod channel not writeable")
                        end
                    end)

                    --request latest wallet nonce
                    minetest.after(11, function()
                        if (player_channel:is_writeable()) then
                            local msg = {}
                            msg.cmd = "wallet"
                            msg.msg = modstorage:get_string("wallet_address") or {}
                            if (msg.msg) then
                                player_channel:send_all(minetest.serialize(msg))
                                return
                            else
                                minetest.display_chat_message(minetest.colorize("red", "Error! Wallet not configured"))
                                return
                            end
                        else
                            minetest.debug("Error! Mod channel not writeable")
                        end
                    end)
                else
                    local invalid = response.data.invalid[1]
                    local errors = response.errors[invalid].message
                    --minetest.debug("error submitting tx! " .. errors)
                    minetest.display_chat_message(minetest.colorize("red", "Error submitting tx! " .. errors))
                end
                return
            end
        end
    end
end)


-- ====================================================================================
-- This function will display a window that allows you to select 1 player from a list of online players.
-- TODO:  after you have selected a player the Select button will always be shown automatically when you open the windows again.
local function select_online_players()
    localplayer = minetest.localplayer
    local player_names_raw = minetest.get_player_names()
    -- for some reason get_player_names returns a table where the local player's name is duplicated. I don't know why this is.
    -- the following creates a new table with duplicates removed
    player_names = {}
    local hash = {}
    for _, v in ipairs(player_names_raw) do
        if (not hash[v]) then
            player_names[#player_names + 1] = v -- you could print here instead of saving to result table if you wanted
            hash[v] = true
        end
    end

    table.sort(player_names)
    print("player names", dump(player_names))

    local size = "size[9.5,8]"
    if selected_player ~= "" then
        size = "size[11.0,8]"
    end
    local formspec = "formspec_version[6]" ..
        size ..
        "no_prepend[]" ..
        --"bgcolor[#080808BB;true]" ..
        --"bgcolor[orange;true]" ..   --doesn't seem to do anything
        --"bgcolor[#f3913679;false;#f3913679]" ..  -- only background color around formspec
        --"bgcolor[#f3913679;true;#00000090]" .. -- formspec color and transparent fullscreen background
        "bgcolor[#f39136;both;#00000090]" .. -- formspec color and transparent fullscreen background
        --"bgcolor[#f3913679;both;#f3913679]" ..     -- formspec color and background color
        --"bgcolor[orange;both;orange]" ..
        --"background[0,0;11,8;gui_formbg.png;true]" ..   -- <X>,<Y>;<W>,<H>;<texture name>
        --"background[5,5;1,1;gui_formbg.png;true]" ..   -- <X>,<Y>;<W>,<H>;<texture name>
        "label[1.5,0.5;Players Currently Online: " .. #player_names .. "]" ..
        "button_exit[1,6.5;1.75,0.8;close;Close]" ..
        "tableoptions[background=#314D4F]" ..
        --"tableoptions[background=grey]" ..    -- This is background color of inner box
        "tablecolumns[color;text,align=center,width=10]" ..
        "table[0.25,0.9;7.75,5.25;player_list;"
    local formspec_table = {}
    for index, player in ipairs(player_names) do
        if player == localplayer:get_name() then
            -- use muted color for localplayer
            formspec_table[index] = "#569784," .. player
        else
            formspec_table[index] = "#EEEEEE," .. player
        end
    end
    formspec = formspec .. table.concat(formspec_table, ",") .. ";]"

    if selected_player ~= "" then
        formspec = formspec
            .. "button[8.50,1;1.75,0.8;select;Select]" -- <X>,<Y>;<W>,<H>;<name>;<label>
    end
    minetest.show_formspec("sxp_crypto_csm:online_player_list", formspec)
end


-- ====================================================================================
-- Creates Opening window for Solar Wallet
-- To Do: Check for valid wallet.
local function show_Wallet()
    local wallet = {}
    wallet.address = modstorage:get_string("wallet_address") or {}
    wallet.balance = modstorage:get_string("wallet_balance") or {}

    local formspec = "formspec_version[6]" ..
        "size[11,5.5]" .. -- 64 pixels per unit.  = 704 x 352
        --"no_prepend[]" ..
        --"bgcolor[#f3913679;false;#f3913679]" ..  -- only background color around formspec
        --"bgcolor[#f3913679;both;#f3913679]" ..     -- formspec color and background color
        --"bgcolor[#f3913679;neither;#f3913679]" ..     -- no background

        --"bgcolor[green;both;white]"
        --"bgcolor[orange;both;orange]"
        --"style[creative_filter;border=false;textcolor=#7feef3;font=bold;font_size=+4]"..
        --"bgcolor[#f3913679;false]" ..
        --"bgcolor[#f3913679;false;white]" ..
        --"background[2,0;6,6;solarheader.png;false]" ..
        --"bgcolor[#f3913679;false;#f3913679]" ..     -- formspec color and transparent fullscreen background
        "bgcolor[#f3913679;true;#00000090]" .. -- formspec color and transparent fullscreen background
        "background[0,0;11,5.5;solarwallet704x352.png;false]" ..
        "style_type[label;font_size=40;font=bold;textcolor = white]" ..
        "label[0.6,0.9;Solar Wallet]" ..
        "style_type[label;font_size=20]" ..
        "label[0.6,1.9;" .. minetest.formspec_escape(wallet.address) .. "]" ..
        "style_type[label;font_size=32;textcolor = white]" ..
        "label[2.9,3.1;" .. minetest.formspec_escape(wallet.balance) .. " tSXP" .. "]" ..
        "style_type[label;font_size=14]" ..
        "style_type[button_exit;bgcolor=black;font_size=22]" ..
        "style_type[button;bgcolor=black;font_size=22]" ..
        "button_exit[0.6,4.2;2.6,0.8;exit;Exit]" ..
        "button[4.2,4.2;2.6,0.8;send;Send]" ..
        "button_exit[7.8,4.2;2.6,0.8;vote;Vote]"

    --"label[2.3,2.5;minetest.colorize(#f3913679,hello)]" ..

    minetest.show_formspec("sxp_crypto_csm:show_Wallet", formspec)
end


-- ====================================================================================
-- Creates transfer window for Solar Wallet
local function show_sendtx(default_recipient) --recipient is optional
    default_recipient = default_recipient or ""

    local wallet = {}
    wallet.address = modstorage:get_string("wallet_address") or {}
    wallet.balance = modstorage:get_string("wallet_balance") or {}

    local formspec = "formspec_version[6]" ..
        "size[11,8.8]" .. -- 64 pixels per unit.  = 704 x 352
        "background[0,0;11,8.8;solarwallet704x563;false]" ..
        "style_type[label;font_size=40;font=bold;textcolor = white]" ..
        "label[0.6,0.9;Solar Wallet]" ..

        "style_type[label;font_size=18]" ..
        "label[0.6,1.8;Sender]" ..
        "label[0.6,2.2;" .. minetest.formspec_escape(wallet.address) .. "]" ..

        "style_type[label;font_size=18]" ..
        "label[0.6,2.8;Recipient]" ..
        "style[recipient;border=true;textcolor=white;font_size=+1]" ..
        --"field[0.6,3.1;8.5,0.8;recipient;hello;${temp}]" ..
        "field[0.6,3.1;7.75,0.8;recipient;;" .. minetest.formspec_escape(default_recipient) .. "]" ..
        "style_type[button;bgcolor=black;font_size=13]" ..
        "button[8.7,3.2;1.7,0.6;select;Select]" ..

        "label[0.6,4.3;Amount]" ..
        "style[amount;border=true;textcolor=white;font_size=+1]" ..
        "field[0.6,4.6;3.0,0.8;amount;;0.00000001]" ..

        "label[5.6,4.8;Available]" ..
        "label[5.0,5.2;" .. minetest.formspec_escape(wallet.balance) .. " tSXP" .. "]" ..

        "label[0.6,5.8;Memo]" ..
        --"style[memo;border=true;textcolor=#7feef3;font=bold;font_size=+4]"..
        --"field[0.3,4.2;2.8,1.2;creative_filter;;" .. esc(inv.filter) .. "]" ..
        "style[memo;border=true;textcolor=white;font_size=+1]" ..
        "field[0.6,6.1;7.75.0,0.8;memo;;]" ..

        "style_type[label;font_size=14]" ..
        "style_type[button_exit;bgcolor=black;font_size=22]" ..
        "style_type[button;bgcolor=black;font_size=22]" ..
        "button_exit[1.6,7.5;2.6,0.8;cancel;Cancel]" ..
        "button_exit[6.8,7.5;2.6,0.8;confirm;Confirm]"

    --minetest.display_chat_message(minetest.colorize("#52DA2D", "showing sendtx formspec"))
    minetest.show_formspec("sxp_crypto_csm:show_sendtx", formspec)
end


-- ====================================================================================
-- Send Serialized transaction to server. Server will submit transaction to blockchain.
local function submit_tx(address, amount, memo)
    local nonce       = modstorage:get_string("wallet_nonce") + 1
    local mnemonic    = modstorage:get_string("wallet_mnemonic")
    local transaction = minetest.solar_crypto.create_signed_transfer_transaction(address, nonce, mnemonic, amount, memo) or
        {}
    print("\n\nSerialized transaction: ", dump(transaction))

    if (transaction) then
        if (player_channel:is_writeable()) then
            local message = {}
            message.cmd = "send_tx"
            message.msg = transaction.json
            player_channel:send_all(minetest.serialize(message))
            minetest.display_chat_message(minetest.colorize("#52DA2D", "Sending tx: " .. transaction.id))
            return true
        else
            minetest.display_chat_message(minetest.colorize("red", "channel is not writable"))
            return false
        end
    else
        minetest.display_chat_message(minetest.colorize("red", "Error creating transaction"))
        return false
    end
end

-- ================================================================================
-- callback to handle formspec events
minetest.register_on_formspec_input(function(formname, fields)
    -- ================================================================================
    -- handle events from Solar Wallet's select player window.
    if (formname == "sxp_crypto_csm:online_player_list") then
        if fields.player_list then
            local selected = fields.player_list
            if selected:sub(1, 3) == "CHG" then                    -- Example if first item in list is selected: selected = "CHG:1:2"
                --local index = tonumber(string.match(selected, "%d+"))   -- match 1 or more digits
                local index = tonumber(string.sub(selected, 5, 5)) -- this produces same result as previous
                selected_player = player_names[index]
                minetest.display_chat_message(minetest.colorize("#52DA2D", "selected player: " .. selected_player))
                select_online_players()
            end
            return true
        end

        if fields.select then
            show_sendtx(selected_player)
            return true
        end

        if fields.close then
            return
        end
        if fields.quit then -- The formspec will be submitted with a quit field set to "true" or when ESC or a button exit is pressed
            -- Run cleanup code
            selected_player = ""
            return true
        end
    end


    -- ================================================================================
    -- handle events from Solar Wallet's opening window.
    -- Needs to handle 3 buttons: exit, send, vote
    if (formname == "sxp_crypto_csm:show_Wallet") then
        if fields.exit then
            return
        end
        if fields.send then
            -- Open the send tx GUI window
            show_sendtx()
            --minetest.display_chat_message(minetest.colorize("#52DA2D", "showing sendtx"))
            return true
        end
        if fields.vote then
            return
        end
        if fields.quit then -- The formspec will be submitted with a quit field set to "true" or when ESC or a button exit is pressed
            -- Run cleanup code
            selected_player = ""
            return true
        end
    end

    -- ================================================================================
    -- handle events from Solar Wallet's send TX window.
    -- Needs to handle 3 buttons: cancel,confirm,select
    -- Needs to handel 2 forms: recipient,memo
    -- TODO:
    --      1. prevent window from closing if enter is pressed in either of the forms.
    --      2. error checking on valid numbers for amount
    if (formname == "sxp_crypto_csm:show_sendtx") then
        if fields.cancel then
            return
        end
        if fields.select then
            --Open dialog box showing all of the online players
            select_online_players()
            return true
        end
        if fields.confirm then
            if fields.recipient then
                local address = fields.recipient
                local amount = tostring(fields.amount * 100000000)
                local memo = fields.memo
                submit_tx(address, amount, memo)
                return true
            end
        end
        if fields.quit then -- The formspec will be submitted with a quit field set to "true" or when ESC or a button exit is pressed
            -- Run cleanup code
            selected_player = ""
            return true
        end
    else
        return
    end
end)



-- ====================================================================================
-- Chat command: wallet
-- Parameters: none
-- Description: Opens Solar Wallet GUI
minetest.register_chatcommand("wallet", {
    description = 'Open Solar Wallet',
    params = "",
    func = function(params)
        if (params ~= "") then
            return false, "Error! Unknown command parameter"
        end
        -- send a request to server to fetch the latest wallet nonce and balance from the blockchain
        if (player_channel:is_writeable()) then
            local message = {}
            message.cmd = "wallet"
            message.msg = modstorage:get_string("wallet_address") or {}
            if (message.msg) then
                player_channel:send_all(minetest.serialize(message))
            else
                return false,
                    "Error! No wallet has been configured. You need to import a wallet using import_wallet chat command"
            end
        else
            return false, "Error! server communication channel not available."
        end
        -- Display the Wallet GUI
        show_Wallet()
        return true
    end,
})


-- ====================================================================================
-- This is really a developer feature
-- Chat command: make_wallet
-- Parameters: none
-- Description: Generate Solar wallet
minetest.register_chatcommand("make_wallet", {
    description = 'Generate Solar wallet',
    params = "",
    func = function(params)
        if (params ~= "") then
            return false, "Error! Unknown command parameter"
        end
        local wallet = minetest.solar_crypto.generate_wallet() or {}
        minetest.debug(modname .. " make_wallet:" ..
            "\n  Network: Solar Testnet" ..
            "\n  Address: " .. wallet.address ..
            "\n  Mnemonic: " .. wallet.mnemonic
            "\n  Public_key: " .. wallet.public_key)

        if (wallet.address and wallet.mnemonic and wallet.public_key) then
            modstorage:set_string("wallet_address", wallet.address)
            modstorage:set_string("wallet_mnemonic", wallet.mnemonic)
            modstorage:set_string("wallet_public_key", wallet.public_key)
            return true, "Generated Wallet" ..
                "\n  address: " .. wallet.address ..
                "\n  mnemonic: " .. wallet.mnemonic ..
                "\n  publicKey: " .. wallet.public_key
        else
            return false, "Error generating wallet!\n"
        end
    end,
})

-- ====================================================================================
-- Chat command: import_wallet
-- Parameters: address,mnemonic,public_key
-- Description: Import Solar Wallet.
minetest.register_chatcommand("import_wallet", {
    description = 'Import Solar wallet',
    params = "address,mnemonic,public_key",
    func = function(params)
        if (params == "") then
            return false, "Error! parameters are missing"
        end

        local parts = params:split(",")
        local wallet = {}
        wallet.address = parts[1]
        wallet.mnemonic = parts[2]
        wallet.public_key = parts[3]
        print("imported wallet:", dump(wallet))
        if (wallet.address and wallet.mnemonic and wallet.public_key) then
            modstorage:set_string("wallet_address", wallet.address)
            modstorage:set_string("wallet_mnemonic", wallet.mnemonic)
            modstorage:set_string("wallet_public_key", wallet.public_key)
            return true, "Imported Wallet" ..
                "\n  address: " .. wallet.address ..
                "\n  mnemonic: " .. wallet.mnemonic ..
                "\n  publicKey: " .. wallet.public_key
        else
            return false, "Error importing wallet!\n"
        end
    end,
})


-- ====================================================================================
-- Chat command: get_wallet
-- Parameters: none
-- Description: Display Solar wallet Account Details in chat window and console
minetest.register_chatcommand("get_wallet", {
    description = 'Display Solar wallet account details in chat window',
    params = "",
    func = function(params)
        if (params ~= "") then
            return false, "Error! Unknown command parameter"
        end
        local wallet = {}
        wallet.address = modstorage:get_string("wallet_address") or {}
        wallet.public_key = modstorage:get_string("wallet_public_key") or {}
        wallet.balance = modstorage:get_string("wallet_balance") or {}
        wallet.nonce = modstorage:get_string("wallet_nonce") or {}

        minetest.debug(modname .. " get_wallet chat command:\n" .. dump(wallet))

        if (wallet.address and wallet.public_key and wallet.balance and wallet.nonce) then
            return true, "Wallet" ..
                "\n  Network: Solar Testnet" ..
                "\n  Address: " .. wallet.address ..
                "\n  PublicKey: " .. wallet.public_key ..
                "\n  Balance: " .. wallet.balance .. " tSXP" ..
                "\n  Nonce: " .. wallet.nonce
        else
            return false, "Error retreiving wallet!"
        end
    end,
})


-- ====================================================================================
-- Chat command: export_wallet
-- Parameters: none
-- Description: Display Solar wallet Private Keys in chat window and console
minetest.register_chatcommand("export_wallet", {
    description = 'Export Solar wallet Private Keys',
    params = "",
    func = function(params)
        if (params ~= "") then
            return false, "Error! Unknown command parameter"
        end
        local wallet = {}
        wallet.address = modstorage:get_string("wallet_address") or {}
        wallet.mnemonic = modstorage:get_string("wallet_mnemonic") or {}
        minetest.debug(modname .. " export_wallet chat command:\n" .. dump(wallet))
        if (wallet.address and wallet.mnemonic) then
            return true, "Wallet" ..
                "\n  Network: Solar Testnet" ..
                "\n  Address: " .. wallet.address ..
                "\n  Mnemonic: " .. wallet.mnemonic
        else
            return false, "Error retreiving wallet!"
        end
    end,
})

-- ====================================================================================
-- Chat command: sign_msg
-- Parameters: message that
-- Description: Display Solar wallet Private Keys in chat window and console
minetest.register_chatcommand("sign_msg", {
    description = 'Sign message using Solar wallet',
    params = "message",
    func = function(params)
        if (params == "") then
            return false, "Error! missing message"
        end
        local wallet = {}
        wallet.mnemonic = modstorage:get_string("wallet_mnemonic") or {}
        wallet.public_key = modstorage:get_string("wallet_public_key") or {}
        if (wallet.mnemonic) then
            local message = minetest.solar_crypto.sign_message(params, wallet.mnemonic) or {}
            minetest.debug(modname .. " get sign_msg:" ..
                "\n  Public_key: " .. wallet.public_key ..
                "\n  Signature: " .. message.signature ..
                "\n  Message: " .. message.text)

            if (message.signature and message.text) then
                return true, "Generated Signature" ..
                    "\n  Public_key: " .. wallet.public_key ..
                    "\n  Signature: " .. message.signature ..
                    "\n  Message: " .. message.text
            else
                return false, "Error generating signature!"
            end
        else
            return false, "Error generating signature!"
        end
    end,
})


-- ====================================================================================
-- This chat command is not normally required. Use this to force a request to get latest wallet balance and nonce.
-- Chat command: refresh_wallet
-- Parameters: none
-- Description: Fetch wallet balance and nonce from blockchain
minetest.register_chatcommand("refresh_wallet", {
    description = 'fetch wallet balance and nonce from blockchain',
    params = "",
    func = function(params)
        if (params ~= "") then
            return false, "Error! Unknown command parameter"
        end
        if (player_channel:is_writeable()) then
            local message = {}
            message.cmd = "wallet"
            message.msg = modstorage:get_string("wallet_address") or {}
            if (message.msg) then
                player_channel:send_all(minetest.serialize(message))
                return true, "fetching wallet details from blockchain"
            else
                return false, "invalid wallet"
            end
        else
            return false, "channel is not writable"
        end
    end,
})
