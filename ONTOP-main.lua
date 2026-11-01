--!nocheck
-- OXIRO V5 — full assembly
-- Delta / Mobile. Key: hello
-- Architecture: multi-mechanism void v2 (resume + cooldown), tick-aligned RB correction,
-- per-weapon contract lock, silent command layer, extended chat commands, anti-scripter suite.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TextChatService   = game:GetService("TextChatService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")

local Player   = Players.LocalPlayer
local MAX_ATTEMPTS = 3
local CORRECT_KEY  = "hello"
local attempts = 0

local immunePlayers = {}

-- =========================================================
-- HELPERS
-- =========================================================
local function getHRP(p)
    p = p or Player
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function getHum(p)
    p = p or Player
    return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
local function isProtected(t)
    if not t then return false end
    if type(t) == "string" then
        for p, s in pairs(immunePlayers) do
            if s and (p.Name == t or p.DisplayName == t) then return true end
        end
    elseif typeof(t) == "Instance" then
        if t:IsA("Player") then return immunePlayers[t] == true
        elseif t:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(t)
            return p and immunePlayers[p] == true
        end
    end
    return false
end
local function isPlayerSafe(p) return isProtected(p) end
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
    end)
end
local function findPlayerByFuzzy(str)
    if not str or str == "" then return nil end
    str = str:lower():gsub("@", "")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.DisplayName:lower():find(str, 1, true) or plr.Name:lower():find(str, 1, true) then
            return plr
        end
    end
    return nil
end
local function sayChat(text)
    pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if ev and ev:FindFirstChild("SayMessageRequest") then
            ev.SayMessageRequest:FireServer(text, "All")
        end
    end)
end

-- namecall guard: protects immunes from FireServer/InvokeServer args matching them
pcall(function()
    local gmt = getrawmetatable(game)
    local oldNamecall = gmt.__namecall
    setreadonly(gmt, false)
    gmt.__namecall = newcclosure(function(self, ...)
        local meth = getnamecallmethod()
        if meth == "FireServer" or meth == "InvokeServer" then
            local args = {...}
            for p, s in pairs(immunePlayers) do
                if s and p then
                    for _, a in pairs(args) do
                        if a == p or a == p.Character then return nil end
                        if type(a) == "string" and (a == p.Name or a == p.DisplayName) then return nil end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(gmt, true)
end)

-- =========================================================
-- KEY GATE UI
-- =========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OXIROGATE"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
MainFrame.Position = UDim2.new(0.5, -185, 0.5, -125)
MainFrame.Size = UDim2.new(0, 370, 0, 250)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

local OuterStroke = Instance.new("UIStroke", MainFrame)
OuterStroke.Color = Color3.fromRGB(60, 220, 255)
OuterStroke.Thickness = 3
TweenService:Create(OuterStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Color = Color3.fromRGB(140, 240, 255), Thickness = 5}):Play()

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 18)
Title.Size = UDim2.new(1, 0, 0, 55)
Title.Font = Enum.Font.GothamBold
Title.Text = "OXIRO GATE"
Title.TextColor3 = Color3.fromRGB(80, 240, 255)
Title.TextSize = 36

local SubTitle = Instance.new("TextLabel")
SubTitle.Parent = MainFrame
SubTitle.BackgroundTransparency = 1
SubTitle.Position = UDim2.new(0, 0, 0, 70)
SubTitle.Size = UDim2.new(1, 0, 0, 22)
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.Text = "SECURITY VERIFICATION"
SubTitle.TextColor3 = Color3.fromRGB(160, 200, 220)
SubTitle.TextSize = 13

local KeyBox = Instance.new("TextBox")
KeyBox.Parent = MainFrame
KeyBox.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
KeyBox.Position = UDim2.new(0.07, 0, 0, 100)
KeyBox.Size = UDim2.new(0.86, 0, 0, 50)
KeyBox.Font = Enum.Font.Gotham
KeyBox.PlaceholderText = "Enter access key..."
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(220, 250, 255)
KeyBox.TextSize = 16
Instance.new("UICorner", KeyBox).CornerRadius = UDim.new(0, 10)

local SubmitBtn = Instance.new("TextButton")
SubmitBtn.Parent = MainFrame
SubmitBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 200)
SubmitBtn.Position = UDim2.new(0.18, 0, 0, 165)
SubmitBtn.Size = UDim2.new(0.64, 0, 0, 45)
SubmitBtn.Font = Enum.Font.GothamBold
SubmitBtn.Text = "VERIFY"
SubmitBtn.TextColor3 = Color3.fromRGB(240, 255, 255)
SubmitBtn.TextSize = 17
Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 10)

local Status = Instance.new("TextLabel")
Status.Parent = MainFrame
Status.BackgroundTransparency = 1
Status.Position = UDim2.new(0, 0, 0, 218)
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Font = Enum.Font.GothamMedium
Status.Text = ""
Status.TextColor3 = Color3.fromRGB(255, 90, 90)
Status.TextSize = 12

-- =========================================================
-- MAIN
-- =========================================================
local function runMainScript()
    ScreenGui:Destroy()

    local OWNER_USERNAME = "Markarenoob"
    local isOwner = Player.Name == OWNER_USERNAME

    -- state
    local mode = "idle"
    local attackTarget = nil
    local savedTargetUserId = nil
    local HITBOX_SIZE = 100
    local BLOCK_ENABLED = true
    local UNLIMITED_M1_ENABLED = true
    local M2_SPAM_ENABLED = true
    local NOCLIP_ENABLED = false
    local AUTO_EQUIP_ENABLED = false
    local SPEEDWALK_ENABLED = false
    local SPEEDWALK_SPEED = 90
    local VOID_MODE_ENABLED = false
    local HVH_MODE = false
    local HVH_TARGET_USERID = nil
    local HVH_VOID = false
    local HVH_NOCLIP = false
    local isVoiding = false
    local isSpammingM2 = false
    local isChasing = false
    local chaseTarget = nil
    local chaseConnection = nil
    local noclipConnection = nil
    local blockConnection = nil
    local rbConnection = nil
    local speedConnection = nil
    local playerButtons = {}
    local currentTab = "target"
    local PREDICTION_MULT = 1.0
    local PREDICTION_BASE = 0.2
    local CHASE_DISTANCE = 3.5
    local FALL_SPEED = -3500
    local FALL_CHECK_Y = -4900
    local ATTACK_RESET_INTERVAL = 4
    local VOID_COOLDOWN_UNTIL = 0
    local RESUME_DELAY = 0.15
    local preVoidCFrame = nil
    local lastGoodCFrame = nil
    local rbSuppress = false
    local immuneScrollRefresh = nil

    -- remote cache
    local cachedRemotes = nil
    local function getRemotes()
        if cachedRemotes then return cachedRemotes end
        cachedRemotes = {}
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                table.insert(cachedRemotes, d)
            end
        end
        return cachedRemotes
    end
    local function findRemotes(pattern)
        local out = {}
        local p = pattern:lower()
        for _, r in ipairs(getRemotes()) do
            if r.Name:lower():find(p, 1, true) then table.insert(out, r) end
        end
        return out
    end
    local function findRemoteExact(name)
        for _, r in ipairs(getRemotes()) do
            if r.Name == name then return r end
        end
        return nil
    end

    -- weapon contract
    local EQUIP_LIST = {"Katana", "Short sword", "Bat", "Axe", "Swarm Controller", "Pickaxe"}
    local weaponContract = {}
    local function probeWeapon(name)
        if weaponContract[name] ~= nil then return weaponContract[name] end
        local rem = findRemoteExact("EquippingRemote")
        if not rem then weaponContract[name] = false; return false end
        local candidates = {
            name, name:lower(), name:gsub("%s", ""), name:gsub("%s", "_"),
            name:gsub("%s", ""):lower(),
        }
        for _, arg in ipairs(candidates) do
            if rem:IsA("RemoteFunction") then
                local ok, res = pcall(function() return rem:InvokeServer(arg) end)
                if ok and res ~= nil and res ~= false then
                    weaponContract[name] = arg; return arg
                end
            else
                pcall(function() rem:FireServer(arg) end)
                weaponContract[name] = arg; return arg
            end
        end
        weaponContract[name] = false
        return false
    end
    local function equipWeapon(name)
        local arg = probeWeapon(name)
        if arg then
            local rem = findRemoteExact("EquippingRemote")
            if rem and rem:IsA("RemoteEvent") then
                pcall(function() rem:FireServer(arg) end)
            end
            notify("EQUIP", "Fired " .. name .. " [" .. tostring(arg) .. "]")
        else
            local bp = Player:FindFirstChild("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and t.Name:lower():find(name:lower(), 1, true) then
                        local hum = getHum()
                        if hum then hum:EquipTool(t) end
                        notify("EQUIP", "Backpack: " .. t.Name)
                        return
                    end
                end
            end
            notify("EQUIP", "No contract for " .. name)
        end
    end
    local function autoEquip()
        local c = Player.Character
        if not c or c:FindFirstChildOfClass("Tool") then return end
        local bp = Player:FindFirstChild("Backpack")
        if not bp then return end
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local hum = getHum()
                if hum then pcall(function() hum:EquipTool(t) end) end
                return
            end
        end
        for _, w in ipairs(EQUIP_LIST) do
            if probeWeapon(w) then equipWeapon(w); return end
        end
    end

    -- NOCLIP
    local function setNoclip(enabled)
        NOCLIP_ENABLED = enabled
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        if enabled then
            noclipConnection = RunService.Stepped:Connect(function()
                local c = Player.Character
                if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end)
        end
    end

    -- CHASE
    local function stopChase()
        isChasing = false
        chaseTarget = nil
        if chaseConnection then chaseConnection:Disconnect(); chaseConnection = nil end
        local c = Player.Character
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = true end
            end
        end
    end
    local function startChase(target)
        if chaseConnection then chaseConnection:Disconnect() end
        chaseTarget = target
        isChasing = true
        chaseConnection = RunService.RenderStepped:Connect(function()
            if isVoiding then return end
            if not isChasing or not chaseTarget or not chaseTarget.Character then stopChase(); return end
            local myHRP = getHRP(Player)
            local tHRP = getHRP(chaseTarget)
            if not myHRP or not tHRP then stopChase(); return end
            local c = Player.Character
            if c then
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
            local pred = PREDICTION_BASE * PREDICTION_MULT
            local predictedPos = tHRP.Position + (tHRP.Velocity * pred)
            local look = tHRP.CFrame.LookVector
            local desired = predictedPos - (look * CHASE_DISTANCE) + Vector3.new(0, 1, 0)
            if (desired - myHRP.Position).Magnitude > 1 then
                myHRP.CFrame = CFrame.new(desired, tHRP.Position)
                myHRP.Velocity = Vector3.zero
                myHRP.RotVelocity = Vector3.zero
            else
                myHRP.Velocity = tHRP.Velocity
            end
        end)
    end

    -- RESUME
    local function resumeToTarget(target)
        if not target or not target.Character then return end
        local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end
        local myHRP = getHRP(Player)
        if not myHRP then return end
        local pred = PREDICTION_BASE * PREDICTION_MULT
        local dest = tHRP.Position + tHRP.Velocity * pred + Vector3.new(0, 2, 0)
        myHRP.CFrame = CFrame.new(dest, tHRP.Position)
        myHRP.Velocity = Vector3.zero
        myHRP.AssemblyLinearVelocity = Vector3.zero
        if not isChasing then startChase(target) end
    end

    -- VOID v2
    local function goVoid(target)
        if isVoiding or not VOID_MODE_ENABLED then return end
        if not target or not target.Character then return end
        if isPlayerSafe(target) then return end
        if tick() < VOID_COOLDOWN_UNTIL then return end

        local myHRP = getHRP(Player)
        local myHum = getHum(Player)
        if not myHRP or not myHum then return end
        local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end

        isVoiding = true
        VOID_COOLDOWN_UNTIL = tick() + ATTACK_RESET_INTERVAL
        preVoidCFrame = myHRP.CFrame

        for _, r in ipairs(findRemotes("kill")) do
            pcall(function() r:FireServer(target, "Void") end)
        end
        for _, r in ipairs(findRemotes("void")) do
            pcall(function() r:FireServer(target) end)
        end

        myHRP.CFrame = CFrame.new(tHRP.Position.X, myHRP.Position.Y, tHRP.Position.Z)
        task.spawn(function()
            for _ = 1, 8 do
                task.wait(0.015)
                if not isVoiding then break end
                local h = getHRP(Player)
                if not h then break end
                h.Velocity = Vector3.new(0, FALL_SPEED, 0)
            end
        end)

        task.spawn(function()
            local deadline = tick() + 2
            while tick() < deadline do
                task.wait(0.03)
                local h, hum = getHRP(Player), getHum(Player)
                if not h or not hum then break end
                if h.Position.Y < FALL_CHECK_Y then
                    pcall(function() hum.Health = 0 end)
                    break
                end
            end
            isVoiding = false
            task.wait(RESUME_DELAY)
            if attackTarget and not isPlayerSafe(attackTarget) then
                resumeToTarget(attackTarget)
            elseif preVoidCFrame then
                local h = getHRP(Player)
                if h then h.CFrame = preVoidCFrame end
            end
        end)
    end

    task.spawn(function()
        while true do
            task.wait(ATTACK_RESET_INTERVAL)
            if VOID_MODE_ENABLED and mode == "attack" and attackTarget
               and not isPlayerSafe(attackTarget) and not isVoiding then
                goVoid(attackTarget)
            end
        end
    end)

    -- BLOCK
    local function setInfBlock(enabled)
        BLOCK_ENABLED = enabled
        if blockConnection then blockConnection:Disconnect(); blockConnection = nil end
        if not enabled then return end
        blockConnection = RunService.RenderStepped:Connect(function()
            if not BLOCK_ENABLED then return end
            local c = Player.Character
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Blocking, true)
                local st = hum:GetState()
                if st ~= Enum.HumanoidStateType.Blocking then
                    if st == Enum.HumanoidStateType.Stunned or st == Enum.HumanoidStateType.FallingDown then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                    hum:ChangeState(Enum.HumanoidStateType.Blocking)
                end
            end
            pcall(function()
                local cr = findRemoteExact("CombatRemote")
                if cr then cr:FireServer("Block") end
                for _, rem in ipairs(findRemotes("block")) do rem:FireServer(true) end
                for _, rem in ipairs(findRemotes("guard")) do rem:FireServer(true) end
                for _, rem in ipairs(findRemotes("shield")) do rem:FireServer(true) end
                local bp = Player:FindFirstChild("Backpack")
                if bp and hum then
                    for _, tool in ipairs(bp:GetChildren()) do
                        if tool:IsA("Tool") and (tool.Name:lower():find("block") or tool.Name:lower():find("shield")) then
                            hum:EquipTool(tool)
                        end
                    end
                end
            end)
        end)
    end

    -- SPEEDWALK + RB
    local posHistory = {}
    local resetSuppressUntil = 0
    rbConnection = RunService.Stepped:Connect(function()
        local hrp = getHRP(Player)
        if not hrp then return end
        local now = tick()
        table.insert(posHistory, {t = now, p = hrp.Position, cf = hrp.CFrame})
        while #posHistory > 30 do table.remove(posHistory, 1) end

        if #posHistory >= 2 and now > resetSuppressUntil then
            local a = posHistory[#posHistory - 1]
            local b = posHistory[#posHistory]
            local dt = math.max(b.t - a.t, 1/240)
            local dist = (b.p - a.p).Magnitude
            if dist / dt > 800 then
                for i = #posHistory - 1, 1, -1 do
                    local cand = posHistory[i]
                    if (cand.p - b.p).Magnitude > 5 then
                        hrp.CFrame = cand.cf
                        hrp.Velocity = Vector3.zero
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        resetSuppressUntil = now + 0.05
                        table.clear(posHistory)
                        break
                    end
                end
            end
        end
    end)

    local function setSpeedwalk(enabled, speed)
        SPEEDWALK_ENABLED = enabled
        if speed then SPEEDWALK_SPEED = speed end
        if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
        if not enabled then return end
        speedConnection = RunService.RenderStepped:Connect(function()
            if not SPEEDWALK_ENABLED or tick() < resetSuppressUntil then return end
            local c = Player.Character
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            local hrp = getHRP(Player)
            if not hum or not hrp then return end
            hum.WalkSpeed = 16
            local dir = hum.MoveDirection
            if dir.Magnitude > 0 then
                local step = dir * (SPEEDWALK_SPEED / 60)
                hrp.CFrame = hrp.CFrame + step
            end
        end)
    end

    -- M1 / M2 loops
    task.spawn(function()
        while true do
            RunService.Heartbeat:Wait()
            if UNLIMITED_M1_ENABLED then
                pcall(function()
                    local r = findRemoteExact("CombatRemote")
                    if r then r:FireServer("M1") end
                    for _, rem in ipairs(findRemotes("M1")) do rem:FireServer() end
                end)
            end
        end
    end)
    task.spawn(function()
        while true do
            task.wait(isSpammingM2 and 0.01 or 0.1)
            if M2_SPAM_ENABLED then
                pcall(function()
                    local r = findRemoteExact("CombatRemote")
                    if r then r:FireServer("M2") end
                    for _, rem in ipairs(findRemotes("M2")) do rem:FireServer() end
                end)
            end
        end
    end)

    -- SELECT
    local function selectTarget(plr)
        if plr == Player or isPlayerSafe(plr) then return end
        mode = "attack"
        attackTarget = plr
        savedTargetUserId = plr.UserId
        startChase(plr)
        notify("TARGET", "Locked: " .. plr.Name)
    end

    -- =========================================================
    -- SILENT CMD + COMMANDS
    -- =========================================================
    local CMD_PREFIX = ";"
    local SILENT_BIND = Enum.KeyCode.F2

    local function onChatCommand(raw)
        if type(raw) ~= "string" then return end
        if raw:sub(1, #CMD_PREFIX) ~= CMD_PREFIX then return end
        local body = raw:sub(#CMD_PREFIX + 1)
        local args = {}
        for w in body:gmatch("%S+") do table.insert(args, w) end
        if #args == 0 then return end
        local cmd = args[1]:lower()
        table.remove(args, 1)

        local function tgt(i)
            local s = args[i]
            if not s then return nil end
            return findPlayerByFuzzy(s:gsub("^@", ""))
        end
        local function argLower(i, def) return (args[i] or def):lower() end

        if cmd == "help" then
            notify("CMDS", "sv/multpred/ws/hb/rj/sh/anti/target/void/stop/chase/block/m1/m2/noclip/equip/diag/say/tp/bring/kick/respawn")
        elseif cmd == "sv" or cmd == "safe" then
            local p = tgt(1)
            if p then
                if immunePlayers[p] then immunePlayers[p] = nil; notify("SAFE", "off " .. p.Name)
                else immunePlayers[p] = true; notify("SAFE", "on " .. p.Name) end
                if immuneScrollRefresh then immuneScrollRefresh() end
            end
        elseif cmd == "multpred" then
            local n = tonumber(args[1]); if n then PREDICTION_MULT = n; notify("PRED", "x" .. n) end
        elseif cmd == "ws" or cmd == "walkspeed" then
            local n = tonumber(args[1]); if n then SPEEDWALK_SPEED = n; setSpeedwalk(true, n); notify("WS", n) end
        elseif cmd == "hb" or cmd == "hitbox" then
            local n = tonumber(args[1]); if n then HITBOX_SIZE = n; notify("HB", n) end
        elseif cmd == "rj" or cmd == "rejoin" then
            pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
        elseif cmd == "sh" or cmd == "serverhop" then
            task.spawn(function()
                local ok, res = pcall(function()
                    return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
                end)
                if not ok then notify("SH", "fetch failed"); return end
                local data = HttpService:JSONDecode(res)
                for _, srv in ipairs(data.data or {}) do
                    if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, Player) end)
                        notify("SH", "hopping"); return
                    end
                end
                notify("SH", "no open server")
            end)
        elseif cmd == "anti" then
            if ANTI then ANTI.enabled = not ANTI.enabled; notify("ANTI", tostring(ANTI.enabled)) end
        elseif cmd == "target" then local p = tgt(1); if p then selectTarget(p) end
        elseif cmd == "void" then if attackTarget then goVoid(attackTarget) end
        elseif cmd == "stop" then stopChase(); mode = "idle"; attackTarget = nil; savedTargetUserId = nil; isVoiding = false
        elseif cmd == "chase" then
            local p = tgt(1) or attackTarget
            if p and not isPlayerSafe(p) then startChase(p); attackTarget = p end
        elseif cmd == "block" then setInfBlock(argLower(1, "on") == "on")
        elseif cmd == "m1" then UNLIMITED_M1_ENABLED = argLower(1, "on") == "on"
        elseif cmd == "m2" then M2_SPAM_ENABLED = argLower(1, "on") == "on"
        elseif cmd == "noclip" then setNoclip(argLower(1, "on") == "on")
        elseif cmd == "speed" or cmd == "sw" then
            local n = tonumber(args[1]); if n then setSpeedwalk(true, n); SPEEDWALK_SPEED = n end
        elseif cmd == "equip" then if args[1] then equipWeapon(table.concat(args, " ")) end
        elseif cmd == "diag" then
            notify("DIAG", "mode=" .. mode .. " target=" .. (attackTarget and attackTarget.Name or "none") .. " remotes=" .. #getRemotes())
        elseif cmd == "say" then local m = table.concat(args, " "); if #m > 0 then sayChat(m) end
        elseif cmd == "tp" then
            local p = tgt(1)
            if p and p.Character then
                local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                local myHRP = getHRP(Player)
                if tHRP and myHRP then myHRP.CFrame = tHRP.CFrame + Vector3.new(0, 3, 0) end
            end
        elseif cmd == "bring" then
            local p = tgt(1)
            if p and p.Character then
                local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                local myHRP = getHRP(Player)
                if tHRP and myHRP then tHRP.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 4 end
            end
        elseif cmd == "kick" then
            local p = tgt(1)
            if p then for _, r in ipairs(findRemotes("kick")) do pcall(function() r:FireServer(p) end) end end
        elseif cmd == "respawn" then
            local hum = getHum(Player); if hum then hum.Health = 0 end
        end
    end

    -- silence own command messages from chat
    pcall(function()
        if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end
        for _, ch in ipairs(TextChatService:GetDescendants()) do
            if ch:IsA("TextChannel") then
                local old = ch.SendAsync
                ch.SendAsync = newcclosure(function(self, text, ...)
                    if typeof(text) == "string" and text:sub(1, #CMD_PREFIX) == CMD_PREFIX then return nil end
                    return old(self, text, ...)
                end)
            end
        end
    end)

    -- bind chat sources
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local function hook(ch)
                ch.MessageReceived:Connect(function(msg)
                    if msg.TextSource and msg.TextSource.UserId == Player.UserId then
                        onChatCommand(msg.Text)
                    end
                end)
            end
            for _, ch in ipairs(TextChatService:GetDescendants()) do
                if ch:IsA("TextChannel") then hook(ch) end
            end
            TextChatService.DescendantAdded:Connect(function(d)
                if d:IsA("TextChannel") then hook(d) end
            end)
        else
            Player.Chatted:Connect(onChatCommand)
        end
    end)

    -- silent console (F2)
    local silentGui = Instance.new("ScreenGui")
    silentGui.Name = "OxiroSilent"
    silentGui.ResetOnSpawn = false
    silentGui.Parent = Player:WaitForChild("PlayerGui")

    local silentBox = Instance.new("TextBox")
    silentBox.Size = UDim2.new(0, 360, 0, 32)
    silentBox.Position = UDim2.new(0.5, -180, 0.85, 0)
    silentBox.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
    silentBox.TextColor3 = Color3.fromRGB(120, 240, 255)
    silentBox.PlaceholderText = "silent cmd ;help"
    silentBox.Text = ""
    silentBox.Font = Enum.Font.Code
    silentBox.TextSize = 14
    silentBox.Visible = false
    silentBox.ClearTextOnFocus = false
    silentBox.Parent = silentGui
    Instance.new("UICorner", silentBox).CornerRadius = UDim.new(0, 6)
    local silentStroke = Instance.new("UIStroke", silentBox)
    silentStroke.Color = Color3.fromRGB(60, 220, 255)
    silentStroke.Thickness = 1.5

    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == SILENT_BIND then
            silentBox.Visible = not silentBox.Visible
            if silentBox.Visible then silentBox:CaptureFocus() else silentBox:ReleaseFocus() end
        elseif inp.KeyCode == Enum.KeyCode.Escape and silentBox.Visible then
            silentBox.Visible = false; silentBox:ReleaseFocus()
        end
    end)
    silentBox.FocusLost:Connect(function(enterPressed)
        if not enterPressed then silentBox.Visible = false; return end
        local txt = silentBox.Text
        silentBox.Text = ""; silentBox.Visible = false
        onChatCommand(txt)
    end)

    -- =========================================================
    -- ANTI-SCRIPTER SUITE
    -- =========================================================
    local suspectedScripters = {}
    ANTI = {
        enabled = true,
        velocityMax = 350,
        yFloor = -4900,
        anchorCheck = true,
        stateLock = true,
        lastSafePos = nil,
        lastCheck = 0,
    }

    local function flagScripter(plr, reason)
        if plr == Player or isPlayerSafe(plr) then return end
        if not suspectedScripters then suspectedScripters = {} end
        if suspectedScripters[plr] then return end
        suspectedScripters[plr] = {since = tick(), reason = reason or "unknown"}
        notify("ANTI", "flag: " .. plr.Name .. " (" .. tostring(reason) .. ")")
        immunePlayers[plr] = true
        if immuneScrollRefresh then immuneScrollRefresh() end
    end

    local function clearFlag(plr)
        if suspectedScripters then suspectedScripters[plr] = nil end
        immunePlayers[plr] = nil
        if immuneScrollRefresh then immuneScrollRefresh() end
    end

    -- velocity / teleport / anchor detector
    local lastPositions = {}
    local antiConnection = RunService.Heartbeat:Connect(function()
        if not ANTI or not ANTI.enabled then return end
        local now = tick()
        if now - (ANTI.lastCheck or 0) < 0.1 then return end
        ANTI.lastCheck = now
        local myHRP = getHRP(Player)
        if myHRP then
            if not ANTI.lastSafePos then ANTI.lastSafePos = myHRP.Position end
            if myHRP.Position.Y < ANTI.yFloor then
                -- self recovery from void-fall
                myHRP.CFrame = CFrame.new(ANTI.lastSafePos + Vector3.new(0, 5, 0))
                myHRP.Velocity = Vector3.zero
            else
                ANTI.lastSafePos = myHRP.Position
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == Player then continue end
            local hrp = getHRP(plr)
            if not hrp then continue end
            local prev = lastPositions[plr]
            local pos = hrp.Position
            if prev then
                local dt = math.max(now - prev.t, 1/240)
                local dist = (pos - prev.p).Magnitude
                local vel = dist / dt
                if vel > ANTI.velocityMax then
                    flagScripter(plr, "vel:" .. math.floor(vel))
                end
                if ANTI.anchorCheck and hrp.AssemblyLinearVelocity.Magnitude < 0.05
                   and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                   and plr.Character:FindFirstChildOfClass("Humanoid").MoveDirection.Magnitude > 0.5
                   and (pos - prev.p).Magnitude < 0.01 then
                    flagScripter(plr, "anchor")
                end
            end
            lastPositions[plr] = {p = pos, t = now}
            if hrp.Position.Y < ANTI.yFloor then
                flagScripter(plr, "voidfall")
            end
        end
    end)

    -- state lock: if a flagged player tries to act on us via remotes, block
    pcall(function()
        local gmt = getrawmetatable(game)
        local oldNamecall = gmt.__namecall
        setreadonly(gmt, false)
        gmt.__namecall = newcclosure(function(self, ...)
            local meth = getnamecallmethod()
            if meth == "FireServer" or meth == "InvokeServer" then
                local args = {...}
                for i, a in pairs(args) do
                    if typeof(a) == "Instance" and a:IsA("Player") and suspectedScripters and suspectedScripters[a] then
                        if ANTI and ANTI.stateLock then return nil end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(gmt, true)
    end)

    -- clear stale flags on player leave
    Players.PlayerRemoving:Connect(function(p)
        if suspectedScripters then suspectedScripters[p] = nil end
        immunePlayers[p] = nil
        lastPositions[p] = nil
    end)

    -- =========================================================
    -- HITBOX EXPANSION (per-target)
    -- =========================================================
    local hitboxConnections = {}
    local function clearHitboxes()
        for _, c in ipairs(hitboxConnections) do c:Disconnect() end
        table.clear(hitboxConnections)
    end

    local function applyHitbox(plr, size)
        if not plr or not plr.Character then return end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.Size = Vector3.new(size, size, size)
        hrp.Transparency = 0.5
        hrp.CanCollide = false
    end

    -- =========================================================
    -- GUI — MAIN PANEL
    -- =========================================================
    local MainGui = Instance.new("ScreenGui")
    MainGui.Name = "OXIRO_MAIN"
    MainGui.ResetOnSpawn = false
    MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    MainGui.Parent = Player:WaitForChild("PlayerGui")

    local Root = Instance.new("Frame")
    Root.Size = UDim2.new(0, 520, 0, 380)
    Root.Position = UDim2.new(0.5, -260, 0.5, -190)
    Root.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
    Root.Active = true
    Root.Draggable = true
    Root.Parent = MainGui
    Instance.new("UICorner", Root).CornerRadius = UDim.new(0, 14)
    local RootStroke = Instance.new("UIStroke", Root)
    RootStroke.Color = Color3.fromRGB(60, 220, 255)
    RootStroke.Thickness = 2

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 38)
    Header.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    Header.Parent = Root
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -80, 1, 0)
    TitleLbl.Position = UDim2.new(0, 14, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.Text = "OXIRO V5"
    TitleLbl.TextColor3 = Color3.fromRGB(80, 240, 255)
    TitleLbl.TextSize = 18
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = Header

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -38, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 14
    CloseBtn.Parent = Header
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
    CloseBtn.MouseButton1Click:Connect(function() Root.Visible = false end)

    -- tab bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -20, 0, 32)
    TabBar.Position = UDim2.new(0, 10, 0, 46)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = Root
    local tabList = {"target", "combat", "movement", "anti", "misc"}
    local tabButtons = {}
    local tabPages = {}

    local PageHolder = Instance.new("Frame")
    PageHolder.Size = UDim2.new(1, -20, 1, -130)
    PageHolder.Position = UDim2.new(0, 10, 0, 86)
    PageHolder.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
    PageHolder.Parent = Root
    Instance.new("UICorner", PageHolder).CornerRadius = UDim.new(0, 10)

    for i, name in ipairs(tabList) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 92, 1, 0)
        btn.Position = UDim2.new(0, (i - 1) * 96, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btn.Text = name:upper()
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.fromRGB(150, 200, 220)
        btn.TextSize = 12
        btn.Parent = TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        tabButtons[name] = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -12, 1, -12)
        page.Position = UDim2.new(0, 6, 0, 6)
        page.BackgroundTransparency = 1
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollBarThickness = 4
        page.Visible = (name == "target")
        page.Parent = PageHolder
        tabPages[name] = page

        btn.MouseButton1Click:Connect(function()
            currentTab = name
            for k, p in pairs(tabPages) do p.Visible = (k == name) end
            for k, b in pairs(tabButtons) do
                b.BackgroundColor3 = (k == name) and Color3.fromRGB(30, 120, 190) or Color3.fromRGB(16, 22, 32)
            end
        end)
    end
    tabButtons.target.BackgroundColor3 = Color3.fromRGB(30, 120, 190)

    -- helper: layout list
    local function newList(parent)
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 6)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = parent
        return list
    end

    -- helper: labeled toggle
    local function makeToggle(parent, order, label, getState, setState)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -8, 0, 34)
        holder.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
        holder.LayoutOrder = order
        holder.Parent = parent
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -90, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(200, 230, 240)
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = holder

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 64, 0, 24)
        btn.Position = UDim2.new(1, -74, 0, 5)
        btn.BackgroundColor3 = getState() and Color3.fromRGB(40, 180, 100) or Color3.fromRGB(70, 30, 30)
        btn.Text = getState() and "ON" or "OFF"
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.fromRGB(240, 255, 255)
        btn.TextSize = 12
        btn.Parent = holder
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            setState(not getState())
            btn.BackgroundColor3 = getState() and Color3.fromRGB(40, 180, 100) or Color3.fromRGB(70, 30, 30)
            btn.Text = getState() and "ON" or "OFF"
        end)
        return holder
    end

    local function makeSlider(parent, order, label, minV, maxV, getV, setV)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -8, 0, 46)
        holder.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
        holder.LayoutOrder = order
        holder.Parent = parent
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 0, 20)
        lbl.Position = UDim2.new(0, 10, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = label .. ": " .. tostring(getV())
        lbl.TextColor3 = Color3.fromRGB(200, 230, 240)
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = holder

        local bar = Instance.new("TextButton")
        bar.Size = UDim2.new(1, -20, 0, 14)
        bar.Position = UDim2.new(0, 10, 0, 24)
        bar.BackgroundColor3 = Color3.fromRGB(30, 60, 80)
        bar.Text = ""
        bar.Parent = holder
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 6)

        local function setFromX(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(minV + (maxV - minV) * rel)
            setV(v)
            lbl.Text = label .. ": " .. tostring(v)
        end

        bar.MouseButton1Down:Connect(function() setFromX(UserInputService:GetMouseLocation().X) end)
        UserInputService.InputChanged:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseMovement and bar:IsDescendantOf(PageHolder) then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    setFromX(UserInputService:GetMouseLocation().X)
                end
            end
        end)
    end

    -- ================= TARGET PAGE =================
    local targetList = Instance.new("Frame")
    targetList.Size = UDim2.new(1, -8, 0, 200)
    targetList.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    targetList.LayoutOrder = 1
    targetList.Parent = tabPages.target
    Instance.new("UICorner", targetList).CornerRadius = UDim.new(0, 8)

    local tlScroll = Instance.new("ScrollingFrame")
    tlScroll.Size = UDim2.new(1, -8, 1, -8)
    tlScroll.Position = UDim2.new(0, 4, 0, 4)
    tlScroll.BackgroundTransparency = 1
    tlScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tlScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    tlScroll.ScrollBarThickness = 4
    tlScroll.Parent = targetList
    newList(tlScroll)

    local function refreshPlayerList()
        for _, c in ipairs(tlScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        playerButtons = {}
        local order = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == Player then continue end
            order += 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 30)
            b.BackgroundColor3 = immunePlayers[plr] and Color3.fromRGB(90, 50, 20) or Color3.fromRGB(18, 24, 34)
            b.Text = plr.Name .. "  [" .. plr.DisplayName .. "]"
            b.Font = Enum.Font.Code
            b.TextColor3 = immunePlayers[plr] and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(180, 220, 240)
            b.TextSize = 12
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.LayoutOrder = order
            b.Parent = tlScroll
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.MouseButton1Click:Connect(function()
                if plr == Player then return end
                selectTarget(plr)
                refreshPlayerList()
            end)
            playerButtons[plr] = b
        end
    end
    immuneScrollRefresh = refreshPlayerList
    refreshPlayerList()
    Players.PlayerAdded:Connect(refreshPlayerList)
    Players.PlayerRemoving:Connect(refreshPlayerList)

    -- combat page
    makeToggle(tabPages.combat, 1, "Unlimited M1", function() return UNLIMITED_M1_ENABLED end,
        function(v) UNLIMITED_M1_ENABLED = v end)
    makeToggle(tabPages.combat, 2, "M2 Spam", function() return M2_SPAM_ENABLED end,
        function(v) M2_SPAM_ENABLED = v end)
    makeToggle(tabPages.combat, 3, "Infinite Block", function() return BLOCK_ENABLED end,
        function(v) setInfBlock(v) end)
    makeToggle(tabPages.combat, 4, "Void Mode", function() return VOID_MODE_ENABLED end,
        function(v) VOID_MODE_ENABLED = v end)
    makeToggle(tabPages.combat, 5, "Auto Equip", function() return AUTO_EQUIP_ENABLED end,
        function(v)
            AUTO_EQUIP_ENABLED = v
            if v then autoEquip() end
        end)
    makeSlider(tabPages.combat, 6, "Hitbox Size", 5, 200,
        function() return HITBOX_SIZE end,
        function(v) HITBOX_SIZE = v end)
    makeSlider(tabPages.combat, 7, "Prediction x", 1, 3,
        function() return PREDICTION_MULT end,
        function(v) PREDICTION_MULT = v end)

    -- movement page
    makeToggle(tabPages.movement, 1, "Noclip", function() return NOCLIP_ENABLED end,
        function(v) setNoclip(v) end)
    makeToggle(tabPages.movement, 2, "Speedwalk", function() return SPEEDWALK_ENABLED end,
        function(v) setSpeedwalk(v, SPEEDWALK_SPEED) end)
    makeSlider(tabPages.movement, 3, "Walk Speed", 16, 300,
        function() return SPEEDWALK_SPEED end,
        function(v) SPEEDWALK_SPEED = v; if SPEEDWALK_ENABLED then setSpeedwalk(true, v) end end)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(1, -8, 0, 36)
    stopBtn.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    stopBtn.Text = "STOP ALL"
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.TextSize = 13
    stopBtn.LayoutOrder = 10
    stopBtn.Parent = tabPages.movement
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
    stopBtn.MouseButton1Click:Connect(function()
        stopChase()
        setNoclip(false)
        setSpeedwalk(false)
        setInfBlock(false)
        VOID_MODE_ENABLED = false
        mode = "idle"
        attackTarget = nil
        notify("STOP", "all systems halted")
    end)

    -- anti page
    makeToggle(tabPages.anti, 1, "Anti-Scripter", function() return ANTI.enabled end,
        function(v) ANTI.enabled = v end)
    makeToggle(tabPages.anti, 2, "Anchor Detection", function() return ANTI.anchorCheck end,
        function(v) ANTI.anchorCheck = v end)
    makeToggle(tabPages.anti, 3, "State Lock", function() return ANTI.stateLock end,
        function(v) ANTI.stateLock = v end)

    local clearAllBtn = Instance.new("TextButton")
    clearAllBtn.Size = UDim2.new(1, -8, 0, 32)
    clearAllBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 60)
    clearAllBtn.Text = "Clear All Flags"
    clearAllBtn.Font = Enum.Font.GothamMedium
    clearAllBtn.TextColor3 = Color3.fromRGB(230, 255, 240)
    clearAllBtn.TextSize = 12
    clearAllBtn.LayoutOrder = 10
    clearAllBtn.Parent = tabPages.anti
    Instance.new("UICorner", clearAllBtn).CornerRadius = UDim.new(0, 6)
    clearAllBtn.MouseButton1Click:Connect(function()
        for p, _ in pairs(suspectedScripters or {}) do clearFlag(p) end
        immunePlayers = {}
        refreshPlayerList()
        notify("ANTI", "flags cleared")
    end)

    -- misc page
    local diagBtn = Instance.new("TextButton")
    diagBtn.Size = UDim2.new(1, -8, 0, 32)
    diagBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
    diagBtn.Text = "Diagnostics"
    diagBtn.Font = Enum.Font.GothamMedium
    diagBtn.TextColor3 = Color3.fromRGB(220, 240, 255)
    diagBtn.TextSize = 12
    diagBtn.LayoutOrder = 1
    diagBtn.Parent = tabPages.misc
    Instance.new("UICorner", diagBtn).CornerRadius = UDim.new(0, 6)
    diagBtn.MouseButton1Click:Connect(function()
        notify("DIAG", "mode=" .. mode .. " target=" .. (attackTarget and attackTarget.Name or "none") .. " remotes=" .. #getRemotes() .. " flags=" .. (function()
            local n = 0; for _ in pairs(suspectedScripters or {}) do n += 1 end; return n
        end)())
    end)

    local rejoinBtn = Instance.new("TextButton")
    rejoinBtn.Size = UDim2.new(1, -8, 0, 32)
    rejoinBtn.BackgroundColor3 = Color3.fromRGB(90, 30, 30)
    rejoinBtn.Text = "Rejoin"
    rejoinBtn.Font = Enum.Font.GothamMedium
    rejoinBtn.TextColor3 = Color3.fromRGB(255, 230, 230)
    rejoinBtn.TextSize = 12
    rejoinBtn.LayoutOrder = 2
    rejoinBtn.Parent = tabPages.misc
    Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)
    rejoinBtn.MouseButton1Click:Connect(function()
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
    end)

    -- auto-respawn loop
    task.spawn(function()
        while true do
            task.wait(1)
            local hum = getHum(Player)
            if hum and hum.Health <= 0 and attackTarget and attackTarget.Character then
                task.wait(3)
                if savedTargetUserId then
                    local plr = Players:GetPlayerByUserId(savedTargetUserId)
                    if plr and not isPlayerSafe(plr) then selectTarget(plr) end
                end
            end
            if AUTO_EQUIP_ENABLED and not VOID_MODE_ENABLED then autoEquip() end
        end
    end)
end

-- gate submit
SubmitBtn.MouseButton1Click:Connect(function()
    local entered = KeyBox.Text
    if entered == CORRECT_KEY then
        Status.Text = "verified"
        Status.TextColor3 = Color3.fromRGB(80, 240, 140)
        task.wait(0.5)
        runMainScript()
    else
        attempts += 1
        if attempts >= MAX_ATTEMPTS then
            Status.Text = "locked out"
            Status.TextColor3 = Color3.fromRGB(255, 60, 60)
            task.wait(2)
            pcall(function()
                Player:Kick("security: max attempts exceeded")
            end)
        else
            Status.Text = "invalid key (" .. attempts .. "/" .. MAX_ATTEMPTS .. ")"
            Status.TextColor3 = Color3.fromRGB(255, 90, 90)
        end
    end
end)

KeyBox.FocusLost:Connect(function(enter)
    if enter then SubmitBtn.MouseButton1Click() end
end)
