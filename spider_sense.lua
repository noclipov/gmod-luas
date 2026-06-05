--[[
    HUD: Out of View Indicator (Wall Check)
    Реагирует только если прицел проходит без стен
]]

local ply = LocalPlayer()

-- Настройки HUD
local config = {
    color_aim = Color(255, 60, 60, 200),
    color_near = Color(255, 140, 60, 180),
    
    radius = 40,
    arrow_size = 12,
    arc_thickness = 2,
    arc_angle = 100,
    
    max_distance = 2500,
    aim_tolerance = 10,
    near_tolerance = 30,
}

-- Проверка видимости через стены
local function IsVisible(shooter, target)
    local trace = {}
    trace.start = shooter:EyePos()
    trace.endpos = target:GetShootPos()
    trace.filter = {shooter, target}
    trace.mask = MASK_SHOT_HULL
    
    local tr = util.TraceLine(trace)
    return not tr.HitWorld -- Если не попали в мир (стену), значит видит
end

-- Проверка прицела с учётом стен
local function CheckAimProximity(shooter, target)
    if not IsValid(shooter) or not IsValid(target) then return false, false end
    if not shooter:Alive() or not target:Alive() then return false, false end
    
    local distance = shooter:GetPos():Distance(target:GetPos())
    if distance > config.max_distance then return false, false end
    
    -- Сначала проверяем видимость
    if not IsVisible(shooter, target) then
        return false, false -- Не видит сквозь стену - игнорируем
    end
    
    local shooterAngles = shooter:EyeAngles()
    local shooterForward = shooterAngles:Forward()
    local toTarget = (target:GetShootPos() - shooter:EyePos()):GetNormalized()
    
    local dot = shooterForward:Dot(toTarget)
    local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))
    
    local isDirect = angle <= config.aim_tolerance
    local isNear = angle <= config.near_tolerance
    
    return isDirect, isNear
end

-- Поиск угроз (только видимые)
local function FindThreats()
    local threats = {}
    for _, plyCheck in ipairs(player.GetAll()) do
        if plyCheck == ply or not plyCheck:Alive() then continue end
        local isDirect, isNear = CheckAimProximity(plyCheck, ply)
        if isDirect or isNear then
            table.insert(threats, {player = plyCheck, isDirect = isDirect})
        end
    end
    return threats
end

-- Направление на врага
local function GetDirectionToEnemy(targetPos)
    local myPos = ply:GetPos()
    local myAngles = ply:EyeAngles()
    local toTarget = (targetPos - myPos):GetNormalized()
    local forward = myAngles:Forward()
    local right = myAngles:Right()
    return math.atan2(right:Dot(toTarget), forward:Dot(toTarget))
end

-- Рисование дуги
local function DrawArc(centerX, centerY, directionAngle, color)
    local screenAngle = directionAngle - math.pi / 2
    local arcRad = math.rad(config.arc_angle)
    local halfArc = arcRad / 2
    local startAngle = screenAngle - halfArc
    local endAngle = screenAngle + halfArc
    
    local radius = config.radius
    local innerRadius = radius - config.arc_thickness
    
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    
    -- Внешняя дуга
    local lastPoint = nil
    for i = 0, 30 do
        local angle = startAngle + (endAngle - startAngle) * (i / 30)
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        if lastPoint then
            surface.DrawLine(lastPoint.x, lastPoint.y, x, y)
        end
        lastPoint = {x = x, y = y}
    end
    
    -- Внутренняя дуга
    lastPoint = nil
    for i = 0, 30 do
        local angle = startAngle + (endAngle - startAngle) * (i / 30)
        local x = centerX + math.cos(angle) * innerRadius
        local y = centerY + math.sin(angle) * innerRadius
        if lastPoint then
            surface.DrawLine(lastPoint.x, lastPoint.y, x, y)
        end
        lastPoint = {x = x, y = y}
    end
end

-- Рисование треугольной стрелки
local function DrawTriangleArrow(centerX, centerY, directionAngle, color)
    local screenAngle = directionAngle - math.pi / 2
    
    local baseX = centerX + math.cos(screenAngle) * (config.radius - 2)
    local baseY = centerY + math.sin(screenAngle) * (config.radius - 2)
    
    local tipX = baseX + math.cos(screenAngle) * config.arrow_size
    local tipY = baseY + math.sin(screenAngle) * config.arrow_size
    
    local perpAngle = screenAngle + math.pi / 2
    local wingSize = config.arrow_size * 0.5
    
    local leftX = baseX + math.cos(perpAngle) * wingSize
    local leftY = baseY + math.sin(perpAngle) * wingSize
    
    local rightX = baseX - math.cos(perpAngle) * wingSize
    local rightY = baseY - math.sin(perpAngle) * wingSize
    
    surface.SetDrawColor(color.r, color.g, color.b, color.a + 40)
    local triangle = {
        {x = tipX, y = tipY},
        {x = leftX, y = leftY},
        {x = rightX, y = rightY}
    }
    surface.DrawPoly(triangle)
end

-- Основная отрисовка
local function DrawThreatIndicator()
    if not IsValid(ply) or not ply:Alive() then return end
    
    local threats = FindThreats()
    if #threats == 0 then return end
    
    local centerX = ScrW() / 2
    local centerY = ScrH() / 2
    
    -- Группировка
    local grouped = {}
    for _, threat in ipairs(threats) do
        local angle = GetDirectionToEnemy(threat.player:GetPos())
        local found = false
        for _, g in ipairs(grouped) do
            if math.abs(angle - g.angle) < 0.3 then
                g.count = g.count + 1
                if threat.isDirect then g.hasDirect = true end
                found = true
                break
            end
        end
        if not found then
            table.insert(grouped, {angle = angle, count = 1, hasDirect = threat.isDirect})
        end
    end
    
    for _, group in ipairs(grouped) do
        local color = group.hasDirect and config.color_aim or config.color_near
        DrawArc(centerX, centerY, group.angle, color)
        DrawTriangleArrow(centerX, centerY, group.angle, color)
        
        if group.count > 1 then
            local screenAngle = group.angle - math.pi / 2
            local tx = centerX + math.cos(screenAngle) * (config.radius + 12)
            local ty = centerY + math.sin(screenAngle) * (config.radius + 12)
            draw.SimpleText(group.count, "Trebuchet24", tx, ty, Color(255,255,255,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- Отладка
local debug_enabled = false
local function DrawDebugInfo()
    if not debug_enabled then return end
    local threats = FindThreats()
    surface.SetDrawColor(0,0,0,200)
    surface.DrawRect(0,0,400,30 + #threats * 22)
    draw.SimpleText("=== Wall-Aware Threat Detector ===", "Trebuchet24", 10,10, Color(255,255,255))
    for i, t in ipairs(threats) do
        local dist = ply:GetPos():Distance(t.player:GetPos())
        draw.SimpleText(string.format("%s [%s] - %.0fm", t.player:Nick(), t.isDirect and "DIRECT" or "NEAR", dist), 
            "Trebuchet24", 10, 30 + i*20, Color(255,180,100))
    end
    if #threats == 0 then
        draw.SimpleText("No visible threats", "Trebuchet24", 10, 30, Color(100,255,100))
    end
end

-- Тест
local test_mode = false
local function DrawTest()
    if not test_mode then return end
    local cx, cy = ScrW()/2, ScrH()/2
    for _, ang in ipairs({-3.14, -1.57, 0, 1.57, 3.14}) do
        DrawArc(cx, cy, ang, Color(100,150,255,100))
        DrawTriangleArrow(cx, cy, ang, Color(100,150,255,150))
    end
end

hook.Add("HUDPaint", "OutOfView", DrawThreatIndicator)
hook.Add("HUDPaint", "OutOfViewDebug", DrawDebugInfo)
hook.Add("HUDPaint", "OutOfViewTest", DrawTest)

concommand.Add("outofview_debug", function() debug_enabled = not debug_enabled end)
concommand.Add("outofview_test", function() test_mode = not test_mode end)

print("========================================")
print("[OutOfView] Loaded - Wall Check Enabled")
print("  Only shows if enemy has LINE OF SIGHT")
print("  No reaction through walls!")
print("========================================")