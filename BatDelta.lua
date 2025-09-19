-- BatDelta — Versão final com BatBtn arrastável
-- Substitua seu scripts1.lua por este conteúdo.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- CONFIG
local COMPATIBLE_COMMUNITY_ID = 6042520
local GAMEPASS_ID = 1382208297
local VALIDITY_SECONDS = 2 * 24 * 60 * 60 -- 2 dias
local DATA_FILENAME = "batdelta_key_status.json"
local USED_FILENAME = "batdelta_used_keys.json"

local function log(...) print("[BatDelta]", ...) end
local function warn(...) warn("[BatDelta]", ...) end

-- robust LocalPlayer
local function getLocalPlayer(timeout)
    timeout = timeout or 6
    local t0 = tick()
    while tick() - t0 < timeout do
        if Players.LocalPlayer then return Players.LocalPlayer end
        task.wait(0.05)
    end
    local pls = Players:GetPlayers()
    if #pls > 0 then return pls[1] end
    return Players.PlayerAdded:Wait(4)
end
local player = getLocalPlayer(6)
if not player then warn("LocalPlayer não encontrado"); return end

local function findGuiParent(pl)
    if pl then
        local ok, pg = pcall(function() return pl:FindFirstChild("PlayerGui") end)
        if ok and pg then return pg end
    end
    if type(gethui) == "function" then
        local ok, g = pcall(gethui)
        if ok and g then return g end
    end
    return CoreGui
end
local guiParent = findGuiParent(player)

local function protectGui(g)
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(function() syn.protect_gui(g) end)
    end
end

-- cleanup old GUIs
for _,c in ipairs(guiParent:GetChildren()) do
    if c.Name == "ChaveFlyGui" or c.Name == "BatMenuGui" or c.Name == "BatDetectGui" then
        pcall(function() c:Destroy() end)
    end
end

-- persistence (robust)
local localStatus = { users = {} }
local usedKeys = {}
local function safeDecodeJSON(s)
    if type(s) ~= "string" then return nil end
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    if ok then return res else return nil end
end
local function loadLocal()
    if type(isfile) == "function" and isfile(DATA_FILENAME) and type(readfile) == "function" then
        local ok, cont = pcall(function() return readfile(DATA_FILENAME) end)
        if ok and cont then
            local dec = safeDecodeJSON(cont)
            if type(dec) == "table" and type(dec.users) == "table" then
                localStatus = dec
            else
                localStatus = { users = {} }
            end
        end
    end
    if type(isfile) == "function" and isfile(USED_FILENAME) and type(readfile) == "function" then
        local ok2, cont2 = pcall(function() return readfile(USED_FILENAME) end)
        if ok2 and cont2 then
            local dec2 = safeDecodeJSON(cont2)
            if type(dec2) == "table" then usedKeys = dec2 else usedKeys = {} end
        end
    end
    if type(localStatus) ~= "table" then localStatus = { users = {} } end
    if type(localStatus.users) ~= "table" then localStatus.users = {} end
    if type(usedKeys) ~= "table" then usedKeys = {} end
end
local function saveLocal()
    if type(writefile) == "function" then
        pcall(function() writefile(DATA_FILENAME, HttpService:JSONEncode(localStatus)) end)
        pcall(function() writefile(USED_FILENAME, HttpService:JSONEncode(usedKeys)) end)
    end
end
loadLocal()

local function isLocallyValidatedForPlayer(pl)
    if not pl or not pl.UserId then return false end
    if type(localStatus) ~= "table" or type(localStatus.users) ~= "table" then return false end
    local uid = tostring(pl.UserId)
    local v = localStatus.users[uid]
    if type(v) ~= "number" then return false end
    return os.time() < v
end

-- UI helpers
local function capsule(text, bg)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(150,34)
    l.BackgroundColor3 = bg
    l.TextColor3 = Color3.new(1,1,1)
    l.Text = text
    l.Font = Enum.Font.SourceSansBold
    l.TextScaled = true
    l.BorderSizePixel = 0
    return l
end
local function pillBtn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(150,34)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.Font = Enum.Font.SourceSansBold
    b.TextScaled = true
    b.BorderSizePixel = 0
    return b
end

--------------------------------------------------------------------------------
-- Detection GUI
--------------------------------------------------------------------------------
local function createDetectionGui(parent)
    local SG = Instance.new("ScreenGui")
    SG.Name = "BatDetectGui"
    SG.ResetOnSpawn = false
    pcall(function() SG.IgnoreGuiInset = true end)
    SG.Parent = parent
    protectGui(SG)

    local Frame = Instance.new("Frame", SG)
    Frame.Size = UDim2.fromOffset(520,120)
    Frame.Position = UDim2.new(0.5, -260, 0.5, -60)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.BorderSizePixel = 0
    Frame.ZIndex = 300

    local Label = Instance.new("TextLabel", Frame)
    Label.Size = UDim2.new(1, -20, 1, -20)
    Label.Position = UDim2.new(0,10,0,10)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.SourceSansBold
    Label.TextSize = 20
    Label.TextWrapped = true
    Label.Text = "Detectando jogo..."
    Label.TextColor3 = Color3.new(1,1,1)
    Label.TextXAlignment = Enum.TextXAlignment.Center
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.ZIndex = 301

    local CloseBtn = Instance.new("TextButton", Frame)
    CloseBtn.Name = "DetectCloseBtn"
    CloseBtn.Size = UDim2.fromOffset(30,30)
    CloseBtn.Position = UDim2.new(1, -36, 0, 6)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.TextScaled = true
    CloseBtn.Visible = false
    CloseBtn.ZIndex = 305

    return { SG = SG, Frame = Frame, Label = Label, CloseBtn = CloseBtn }
end
local detectGui = createDetectionGui(guiParent)

--------------------------------------------------------------------------------
-- Key GUI
--------------------------------------------------------------------------------
local function createKeyGui(parent)
    local SG = Instance.new("ScreenGui")
    SG.Name = "ChaveFlyGui"
    SG.ResetOnSpawn = false
    pcall(function() SG.IgnoreGuiInset = true end)
    SG.Parent = parent
    protectGui(SG)

    local MainFrame = Instance.new("Frame", SG)
    MainFrame.Size = UDim2.new(0,320,0,200)
    MainFrame.Position = UDim2.new(0.33,0,0.32,0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true

    -- NOT draggable (per request)
    local Title = Instance.new("TextLabel", MainFrame)
    Title.Size = UDim2.new(1,0,0.18,0); Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundTransparency = 1; Title.Text = "Sistema de Chave"; Title.Font = Enum.Font.SourceSansBold; Title.TextScaled = true; Title.TextColor3 = Color3.new(1,1,1)

    local TextBox = Instance.new("TextBox", MainFrame)
    TextBox.Size = UDim2.new(0.82,0,0.22,0); TextBox.Position = UDim2.new(0.09,0,0.2,0)
    TextBox.Text = "Digite a chave aqui!"; TextBox.ClearTextOnFocus = false; TextBox.Font = Enum.Font.SourceSans
    TextBox.TextSize = 16; TextBox.TextColor3 = Color3.new(1,1,1); TextBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    TextBox.Focused:Connect(function() if TextBox.Text == "Digite a chave aqui!" then TextBox.Text = "" end end)

    local function mkBtn(parent, text, sizeX, posX, posY)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(sizeX,0,0.22,0)
        b.Position = UDim2.new(posX,0,posY,0)
        b.Text = text; b.Font = Enum.Font.SourceSansBold; b.TextSize = 16
        return b
    end

    local ChecarBtn = mkBtn(MainFrame, "Verificar", 0.38, 0.09, 0.52); ChecarBtn.BackgroundColor3 = Color3.fromRGB(70,200,80)
    local LinkBtn = mkBtn(MainFrame, "Link da chave", 0.38, 0.53, 0.52); LinkBtn.BackgroundColor3 = Color3.fromRGB(44,156,255)

    local PularBtn = Instance.new("TextButton", MainFrame)
    PularBtn.Size = UDim2.new(0.82,0,0.18,0)
    PularBtn.Position = UDim2.new(0.09,0,0.74,0)
    PularBtn.Text = "Pular Chave"; PularBtn.Font = Enum.Font.SourceSansBold; PularBtn.TextSize = 16
    PularBtn.BackgroundColor3 = Color3.fromRGB(200,70,70)

    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.Size = UDim2.new(1,0,0.16,0); StatusLabel.Position = UDim2.new(0,0,0.92,0)
    StatusLabel.BackgroundTransparency = 1; StatusLabel.Font = Enum.Font.SourceSans; StatusLabel.TextSize = 16; StatusLabel.TextColor3 = Color3.fromRGB(200,200,200); StatusLabel.Text = ""

    return { SG = SG, Frame = MainFrame, TextBox = TextBox, ChecarBtn = ChecarBtn, LinkBtn = LinkBtn, PularBtn = PularBtn, StatusLabel = StatusLabel }
end

-- secret pattern validation (kept secret)
local function isKeyPatternValid(s)
    if type(s) ~= "string" then return false end
    if #s ~= 10 then return false end
    if s:sub(1,1) ~= "B" then return false end
    if s:sub(-1,-1) ~= "@" then return false end
    return true
end

-- Remote notify
local function notifyServerKeyUsed(key, expireTimestamp)
    local names = { "BatDelta_KeyEvent", "BatKeyRemote", "BatDeltaKeyRemote", "BatKeyUsedEvent" }
    for _, n in ipairs(names) do
        local rem = ReplicatedStorage:FindFirstChild(n)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer({ key = key, userId = player.UserId, expire = expireTimestamp }) end)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Full menu implementation (complete)
--------------------------------------------------------------------------------
local function createFullMenu(parent)
    local SG = Instance.new("ScreenGui")
    SG.Name = "BatMenuGui"
    SG.ResetOnSpawn = false
    pcall(function() SG.IgnoreGuiInset = true end)
    SG.Parent = parent
    protectGui(SG)

    local vs = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    local width = math.clamp(math.floor(vs.X * 0.62), 520, 900)
    local height = math.clamp(math.floor(vs.Y * 0.6), 360, 720)

    local Main = Instance.new("Frame", SG)
    Main.Name = "Main"; Main.Size = UDim2.fromOffset(width, height)
    Main.Position = UDim2.new(0.5, -width/2, 0.5, -height/2)
    Main.BackgroundColor3 = Color3.fromRGB(70,70,74); Main.BorderSizePixel = 0

    local Header = Instance.new("TextLabel", Main)
    Header.Size = UDim2.new(1, -220, 0, 72); Header.Position = UDim2.new(0, 16, 0, 8)
    Header.BackgroundTransparency = 1; Header.Text = "99 noites na floresta"; Header.Font = Enum.Font.SourceSansBold; Header.TextScaled = true; Header.TextColor3 = Color3.new(1,1,1)

    local Marca = Instance.new("TextLabel", Main)
    Marca.Size = UDim2.fromOffset(160,28); Marca.Position = UDim2.new(0.5, -80, 1, -40)
    Marca.BackgroundTransparency = 1; Marca.Text = "BatDelta"; Marca.TextColor3 = Color3.fromRGB(255,180,80); Marca.Font = Enum.Font.SourceSansItalic; Marca.TextScaled = true

    local BtnArrow = Instance.new("TextButton", Main)
    BtnArrow.Size = UDim2.fromOffset(48,48); BtnArrow.Position = UDim2.new(1,-116,0,10)
    BtnArrow.BackgroundTransparency = 1; BtnArrow.Text = "◀"; BtnArrow.Font = Enum.Font.SourceSansBold; BtnArrow.TextScaled = true; BtnArrow.TextColor3 = Color3.fromRGB(60,240,80)

    local BtnX = Instance.new("TextButton", Main)
    BtnX.Size = UDim2.fromOffset(48,48); BtnX.Position = UDim2.new(1,-60,0,10)
    BtnX.BackgroundTransparency = 1; BtnX.Text = "X"; BtnX.Font = Enum.Font.SourceSansBold; BtnX.TextScaled = true; BtnX.TextColor3 = Color3.fromRGB(230,40,40)

    -- BatBtn (arrastável) criado no SG do menu para poder aparecer quando o menu for minimizado
    local BatBtn = Instance.new("TextButton", SG)
    BatBtn.Name = "BatBtn"; BatBtn.Size = UDim2.fromOffset(48,48); BatBtn.Position = UDim2.new(1, -80, 0, 18)
    BatBtn.BackgroundColor3 = Color3.fromRGB(30,30,34); BatBtn.Text = "🦇"; BatBtn.TextScaled = true; BatBtn.BorderSizePixel = 0; BatBtn.TextColor3 = Color3.new(1,1,1)
    BatBtn.Visible = false
    -- Tornar BatBtn arrastável:
    do
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil
        BatBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = BatBtn.Position
                dragInput = input
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        dragInput = nil
                    end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                local delta = input.Position - dragStart
                BatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- Confirm / ValuePrompt (igual às versões anteriores)
    local Confirm = Instance.new("Frame", Main)
    Confirm.Size = UDim2.fromOffset(360,140)
    Confirm.Position = UDim2.new(0.5,-180,0.5,-70)
    Confirm.BackgroundColor3 = Color3.fromRGB(28,28,30)
    Confirm.Visible = false
    Confirm.ZIndex = 150
    Confirm.BorderSizePixel = 0

    local ConfirmTxt = Instance.new("TextLabel", Confirm)
    ConfirmTxt.Size = UDim2.new(1, -20, 0, 60); ConfirmTxt.Position = UDim2.new(0, 10, 0, 10)
    ConfirmTxt.BackgroundTransparency = 1
    ConfirmTxt.Font = Enum.Font.SourceSansBold
    ConfirmTxt.TextSize = 20
    ConfirmTxt.TextWrapped = true
    ConfirmTxt.TextScaled = false
    ConfirmTxt.TextColor3 = Color3.new(1,1,1)
    ConfirmTxt.TextXAlignment = Enum.TextXAlignment.Center
    ConfirmTxt.TextYAlignment = Enum.TextYAlignment.Center
    ConfirmTxt.ZIndex = 152

    local BtnSim = Instance.new("TextButton", Confirm)
    BtnSim.Size = UDim2.fromOffset(140,36); BtnSim.Position = UDim2.new(0,20,0,88); BtnSim.BackgroundColor3 = Color3.fromRGB(60,200,90); BtnSim.Text = "Sim"; BtnSim.Font = Enum.Font.SourceSansBold; BtnSim.TextScaled = true; BtnSim.TextColor3 = Color3.new(1,1,1); BtnSim.ZIndex = 153
    local BtnNao = Instance.new("TextButton", Confirm)
    BtnNao.Size = UDim2.fromOffset(140,36); BtnNao.Position = UDim2.new(1,-160,0,88); BtnNao.BackgroundColor3 = Color3.fromRGB(220,60,60); BtnNao.Text = "Não"; BtnNao.Font = Enum.Font.SourceSansBold; BtnNao.TextScaled = true; BtnNao.TextColor3 = Color3.new(1,1,1); BtnNao.ZIndex = 153

    local ValuePrompt = Instance.new("Frame", Main)
    ValuePrompt.Size = UDim2.fromOffset(380,170)
    ValuePrompt.Position = UDim2.new(0.5,-190,0.5,-85)
    ValuePrompt.BackgroundColor3 = Color3.fromRGB(28,28,30)
    ValuePrompt.BorderSizePixel = 0
    ValuePrompt.Visible = false
    ValuePrompt.ZIndex = 160

    local VP_Title = Instance.new("TextLabel", ValuePrompt)
    VP_Title.Size = UDim2.new(1, -20, 0, 40); VP_Title.Position = UDim2.new(0, 10, 0, 8); VP_Title.BackgroundTransparency = 1
    VP_Title.Font = Enum.Font.SourceSansBold; VP_Title.TextScaled = false; VP_Title.TextSize = 18; VP_Title.TextColor3 = Color3.new(1,1,1); VP_Title.Text = "Valor atual:"

    local VP_Current = Instance.new("TextLabel", ValuePrompt)
    VP_Current.Size = UDim2.new(1, -20, 0, 36); VP_Current.Position = UDim2.new(0, 10, 0, 52)
    VP_Current.BackgroundColor3 = Color3.fromRGB(50,50,54); VP_Current.Font = Enum.Font.SourceSans; VP_Current.TextScaled = false; VP_Current.TextSize = 20; VP_Current.TextColor3 = Color3.new(1,1,1); VP_Current.Text = ""

    local VP_Input = Instance.new("TextBox", ValuePrompt)
    VP_Input.Size = UDim2.fromOffset(240,40); VP_Input.Position = UDim2.new(0.5, -120, 0, 112); VP_Input.BackgroundColor3 = Color3.fromRGB(60,60,64)
    VP_Input.Font = Enum.Font.SourceSans; VP_Input.TextColor3 = Color3.new(1,1,1); VP_Input.PlaceholderText = "Digite o novo número"; VP_Input.ClearTextOnFocus = false; VP_Input.Visible = true
    VP_Input.ZIndex = 162
    VP_Input.TextSize = 18

    local VP_Confirm = Instance.new("TextButton", ValuePrompt)
    VP_Confirm.Size = UDim2.fromOffset(100,40); VP_Confirm.Position = UDim2.new(1, -110, 0, 112); VP_Confirm.BackgroundColor3 = Color3.fromRGB(60,200,90); VP_Confirm.Font = Enum.Font.SourceSansBold; VP_Confirm.TextScaled = true; VP_Confirm.Text = "confirmar"; VP_Confirm.TextColor3 = Color3.new(1,1,1); VP_Confirm.ZIndex = 162

    local VP_Cancel = Instance.new("TextButton", ValuePrompt)
    VP_Cancel.Size = UDim2.fromOffset(100,40); VP_Cancel.Position = UDim2.new(0, 10, 0, 112); VP_Cancel.BackgroundColor3 = Color3.fromRGB(220,60,60); VP_Cancel.Font = Enum.Font.SourceSansBold; VP_Cancel.TextScaled = true; VP_Cancel.Text = "cancelar"; VP_Cancel.TextColor3 = Color3.new(1,1,1); VP_Cancel.ZIndex = 162

    VP_Input.FocusLost:Connect(function(enter) if enter then VP_Confirm:CaptureFocus() end end)

    -- states & variables
    local C_BLUE  = Color3.fromRGB(44,156,255)
    local C_PINK  = Color3.fromRGB(255,80,140)
    local C_GREEN = Color3.fromRGB(70,200,90)
    local C_ORANGE= Color3.fromRGB(255,140,40)
    local C_PURP  = Color3.fromRGB(200,80,255)
    local C_YELL  = Color3.fromRGB(240,185,40)
    local C_BLACK = Color3.fromRGB(20,20,20)
    local C_PEACH = Color3.fromRGB(255,190,160)

    local flightEnabled = false
    local flightSpeed = 16
    local infiniteJump = false; local jumpConn = nil
    local speedEnabled = false; local customWalk = 32; local originalWalk = 16
    local noclip = false
    local noclipConn = nil
    local noclipHB = nil
    local noclip_original = setmetatable({}, { __mode = "k" })

    local espOn = false
    local highlights = {}
    local billboards = {}
    local charAddedConns = {}
    local playerAddedConn, playerRemovingConn

    local function getMoveVectorFallback()
        local x,z=0,0
        if UIS:IsKeyDown(Enum.KeyCode.A) then x=x-1 end
        if UIS:IsKeyDown(Enum.KeyCode.D) then x=x+1 end
        if UIS:IsKeyDown(Enum.KeyCode.W) then z=z+1 end
        if UIS:IsKeyDown(Enum.KeyCode.S) then z=z-1 end
        return Vector3.new(x,0,z)
    end

    -- ValuePrompt setter
    local currentSetter = nil
    local function showValuePrompt(title, currentValue, setter)
        VP_Title.Text = title or "Valor atual:"
        VP_Current.Text = tostring(currentValue or "")
        VP_Input.Text = tostring(currentValue or "")
        VP_Input.Visible = true; VP_Confirm.Visible = true
        ValuePrompt.Visible = true
        Confirm.Visible = false
        currentSetter = setter
        VP_Input:CaptureFocus()
    end
    VP_Confirm.MouseButton1Click:Connect(function()
        local n = tonumber(VP_Input.Text)
        if currentSetter and n then pcall(currentSetter, n) end
        ValuePrompt.Visible = false
        currentSetter = nil
    end)
    VP_Cancel.MouseButton1Click:Connect(function() ValuePrompt.Visible = false; currentSetter = nil end)

    -- confirm helper
    local confirmYesCb = nil
    local confirmNoCb = nil
    local function showConfirm(text, yesColor, noColor, yesCb, noCb)
        ConfirmTxt.Text = tostring(text or "")
        ConfirmTxt.Visible = true
        ConfirmTxt.TextWrapped = true
        ConfirmTxt.TextXAlignment = Enum.TextXAlignment.Center
        ConfirmTxt.TextYAlignment = Enum.TextYAlignment.Center
        BtnSim.BackgroundColor3 = yesColor or Color3.fromRGB(60,200,90)
        BtnNao.BackgroundColor3 = noColor or Color3.fromRGB(220,60,60)
        Confirm.Visible = true
        ValuePrompt.Visible = false
        confirmYesCb = yesCb
        confirmNoCb = noCb
    end
    BtnSim.MouseButton1Click:Connect(function()
        Confirm.Visible = false
        if type(confirmYesCb) == "function" then pcall(confirmYesCb) end
        confirmYesCb = nil; confirmNoCb = nil
    end)
    BtnNao.MouseButton1Click:Connect(function()
        Confirm.Visible = false
        if type(confirmNoCb) == "function" then pcall(confirmNoCb) end
        confirmYesCb = nil; confirmNoCb = nil
    end)

    -- Flight implementation
    local controlModule = nil
    pcall(function()
        local ps = player:WaitForChild("PlayerScripts", 2)
        if ps then
            local pm = ps:FindFirstChild("PlayerModule")
            if pm and pm:FindFirstChild("ControlModule") then
                controlModule = require(pm:WaitForChild("ControlModule"))
            end
        end
    end)

    local flightforce = Instance.new("BodyVelocity")
    flightforce.MaxForce = Vector3.new(1, 1, 1) * (10^6)
    flightforce.P = 10^6

    local flightGryo = Instance.new("BodyGyro")
    flightGryo.MaxTorque = Vector3.new(1, 1, 1) * (10^6)
    flightGryo.P = 10^6

    local flying = false
    local isjumping = false
    local flightHB = nil

    local function stateChange(old, new)
        if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Freefall then
            isjumping = true
        elseif new == Enum.HumanoidStateType.Landed then
            isjumping = false
        end
    end

    local function ToggleFlight(force)
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return false end

        if not force then
            if not isjumping or hum:GetState() ~= Enum.HumanoidStateType.Freefall then
                return false
            end
        end

        flying = not flying
        flightGryo.Parent = flying and hrp or nil
        flightforce.Parent = flying and hrp or nil
        flightGryo.CFrame = hrp.CFrame
        flightforce.Velocity = Vector3.new()

        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = flying end

        if flying then
            if flightHB then flightHB:Disconnect(); flightHB = nil end
            flightHB = RunService.Heartbeat:Connect(function()
                if not flying then return end
                local movevector = Vector3.new(0,0,0)
                if controlModule and type(controlModule.GetMoveVector) == "function" then
                    pcall(function()
                        local mv = controlModule:GetMoveVector()
                        if mv then movevector = Vector3.new(mv.X or 0, 0, mv.Z or 0) end
                    end)
                else
                    movevector = getMoveVectorFallback()
                end

                local cam = Workspace.CurrentCamera
                if not cam then return end
                local direction = cam.CFrame.RightVector * (movevector.X) + cam.CFrame.LookVector * (movevector.Z * -1)
                if direction:Dot(direction) > 0 then direction = direction.Unit else direction = Vector3.new() end

                flightGryo.CFrame = cam.CFrame
                flightforce.Velocity = direction * (flightSpeed or 100)
            end)
        else
            if flightHB then flightHB:Disconnect(); flightHB = nil end
            if flightforce and flightforce.Parent then flightforce.Parent = nil end
            if flightGryo and flightGryo.Parent then flightGryo.Parent = nil end
            local animate = char:FindFirstChild("Animate")
            if animate then animate.Disabled = false end
        end

        return true
    end

    local function attachStateConn(ch)
        local hum = ch:FindFirstChild("Humanoid") or ch:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.StateChanged:Connect(stateChange) end) end
    end
    if player.Character then attachStateConn(player.Character) end
    player.CharacterAdded:Connect(function(ch) task.wait(0.2); attachStateConn(ch) end)

    -- Noclip
    local function ensurePartNoCollide(part)
        if part and part:IsA("BasePart") then
            noclip_original[part] = part.CanCollide
            pcall(function() part.CanCollide = false end)
        end
    end

    local function enableNoclip()
        if noclip then return end
        noclip_original = setmetatable({}, { __mode = "k" })
        local ch = player.Character
        if not ch then return end
        for _, part in ipairs(ch:GetDescendants()) do
            if part:IsA("BasePart") then ensurePartNoCollide(part) end
        end
        noclipConn = ch.DescendantAdded:Connect(function(desc) if desc:IsA("BasePart") then ensurePartNoCollide(desc) end end)
        noclipHB = RunService.Heartbeat:Connect(function()
            if not noclip then return end
            local ch2 = player.Character
            if not ch2 then return end
            local hrp = ch2:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _,part in ipairs(ch2:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    pcall(function() part.CanCollide = false end)
                end
            end
            local origin = hrp.Position
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {ch2}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local maxDist = 6
            local ray = Workspace:Raycast(origin, Vector3.new(0, -maxDist, 0), params)
            if ray and ray.Position then
                local groundY = ray.Position.Y
                local targetY = groundY + 3
                if hrp.Position.Y < targetY - 0.2 then
                    local newPos = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z)
                    pcall(function() hrp.CFrame = CFrame.new(newPos, newPos + hrp.CFrame.LookVector) end)
                end
            end
        end)
        noclip = true
    end

    local function disableNoclip()
        if not noclip then return end
        local ch = player.Character
        if ch then
            for part, orig in pairs(noclip_original) do
                if part and part:IsA("BasePart") then pcall(function() part.CanCollide = orig end) end
            end
        end
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        if noclipHB then noclipHB:Disconnect(); noclipHB = nil end
        noclip_original = setmetatable({}, { __mode = "k" })
        noclip = false
    end

    -- Grid + UI rows
    local grid = Instance.new("Frame", Main)
    grid.Size = UDim2.new(1,-40,1,-94); grid.Position = UDim2.new(0,20,0,74); grid.BackgroundTransparency = 1

    local rowY = {0,46,92,138,184,234}
    local function place(obj, x, row) obj.Parent = grid; obj.Position = UDim2.new(0, x, 0, rowY[row]) end

    local L1A = capsule("VOAR", C_BLUE); place(L1A, 0, 1)
    local L1B = pillBtn("desativado", C_PINK); place(L1B, 170, 1)
    local L1C = pillBtn("velocidade", C_ORANGE); place(L1C, 340, 1)

    local L2A = capsule("salto infinito", C_PURP); place(L2A, 0, 2)
    local L2B = pillBtn("desativado", C_PINK); place(L2B, 170, 2)

    local L3A = capsule("velocidade", C_YELL); place(L3A, 0, 3)
    local L3B = pillBtn("desativado", C_PINK); place(L3B, 170, 3)
    local L3C = pillBtn("tamanho da velocidade", C_ORANGE); place(L3C, 340, 3)

    local L4A = capsule("Noclip", C_BLACK); place(L4A, 0, 4)
    local L4B = pillBtn("desativado", C_PINK); place(L4B, 170, 4)

    local L5A = capsule("player esp", C_PEACH); place(L5A, 0, 5)
    local L5B = pillBtn("desativado", C_PINK); place(L5B, 170, 5)

    local VisualTxt = Instance.new("TextLabel", grid)
    VisualTxt.Size = UDim2.fromOffset(140,28)
    VisualTxt.BackgroundTransparency = 1
    VisualTxt.Position = UDim2.new(0, 10, 0, rowY[6])
    VisualTxt.Text = "(visual)"
    VisualTxt.TextColor3 = Color3.fromRGB(240,220,60)
    VisualTxt.Font = Enum.Font.SourceSansBold
    VisualTxt.TextScaled = true

    -- debounce
    local db = {}
    local function safe(k, fn) if db[k] then return end; db[k] = true; pcall(fn); task.delay(0.12, function() db[k] = nil end) end

    local function refreshFlightBtn() if flightEnabled then L1B.Text="ativado"; L1B.BackgroundColor3=C_GREEN else L1B.Text="desativado"; L1B.BackgroundColor3=C_PINK end end
    local function refreshInfBtn() if infiniteJump then L2B.Text="ativado"; L2B.BackgroundColor3=C_GREEN else L2B.Text="desativado"; L2B.BackgroundColor3=C_PINK end end
    local function refreshRunBtn() if speedEnabled then L3B.Text="ativado"; L3B.BackgroundColor3=C_GREEN else L3B.Text="desativado"; L3B.BackgroundColor3=C_PINK end end
    local function refreshNoclipBtn() if noclip then L4B.Text="ativado"; L4B.BackgroundColor3=C_GREEN else L4B.Text="desativado"; L4B.BackgroundColor3=C_PINK end end
    local function refreshESPBtn() if espOn then L5B.Text="ativado"; L5B.BackgroundColor3=C_GREEN else L5B.Text="desativado"; L5B.BackgroundColor3=C_PINK end end

    -- ESP helpers
    local function makeESPForPlayer(pl)
        if not pl or pl==player then return end
        if not pl.Character then return end
        if not pl.Character:FindFirstChild("BatESP_Highlight") then
            local h = Instance.new("Highlight")
            h.Name = "BatESP_Highlight"
            h.Parent = pl.Character
            h.FillTransparency = 1
            h.OutlineTransparency = 0
            h.OutlineColor = Color3.fromRGB(255,50,50)
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlights[pl] = h
        end
        if not pl.Character:FindFirstChild("BatESP_Billboard") then
            local attachPart = pl.Character:FindFirstChild("Head") or pl.Character:FindFirstChild("HumanoidRootPart")
            if attachPart then
                local bg = Instance.new("BillboardGui")
                bg.Name = "BatESP_Billboard"
                bg.AlwaysOnTop = true
                bg.Size = UDim2.new(0,60,0,60)
                bg.StudsOffset = Vector3.new(0, 2.4, 0)
                bg.Parent = attachPart

                local frame = Instance.new("Frame", bg)
                frame.Size = UDim2.new(1,0,1,0)
                frame.Position = UDim2.new(0,0,0,0)
                frame.BackgroundTransparency = 1
                frame.BorderSizePixel = 0

                local corner = Instance.new("UICorner", frame)
                corner.CornerRadius = UDim.new(1,0)

                local stroke = Instance.new("UIStroke", frame)
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Color = Color3.fromRGB(255,50,50)
                stroke.Thickness = 3

                billboards[pl] = bg
            end
        end
    end

    local function removeESPForPlayer(pl)
        if highlights[pl] then pcall(function() highlights[pl]:Destroy() end) highlights[pl]=nil end
        if billboards[pl] then pcall(function() billboards[pl]:Destroy() end) billboards[pl]=nil end
        if charAddedConns[pl] then pcall(function() charAddedConns[pl]:Disconnect() end) charAddedConns[pl]=nil end
    end

    -- WIRING (buttons and logic)
    L1B.MouseButton1Click:Connect(function()
        safe("fly", function()
            local ok = ToggleFlight(true)
            if ok then
                flightEnabled = not flightEnabled
                refreshFlightBtn()
            else
                if keyGui and keyGui.StatusLabel then
                    keyGui.StatusLabel.Text = "Impossível ativar voo agora"
                    task.delay(1.2, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
                end
            end
        end)
    end)

    L1C.MouseButton1Click:Connect(function()
        safe("flight_speed", function()
            showConfirm("Você quer mudar a velocidade do VOAR? (atual: "..tostring(flightSpeed)..")", Color3.fromRGB(60,200,90), Color3.fromRGB(220,60,60), function()
                showValuePrompt("Velocidade do VOAR", flightSpeed, function(n)
                    flightSpeed = math.clamp(tonumber(n) or flightSpeed, 1, 2000)
                    log("flightSpeed =", flightSpeed)
                end)
            end, function() end)
        end)
    end)

    L2B.MouseButton1Click:Connect(function()
        safe("inf", function()
            infiniteJump = not infiniteJump
            if infiniteJump then
                if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
                jumpConn = UIS.JumpRequest:Connect(function() local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end)
            else
                if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
            end
            refreshInfBtn()
        end)
    end)

    L3B.MouseButton1Click:Connect(function()
        safe("run", function()
            speedEnabled = not speedEnabled
            local ch = player.Character; local h = ch and ch:FindFirstChildOfClass("Humanoid")
            if speedEnabled then
                if h then originalWalk = h.WalkSpeed end
                if not customWalk then customWalk = 32 end
                if h then h.WalkSpeed = tonumber(customWalk) or 32 end
            else
                if h then h.WalkSpeed = originalWalk end
            end
            refreshRunBtn()
        end)
    end)

    L3C.MouseButton1Click:Connect(function()
        safe("walk_size", function()
            showConfirm("Você quer mudar o tamanho da velocidade? (atual: "..tostring(customWalk)..")", Color3.fromRGB(60,200,90), Color3.fromRGB(220,60,60), function()
                showValuePrompt("Tamanho da velocidade (WalkSpeed)", customWalk, function(n)
                    customWalk = math.clamp(tonumber(n) or customWalk, 1, 1000)
                    if speedEnabled then
                        local ch = player.Character; local h = ch and ch:FindFirstChildOfClass("Humanoid")
                        if h then h.WalkSpeed = customWalk end
                    end
                    log("WalkSpeed=", customWalk)
                end)
            end, function() end)
        end)
    end)

    L4B.MouseButton1Click:Connect(function()
        safe("noclip", function()
            if not noclip then enableNoclip() else disableNoclip() end
            refreshNoclipBtn()
        end)
    end)

    L5B.MouseButton1Click:Connect(function() safe("esp", function()
        espOn = not espOn
        if not espOn then
            for pl,_ in pairs(highlights) do removeESPForPlayer(pl) end
            for _,cn in pairs(charAddedConns) do pcall(function() cn:Disconnect() end) end
            charAddedConns = {}
            if playerAddedConn then pcall(function() playerAddedConn:Disconnect() end) playerAddedConn=nil end
            highlights = {}
            billboards = {}
        else
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl ~= player then
                    if pl.Character then makeESPForPlayer(pl) end
                    charAddedConns[pl] = pl.CharacterAdded:Connect(function(ch) task.wait(0.12); if espOn and pl.Character then makeESPForPlayer(pl) end end)
                end
            end
            playerAddedConn = Players.PlayerAdded:Connect(function(pl)
                if pl ~= player then
                    charAddedConns[pl] = pl.CharacterAdded:Connect(function(ch) task.wait(0.12); if espOn and pl.Character then makeESPForPlayer(pl) end end)
                    if pl.Character and espOn then makeESPForPlayer(pl) end
                end
            end)
            playerRemovingConn = Players.PlayerRemoving:Connect(function(pl) removeESPForPlayer(pl) end)
        end
        refreshESPBtn()
    end) end)

    -- Minimize: esconder Main e mostrar BatBtn (arrastável)
    BtnArrow.MouseButton1Click:Connect(function()
        Main.Visible = false
        BatBtn.Visible = true
        Confirm.Visible = false
        ValuePrompt.Visible = false
    end)
    -- Reabrir a partir do BatBtn
    BatBtn.MouseButton1Click:Connect(function()
        Main.Visible = true
        BatBtn.Visible = false
    end)

    BtnX.MouseButton1Click:Connect(function()
        showConfirm("Você realmente quer fechar a janela?", Color3.fromRGB(220,60,60), Color3.fromRGB(60,200,90), function()
            if SG and SG.Parent then pcall(function() SG:Destroy() end) end
        end, function() end)
    end)

    player.CharacterAdded:Connect(function()
        if flightHB then flightHB:Disconnect(); flightHB=nil end
        flying = false; flightEnabled = false
        if noclip then enableNoclip() end
        task.delay(0.8, function() refreshFlightBtn(); refreshInfBtn(); refreshRunBtn(); refreshNoclipBtn(); refreshESPBtn() end)
    end)
    player.CharacterRemoving:Connect(function()
        if flightHB then flightHB:Disconnect(); flightHB=nil end
        flying = false; flightEnabled = false
        if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
        if noclipHB then noclipHB:Disconnect(); noclipHB=nil end
    end)

    refreshFlightBtn(); refreshInfBtn(); refreshRunBtn(); refreshNoclipBtn(); refreshESPBtn()

    return { SG = SG, Main = Main, BatBtn = BatBtn, Confirm = Confirm }
end

--------------------------------------------------------------------------------
-- Bootstrap: key GUI and handlers
--------------------------------------------------------------------------------
local keyGui, menuObj
function openKeyAndMenuBootstrap()
    keyGui = createKeyGui(guiParent)
    if not keyGui then warn("Não foi possível criar Key GUI"); return end
    log("Key GUI criado")

    local function openMenu()
        if menuObj and menuObj.SG and menuObj.SG.Parent then
            menuObj.Main.Visible = true
            return
        end
        menuObj = createFullMenu(guiParent)
        if menuObj then log("Menu completo criado") end
    end

    -- LinkBtn: novo link solicitado
    keyGui.LinkBtn.MouseButton1Click:Connect(function()
        local URL = "https://link-center.net/1399653/xBYWny7FilPT"
        local copied = false
        if type(setclipboard) == "function" then pcall(function() setclipboard(URL); copied = true end) end
        if copied then keyGui.StatusLabel.Text = "Link copiado (área de transferência)" else keyGui.StatusLabel.Text = "Cópia não suportada pelo executor" end
        task.delay(1.6, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
    end)

    -- PularBtn copia link do gamepass
    keyGui.PularBtn.MouseButton1Click:Connect(function()
        if type(setclipboard) == "function" then pcall(function() setclipboard("https://www.roblox.com/pt/game-pass/"..tostring(GAMEPASS_ID).."/Sem-Key-PERMANENTEMENTE") end) end
        keyGui.StatusLabel.Text = "Link copiado (se suportado)"
        task.delay(1.2, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
    end)

    -- ChecarBtn
    keyGui.ChecarBtn.MouseButton1Click:Connect(function()
        keyGui.StatusLabel.Text = "Verificando..."
        local txt = tostring(keyGui.TextBox.Text or ""):gsub("^%s*(.-)%s*$","%1")

        -- hidden reset for testing
        if txt == "__BATDELTA_RESET__" then
            local uid = tostring(player.UserId)
            if type(localStatus) == "table" and type(localStatus.users) == "table" then
                localStatus.users[uid] = nil
                pcall(saveLocal)
            end
            keyGui.StatusLabel.Text = "Validação local reiniciada (teste)"
            task.delay(1.2, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
            return
        end

        -- first: check gamepass
        local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID) end)
        if ok and has then
            keyGui.StatusLabel.Text = "Gamepass verificado!"
            task.wait(0.25)
            keyGui.Frame.Visible = false
            openMenu()
            return
        end

        -- validate pattern (secret)
        if not isKeyPatternValid(txt) then
            keyGui.StatusLabel.Text = "Chave incorreta!"
            task.delay(1.6, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
            return
        end

        -- check used
        if usedKeys[txt] then
            keyGui.StatusLabel.Text = "Chave já utilizada!"
            task.delay(1.6, function() if keyGui and keyGui.StatusLabel then keyGui.StatusLabel.Text = "" end end)
            return
        end

        -- mark used and set local validity for this account
        usedKeys[txt] = true
        local uid = tostring(player.UserId)
        local expireAt = os.time() + VALIDITY_SECONDS
        if type(localStatus) ~= "table" then localStatus = { users = {} } end
        if type(localStatus.users) ~= "table" then localStatus.users = {} end
        localStatus.users[uid] = expireAt
        pcall(saveLocal)

        -- notify remote if available
        local okRemote = notifyServerKeyUsed(txt, expireAt)

        keyGui.StatusLabel.Text = "Chave verificada!"
        task.wait(0.25)
        keyGui.Frame.Visible = false
        openMenu()

        if not okRemote then warn("RemoteEvent não encontrado — invalidação global depende do servidor.") end
    end)
end

--------------------------------------------------------------------------------
-- DETECTION flow
--------------------------------------------------------------------------------
local function isGameFromCommunity()
    local ok, ctype = pcall(function() return game.CreatorType end)
    local ok2, cid = pcall(function() return game.CreatorId end)
    if not ok or not ok2 then return false end
    if game.CreatorType == Enum.CreatorType.Group and tonumber(game.CreatorId) == tonumber(COMPATIBLE_COMMUNITY_ID) then return true end
    return false
end

local compatible = isGameFromCommunity()
if detectGui and detectGui.Label then
    if compatible then
        detectGui.Label.Text = "jogo compatível detectado"
        task.spawn(function()
            task.wait(5)
            if detectGui and detectGui.SG then pcall(function() detectGui.SG:Destroy() end) end
            log("Detecção finalizada para user", player.UserId)
            local ok, err = pcall(function()
                if isLocallyValidatedForPlayer(player) then
                    menuObj = createFullMenu(guiParent)
                    log("Menu direto (validação local ativa)")
                else
                    openKeyAndMenuBootstrap()
                end
            end)
            if not ok then warn("Erro no fluxo pós-deteccao:", err) end
        end)
    else
        detectGui.Label.Text = "esse jogo não é compatível"
        if detectGui.CloseBtn then
            detectGui.CloseBtn.Visible = true
            detectGui.CloseBtn.MouseButton1Click:Connect(function() if detectGui and detectGui.SG then pcall(function() detectGui.SG:Destroy() end) end end)
        end
    end
end

log("BatDelta carregado — detecção realizada.")
