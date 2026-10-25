-- chanhyuk lua v2 - Full Integration with Config System
local v1 = game:GetService("Players")
local v2 = game:GetService("RunService")
local v3 = game:GetService("UserInputService")
local v4 = game:GetService("TweenService")
local v5 = game:GetService("ReplicatedStorage")
local v6 = game:GetService("HttpService")
local LocalPlayer = v1.LocalPlayer

-- 설정 폴더 및 오토로드 파일 경로
local CONFIG_FOLDER = "Chanhyuk lua free"
local AUTOLOAD_FILE = CONFIG_FOLDER .. "/autoload.txt"

local State = {
    targetName = "", lastX = 0, lastY = 0, lastZ = 0,
    rage = false, rageY = 8778,

    -- 기존 UE 카운터
    ueEnabled = false, ueBaseY = 1004046, ueStepAmount = 500, ueStepCooldown = 0.3,
    ueJitterAmp = 5, ueCurrentY = 1004046, ueLastStep = 0, ueHome = nil, ueNetLast = 0,

    -- UE 카운터 V2
    ueV2Enabled = false,
    ueV2YDist = 100,
    ueV2Cooldown = 0.2,

    -- Void Spam
    voidEnabled = false, voidMethod = "HvH", voidSpeed = 1, voidDelay = 20, voidDist = 1270109,
    lastVoidTick = 0, voidEvadeTimer = 0, voidPatternAngle = 0,
    voidEvade = true, voidEvadeRadius = 8e9, voidEvadeSpeed = 6e9, voidEvadeCD = 0.05,
    voidBaseX = 0, voidBaseY = 0, voidBaseZ = 0, voidRadius = 2e11, voidYMin = -1e15, voidYMax = 1e15,
    voidTPMin = -1e10, voidTPMax = 1e10, voidPos = Vector3.zero, voidCamSaved = nil,

    -- Orbit
    orbitEnabled = false, orbitMode = "Circle", orbitSpeed = 90, orbitDist = 8,
    orbitHeight = 0, orbitLerp = 0.3, orbitPredict = false, orbitFace = true, orbitAngle = 0,
    orbitCurRadius = 8, orbitTwist = 0, orbitTwistSpeed = 1440,
    orbitEvadeAim = true, orbitEvadeAngle = 0, orbitEvadeRadius = 90, orbitDodgeDist = 12,
    orbitDodgeCooldown = 0.1, orbitLastDodge = 0, orbitPhase = "orbit", orbitPhaseUntil = 0,
}

-- Config 시스템 함수들
local function initFolder()
    pcall(function()
        if makefolder and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end
initFolder()

local function saveConfig(name)
    if not name or name == "" then return end
    initFolder()
    local success, encoded = pcall(function()
        return v6:JSONEncode({
            targetName = State.targetName,
            rage = State.rage,
            rageY = State.rageY,
            ueEnabled = State.ueEnabled,
            ueBaseY = State.ueBaseY,
            ueStepAmount = State.ueStepAmount,
            ueStepCooldown = State.ueStepCooldown,
            ueJitterAmp = State.ueJitterAmp,
            ueV2Enabled = State.ueV2Enabled,
            ueV2YDist = State.ueV2YDist,
            ueV2Cooldown = State.ueV2Cooldown,
            voidEnabled = State.voidEnabled,
            voidMethod = State.voidMethod,
            voidSpeed = State.voidSpeed,
            voidDelay = State.voidDelay,
            voidDist = State.voidDist,
            orbitEnabled = State.orbitEnabled,
            orbitMode = State.orbitMode,
            orbitSpeed = State.orbitSpeed,
            orbitDist = State.orbitDist,
            orbitHeight = State.orbitHeight,
        })
    end)
    if success and encoded and writefile then
        pcall(function()
            writefile(CONFIG_FOLDER .. "/" .. name .. ".json", encoded)
        end)
    end
end

local function loadConfig(name)
    if not name or name == "" then return end
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if readfile and isfile and isfile(filePath) then
        local success, decoded = pcall(function()
            return v6:JSONDecode(readfile(filePath))
        end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if State[k] ~= nil then
                    State[k] = v
                end
            end
        end
    end
end

local function deleteConfig(name)
    if not name or name == "" then return end
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if delfile and isfile and isfile(filePath) then
        pcall(function()
            delfile(filePath)
        end)
    end
end

local function getConfigsList()
    local list = {}
    if listfiles then
        pcall(function()
            for _, file in ipairs(listfiles(CONFIG_FOLDER)) do
                if file:sub(-5) == ".json" then
                    local name = file:match("([^/\\]+)%.json$")
                    if name then
                        table.insert(list, name)
                    end
                end
            end
        end)
    end
    if #list == 0 then
        table.insert(list, "default")
    end
    return list
end

local function setAutoload(name)
    initFolder()
    if writefile then
        pcall(function()
            writefile(AUTOLOAD_FILE, name)
        end)
    end
end

local function cancelAutoload()
    if delfile and isfile and isfile(AUTOLOAD_FILE) then
        pcall(function()
            delfile(AUTOLOAD_FILE)
        end)
    end
end

-- 스크립트 실행 시 오토로드 확인 및 자동 실행
pcall(function()
    if readfile and isfile and isfile(AUTOLOAD_FILE) then
        local autoName = readfile(AUTOLOAD_FILE):gsub("^%s+", ""):gsub("%s+$", "")
        if autoName ~= "" then
            loadConfig(autoName)
        end
    end
end)

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function makeRaycastParams(filter)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter and {filter} or {}
    params.IgnoreWater = true
    return params
end

local function getGroundY(pos, character)
    local ok, y = pcall(function()
        local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 8, pos.Z), Vector3.new(0, -400, 0), makeRaycastParams(character))
        if hit then return hit.Position.Y + 3 end
        return nil
    end)
    return ok and y or nil
end

local function sanitizePosition(pos, character, keepY)
    if not pos then return Vector3.zero end
    local x, y, z = pos.X, pos.Y, pos.Z
    if x ~= x or y ~= y or z ~= z then return Vector3.new(0, 50, 0) end
    local limit = 2000000
    if math.abs(x) > limit then x = math.clamp(x, -limit, limit) end
    if math.abs(z) > limit then z = math.clamp(z, -limit, limit) end
    if not keepY and (math.abs(y) > 5000 or y < -800) then
        local groundY = getGroundY(Vector3.new(x, math.clamp(y, -100, 800), z), character)
        y = groundY or math.clamp(y, -50, 400)
    end
    return Vector3.new(x, y, z)
end

local function walkHome(homeCF, humanoid, hrp)
    if not homeCF then return homeCF end
    local character = LocalPlayer.Character
    local pos = sanitizePosition(homeCF.Position, character, true)
    local moveDir = Vector3.zero
    if humanoid then
        local m = humanoid.MoveDirection
        if m.Magnitude >= 0.05 then moveDir = Vector3.new(m.X, 0, m.Z).Unit end
    end
    if moveDir.Magnitude < 0.05 then
        pcall(function()
            local x, z = 0, 0
            if v3:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
            if v3:IsKeyDown(Enum.KeyCode.S) then z += 1 end
            if v3:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
            if v3:IsKeyDown(Enum.KeyCode.D) then x += 1 end
            if x == 0 and z == 0 then return end
            local camera = workspace.CurrentCamera
            local cf = camera and camera.CFrame or (hrp and hrp.CFrame)
            if cf then
                local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
                local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
                if flatLook.Magnitude > 0.05 then flatLook = flatLook.Unit end
                if flatRight.Magnitude > 0.05 then flatRight = flatRight.Unit end
                moveDir = flatLook * -z + flatRight * x
            end
        end)
    end
    local speed = (humanoid and humanoid.WalkSpeed) or 16
    if speed < 1 then speed = 16 end
    if moveDir.Magnitude > 0.05 then
        local step = math.min(speed * (1/60), 2.2)
        local origin = pos + Vector3.new(0, 1.5, 0)
        local hit = workspace:Raycast(origin, moveDir * (step + 1.2), makeRaycastParams(character))
        if hit then
            local stop = math.max(0, (hit.Position - origin).Magnitude - 1.2)
            pos = pos + moveDir * stop
        else
            pos = pos + moveDir * step
        end
        pos = Vector3.new(pos.X, homeCF.Position.Y, pos.Z)
    end
    pos = sanitizePosition(pos, character, true)
    local currentLook = homeCF.LookVector
    local flatLook = Vector3.new(currentLook.X, 0, currentLook.Z)
    if moveDir.Magnitude > 0.05 then
        if flatLook.Magnitude < 0.05 then flatLook = moveDir
        else flatLook = flatLook.Unit:Lerp(moveDir, math.clamp(10 * (1/60), 0.08, 0.35)) end
    end
    if flatLook.Magnitude < 0.05 then flatLook = Vector3.new(0, 0, -1) else flatLook = flatLook.Unit end
    return CFrame.new(pos, pos + flatLook)
end

local function applyClientCF(root, homeCF)
    if not root or not homeCF then return end
    local pos = sanitizePosition(homeCF.Position, LocalPlayer.Character, true)
    root.CFrame = CFrame.new(pos) * (homeCF - homeCF.Position)
    local v = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(math.clamp(v.X, -40, 40), math.clamp(v.Y, -5, 5), math.clamp(v.Z, -40, 40))
    root.AssemblyAngularVelocity = Vector3.zero
end

_G.__chanDesyncDt = 1 / 60
_G.__chanDesyncLastHome = nil
if not _G.__chanDesyncDtConn then
    _G.__chanDesyncDtConn = v2.RenderStepped:Connect(function(dt)
        if type(dt) == "number" and dt > 0 then
            _G.__chanDesyncDt = math.clamp(dt, 0.008, 0.033)
        end
    end)
end

local function desyncReturnToClient(homeCF)
    homeCF = homeCF or _G.__chanDesyncLastHome
    if not homeCF then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    pcall(function()
        for _, o in ipairs(hrp:GetChildren()) do
            if o:IsA("BodyPosition") or o:IsA("BodyGyro") or o:IsA("BodyVelocity") then
                o:Destroy()
            end
        end
        hrp.Anchored = false
        local pos = sanitizePosition(homeCF.Position, char, false)
        local gy = getGroundY(pos, char)
        if gy then
            pos = Vector3.new(pos.X, gy, pos.Z)
        end
        local cf = CFrame.new(pos) * (homeCF - homeCF.Position)
        for _ = 1, 4 do
            hrp.CFrame = cf
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = true
            end
        end
        local cam = workspace.CurrentCamera
        if cam and humanoid then
            if cam.CameraType ~= Enum.CameraType.Custom then
                cam.CameraType = Enum.CameraType.Custom
            end
            cam.CameraSubject = humanoid
        end
        _G.__chanDesyncLastHome = cf
    end)
end

-- RAGE SYSTEM
local rageActive = false
local rageLockPos = nil
local rageTargetPlayer = nil
local rageRealCF = nil
local rageRealChar = nil
local ragePreParkCF = nil
local RAGE_RESTORE_NAME = "__chanhyuk_rage_restore"
local RAGE_CAMERA_NAME = "__chanhyuk_rage_camera"
local rageDesyncBound = false
local rageStepConn = nil

local function rageGetTarget()
    local name = tostring(State.targetName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" then
        for _, p in ipairs(v1:GetPlayers()) do
            if p ~= LocalPlayer and (p.Name == name or p.DisplayName == name) then
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    return p.Character, p
                end
            end
        end
    end
    local closest, closestPlr, minD = nil, nil, math.huge
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, nil end
    for _, p in ipairs(v1:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local th = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if th and hum and hum.Health > 0 then
                local d = (myHrp.Position - th.Position).Magnitude
                if d < minD then
                    minD = d
                    closest = p.Character
                    closestPlr = p
                end
            end
        end
    end
    return closest, closestPlr
end

local function rageIsSaneHome(pos)
    if not pos then return false end
    if pos.Y ~= pos.Y then return false end
    if math.abs(pos.Y) > 50000 then return false end
    if math.abs(pos.X) > 1e6 or math.abs(pos.Z) > 1e6 then return false end
    return true
end

local function rageUnbindDesync()
    pcall(function() v2:UnbindFromRenderStep(RAGE_RESTORE_NAME) end)
    pcall(function() v2:UnbindFromRenderStep(RAGE_CAMERA_NAME) end)
    if rageStepConn then
        pcall(function() rageStepConn:Disconnect() end)
        rageStepConn = nil
    end
    rageDesyncBound = false
end

local function rageWalkClientHome(hrp, humanoid, dt)
    if not hrp then return end
    local baseCF = ragePreParkCF or rageRealCF
    if not baseCF or not rageIsSaneHome(baseCF.Position) then
        if rageIsSaneHome(hrp.Position) then baseCF = hrp.CFrame
        else return end
    end
    local home = walkHome(baseCF, humanoid, hrp)
    if not home then return end
    ragePreParkCF = home
    rageRealCF = home
    rageRealChar = LocalPlayer.Character
    return home
end

local function rageRestoreHome(pin)
    if not State.rage or not rageActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hrp.Parent then return end
    local dt = 1 / 60
    local back = rageWalkClientHome(hrp, humanoid, dt) or ragePreParkCF or rageRealCF
    if not back or not rageIsSaneHome(back.Position) then return end
    pcall(function()
        applyClientCF(hrp, back)
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

local function rageBindDesync()
    pcall(function() v2:UnbindFromRenderStep(RAGE_RESTORE_NAME) end)
    pcall(function() v2:UnbindFromRenderStep(RAGE_CAMERA_NAME) end)
    if rageStepConn then
        pcall(function() rageStepConn:Disconnect() end)
        rageStepConn = nil
    end
    pcall(function()
        v2:BindToRenderStep(RAGE_RESTORE_NAME, Enum.RenderPriority.Camera.Value - 1, function()
            if not State.rage or not rageActive then return end
            rageRestoreHome(false)
        end)
    end)
    if not _G.__chanhyuk_rage_hb then
        _G.__chanhyuk_rage_hb = v2.Heartbeat:Connect(function()
            if State.rage and rageActive then pcall(triggerRage) end
        end)
    end
    rageDesyncBound = true
end

local function stopRage()
    local _home = ragePreParkCF or rageRealCF
    State.rage = false
    rageActive = false
    rageLockPos = nil
    rageTargetPlayer = nil
    pcall(function() desyncReturnToClient(_home) end)
    pcall(rageUnbindDesync)
    if _G.__chanhyuk_rage_hb then
        pcall(function() _G.__chanhyuk_rage_hb:Disconnect() end)
        _G.__chanhyuk_rage_hb = nil
    end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp then
            for _, o in ipairs(hrp:GetChildren()) do
                if o:IsA("BodyPosition") or o:IsA("BodyGyro") or o:IsA("BodyVelocity") then
                    if tostring(o.Name):find("Rage") or o.Name == "RageBP" or o.Name == "RageBP_T" then
                        pcall(function() o:Destroy() end)
                    end
                end
            end
            local restore = ragePreParkCF or (rageRealChar == char and rageRealCF) or nil
            if restore then
                pcall(function()
                    hrp.Anchored = false
                    hrp.CFrame = CFrame.new(restore.Position) * (hrp.CFrame - hrp.CFrame.Position)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum.AutoRotate = true
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                task.defer(function()
                    if hum and hum.Parent then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)
            end)
        end
        local cam = workspace.CurrentCamera
        if cam and hum then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
        end
    end)
    ragePreParkCF = nil
    rageRealCF = nil
    rageRealChar = nil
end

function triggerRage()
    if not State.rage then
        if rageActive then stopRage() end
        return
    end
    rageActive = true
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    local targetChar, targetPlr = rageGetTarget()
    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end
    local targetHrp = targetChar.HumanoidRootPart
    rageTargetPlayer = targetPlr
    if rageIsSaneHome(hrp.Position) then
        if not rageRealCF or rageRealChar ~= char then
            rageRealCF = hrp.CFrame
            rageRealChar = char
            ragePreParkCF = hrp.CFrame
        end
        if ragePreParkCF and math.abs(ragePreParkCF.Position.Y) > 50000 then
            if rageIsSaneHome(hrp.Position) then
                ragePreParkCF = hrp.CFrame
                rageRealCF = hrp.CFrame
                rageRealChar = char
            end
        elseif not ragePreParkCF then
            ragePreParkCF = rageRealCF or hrp.CFrame
        end
    end
    if not ragePreParkCF and rageRealCF then ragePreParkCF = rageRealCF end
    rageBindDesync()
    local rageY = tonumber(State.rageY) or 8778
    if not rageLockPos then
        rageLockPos = Vector3.new(targetHrp.Position.X, rageY, targetHrp.Position.Z)
    else
        rageLockPos = Vector3.new(rageLockPos.X, rageY, rageLockPos.Z)
    end
    local lockCF = CFrame.new(rageLockPos)
    pcall(function()
        if sethiddenproperty then
            pcall(function() sethiddenproperty(targetHrp, "NetworkOwner", LocalPlayer) end)
            pcall(function() sethiddenproperty(targetHrp, "NetworkIsSleeping", false) end)
            pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", false) end)
        end
        pcall(function() if targetHrp.SetNetworkOwner then targetHrp:SetNetworkOwner(LocalPlayer) end end)
        pcall(function() if hrp.SetNetworkOwner then hrp:SetNetworkOwner(LocalPlayer) end end)
    end)
    for _ = 1, 24 do
        pcall(function()
            hrp.CFrame = lockCF
            targetHrp.CFrame = lockCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            targetHrp.AssemblyLinearVelocity = Vector3.zero
            targetHrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    pcall(function()
        local sbp = hrp:FindFirstChild("RageBP")
        if sbp then sbp:Destroy() end
        local rbp = targetHrp:FindFirstChild("RageBP")
        if not rbp or not rbp:IsA("BodyPosition") then
            if rbp then rbp:Destroy() end
            rbp = Instance.new("BodyPosition")
            rbp.Name = "RageBP"
            rbp.Parent = targetHrp
        end
        rbp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        rbp.P = 5e5
        rbp.D = 8000
        rbp.Position = lockCF.Position
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        local th = targetChar:FindFirstChildOfClass("Humanoid")
        if th then th:ChangeState(Enum.HumanoidStateType.Physics) end
    end)
end

local function startRage()
    State.rage = true
    rageActive = true
    rageLockPos = nil
    ragePreParkCF = nil
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and rageIsSaneHome(hrp.Position) then
        rageRealCF = hrp.CFrame
        rageRealChar = char
        ragePreParkCF = hrp.CFrame
    end
    rageBindDesync()
end

local function getTarget()
    local char, plr = rageGetTarget()
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- VOID SPAM & ORBIT FUNCTIONS
local function lockCameraForVoid()
    if State.voidCamSaved then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    State.voidCamSaved = { type = camera.CameraType, subject = camera.CameraSubject, cframe = camera.CFrame }
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = State.voidCamSaved.cframe
end

local function restoreCameraFromVoid()
    local camera = workspace.CurrentCamera
    if not camera or not State.voidCamSaved then return end
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    camera.CameraType = State.voidCamSaved.type or Enum.CameraType.Custom
    camera.CameraSubject = humanoid or State.voidCamSaved.subject
    State.voidCamSaved = nil
end

local function doVoidSpam(dt, currentCF)
    if not State.voidCamSaved then lockCameraForVoid() end
    if tick() - State.lastVoidTick < (State.voidDelay / 1000) then return currentCF end
    State.lastVoidTick = tick()

    local base = currentCF.Position
    local mode = State.voidMethod
    local mult = State.voidSpeed
    local dist = State.voidDist * mult
    local targetRoot = getTarget()

    if mode == "HvH" then
        State.voidPatternAngle = (State.voidPatternAngle + math.random(30, 90)) % 360
        local pattern = math.random(1, 100)
        local offset = Vector3.zero
        if pattern <= 35 and targetRoot then
            local look = targetRoot.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.05 then flat = flat.Unit else flat = Vector3.new(0, 0, -1) end
            local side = Vector3.new(-flat.Z, 0, flat.X)
            local sideSign = (math.random() > 0.5) and 1 or -1
            offset = side * dist * sideSign + Vector3.new(0, (math.random() - 0.5) * dist * 0.3, 0)
        elseif pattern <= 60 and targetRoot then
            offset = (targetRoot.Position - base) + Vector3.new(
                (math.random() - 0.5) * 4,
                (math.random() - 0.5) * 4,
                (math.random() - 0.5) * 4
            )
        elseif pattern <= 80 then
            offset = Vector3.new(
                (math.random() - 0.5) * dist * 0.4,
                (math.random() > 0.5 and 1 or -1) * dist * (0.7 + math.random() * 0.3),
                (math.random() - 0.5) * dist * 0.4
            )
        else
            local a = math.rad(State.voidPatternAngle)
            offset = Vector3.new(math.cos(a) * dist, (math.random() - 0.5) * dist, math.sin(a) * dist)
        end
        local rot = CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)))
        return CFrame.new(base + offset) * rot
    elseif mode == "Chanhyuk" then
        local r1, r2, r3 = math.random() - 0.5, math.random() - 0.5, math.random() - 0.5
        local offset = Vector3.new(r1 * 2 * dist, r2 * 2 * dist, r3 * 2 * dist)
        local randomRot = CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)))
        return CFrame.new(base + offset) * randomRot
    elseif mode == "Quantum" then
        local rx = (math.random() * 2 - 1) * State.voidRadius
        local ry = (math.random() * 2 - 1) * (State.voidYMax - State.voidYMin) / 2 + (State.voidYMax + State.voidYMin) / 2
        local rz = (math.random() * 2 - 1) * State.voidRadius
        return CFrame.new(State.voidBaseX + rx, ry, State.voidBaseZ + rz)
    elseif mode == "TP Everywhere" then
        local distTP = State.voidTPMin + math.random() * (State.voidTPMax - State.voidTPMin)
        local camera = workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            local ray = camera:ViewportPointToRay(math.random() * viewport.X, math.random() * viewport.Y, math.abs(distTP))
            local point = ray.Origin + ray.Direction.Unit * math.abs(distTP)
            return CFrame.new(point.X, point.Y, point.Z)
        end
    elseif mode == "Chaos" then
        local pos = (State.voidPos == Vector3.zero and base or State.voidPos) + Vector3.new((math.random() - 0.5) * dist * dt * 50, (math.random() - 0.5) * dist * dt * 50, (math.random() - 0.5) * dist * dt * 50)
        State.voidPos = pos
        return CFrame.new(pos)
    end
    return CFrame.new(base + Vector3.new(math.random(-dist, dist), math.random(-dist, dist), math.random(-dist, dist)))
end

local function checkVoidEvasion(pos)
    if not State.voidEvade or State.voidEvadeTimer > 0 then return pos end
    local minDist, threatVec = math.huge, Vector3.zero
    for _, player in ipairs(v1:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position + hrp.AssemblyLinearVelocity * 0.5 - pos).Magnitude
                if dist < minDist then
                    minDist = dist
                    threatVec = (hrp.Position + hrp.AssemblyLinearVelocity * 0.5 - pos).Unit
                end
            end
        end
    end
    if minDist < State.voidEvadeRadius then
        pos = pos - threatVec * State.voidEvadeSpeed * 0.5
        State.voidEvadeTimer = State.voidEvadeCD
    end
    return pos
end

local function doOrbit(dt, currentCF)
    local targetRoot = getTarget()
    if not targetRoot or not targetRoot.Parent then return currentCF end
    local now = tick()
    local targetPos = targetRoot.Position
    if State.orbitPredict then targetPos = targetPos + targetRoot.AssemblyLinearVelocity * 0.2 end

    local targetHead = targetRoot.Parent:FindFirstChild("Head") or targetRoot
    local enemyLook = targetHead.CFrame.LookVector
    local myPos = currentCF.Position
    local toMe = myPos - targetPos
    local aiming = false
    if toMe.Magnitude > 0.1 then aiming = enemyLook:Dot(toMe.Unit) > 0.5 end

    if now >= State.orbitPhaseUntil then
        if State.orbitEvadeAim and aiming and now - State.orbitLastDodge > State.orbitDodgeCooldown then
            State.orbitPhase = "dodge"
            State.orbitPhaseUntil = now + 0.15
            State.orbitLastDodge = now
            State.orbitEvadeAngle = math.random() * math.pi * 2
        else
            State.orbitPhase = "orbit"
            State.orbitPhaseUntil = now + 0.3
        end
    end

    if State.orbitPhase == "dodge" then
        local dodgeDir = Vector3.new(math.cos(State.orbitEvadeAngle), 0, math.sin(State.orbitEvadeAngle))
        local dodgePos = myPos + dodgeDir * State.orbitDodgeDist
        local outward = (myPos - targetPos)
        outward = Vector3.new(outward.X, 0, outward.Z)
        if outward.Magnitude > 0.1 then
            dodgePos = dodgePos + outward.Unit * 4
        end
        local dodgeCF = CFrame.new(dodgePos, Vector3.new(targetPos.X, dodgePos.Y, targetPos.Z))
        local spin = CFrame.Angles(0, math.rad(math.random(-180, 180)), 0)
        return dodgeCF * spin
    end

    State.orbitAngle = (State.orbitAngle + math.rad(State.orbitSpeed) * dt) % (2 * math.pi)
    local x, y, z = 0, 0, 0
    local radius = State.orbitDist
    if State.orbitMode == "Circle" then
        x = math.cos(State.orbitAngle) * radius; z = math.sin(State.orbitAngle) * radius; y = State.orbitHeight
    elseif State.orbitMode == "Figure 8" then
        x = math.sin(State.orbitAngle) * radius
        z = math.sin(State.orbitAngle) * math.cos(State.orbitAngle) * radius * 0.7
        y = State.orbitHeight
    elseif State.orbitMode == "Spiral In" then
        State.orbitCurRadius = math.max(1, (State.orbitCurRadius or radius) - dt * 20)
        x = math.cos(State.orbitAngle) * State.orbitCurRadius; z = math.sin(State.orbitAngle) * State.orbitCurRadius; y = State.orbitHeight
    elseif State.orbitMode == "Spiral Out" then
        State.orbitCurRadius = math.min(radius * 2, (State.orbitCurRadius or radius) + dt * 20)
        x = math.cos(State.orbitAngle) * State.orbitCurRadius; z = math.sin(State.orbitAngle) * State.orbitCurRadius; y = State.orbitHeight
    elseif State.orbitMode == "Bounce" then
        x = math.cos(State.orbitAngle) * radius; z = math.sin(State.orbitAngle) * radius
        y = State.orbitHeight + math.sin(tick() * 3) * 5
    end

    local dst = targetPos + Vector3.new(x, y, z)
    local smooth = myPos:Lerp(dst, State.orbitLerp)

    State.orbitTwist = ((State.orbitTwist or 0) + dt * State.orbitTwistSpeed) % 360
    local twistX = math.rad(math.sin(tick() * 40) * 60)
    local twistY = math.rad(State.orbitTwist)
    local twistZ = math.rad(math.cos(tick() * 35) * 60)
    local twistCF = CFrame.Angles(twistX, twistY, twistZ)

    if State.orbitFace then
        return CFrame.new(smooth, Vector3.new(targetPos.X, smooth.Y, targetPos.Z)) * twistCF
    end
    return CFrame.new(smooth) * twistCF
end

-- UE COUNTER (기존)
v2.Heartbeat:Connect(function()
    if not State.ueEnabled then return end
    local root = getRoot()
    if not root then return end
    local now = tick()
    if not State.ueHome then
        if math.abs(root.Position.Y) < 5000 then
            State.ueHome = root.CFrame
        else
            State.ueHome = CFrame.new(root.Position.X, 50, root.Position.Z)
        end
        State.ueCurrentY = State.ueBaseY
        State.ueLastStep = now
    end
    if now - State.ueLastStep >= State.ueStepCooldown then
        State.ueLastStep = now
        State.ueCurrentY = State.ueCurrentY + State.ueStepAmount
    end
    local targetRoot = getTarget()
    local jitterY = math.sin(now * 15) * State.ueJitterAmp
    local finalY = State.ueCurrentY + jitterY
    if now - State.ueNetLast > 0.15 then
        State.ueNetLast = now
        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(root, "NetworkIsSleeping", false)
                if targetRoot then
                    sethiddenproperty(targetRoot, "NetworkOwner", LocalPlayer)
                    sethiddenproperty(targetRoot, "NetworkIsSleeping", false)
                end
            end
            if root.SetNetworkOwner then root:SetNetworkOwner(LocalPlayer) end
            if targetRoot and targetRoot.SetNetworkOwner then targetRoot:SetNetworkOwner(LocalPlayer) end
        end)
    end
    if targetRoot then
        local lockCF = CFrame.new(targetRoot.Position.X, finalY, targetRoot.Position.Z)
        for _ = 1, 8 do
            root.CFrame = lockCF
            targetRoot.CFrame = lockCF
        end
        local targetHumanoid = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
        if targetHumanoid then targetHumanoid:ChangeState(Enum.HumanoidStateType.Physics) end
    else
        local lockCF = CFrame.new(root.Position.X, finalY, root.Position.Z)
        for _ = 1, 6 do
            root.CFrame = lockCF
        end
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end)

-- UE COUNTER V2
local function runUECounterV2()
    local character = LocalPlayer.Character
    if not character then
        character = LocalPlayer.CharacterAdded:Wait()
    end
    local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then
        HumanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    end
    if not HumanoidRootPart then return end

    local v25 = HumanoidRootPart.Position + Vector3.new(0, State.ueV2YDist, 0)
    HumanoidRootPart.CFrame = CFrame.new(v25)
end

task.spawn(function()
    while true do
        if State.ueV2Enabled then
            runUECounterV2()
            task.wait(math.max(State.ueV2Cooldown, 0.05))
        else
            task.wait(0.2)
        end
    end
end)

-- MAIN RENDER STEP
v2.RenderStepped:Connect(function(dt)
    local root = getRoot()
    if not root then
        if State.voidCamSaved then restoreCameraFromVoid() end
        return
    end
    if State.voidEvadeTimer > 0 then State.voidEvadeTimer = State.voidEvadeTimer - dt end

    if State.rage and rageActive then
        State.lastX, State.lastY, State.lastZ = root.Position.X, root.Position.Y, root.Position.Z
        return
    end
    if State.ueEnabled then
        State.lastX, State.lastY, State.lastZ = root.Position.X, root.Position.Y, root.Position.Z
        return
    end

    local cf = root.CFrame

    if State.voidEnabled then
        cf = doVoidSpam(dt, cf)
        cf = CFrame.new(checkVoidEvasion(cf.Position))
    else
        if State.voidCamSaved then restoreCameraFromVoid() end
        if State.orbitEnabled then cf = doOrbit(dt, cf) end
    end

    root.CFrame = cf
    State.lastX, State.lastY, State.lastZ = root.Position.X, root.Position.Y, root.Position.Z
end)

-- UI
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "chanhyuk_lua_v2_full"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    local success = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not success then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local clickAway = Instance.new("TextButton")
    clickAway.Size = UDim2.new(1, 0, 1, 0)
    clickAway.BackgroundTransparency = 1
    clickAway.Text = ""
    clickAway.AutoButtonColor = false
    clickAway.Visible = false
    clickAway.ZIndex = 50
    clickAway.Parent = gui

    local activeDropdown = nil
    local function closeActiveDropdown()
        if activeDropdown then activeDropdown.Visible = false; activeDropdown = nil end
        clickAway.Visible = false
    end
    clickAway.MouseButton1Click:Connect(closeActiveDropdown)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 420)
    frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.ClipsDescendants = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(180, 120, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = frame
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 40), Color3.fromRGB(10, 10, 15))
    gradient.Rotation = 45
    gradient.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, -24, 0, 32)
    titleBar.Position = UDim2.new(0, 12, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "chanhyuk lua free"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local titleLine = Instance.new("Frame")
    titleLine.Size = UDim2.new(1, -24, 0, 1)
    titleLine.Position = UDim2.new(0, 12, 1, -1)
    titleLine.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
    titleLine.BackgroundTransparency = 0.5
    titleLine.BorderSizePixel = 0
    titleLine.Parent = titleBar

    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -16, 0, 24)
    tabContainer.Position = UDim2.new(0, 8, 0, 36)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = frame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 2)
    tabLayout.Parent = tabContainer

    local coordCard = Instance.new("Frame")
    coordCard.Size = UDim2.new(1, -16, 0, 26)
    coordCard.Position = UDim2.new(0, 8, 0, 64)
    coordCard.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    coordCard.BackgroundTransparency = 0.2
    coordCard.BorderSizePixel = 0
    coordCard.Parent = frame

    local coordCorner = Instance.new("UICorner")
    coordCorner.CornerRadius = UDim.new(0, 6)
    coordCorner.Parent = coordCard

    local coordStroke = Instance.new("UIStroke")
    coordStroke.Color = Color3.fromRGB(180, 120, 255)
    coordStroke.Transparency = 0.5
    coordStroke.Parent = coordCard

    local coords = Instance.new("TextLabel")
    coords.Size = UDim2.new(1, 0, 1, 0)
    coords.BackgroundTransparency = 1
    coords.Text = "X: 0 | Y: 0 | Z: 0"
    coords.TextColor3 = Color3.fromRGB(255, 255, 255)
    coords.TextSize = 11
    coords.Font = Enum.Font.Code
    coords.TextXAlignment = Enum.TextXAlignment.Center
    coords.Parent = coordCard

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -10, 1, -100)
    content.Position = UDim2.new(0, 5, 0, 96)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 2
    content.ScrollBarImageColor3 = Color3.fromRGB(180, 120, 255)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local yCounter = 0
    local function clearContent()
        closeActiveDropdown()
        for _, child in ipairs(content:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        yCounter = 0
    end

    local function addHeader(text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(180, 120, 255)
        label.TextSize = 10
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = yCounter
        label.Parent = content
        yCounter = yCounter + 1
    end

    local function addToggle(text, default, callback)
        local container = Instance.new("TextButton")
        container.Size = UDim2.new(1, 0, 0, 24)
        container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        container.BackgroundTransparency = 0.3
        container.BorderSizePixel = 0
        container.Text = ""
        container.AutoButtonColor = false
        container.LayoutOrder = yCounter
        container.Parent = content
        local cornerInner = Instance.new("UICorner")
        cornerInner.CornerRadius = UDim.new(0, 6)
        cornerInner.Parent = container
        local strokeInner = Instance.new("UIStroke")
        strokeInner.Color = Color3.fromRGB(60, 60, 80)
        strokeInner.Thickness = 1
        strokeInner.Transparency = 0.5
        strokeInner.Parent = container
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = default and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 210)
        label.TextSize = 11
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container
        local switchBg = Instance.new("Frame")
        switchBg.Size = UDim2.new(0, 28, 0, 14)
        switchBg.Position = UDim2.new(1, -38, 0.5, -7)
        switchBg.BackgroundColor3 = default and Color3.fromRGB(180, 120, 255) or Color3.fromRGB(50, 50, 60)
        switchBg.BorderSizePixel = 0
        switchBg.Parent = container
        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = switchBg
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, 10, 0, 10)
        circle.Position = default and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        circle.BorderSizePixel = 0
        circle.Parent = switchBg
        local circleCorner = Instance.new("UICorner")
        circleCorner.CornerRadius = UDim.new(1, 0)
        circleCorner.Parent = circle
        local isOn = default
        local function updateVisuals()
            v4:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = isOn and Color3.fromRGB(180, 120, 255) or Color3.fromRGB(50, 50, 60)}):Play()
            v4:Create(circle, TweenInfo.new(0.2), {Position = isOn and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)}):Play()
            label.TextColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 210)
        end
        container.MouseButton1Click:Connect(function()
            isOn = not isOn
            updateVisuals()
            callback(isOn)
        end)
        yCounter = yCounter + 1
    end

    local function addInput(text, default, callback, isString)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 32)
        container.BackgroundTransparency = 1
        container.LayoutOrder = yCounter
        container.Parent = content
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 12)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(150, 150, 160)
        label.TextSize = 9
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container
        local boxContainer = Instance.new("Frame")
        boxContainer.Size = UDim2.new(1, 0, 0, 18)
        boxContainer.Position = UDim2.new(0, 0, 0, 14)
        boxContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        boxContainer.BackgroundTransparency = 0.2
        boxContainer.Parent = container
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 4)
        boxCorner.Parent = boxContainer
        local boxStroke = Instance.new("UIStroke")
        boxStroke.Color = Color3.fromRGB(60, 60, 80)
        boxStroke.Thickness = 1
        boxStroke.Parent = boxContainer
        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -12, 1, 0)
        textBox.Position = UDim2.new(0, 6, 0, 0)
        textBox.BackgroundTransparency = 1
        textBox.Text = tostring(default)
        textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textBox.TextSize = 10
        textBox.Font = Enum.Font.Code
        textBox.ClearTextOnFocus = false
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.Parent = boxContainer
        textBox.FocusLost:Connect(function()
            if isString then callback(textBox.Text)
            else
                local num = tonumber(textBox.Text)
                if num then callback(num) else textBox.Text = tostring(default) end
            end
        end)
        yCounter = yCounter + 1
    end

    local function addDropdown(text, options, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 32)
        container.BackgroundTransparency = 1
        container.LayoutOrder = yCounter
        container.Parent = content
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 12)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(150, 150, 160)
        label.TextSize = 9
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 18)
        button.Position = UDim2.new(0, 0, 0, 14)
        button.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        button.BackgroundTransparency = 0.2
        button.BorderSizePixel = 0
        button.Text = "  " .. tostring(default) .. "  v"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 10
        button.Font = Enum.Font.Code
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.AutoButtonColor = false
        button.Parent = container
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = button
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(60, 60, 80)
        btnStroke.Thickness = 1
        btnStroke.Parent = button
        local list = Instance.new("Frame")
        list.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 100
        list.Parent = gui
        local listCorner = Instance.new("UICorner")
        listCorner.CornerRadius = UDim.new(0, 4)
        listCorner.Parent = list
        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Color3.fromRGB(180, 120, 255)
        listStroke.Thickness = 1
        listStroke.Parent = list
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = list
        button.MouseButton1Click:Connect(function()
            if list.Visible then
                closeActiveDropdown()
            else
                closeActiveDropdown()
                local btnPos = button.AbsolutePosition
                local guiPos = gui.AbsolutePosition or Vector2.zero
                list.Position = UDim2.fromOffset(btnPos.X - guiPos.X, btnPos.Y - guiPos.Y + button.AbsoluteSize.Y)
                list.Size = UDim2.fromOffset(button.AbsoluteSize.X, #options * 18)
                list.Visible = true
                activeDropdown = list
                clickAway.Visible = true
            end
        end)
        for i, option in ipairs(options) do
            local optionBtn = Instance.new("TextButton")
            optionBtn.Size = UDim2.new(1, 0, 0, 18)
            optionBtn.BackgroundTransparency = 1
            optionBtn.Text = "  " .. tostring(option)
            optionBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
            optionBtn.TextSize = 10
            optionBtn.Font = Enum.Font.Code
            optionBtn.TextXAlignment = Enum.TextXAlignment.Left
            optionBtn.LayoutOrder = i
            optionBtn.ZIndex = 100
            optionBtn.AutoButtonColor = false
            optionBtn.Parent = list
            optionBtn.MouseEnter:Connect(function() optionBtn.BackgroundTransparency = 0.8 end)
            optionBtn.MouseLeave:Connect(function() optionBtn.BackgroundTransparency = 1 end)
            optionBtn.MouseButton1Click:Connect(function()
                button.Text = "  " .. tostring(option) .. "  v"
                callback(option)
                closeActiveDropdown()
            end)
        end
        yCounter = yCounter + 1
    end

    local function addButton(text, color, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 24)
        button.BackgroundColor3 = color or Color3.fromRGB(180, 120, 255)
        button.BackgroundTransparency = 0.2
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 11
        button.Font = Enum.Font.GothamBold
        button.AutoButtonColor = false
        button.LayoutOrder = yCounter
        button.Parent = content
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = button
        button.MouseButton1Click:Connect(callback)
        yCounter = yCounter + 1
    end

    local tabs = {"Main", "Void", "Orbit", "UE V2", "Config", "Misc"}

    local function buildMain()
        clearContent()
        addHeader("RAGEBOT")
        addToggle("Enable Rage", State.rage, function(v) State.rage = v; if v then startRage() else stopRage() end end)
        addInput("Rage Y", State.rageY, function(v) State.rageY = v end, false)
        addInput("Target Name", State.targetName, function(v) State.targetName = tostring(v) end, true)

        addHeader("UE COUNTER (ORIGINAL)")
        addToggle("Enable UE Counter", State.ueEnabled, function(v)
            State.ueEnabled = v
            if not v then State.ueHome = nil end
        end)
        addInput("UE Base Y", State.ueBaseY, function(v) State.ueBaseY = v; State.ueCurrentY = v end, false)
        addInput("UE Step Amount", State.ueStepAmount, function(v) State.ueStepAmount = v end, false)
        addInput("UE Step CD (s)", State.ueStepCooldown, function(v) State.ueStepCooldown = v end, false)
        addInput("UE Jitter Amp", State.ueJitterAmp, function(v) State.ueJitterAmp = v end, false)
    end

    local function buildVoid()
        clearContent()
        addHeader("VOID SPAM")
        addToggle("Enable Void", State.voidEnabled, function(v) State.voidEnabled = v; if not v and State.voidCamSaved then restoreCameraFromVoid() end end)
        addDropdown("Void Method", {"HvH", "Chanhyuk", "Quantum", "TP Everywhere", "Chaos"}, State.voidMethod, function(v) State.voidMethod = v end)
        addInput("Delay (ms)", State.voidDelay, function(v) State.voidDelay = v end, false)
        addInput("Speed Mult", State.voidSpeed, function(v) State.voidSpeed = v end, false)
        addInput("Radius", State.voidDist, function(v) State.voidDist = v end, false)
        addHeader("VOID EVASION")
        addToggle("Evade Enemies", State.voidEvade, function(v) State.voidEvade = v end)
        addInput("Evade Radius", State.voidEvadeRadius, function(v) State.voidEvadeRadius = v end, false)
        addInput("Evade Speed", State.voidEvadeSpeed, function(v) State.voidEvadeSpeed = v end, false)
    end

    local function buildOrbit()
        clearContent()
        addHeader("ORBIT")
        addToggle("Enable Orbit", State.orbitEnabled, function(v) State.orbitEnabled = v end)
        addDropdown("Mode", {"Circle", "Figure 8", "Spiral In", "Spiral Out", "Bounce"}, State.orbitMode, function(v) State.orbitMode = v; State.orbitCurRadius = State.orbitDist end)
        addInput("Radius", State.orbitDist, function(v) State.orbitDist = v; State.orbitCurRadius = v end, false)
        addInput("Speed (deg/s)", State.orbitSpeed, function(v) State.orbitSpeed = v end, false)
        addInput("Height", State.orbitHeight, function(v) State.orbitHeight = v end, false)
        addInput("Smoothing (0-1)", State.orbitLerp, function(v) State.orbitLerp = v end, false)
        addHeader("ORBIT OPTIONS")
        addToggle("Predict Target", State.orbitPredict, function(v) State.orbitPredict = v end)
        addToggle("Face Target", State.orbitFace, function(v) State.orbitFace = v end)
        addHeader("AIM EVADE")
        addToggle("Evade When Aimed", State.orbitEvadeAim, function(v) State.orbitEvadeAim = v end)
        addInput("Aim Radius", State.orbitEvadeRadius, function(v) State.orbitEvadeRadius = v end, false)
        addInput("Dodge Dist", State.orbitDodgeDist, function(v) State.orbitDodgeDist = v end, false)
        addInput("Dodge Cooldown", State.orbitDodgeCooldown, function(v) State.orbitDodgeCooldown = v end, false)
        addHeader("TWIST")
        addInput("Twist Speed", State.orbitTwistSpeed, function(v) State.orbitTwistSpeed = v end, false)
    end

    local function buildUEV2()
        clearContent()
        addHeader("UE COUNTER V2 (BROKECHEAT)")
        addToggle("UE Counter V2", State.ueV2Enabled, function(v)
            State.ueV2Enabled = v
        end)
        addInput("Teleport Cooldown", State.ueV2Cooldown, function(v) State.ueV2Cooldown = v end, false)
        addInput("Y Distance", State.ueV2YDist, function(v) State.ueV2YDist = v end, false)

        addHeader("INFO")
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, 0, 0, 45)
        info.BackgroundTransparency = 1
        info.Text = "Counters UE's ragebot by increasing your Y coordinates based on Brokecheat setup."
        info.TextColor3 = Color3.fromRGB(150, 150, 160)
        info.TextSize = 10
        info.Font = Enum.Font.Gotham
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextWrapped = true
        info.LayoutOrder = yCounter
        info.Parent = content
        yCounter = yCounter + 1
    end

    local function buildConfig()
        clearContent()
        addHeader("CONFIG MANAGEMENT")

        local selectedConfigName = "default"
        local configsList = getConfigsList()

        addInput("Config Name", "my_config", function(v)
            selectedConfigName = tostring(v)
        end, true)

        addButton("Create / Save Config", Color3.fromRGB(60, 40, 100), function()
            saveConfig(selectedConfigName)
        end)

        addDropdown("Select Config", configsList, configsList[1] or "default", function(v)
            selectedConfigName = v
        end)

        addButton("Load Selected Config", Color3.fromRGB(40, 80, 40), function()
            loadConfig(selectedConfigName)
        end)

        addButton("Delete Selected Config", Color3.fromRGB(100, 40, 40), function()
            deleteConfig(selectedConfigName)
        end)

        addHeader("AUTOLOAD (자동 실행)")
        addButton("Set As Autoload", Color3.fromRGB(50, 100, 50), function()
            setAutoload(selectedConfigName)
        end)

        addButton("Cancel Autoload", Color3.fromRGB(100, 50, 50), function()
            cancelAutoload()
        end)
    end

    local function buildMisc()
        clearContent()
        addHeader("TOOLS")
        addButton("Fast Attack", Color3.fromRGB(40, 80, 40), function()
            if game.GameId ~= 6035872082 then return end
            local ok, items = pcall(function() return require(v5.Modules.ItemLibrary).Items end)
            if not ok or not items then return end
            for _, data in pairs(items) do
                if typeof(data) == "table" then
                    if data.AttackCooldown then data.AttackCooldown = 0.001 end
                    if data.SwingCooldown then data.SwingCooldown = 0.001 end
                    if data.ShootCooldown then data.ShootCooldown = 0.001 end
                end
            end
        end)

        addHeader("INFO")
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, 0, 0, 60)
        info.BackgroundTransparency = 1
        info.Text = "chanhyuk lua free - Full Mod\nRage, UE V1/V2, Void, Orbit, Fast Attack & Configs"
        info.TextColor3 = Color3.fromRGB(150, 150, 160)
        info.TextSize = 10
        info.Font = Enum.Font.Gotham
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextWrapped = true
        info.LayoutOrder = yCounter
        info.Parent = content
        yCounter = yCounter + 1
    end

    for _, name in ipairs(tabs) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 38, 1, 0)
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        button.BackgroundTransparency = 0.5
        button.BorderSizePixel = 0
        button.Text = name
        button.TextColor3 = Color3.fromRGB(200, 200, 210)
        button.TextSize = 9
        button.Font = Enum.Font.GothamBold
        button.AutoButtonColor = false
        button.Parent = tabContainer
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = button
        button.MouseButton1Click:Connect(function()
            if name == "Main" then buildMain()
            elseif name == "Void" then buildVoid()
            elseif name == "Orbit" then buildOrbit()
            elseif name == "UE V2" then buildUEV2()
            elseif name == "Config" then buildConfig()
            elseif name == "Misc" then buildMisc() end
            for _, b in ipairs(tabContainer:GetChildren()) do
                if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(30, 30, 40) end
            end
            button.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
        end)
    end

    buildMain()

    v2.RenderStepped:Connect(function()
        coords.Text = string.format("X: %.0f | Y: %.0f | Z: %.0f", State.lastX, State.lastY, State.lastZ)
    end)
end

createUI()
