-- ============================================================
--  KEY SYSTEM  (Firebase, 24h, 1 account)
--  Website: https://sites.google.com/view/keysystemaimbotscripts
-- ============================================================
local KeySystem = {}

local KEY_CONFIG = {
    ProjectID  = "keysystem-5ca63",
    APIKey     = "AIzaSyCASGam1Kvku6Yu_bOpX0pFzbYXDgIcbro",
    SaveFile   = "aimbotx_key.txt",
    Title      = "AimbotX",
    Subtitle   = "Enter your key from the website",
    WebsiteURL = "https://linkvertise.com/access/9501604/sEbx11SAytTE",
}

local KS_Players = game:GetService("Players")
local KS_Http    = game:GetService("HttpService")
local KS_LP      = KS_Players.LocalPlayer

-- ---------- HTTP wrapper ----------
local function ks_request(opts)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, res = pcall(req, opts)
        if ok and res then return res end
    end
    local ok, res = pcall(function()
        return KS_Http:RequestAsync({
            Url = opts.Url,
            Method = opts.Method or "GET",
            Headers = opts.Headers,
            Body = opts.Body,
        })
    end)
    if ok and res then return { StatusCode = res.StatusCode, Body = res.Body } end
    return nil
end

-- ---------- Firestore REST ----------
local function fs_base()
    return string.format(
        "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/keys/",
        KEY_CONFIG.ProjectID)
end

local function fs_get(keyId)
    local url = fs_base() .. keyId .. "?key=" .. KEY_CONFIG.APIKey
    local res = ks_request({ Url = url, Method = "GET" })
    if not res then return nil, "No response" end
    if res.StatusCode == 404 then return nil, "Key not found" end
    if res.StatusCode ~= 200 then return nil, "HTTP " .. tostring(res.StatusCode) end
    local ok, data = pcall(function() return KS_Http:JSONDecode(res.Body) end)
    if not ok or type(data) ~= "table" then return nil, "Bad JSON" end
    return data
end

local function fs_patch(keyId, fields, mask)
    local url = fs_base() .. keyId
        .. "?key=" .. KEY_CONFIG.APIKey
        .. "&" .. mask
    local body = KS_Http:JSONEncode({ fields = fields })
    local res = ks_request({
        Url = url,
        Method = "PATCH",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    return res and (res.StatusCode == 200 or res.StatusCode == 201)
end

local function field_value(field)
    if not field then return nil end
    return field.stringValue
        or field.integerValue
        or field.doubleValue
        or field.booleanValue
        or field.timestampValue
        or field.nullValue
end

local function firestore_fields(doc)
    if not doc or not doc.fields then return nil end
    local out = {}
    for k, v in pairs(doc.fields) do out[k] = field_value(v) end
    return out
end

-- ---------- Saved key ----------
local function ks_load_saved()
    if not (isfile and readfile) then return nil end
    local ok, exists = pcall(isfile, KEY_CONFIG.SaveFile)
    if not ok or not exists then return nil end
    local ok2, data = pcall(readfile, KEY_CONFIG.SaveFile)
    if ok2 and type(data) == "string" and #data > 0 then return data end
    return nil
end

local function ks_save(k)
    if savefile then pcall(savefile, KEY_CONFIG.SaveFile, k) end
end

local function ks_clear_saved()
    if writefile and isfile then
        local ok, exists = pcall(isfile, KEY_CONFIG.SaveFile)
        if ok and exists then pcall(writefile, KEY_CONFIG.SaveFile, "") end
    end
end

-- ---------- Validation ----------
function KeySystem.Validate(key)
    key = tostring(key or ""):gsub("%s+", ""):upper()
    if key == "" then return false, "Enter a key." end

    local doc, err = fs_get(key)
    if not doc then return false, err or "Key not found." end

    local f = firestore_fields(doc)
    if not f then return false, "Bad key data." end

    local expiresAt = tonumber(f.expiresAt) or 0
    if expiresAt > 0 and os.time() * 1000 > expiresAt then
        return false, "This key has expired. Get a new one."
    end

    if f.used == false or f.used == nil then
        local myId = tostring(KS_LP.UserId)
        local ok = fs_patch(key, {
            used        = { booleanValue = true },
            boundUserId = { stringValue = myId },
            boundAt     = { integerValue = tostring(os.time() * 1000) },
        }, "updateMask.fieldPaths=used&updateMask.fieldPaths=boundUserId&updateMask.fieldPaths=boundAt")
        if not ok then return false, "Could not bind key to account." end
        return true
    end

    local bound = tostring(f.boundUserId or "")
    if bound ~= "" and bound ~= tostring(KS_LP.UserId) then
        return false, "This key belongs to another account."
    end

    return true
end

-- ---------- UI helpers ----------
local function ks_parent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return KS_LP:WaitForChild("PlayerGui")
end

local function ks_new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function ks_round(o, r)
    ks_new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

-- ---------- Key System UI ----------
function KeySystem.ShowUI()
    local parent = ks_parent()
    pcall(function()
        local old = parent:FindFirstChild("AimbotX_KeyUI")
        if old then old:Destroy() end
    end)

    local gui = ks_new("ScreenGui", {
        Name = "AimbotX_KeyUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)

    local main = ks_new("Frame", {
        Size = UDim2.new(0, 360, 0, 280),
        Position = UDim2.new(0.5, -180, 0.5, -140),
        BackgroundColor3 = Color3.fromRGB(20, 20, 26),
        BorderSizePixel = 0,
    }, gui)
    ks_round(main, 10)
    ks_new("UIStroke", { Color = Color3.fromRGB(58, 58, 74), Thickness = 1 }, main)

    ks_new("TextLabel", {
        Size = UDim2.new(1, -50, 0, 22),
        Position = UDim2.new(0, 20, 0, 14),
        BackgroundTransparency = 1,
        Text = KEY_CONFIG.Title .. " — Key Required",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    ks_new("TextLabel", {
        Size = UDim2.new(1, -50, 0, 16),
        Position = UDim2.new(0, 20, 0, 36),
        BackgroundTransparency = 1,
        Text = KEY_CONFIG.Subtitle,
        TextColor3 = Color3.fromRGB(140, 140, 160),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    ks_new("Frame", {
        Size = UDim2.new(1, -40, 0, 1),
        Position = UDim2.new(0, 20, 0, 60),
        BackgroundColor3 = Color3.fromRGB(48, 48, 62),
        BorderSizePixel = 0,
    }, main)

    local close = ks_new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -36, 0, 12),
        BackgroundColor3 = Color3.fromRGB(38, 38, 50),
        Text = "✕",
        TextColor3 = Color3.fromRGB(200, 200, 215),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        BorderSizePixel = 0,
    }, main)
    ks_round(close, 6)

    ks_new("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 72),
        BackgroundTransparency = 1,
        Text = "STEP 1 — Get your key",
        TextColor3 = Color3.fromRGB(120, 200, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    local linkBtn = ks_new("TextButton", {
        Size = UDim2.new(1, -40, 0, 34),
        Position = UDim2.new(0, 20, 0, 90),
        BackgroundColor3 = Color3.fromRGB(88, 101, 242),
        Text = "📋  Copy Website Link",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        BorderSizePixel = 0,
    }, main)
    ks_round(linkBtn, 6)

    ks_new("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 132),
        BackgroundTransparency = 1,
        Text = "STEP 2 — Paste your key",
        TextColor3 = Color3.fromRGB(120, 200, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    local box = ks_new("TextBox", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.new(0, 20, 0, 150),
        BackgroundColor3 = Color3.fromRGB(30, 30, 40),
        PlaceholderText = "AIMBOT-XXXX-XXXX-XXXX-XXXX",
        PlaceholderColor3 = Color3.fromRGB(100, 100, 120),
        Text = "",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
    }, main)
    ks_round(box, 6)
    ks_new("UIStroke", { Color = Color3.fromRGB(58, 58, 74), Thickness = 1 }, box)

    local submit = ks_new("TextButton", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.new(0, 20, 0, 194),
        BackgroundColor3 = Color3.fromRGB(64, 200, 120),
        Text = "Unlock",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
    }, main)
    ks_round(submit, 6)

    local status = ks_new("TextLabel", {
        Size = UDim2.new(1, -40, 0, 30),
        Position = UDim2.new(0, 20, 0, 236),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(140, 140, 160),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    -- Dragging
    do
        local dragging, dragStart, startPos
        main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        main.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    local done, result = false, nil

    close.MouseButton1Click:Connect(function() done, result = true, nil end)

    linkBtn.MouseButton1Click:Connect(function()
        if setclipboard then pcall(setclipboard, KEY_CONFIG.WebsiteURL) end
        status.Text = "Website link copied! Open it, generate a key, paste above."
        status.TextColor3 = Color3.fromRGB(120, 200, 255)
    end)

    box.FocusLost:Connect(function(enter)
        if enter then submit:Fire("MouseButton1Click") end
    end)

    submit.MouseButton1Click:Connect(function()
        submit.Text = "Checking..."
        submit.BackgroundColor3 = Color3.fromRGB(50, 50, 62)
        status.Text = ""
        task.wait(0.05)

        local ok, err = KeySystem.Validate(box.Text)
        if ok then
            status.Text = "Key accepted. Loading script..."
            status.TextColor3 = Color3.fromRGB(64, 200, 120)
            submit.Text = "✓ Unlocked"
            submit.BackgroundColor3 = Color3.fromRGB(64, 200, 120)
            task.wait(0.5)
            done, result = true, box.Text
        else
            status.Text = err or "Invalid key."
            status.TextColor3 = Color3.fromRGB(255, 110, 110)
            submit.Text = "Unlock"
            submit.BackgroundColor3 = Color3.fromRGB(64, 200, 120)
        end
    end)

    while not done do task.wait(0.1) end
    pcall(function() gui:Destroy() end)
    task.wait(0.3) -- let the key UI fully disappear before AimbotX UI spawns
    return result
end

-- ---------- Init ----------
function KeySystem.Init()
    local saved = ks_load_saved()
    if saved and #saved > 0 then
        local ok = KeySystem.Validate(saved)
        if ok then
            print("[KeySystem] Auto-logged in with saved key.")
            return true
        end
        ks_clear_saved()
    end

    local key = KeySystem.ShowUI()
    if key then
        ks_save(key)
        return true
    end
    return false
end

-- ---------- Run key check ----------
if not KeySystem.Init() then
    warn("[KeySystem] Access denied. Script aborted.")
    return
end

-- small pause so everything settles
task.wait(0.3)

-- ============================================================
--  END KEY SYSTEM — AimbotX starts below (your full script)
-- ============================================================


-- ============================================================
--  AimbotX Lock-On Camera  (v7 - FULL)
--  Location: StarterPlayer > StarterPlayerScripts  (LocalScript)
-- ============================================================

print("[AimbotX] 1. script started")

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

print("[AimbotX] 2. services loaded")

local LP = Players.LocalPlayer
if not LP then
    warn("[AimbotX] X. No LocalPlayer - this is NOT a LocalScript. Stop here.")
    return
end

print("[AimbotX] 3. LocalPlayer =", LP.Name)

local CAMERA = workspace.CurrentCamera
local pg = LP:WaitForChild("PlayerGui", 5)

if not pg then
    warn("[AimbotX] X. PlayerGui missing - script is running on server, not client. Stop here.")
    return
end

print("[AimbotX] 4. PlayerGui found")

-- ============================================================
-- UI (YOUR DESIGN - UNCHANGED)
-- ============================================================
local ScreenGui = {
    ScreenGui = Instance.new("ScreenGui"),
    Frame = Instance.new("Frame"),
    UIStroke = Instance.new("UIStroke"),
    UICorner = Instance.new("UICorner"),
    Title = Instance.new("TextLabel"),
    UIStroke_2 = Instance.new("UIStroke"),
    CloseButton = Instance.new("TextButton"),
    UIStroke_3 = Instance.new("UIStroke"),
    UICorner_2 = Instance.new("UICorner"),
    Camera = Instance.new("TextButton"),
    UIStroke_4 = Instance.new("UIStroke"),
    UICorner_3 = Instance.new("UICorner"),
    UIStroke_5 = Instance.new("UIStroke"),
    Mouse = Instance.new("TextButton"),
    UIStroke_6 = Instance.new("UIStroke"),
    UICorner_4 = Instance.new("UICorner"),
    UIStroke_7 = Instance.new("UIStroke"),
    SmoothnesBar = Instance.new("Frame"),
    UICorner_5 = Instance.new("UICorner"),
    UIStroke_8 = Instance.new("UIStroke"),
    Slider = Instance.new("TextButton"),
    UICorner_6 = Instance.new("UICorner"),
    UIStroke_9 = Instance.new("UIStroke"),
    OFF_ON_BUTTON = Instance.new("TextButton"),
    UICorner_7 = Instance.new("UICorner"),
    UIStroke_10 = Instance.new("UIStroke"),
    Lock = Instance.new("TextLabel"),
    Cycle = Instance.new("TextLabel"),
}

print("[AimbotX] 5. instances created")

ScreenGui.ScreenGui.Parent = pg
ScreenGui.Frame.Parent = ScreenGui.ScreenGui
ScreenGui.UIStroke.Parent = ScreenGui.Frame
ScreenGui.UICorner.Parent = ScreenGui.Frame
ScreenGui.Title.Parent = ScreenGui.Frame
ScreenGui.UIStroke_2.Parent = ScreenGui.Title
ScreenGui.CloseButton.Parent = ScreenGui.Frame
ScreenGui.UIStroke_3.Parent = ScreenGui.CloseButton
ScreenGui.UICorner_2.Parent = ScreenGui.CloseButton
ScreenGui.Camera.Parent = ScreenGui.Frame
ScreenGui.UIStroke_4.Parent = ScreenGui.Camera
ScreenGui.UICorner_3.Parent = ScreenGui.Camera
ScreenGui.UIStroke_5.Parent = ScreenGui.Camera
ScreenGui.Mouse.Parent = ScreenGui.Frame
ScreenGui.UIStroke_6.Parent = ScreenGui.Mouse
ScreenGui.UICorner_4.Parent = ScreenGui.Mouse
ScreenGui.UIStroke_7.Parent = ScreenGui.Mouse
ScreenGui.SmoothnesBar.Parent = ScreenGui.Frame
ScreenGui.UICorner_5.Parent = ScreenGui.SmoothnesBar
ScreenGui.UIStroke_8.Parent = ScreenGui.SmoothnesBar
ScreenGui.Slider.Parent = ScreenGui.SmoothnesBar
ScreenGui.UICorner_6.Parent = ScreenGui.Slider
ScreenGui.UIStroke_9.Parent = ScreenGui.Slider
ScreenGui.OFF_ON_BUTTON.Parent = ScreenGui.Frame
ScreenGui.UICorner_7.Parent = ScreenGui.OFF_ON_BUTTON
ScreenGui.UIStroke_10.Parent = ScreenGui.OFF_ON_BUTTON
ScreenGui.Lock.Parent = ScreenGui.Frame
ScreenGui.Cycle.Parent = ScreenGui.Frame

print("[AimbotX] 6. parents assigned")

ScreenGui.ScreenGui.Name = "AimbotXUI"
ScreenGui.ScreenGui.ResetOnSpawn = false
ScreenGui.ScreenGui.IgnoreGuiInset = true
ScreenGui.ScreenGui.DisplayOrder = 2147483647
ScreenGui.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ScreenGui.Enabled = true

ScreenGui.Frame.Name = "Frame"
ScreenGui.Frame.ZIndex = 1
ScreenGui.Frame.Position = UDim2.new(0.335075796, 0, 0.14825581, 0)
ScreenGui.Frame.Size = UDim2.new(0, 236, 0, 155)
ScreenGui.Frame.BackgroundColor3 = Color3.fromRGB(45,45,45)
ScreenGui.Frame.BackgroundTransparency = 0
ScreenGui.Frame.Visible = true
ScreenGui.Frame.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Frame.ClipsDescendants = false
ScreenGui.Frame.BorderSizePixel = 0
ScreenGui.Frame.Active = true

ScreenGui.UIStroke.Name = "UIStroke"
ScreenGui.UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
ScreenGui.UIStroke.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke.Thickness = 2.700000047683716
ScreenGui.UIStroke.Transparency = 0
ScreenGui.UIStroke.Enabled = true

ScreenGui.UICorner.Name = "UICorner"
ScreenGui.UICorner.CornerRadius = UDim.new(0, 8)

ScreenGui.Title.Name = "Title"
ScreenGui.Title.ZIndex = 1
ScreenGui.Title.Position = UDim2.new(0.283898175, 0, 0.0463576168, 0)
ScreenGui.Title.Size = UDim2.new(0, 102, 0, 23)
ScreenGui.Title.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Title.BackgroundTransparency = 1
ScreenGui.Title.Text = "AimbotX"
ScreenGui.Title.TextScaled = true
ScreenGui.Title.TextSize = 14
ScreenGui.Title.Font = Enum.Font.Unknown
ScreenGui.Title.TextColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Title.TextStrokeTransparency = 1
ScreenGui.Title.TextWrapped = true
ScreenGui.Title.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Title.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Title.TextTransparency = 0
ScreenGui.Title.Visible = true
ScreenGui.Title.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Title.ClipsDescendants = false

ScreenGui.UIStroke_2.Name = "UIStroke"
ScreenGui.UIStroke_2.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
ScreenGui.UIStroke_2.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_2.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_2.Thickness = 2.700000047683716
ScreenGui.UIStroke_2.Transparency = 0
ScreenGui.UIStroke_2.Enabled = true

ScreenGui.CloseButton.Name = "CloseButton"
ScreenGui.CloseButton.ZIndex = 1
ScreenGui.CloseButton.Position = UDim2.new(0.868643939, 0, 0.0463576168, 0)
ScreenGui.CloseButton.Size = UDim2.new(0, 24, 0, 23)
ScreenGui.CloseButton.BackgroundColor3 = Color3.fromRGB(255,0,4)
ScreenGui.CloseButton.BackgroundTransparency = 0
ScreenGui.CloseButton.Text = "X"
ScreenGui.CloseButton.TextScaled = true
ScreenGui.CloseButton.TextSize = 14
ScreenGui.CloseButton.Font = Enum.Font.Unknown
ScreenGui.CloseButton.TextColor3 = Color3.fromRGB(0,0,0)
ScreenGui.CloseButton.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.CloseButton.TextStrokeTransparency = 1
ScreenGui.CloseButton.TextWrapped = true
ScreenGui.CloseButton.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.CloseButton.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.CloseButton.TextTransparency = 0
ScreenGui.CloseButton.Visible = true
ScreenGui.CloseButton.AnchorPoint = Vector2.new(0, 0)
ScreenGui.CloseButton.ClipsDescendants = false

ScreenGui.UIStroke_3.Name = "UIStroke"
ScreenGui.UIStroke_3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_3.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_3.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_3.Thickness = 2.700000047683716
ScreenGui.UIStroke_3.Transparency = 0
ScreenGui.UIStroke_3.Enabled = true

ScreenGui.UICorner_2.Name = "UICorner"
ScreenGui.UICorner_2.CornerRadius = UDim.new(0, 8)

ScreenGui.Camera.Name = "Camera"
ScreenGui.Camera.ZIndex = 1
ScreenGui.Camera.Position = UDim2.new(0.118644066, 0, 0.251655638, 0)
ScreenGui.Camera.Size = UDim2.new(0, 85, 0, 22)
ScreenGui.Camera.BackgroundColor3 = Color3.fromRGB(26,167,255)
ScreenGui.Camera.BackgroundTransparency = 0
ScreenGui.Camera.Text = "Camera"
ScreenGui.Camera.TextScaled = true
ScreenGui.Camera.TextSize = 14
ScreenGui.Camera.Font = Enum.Font.Unknown
ScreenGui.Camera.TextColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Camera.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Camera.TextStrokeTransparency = 1
ScreenGui.Camera.TextWrapped = true
ScreenGui.Camera.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Camera.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Camera.TextTransparency = 0
ScreenGui.Camera.Visible = true
ScreenGui.Camera.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Camera.ClipsDescendants = false

ScreenGui.UIStroke_4.Name = "UIStroke"
ScreenGui.UIStroke_4.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_4.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_4.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_4.Thickness = 2.700000047683716
ScreenGui.UIStroke_4.Transparency = 0
ScreenGui.UIStroke_4.Enabled = true

ScreenGui.UICorner_3.Name = "UICorner"
ScreenGui.UICorner_3.CornerRadius = UDim.new(0, 8)

ScreenGui.UIStroke_5.Name = "UIStroke"
ScreenGui.UIStroke_5.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
ScreenGui.UIStroke_5.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_5.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_5.Thickness = 2.700000047683716
ScreenGui.UIStroke_5.Transparency = 0
ScreenGui.UIStroke_5.Enabled = true

ScreenGui.Mouse.Name = "Mouse"
ScreenGui.Mouse.ZIndex = 1
ScreenGui.Mouse.Position = UDim2.new(0.521186411, 0, 0.251655638, 0)
ScreenGui.Mouse.Size = UDim2.new(0, 85, 0, 22)
ScreenGui.Mouse.BackgroundColor3 = Color3.fromRGB(26,167,255)
ScreenGui.Mouse.BackgroundTransparency = 0
ScreenGui.Mouse.Text = "Mouse"
ScreenGui.Mouse.TextScaled = true
ScreenGui.Mouse.TextSize = 14
ScreenGui.Mouse.Font = Enum.Font.Unknown
ScreenGui.Mouse.TextColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Mouse.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Mouse.TextStrokeTransparency = 1
ScreenGui.Mouse.TextWrapped = true
ScreenGui.Mouse.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Mouse.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Mouse.TextTransparency = 0
ScreenGui.Mouse.Visible = true
ScreenGui.Mouse.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Mouse.ClipsDescendants = false

ScreenGui.UIStroke_6.Name = "UIStroke"
ScreenGui.UIStroke_6.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_6.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_6.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_6.Thickness = 2.700000047683716
ScreenGui.UIStroke_6.Transparency = 0
ScreenGui.UIStroke_6.Enabled = true

ScreenGui.UICorner_4.Name = "UICorner"
ScreenGui.UICorner_4.CornerRadius = UDim.new(0, 8)

ScreenGui.UIStroke_7.Name = "UIStroke"
ScreenGui.UIStroke_7.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
ScreenGui.UIStroke_7.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_7.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_7.Thickness = 2.700000047683716
ScreenGui.UIStroke_7.Transparency = 0
ScreenGui.UIStroke_7.Enabled = true

ScreenGui.SmoothnesBar.Name = "SmoothnesBar"
ScreenGui.SmoothnesBar.ZIndex = 1
ScreenGui.SmoothnesBar.Position = UDim2.new(0.0338983051, 0, 0.511471748, 0)
ScreenGui.SmoothnesBar.Size = UDim2.new(0, 218, 0, 9)
ScreenGui.SmoothnesBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.SmoothnesBar.BackgroundTransparency = 0
ScreenGui.SmoothnesBar.Visible = true
ScreenGui.SmoothnesBar.AnchorPoint = Vector2.new(0, 0)
ScreenGui.SmoothnesBar.ClipsDescendants = false
ScreenGui.SmoothnesBar.BorderSizePixel = 0
ScreenGui.SmoothnesBar.Active = true

ScreenGui.UICorner_5.Name = "UICorner"
ScreenGui.UICorner_5.CornerRadius = UDim.new(0, 8)

ScreenGui.UIStroke_8.Name = "UIStroke"
ScreenGui.UIStroke_8.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_8.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_8.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_8.Thickness = 2.700000047683716
ScreenGui.UIStroke_8.Transparency = 0
ScreenGui.UIStroke_8.Enabled = true

ScreenGui.Slider.Name = "Slider"
ScreenGui.Slider.ZIndex = 2
ScreenGui.Slider.Position = UDim2.new(0, 0, -0.333333343, 0)
ScreenGui.Slider.Size = UDim2.new(0, 20, 0, 14)
ScreenGui.Slider.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Slider.BackgroundTransparency = 0
ScreenGui.Slider.Text = ""
ScreenGui.Slider.TextScaled = false
ScreenGui.Slider.TextSize = 14
ScreenGui.Slider.Font = Enum.Font.SourceSans
ScreenGui.Slider.TextColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Slider.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Slider.TextStrokeTransparency = 1
ScreenGui.Slider.TextWrapped = false
ScreenGui.Slider.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Slider.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Slider.TextTransparency = 0
ScreenGui.Slider.Visible = true
ScreenGui.Slider.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Slider.ClipsDescendants = false

ScreenGui.UICorner_6.Name = "UICorner"
ScreenGui.UICorner_6.CornerRadius = UDim.new(0, 8)

ScreenGui.UIStroke_9.Name = "UIStroke"
ScreenGui.UIStroke_9.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_9.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_9.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_9.Thickness = 2.700000047683716
ScreenGui.UIStroke_9.Transparency = 0
ScreenGui.UIStroke_9.Enabled = true

ScreenGui.OFF_ON_BUTTON.Name = "OFF/ON BUTTON"
ScreenGui.OFF_ON_BUTTON.ZIndex = 1
ScreenGui.OFF_ON_BUTTON.Position = UDim2.new(0.207627118, 0, 0.787054241, 0)
ScreenGui.OFF_ON_BUTTON.Size = UDim2.new(0, 136, 0, 19)
ScreenGui.OFF_ON_BUTTON.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.OFF_ON_BUTTON.BackgroundTransparency = 0
ScreenGui.OFF_ON_BUTTON.Text = "OFF"
ScreenGui.OFF_ON_BUTTON.TextScaled = true
ScreenGui.OFF_ON_BUTTON.TextSize = 14
ScreenGui.OFF_ON_BUTTON.Font = Enum.Font.Unknown
ScreenGui.OFF_ON_BUTTON.TextColor3 = Color3.fromRGB(0,0,0)
ScreenGui.OFF_ON_BUTTON.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.OFF_ON_BUTTON.TextStrokeTransparency = 1
ScreenGui.OFF_ON_BUTTON.TextWrapped = true
ScreenGui.OFF_ON_BUTTON.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.OFF_ON_BUTTON.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.OFF_ON_BUTTON.TextTransparency = 0
ScreenGui.OFF_ON_BUTTON.Visible = true
ScreenGui.OFF_ON_BUTTON.AnchorPoint = Vector2.new(0, 0)
ScreenGui.OFF_ON_BUTTON.ClipsDescendants = false

ScreenGui.UICorner_7.Name = "UICorner"
ScreenGui.UICorner_7.CornerRadius = UDim.new(0, 8)

ScreenGui.UIStroke_10.Name = "UIStroke"
ScreenGui.UIStroke_10.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ScreenGui.UIStroke_10.Color = Color3.fromRGB(0,0,0)
ScreenGui.UIStroke_10.LineJoinMode = Enum.LineJoinMode.Round
ScreenGui.UIStroke_10.Thickness = 2.700000047683716
ScreenGui.UIStroke_10.Transparency = 0
ScreenGui.UIStroke_10.Enabled = true

ScreenGui.Lock.Name = "Lock"
ScreenGui.Lock.ZIndex = 1
ScreenGui.Lock.Position = UDim2.new(0.207626984, 0, 0.646955609, 0)
ScreenGui.Lock.Size = UDim2.new(0, 73, 0, 15)
ScreenGui.Lock.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Lock.BackgroundTransparency = 1
ScreenGui.Lock.Text = "(Q) LOCK"
ScreenGui.Lock.TextScaled = true
ScreenGui.Lock.TextSize = 14
ScreenGui.Lock.Font = Enum.Font.Unknown
ScreenGui.Lock.TextColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Lock.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Lock.TextStrokeTransparency = 1
ScreenGui.Lock.TextWrapped = true
ScreenGui.Lock.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Lock.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Lock.TextTransparency = 0
ScreenGui.Lock.Visible = true
ScreenGui.Lock.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Lock.ClipsDescendants = false

ScreenGui.Cycle.Name = "Cycle"
ScreenGui.Cycle.ZIndex = 1
ScreenGui.Cycle.Position = UDim2.new(0.474576145, 0, 0.646955609, 0)
ScreenGui.Cycle.Size = UDim2.new(0, 73, 0, 15)
ScreenGui.Cycle.BackgroundColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Cycle.BackgroundTransparency = 1
ScreenGui.Cycle.Text = "(E) CYCLE"
ScreenGui.Cycle.TextScaled = true
ScreenGui.Cycle.TextSize = 14
ScreenGui.Cycle.Font = Enum.Font.Unknown
ScreenGui.Cycle.TextColor3 = Color3.fromRGB(255,255,255)
ScreenGui.Cycle.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ScreenGui.Cycle.TextStrokeTransparency = 1
ScreenGui.Cycle.TextWrapped = true
ScreenGui.Cycle.TextXAlignment = Enum.TextXAlignment.Center
ScreenGui.Cycle.TextYAlignment = Enum.TextYAlignment.Center
ScreenGui.Cycle.TextTransparency = 0
ScreenGui.Cycle.Visible = true
ScreenGui.Cycle.AnchorPoint = Vector2.new(0, 0)
ScreenGui.Cycle.ClipsDescendants = false

print("[AimbotX] 7. UI styled")

-- ============================================================
-- SMOOTHNESS NUMBER LABEL
-- ============================================================
local SmoothNumber = Instance.new("TextLabel")
SmoothNumber.Name = "SmoothNumber"
SmoothNumber.ZIndex = 2
SmoothNumber.Position = UDim2.new(0.0338983051, 0, 0.511471748, -18)
SmoothNumber.Size = UDim2.new(0, 218, 0, 14)
SmoothNumber.BackgroundTransparency = 1
SmoothNumber.Text = "Smoothness: 55"
SmoothNumber.TextScaled = false
SmoothNumber.TextSize = 13
SmoothNumber.Font = Enum.Font.GothamBold
SmoothNumber.TextColor3 = Color3.fromRGB(255, 255, 255)
SmoothNumber.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
SmoothNumber.TextStrokeTransparency = 0.4
SmoothNumber.TextXAlignment = Enum.TextXAlignment.Center
SmoothNumber.TextYAlignment = Enum.TextYAlignment.Center
SmoothNumber.Parent = ScreenGui.Frame

print("[AimbotX] 8. smoothness number added")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    StartEnabled = false,
    ToggleKey    = Enum.KeyCode.Q,
    CycleKey     = Enum.KeyCode.E,
    HideUIKey    = Enum.KeyCode.RightShift,

    MaxLockRange     = 250,
    BreakRange       = 400,
    AimOffset        = Vector3.new(0, 0.4, 0),
    IgnoreSameTeam   = true,
    CheckLineOfSight = false,
    IncludeNPCs      = true,

    CameraDistance = 14,
    CameraHeight   = 4,

    SnappyResponsiveness    = 22,
    CinematicResponsiveness = 5,

    ShowMarker         = true,
    MarkerColor        = Color3.fromRGB(255, 70, 70),
    MarkerTransparency = 0.35,
    MarkerSize         = 0.7,
    MarkerPulse        = true,

    MouseSensitivity = 0.005,
    MouseMaxYawDeg   = 50,
    MouseMaxPitchDeg = 35,
    MouseReturnSpeed = 4,
}

local enabled      = CONFIG.StartEnabled
local mode         = "Camera"
local smoothness   = 0.55

local lockedModel  = nil
local markerPart   = nil
local originalCam  = nil
local smoothAimPos, smoothCamPos, smoothLookDir
local yawOffset, pitchOffset = 0, 0

_G.__AimbotX_UserClosed = false

-- ---------- helpers ----------
local function isAlive(c)
    if not c or not c.Parent then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function getAimPosition(m)
    if not m then return nil end
    local b = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
    if not b then return nil end
    return b.Position + CONFIG.AimOffset
end

local function isSameTeam(m)
    if not CONFIG.IgnoreSameTeam then return false end
    local p = Players:GetPlayerFromCharacter(m)
    if not p or not LP.Team or not p.Team then return false end
    return p.Team == LP.Team
end

local function hasLOS(m)
    if not CONFIG.CheckLineOfSight then return true end
    local mc = LP.Character
    local mr = mc and mc:FindFirstChild("HumanoidRootPart")
    local aim = getAimPosition(m)
    if not mr or not aim then return false end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { mc, m }
    p.IgnoreWater = true
    return workspace:Raycast(mr.Position, aim - mr.Position, p) == nil
end

local function isValid(m)
    if not m or not m.Parent then return false end
    if not isAlive(m) then return false end
    if m == LP.Character then return false end
    if isSameTeam(m) then return false end
    if not getAimPosition(m) then return false end
    return true
end

local function getCandidates()
    local list = {}
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return list end
    local seen = {}
    local function tryAdd(m)
        if seen[m] then return end
        seen[m] = true
        if not isValid(m) then return end
        local aim = getAimPosition(m)
        local d = (aim - myRoot.Position).Magnitude
        if d > CONFIG.MaxLockRange then return end
        if not hasLOS(m) then return end
        table.insert(list, { model = m, dist = d })
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then tryAdd(p.Character) end
    end
    if CONFIG.IncludeNPCs then
        for _, o in ipairs(workspace:GetChildren()) do
            if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid") then tryAdd(o) end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function currentResponsiveness()
    local t = math.clamp(smoothness, 0, 1)
    return CONFIG.SnappyResponsiveness
        + (CONFIG.CinematicResponsiveness - CONFIG.SnappyResponsiveness) * t
end

local function alphaFor(rate, dt) return 1 - math.exp(-rate * dt) end
local function lerpV(a, b, t) return a + (b - a) * t end

local function spawnMarker()
    if not CONFIG.ShowMarker then return end
    if markerPart and markerPart.Parent then return end
    local p = Instance.new("Part")
    p.Name = "LockOnMarker"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(CONFIG.MarkerSize, CONFIG.MarkerSize, CONFIG.MarkerSize)
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
    p.Massless, p.CastShadow = true, false
    p.Material = Enum.Material.Neon
    p.Color = CONFIG.MarkerColor
    p.Transparency = CONFIG.MarkerTransparency
    p.Parent = workspace
    markerPart = p
end

local function destroyMarker()
    if markerPart then markerPart:Destroy() markerPart = nil end
end

local function enterScriptable()
    if originalCam == nil then originalCam = CAMERA.CameraType end
    CAMERA.CameraType = Enum.CameraType.Scriptable
end

local function exitScriptable()
    if originalCam ~= nil then
        CAMERA.CameraType = originalCam
        originalCam = nil
    else
        CAMERA.CameraType = Enum.CameraType.Custom
    end
end

local function unlock()
    if not lockedModel then return end
    lockedModel = nil
    smoothAimPos, smoothCamPos, smoothLookDir = nil, nil, nil
    yawOffset, pitchOffset = 0, 0
    destroyMarker()
    exitScriptable()
end

local function lockOnto(m)
    if not m then return end
    lockedModel = m
    smoothAimPos, smoothCamPos, smoothLookDir = nil, nil, nil
    yawOffset, pitchOffset = 0, 0
    enterScriptable()
    spawnMarker()
end

local function toggleLock()
    if not enabled then return end
    if lockedModel then unlock()
    else
        local list = getCandidates()
        if #list > 0 then lockOnto(list[1].model) end
    end
end

local function cycleTarget()
    if not enabled then return end
    local list = getCandidates()
    if #list == 0 then unlock() return end
    if not lockedModel then lockOnto(list[1].model) return end
    local idx
    for i, e in ipairs(list) do
        if e.model == lockedModel then idx = i break end
    end
    lockOnto(list[idx and (idx % #list) + 1 or 1].model)
end

local function updateCamera(dt, rawAim)
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local rate  = currentResponsiveness()
    local alpha = alphaFor(rate, dt)

    if smoothAimPos == nil then smoothAimPos = rawAim
    else smoothAimPos = lerpV(smoothAimPos, rawAim, alpha) end
    local aim = smoothAimPos

    local toTarget = aim - myRoot.Position
    local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
    if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, -1) end
    flatDir = flatDir.Unit

    local desiredCam = myRoot.Position - flatDir * CONFIG.CameraDistance
        + Vector3.new(0, CONFIG.CameraHeight, 0)
    if smoothCamPos == nil then smoothCamPos = desiredCam
    else smoothCamPos = lerpV(smoothCamPos, desiredCam, alpha) end
    local camPos = smoothCamPos

    local desiredLook
    if mode == "Camera" then
        desiredLook = aim - camPos
        if desiredLook.Magnitude < 0.01 then return end
        desiredLook = desiredLook.Unit
    else
        local delta = UserInputService:GetMouseDelta()
        yawOffset   = yawOffset   - delta.X * CONFIG.MouseSensitivity
        pitchOffset = pitchOffset - delta.Y * CONFIG.MouseSensitivity
        local maxY = math.rad(CONFIG.MouseMaxYawDeg)
        local maxP = math.rad(CONFIG.MouseMaxPitchDeg)
        yawOffset   = math.clamp(yawOffset,   -maxY, maxY)
        pitchOffset = math.clamp(pitchOffset, -maxP, maxP)
        local decay = math.exp(-CONFIG.MouseReturnSpeed * dt)
        yawOffset, pitchOffset = yawOffset * decay, pitchOffset * decay

        local base = aim - camPos
        if base.Magnitude < 0.01 then return end
        base = base.Unit
        local baseYaw   = math.atan2(-base.X, -base.Z)
        local basePitch = math.asin(math.clamp(base.Y, -1, 1))
        local y = baseYaw + yawOffset
        local p = math.clamp(basePitch + pitchOffset, -math.rad(89), math.rad(89))
        local cp = math.cos(p)
        desiredLook = Vector3.new(-math.sin(y) * cp, math.sin(p), -math.cos(y) * cp)
    end

    local lookAlpha = alphaFor(rate * 1.4, dt)
    if smoothLookDir == nil then smoothLookDir = desiredLook
    else smoothLookDir = lerpV(smoothLookDir, desiredLook, lookAlpha).Unit end

    CAMERA.CFrame = CFrame.lookAt(camPos, camPos + smoothLookDir)
end

RunService:BindToRenderStep("LockOnRender", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not enabled then
        if lockedModel then unlock() end
        return
    end
    if not lockedModel then return end
    if not isValid(lockedModel) then unlock() return end

    local aim = getAimPosition(lockedModel)
    if not aim then unlock() return end

    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and (aim - myRoot.Position).Magnitude > CONFIG.BreakRange then
        unlock() return
    end

    updateCamera(dt, aim)

    if markerPart and markerPart.Parent and smoothAimPos then
        markerPart.CFrame = CFrame.new(smoothAimPos)
        if CONFIG.MarkerPulse then
            local s = CONFIG.MarkerSize * (1 + math.sin(tick() * 10) * 0.2)
            markerPart.Size = Vector3.new(s, s, s)
        end
    end
end)

print("[AimbotX] 9. render loop bound")

-- ============================================================
-- UI WIRING
-- ============================================================
local SLIDER_TRACK_W = 218
local SLIDER_W       = 20
local SLIDER_Y_SCALE = -0.333333343

local function updateSliderVisual()
    local travel = SLIDER_TRACK_W - SLIDER_W
    local x = smoothness * travel
    ScreenGui.Slider.Position = UDim2.new(0, x, SLIDER_Y_SCALE, 0)
end

local function updateSmoothNumber()
    SmoothNumber.Text = string.format("Smoothness: %d", math.floor(smoothness * 100 + 0.5))
end

local function refreshUI()
    if enabled then
        ScreenGui.OFF_ON_BUTTON.Text = "ON"
        ScreenGui.OFF_ON_BUTTON.BackgroundColor3 = Color3.fromRGB(26, 167, 255)
        ScreenGui.OFF_ON_BUTTON.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        ScreenGui.OFF_ON_BUTTON.Text = "OFF"
        ScreenGui.OFF_ON_BUTTON.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ScreenGui.OFF_ON_BUTTON.TextColor3 = Color3.fromRGB(0, 0, 0)
    end

    local activeBg   = Color3.fromRGB(26, 167, 255)
    local inactiveBg = Color3.fromRGB(70, 70, 70)
    if mode == "Camera" then
        ScreenGui.Camera.BackgroundColor3 = activeBg
        ScreenGui.Mouse.BackgroundColor3  = inactiveBg
    else
        ScreenGui.Camera.BackgroundColor3 = inactiveBg
        ScreenGui.Mouse.BackgroundColor3  = activeBg
    end

    updateSliderVisual()
    updateSmoothNumber()
end

local function setEnabled(v)
    enabled = v
    if not enabled then unlock() end
    refreshUI()
end

local function setMode(m)
    mode = m
    yawOffset, pitchOffset = 0, 0
    refreshUI()
end

local function setSmoothness(v)
    smoothness = math.clamp(v, 0, 1)
    updateSliderVisual()
    updateSmoothNumber()
end

-- Slider drag
do
    local bar    = ScreenGui.SmoothnesBar
    local slider = ScreenGui.Slider
    local dragging = false

    local function applyFromX(absX)
        local rel = absX - bar.AbsolutePosition.X
        local t = math.clamp(rel / bar.AbsoluteSize.X, 0, 1)
        setSmoothness(t)
    end

    local function startDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyFromX(input.Position.X)
        end
    end

    local function updateDrag(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            applyFromX(input.Position.X)
        end
    end

    local function endDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end

    bar.InputBegan:Connect(startDrag)
    bar.InputChanged:Connect(updateDrag)
    slider.InputBegan:Connect(startDrag)
    slider.InputChanged:Connect(updateDrag)
    UserInputService.InputEnded:Connect(endDrag)
end

-- Panel dragging
do
    local frame  = ScreenGui.Frame
    local handle = ScreenGui.Title
    local dragging, dragStart, startPos = false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

ScreenGui.OFF_ON_BUTTON.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

ScreenGui.Camera.MouseButton1Click:Connect(function() setMode("Camera") end)
ScreenGui.Mouse.MouseButton1Click:Connect(function() setMode("Mouse") end)

ScreenGui.CloseButton.MouseButton1Click:Connect(function()
    _G.__AimbotX_UserClosed = true
    ScreenGui.Frame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.ToggleKey then
        toggleLock()
    elseif input.KeyCode == CONFIG.CycleKey then
        cycleTarget()
    elseif input.KeyCode == CONFIG.HideUIKey then
        ScreenGui.Frame.Visible = not ScreenGui.Frame.Visible
        _G.__AimbotX_UserClosed = not ScreenGui.Frame.Visible
    end
end)

print("[AimbotX] 10. UI wired")

-- ============================================================
-- KEEP THE UI ALIVE
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if not ScreenGui.ScreenGui.Parent then
            ScreenGui.ScreenGui.Parent = pg
        end
        if not ScreenGui.ScreenGui.Enabled then
            ScreenGui.ScreenGui.Enabled = true
        end
        if not ScreenGui.Frame.Visible and not _G.__AimbotX_UserClosed then
            ScreenGui.Frame.Visible = true
        end
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.25)
    if not ScreenGui.ScreenGui.Parent then
        ScreenGui.ScreenGui.Parent = pg
    end
    ScreenGui.ScreenGui.Enabled = true
    if not _G.__AimbotX_UserClosed then
        ScreenGui.Frame.Visible = true
    end
    unlock()
end)

refreshUI()

print("[AimbotX] DONE - UI should be on screen now")
print("[AimbotX] If you see this but no UI, check PlayerGui -> AimbotXUI")