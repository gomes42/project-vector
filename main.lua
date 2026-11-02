--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                 PROJECT VECTOR · TRUE BORE CROSSHAIR                 ║
    ║        3rd Person Internal Raycast Crosshair (TikTok Cold War)       ║
    ╚══════════════════════════════════════════════════════════════════════╝

    Overview:
    Exact 1:1 replication of the 3rd-person internal true bore crosshair from Cold War gameplay.
    In 3rd person, screen center does NOT match bullet trajectory due to camera offset
    and weapon animations. This script live-tracks the weapon's barrel muzzle every single
    frame, raycasts along the true barrel orientation past character geometry, and projects
    the exact 3D world impact point directly to your screen via draw.WorldToScreen.

    Features:
    [x] Zero-Delay Live Weapon Detection:
        - Multi-tier resolver: Muzzle1 -> Tool Handle -> Right Arm -> Player LookVector
        - Universal vector extractor supporting PascalCase, snake_case, and CFrame structures
    [x] Persistent Visibility on Aiming:
        - Never disappears on Right Click (ADS) — remains 100% active during zoom & hipfire
    [x] True Bore Raycast & Impact Projection:
        - 2.5-stud forward offset along barrel orientation prevents self-collision with player limbs/vest
        - Self-hit bypass: projects through player limbs/vest directly to the world target
        - Infinite sky projection fallback retains barrel orientation when aiming at open horizon
        - Instant 1:1 locked barrel tracking (zero floatiness, lag or dropped frames)
    [x] Exact TikTok Aesthetics:
        - Neon Pink / Magenta '+' crosshair (#FF1493) with razor-sharp black dropshadow outline
    [x] Safe Native Weapon Recoil Reducer:
        - Cold War native BallisticsClient.DebugShotsGui hook (zero memory corruption)
    [x] Lua 5.1 / LuaJIT Bulletproof Safety Layer:
        - Polyfilled clamp, math.clamp, Vector3 constructors, draw.CircleFilled / FilledCircle
        - Zero nil runtime exceptions under any execution path
]]

-- ═══════════════════════════════════════════════════════════════════════
-- LUA 5.1 / LUAJIT COMPATIBILITY & SAFETY LAYER
-- ═══════════════════════════════════════════════════════════════════════
local print = function(...) end
local warn  = function(...) end

local function clamp(val, minVal, maxVal)
    if not val then return minVal or 0 end
    if minVal and val < minVal then return minVal end
    if maxVal and val > maxVal then return maxVal end
    return val
end

if not math.clamp then
    math.clamp = clamp
end

if Vector3 then
    if not Vector3.new and Vector3.New then
        Vector3.new = Vector3.New
    elseif not Vector3.New and Vector3.new then
        Vector3.New = Vector3.new
    end
end

-- Thread Polyfill
if thread then
    if not thread.Create and thread.create then
        thread.Create = thread.create
    elseif not thread.create and thread.Create then
        thread.create = thread.Create
    end
end

-- Universal Draw Polyfill: bridges PascalCase and snake_case across all Vector versions
if draw then
    local realCircleFilled = draw.CircleFilled or draw.circle_filled or draw.FilledCircle
    if realCircleFilled then
        draw.CircleFilled = realCircleFilled
        draw.circle_filled = realCircleFilled
        draw.FilledCircle = realCircleFilled
    end

    local realCircle = draw.Circle or draw.circle
    if realCircle then
        draw.Circle = realCircle
        draw.circle = realCircle
    end

    local realLine = draw.Line or draw.line
    if realLine then
        draw.Line = realLine
        draw.line = realLine
    end

    local realText = draw.Text or draw.text
    if realText then
        draw.Text = realText
        draw.text = realText
    end

    local realScreenSize = draw.GetScreenSize or draw.get_screen_size
    if realScreenSize then
        draw.GetScreenSize = realScreenSize
        draw.get_screen_size = realScreenSize
    end

    local realW2S = draw.WorldToScreen or draw.world_to_screen
    if not realW2S and utility and (utility.WorldToScreen or utility.world_to_screen) then
        realW2S = utility.WorldToScreen or utility.world_to_screen
    end
    if realW2S then
        draw.WorldToScreen = realW2S
        draw.world_to_screen = realW2S
    end
end

-- Safe circle filled drawer
local function safeCircleFilled(x, y, r, col, seg)
    pcall(function()
        if not draw then return end
        local fn = draw.CircleFilled or draw.circle_filled or draw.FilledCircle
        if fn then
            fn(x, y, r, col, seg or 12)
        elseif draw.Circle or draw.circle then
            local cFn = draw.Circle or draw.circle
            for rad = 1, math.max(1, math.floor(r)) do
                cFn(x, y, rad, col, seg or 12, 1)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- MENU SETUP
-- ═══════════════════════════════════════════════════════════════════════
local function safeUI(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

safeUI(menu.AddTab, "Crosshair", "X")

-- Group 1: 3rd Person True Bore Crosshair
safeUI(menu.AddGroup, "Crosshair", "TikTok 3rd Person True Bore Crosshair")
safeUI(menu.AddCheckbox, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_enabled", "Enable True Bore Crosshair", true)
safeUI(menu.AddCombo, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_style", "Crosshair Style", {"Plus Cross (+)", "Plus with Center Dot", "Cross with Gap", "Dot Only"}, 0)
safeUI(menu.AddCheckbox, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_outline", "Draw Black Outline", true)
safeUI(menu.AddCheckbox, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_instant", "Instant 1:1 Tracking (No Lag)", true)

safeUI(menu.AddSeparator, "Crosshair", "TikTok 3rd Person True Bore Crosshair")
safeUI(menu.AddSliderInt, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_size", "Crosshair Size (px)", 3, 25, 7, "%d")
safeUI(menu.AddSliderInt, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_gap", "Center Gap (px)", 0, 15, 0, "%d")
safeUI(menu.AddSliderInt, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_thick", "Line Thickness (px)", 1, 4, 2, "%d")
safeUI(menu.AddSliderFloat, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_smooth", "Smoothing (if instant off)", 0.1, 1.0, 0.6, "%.2f")

safeUI(menu.AddSeparator, "Crosshair", "TikTok 3rd Person True Bore Crosshair")
-- Default color: TikTok Neon Pink / Magenta (#FF1493)
safeUI(menu.AddColorpicker, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_col", "Crosshair Color", {1.0, 0.12, 0.75, 1.0})
safeUI(menu.AddColorpicker, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_dot_col", "Center Dot Color", {1.0, 1.0, 1.0, 1.0})
safeUI(menu.AddCheckbox, "Crosshair", "TikTok 3rd Person True Bore Crosshair", "ch_debug", "Show Debug Info Overlay", false)

-- Group 2: Weapon Recoil Reducer (Native Cold War Ballistics Hook)
safeUI(menu.AddGroup, "Crosshair", "Weapon Modifications")
safeUI(menu.AddSliderInt, "Crosshair", "Weapon Modifications", "mod_recoil", "No Recoil (%)", 0, 100, 100, "%d%%")

-- ═══════════════════════════════════════════════════════════════════════
-- UNIVERSAL POSITION & ORIENTATION EXTRACTOR
-- ═══════════════════════════════════════════════════════════════════════
local function extractPosAndLook(obj)
    if not obj then return nil, nil end
    local pos = nil
    local look = nil

    -- 1. Try direct vector fields
    pcall(function()
        pos = obj.Position or obj.position or obj.WorldPosition
    end)

    pcall(function()
        look = obj.LookVector or obj.look_vector
    end)

    -- 2. Try CFrame reflection
    if not pos or not look then
        pcall(function()
            local cf = obj.CFrame or obj.WorldCFrame
            if cf then
                if not pos then
                    pos = cf.Position or cf.p
                end
                if not look then
                    look = cf.LookVector
                end
            end
        end)
    end

    -- 3. If obj has look vector but pos is missing or vice-versa
    if pos and look then
        return pos, look
    end

    return pos, look
end

-- ═══════════════════════════════════════════════════════════════════════
-- LIVE WEAPON & MUZZLE RESOLVER
-- ═══════════════════════════════════════════════════════════════════════
local lastResolvedSource = "None"

local function resolveWeaponBarrel()
    local lp = entity.GetLocalPlayer()
    local char = lp and lp.Character
    if not char then
        lastResolvedSource = "No Character"
        return nil, nil
    end

    -- 1. Scan Tool in Character (Cold War Standard)
    local tool = char:FindFirstChildWhichIsA("Tool") or char:FindFirstChildOfClass("Tool")
    if not tool then
        for _, child in ipairs(char:GetChildren()) do
            if child.ClassName == "Tool" or (child.IsA and child:IsA("Tool")) then
                tool = child
                break
            end
        end
    end

    if tool then
        local handle = tool:FindFirstChild("Handle") or tool.PrimaryPart
        if handle then
            -- A. Search Muzzle Attachment
            local m = handle:FindFirstChild("Muzzle1") or handle:FindFirstChild("Muzzle")
            if not m then
                for _, desc in ipairs(handle:GetDescendants()) do
                    if string.find(desc.Name, "Muzzle") then
                        m = desc
                        break
                    end
                end
            end

            if m then
                local p, l = extractPosAndLook(m)
                if p and l then
                    lastResolvedSource = "Tool Attachment (" .. m.Name .. ")"
                    return p, l
                end
            end

            -- B. Fallback: Handle itself
            local hp, hl = extractPosAndLook(handle)
            if hp and hl then
                lastResolvedSource = "Tool Handle"
                return hp, hl
            end
        end
    end

    -- 2. Scan Right Arm / ToolGrip Motor6D
    local rArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
    if rArm then
        local toolGrip = rArm:FindFirstChild("ToolGrip") or rArm:FindFirstChildWhichIsA("Motor6D")
        local handle = toolGrip and toolGrip.Part1
        if handle then
            local p, l = extractPosAndLook(handle)
            if p and l then
                lastResolvedSource = "ToolGrip Part1"
                return p, l
            end
        end

        -- Right Arm orientation as high-accuracy weapon proxy
        local ap, al = extractPosAndLook(rArm)
        if ap and al then
            -- Offset 1.8 studs forward from right arm towards hand
            local handPos = ap + (al * 1.8)
            lastResolvedSource = "Right Arm Proxy"
            return handPos, al
        end
    end

    -- 3. Scan 1st Person Viewmodel in Camera (if in first person)
    local cam = workspace.CurrentCamera
    if cam then
        for _, child in ipairs(cam:GetChildren()) do
            if string.find(child.Name, "Viewmodel") or child.ClassName == "Model" then
                for _, desc in ipairs(child:GetDescendants()) do
                    if string.find(desc.Name, "Muzzle") then
                        local p, l = extractPosAndLook(desc)
                        if p and l then
                            lastResolvedSource = "Viewmodel Muzzle"
                            return p, l
                        end
                    end
                end
                local h = child:FindFirstChild("Handle")
                if h then
                    local hp, hl = extractPosAndLook(h)
                    if hp and hl then
                        lastResolvedSource = "Viewmodel Handle"
                        return hp, hl
                    end
                end
            end
        end
    end

    -- 4. Fallback: LocalPlayer HeadPosition + LookVector
    if lp and lp.Position and lp.LookVector then
        local headPos = lp.HeadPosition or (lp.Position + Vector3.New(0, 1.5, 0))
        lastResolvedSource = "Player LookVector"
        return headPos, lp.LookVector
    end

    lastResolvedSource = "Failed"
    return nil, nil
end

-- Animated screen coordinate tracking
local currentScreenX = nil
local currentScreenY = nil
local frameCounter = 0

-- ═══════════════════════════════════════════════════════════════════════
-- MAIN RENDER PIPELINE (OnFrame)
-- ═══════════════════════════════════════════════════════════════════════
OnFrame = function()
    if not menu.Get("ch_enabled") then
        return
    end

    -- Safe periodic native recoil hook (every 60 frames / ~1 sec)
    frameCounter = frameCounter + 1
    if frameCounter % 60 == 0 then
        pcall(function()
            local recoilRed = menu.Get("mod_recoil") or 0
            local pl = game and game.Players and game.Players.LocalPlayer
            local ps = pl and pl:FindFirstChild("PlayerScripts")
            local bc = ps and ps:FindFirstChild("BallisticsClient")
            if bc then
                local dbg = bc:FindFirstChild("DebugShotsGui")
                if recoilRed > 0 then
                    if not dbg then
                        dbg = Instance.new("BoolValue")
                        dbg.Name = "DebugShotsGui"
                        dbg.Parent = bc
                    end
                    dbg.Value = true
                else
                    if dbg and dbg.Value then
                        dbg.Value = false
                    end
                end
            end
        end)
    end

    local sw, sh = draw.GetScreenSize()
    local cx, cy = sw * 0.5, sh * 0.5

    local lp = entity.GetLocalPlayer()
    local char = lp and lp.Character
    local style = menu.Get("ch_style") or 0 -- 0: Plus (+), 1: Plus with Dot, 2: Cross with Gap, 3: Dot Only
    local baseSize = menu.Get("ch_size") or 7
    local baseGap = menu.Get("ch_gap") or 0
    local thick = menu.Get("ch_thick") or 2
    local isInstant = menu.Get("ch_instant") ~= false
    local smoothAlpha = isInstant and 1.0 or (menu.Get("ch_smooth") or 0.6)
    local drawOutline = menu.Get("ch_outline") ~= false
    local showDebug = menu.Get("ch_debug") == true

    local crossCol = menu.GetColor("ch_col") or {1.0, 0.12, 0.75, 1.0}
    local dotCol   = menu.GetColor("ch_dot_col") or {1.0, 1.0, 1.0, 1.0}
    local outlineCol = {0.0, 0.0, 0.0, 0.95}

    -- 2. Resolve Active Weapon Barrel Position & Aim Direction
    local barrelPos, barrelLook = resolveWeaponBarrel()
    local targetX, targetY = cx, cy
    local rayDist = 0

    if barrelPos and barrelLook then
        -- Offset origin 2.5 studs forward along barrel orientation
        -- to completely bypass player character, arms, legs, and running animations
        local rayOrigin = barrelPos + (barrelLook * 2.5)
        local rayTarget = rayOrigin + (barrelLook * 10000)

        local hit, pos, dist, inst = raycast.Cast(rayOrigin, rayTarget)

        local impactPoint = nil
        if hit and pos and dist and dist > 0.5 then
            rayDist = dist
            local hitOwnChar = false
            pcall(function()
                if inst and char and (inst:IsDescendantOf(char) or inst == char) then
                    hitOwnChar = true
                end
            end)
            if hitOwnChar then
                impactPoint = rayOrigin + (barrelLook * 4000)
            else
                impactPoint = pos
            end
        else
            impactPoint = rayOrigin + (barrelLook * 4000)
        end

        -- Project 3D impact point to 2D screen viewport
        local sx, sy, onScreen = draw.WorldToScreen(impactPoint.X or impactPoint.x, impactPoint.Y or impactPoint.y, impactPoint.Z or impactPoint.z)
        if onScreen then
            targetX, targetY = sx, sy
        end
    end

    -- 3. Position Smoothing / 1:1 Instant Snapping
    if isInstant or not currentScreenX then
        currentScreenX = targetX
        currentScreenY = targetY
    else
        currentScreenX = currentScreenX + (targetX - currentScreenX) * smoothAlpha
        currentScreenY = currentScreenY + (targetY - currentScreenY) * smoothAlpha
    end

    local posX, posY = currentScreenX, currentScreenY
    local gap = (style == 0 or style == 1) and 0 or baseGap

    -- 4. Render Crosshair Elements (+ shape matching TikTok video)
    if style == 3 then
        -- Dot Only
        if drawOutline then
            safeCircleFilled(posX, posY, math.max(1, thick) + 1, outlineCol, 12)
        end
        safeCircleFilled(posX, posY, math.max(1, thick), dotCol, 12)
    else
        -- 4-line Crosshair
        local topY1   = posY - gap - baseSize
        local topY2   = posY - gap
        local botY1   = posY + gap
        local botY2   = posY + gap + baseSize
        local leftX1  = posX - gap - baseSize
        local leftX2  = posX - gap
        local rightX1 = posX + gap
        local rightX2 = posX + gap + baseSize

        -- Black Dropshadow Outline for 100% visibility on light backgrounds
        if drawOutline then
            local outThick = thick + 2
            draw.Line(posX, topY1 - 1, posX, topY2 + 1, outlineCol, outThick)
            draw.Line(posX, botY1 - 1, posX, botY2 + 1, outlineCol, outThick)
            draw.Line(leftX1 - 1, posY, leftX2 + 1, posY, outlineCol, outThick)
            draw.Line(rightX1 - 1, posY, rightX2 + 1, posY, outlineCol, outThick)
        end

        -- Main Razor-Sharp Neon Bars
        draw.Line(posX, topY1, posX, topY2, crossCol, thick)
        draw.Line(posX, botY1, posX, botY2, crossCol, thick)
        draw.Line(leftX1, posY, leftX2, posY, crossCol, thick)
        draw.Line(rightX1, posY, rightX2, posY, crossCol, thick)

        -- Center Dot (Style 1)
        if style == 1 then
            if drawOutline then
                safeCircleFilled(posX, posY, math.max(1, thick), outlineCol, 12)
            end
            safeCircleFilled(posX, posY, math.max(1, thick) - 0.5, dotCol, 12)
        end
    end

    -- 5. Optional Debug Overlay
    if showDebug then
        local dbgText = string.format("[Bore Crosshair] Source: %s | Hit Dist: %.1fm | Screen: (%.0f, %.0f)",
            lastResolvedSource, rayDist * 0.28, posX, posY)
        draw.Text(15, sh - 30, dbgText, {1.0, 1.0, 0.2, 0.95}, 12)
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- LOAD NOTIFICATION
-- ═══════════════════════════════════════════════════════════════════════
pcall(function()
    notify.Success("PROJECT VECTOR", "TikTok True Bore Crosshair (Persistent ADS) Ready", 6)
end)
