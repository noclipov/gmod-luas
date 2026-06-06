--[[
    HUD: Out of View Indicator (Wall Check)
    Реагирует только если прицел проходит без стен
    + Отображение информации об оружии целителя
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
    
    -- Настройки для информации об оружии
    weapon_info_offset = 18,     -- Смещение от стрелки (в пикселях)
    weapon_info_bg_alpha = 180,  -- Прозрачность фона
}

-- Проверка видимости через стены
local function IsVisible(shooter, target)
    local trace = {}
    trace.start = shooter:EyePos()
    trace.endpos = target:GetShootPos()
    trace.filter = {shooter, target}
    trace.mask = MASK_SHOT_HULL
    
    local tr = util.TraceLine(trace)
    return not tr.HitWorld
end

-- Проверка прицела с учётом стен
local function CheckAimProximity(shooter, target)
    if not IsValid(shooter) or not IsValid(target) then return false, false end
    if not shooter:Alive() or not target:Alive() then return false, false end
    
    local distance = shooter:GetPos():Distance(target:GetPos())
    if distance > config.max_distance then return false, false end
    
    if not IsVisible(shooter, target) then
        return false, false
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

-- Получение информации об активном оружии игрока (исправленная версия)
local function GetWeaponInfo(player)
    if not IsValid(player) then return nil end
    
    local weapon = player:GetActiveWeapon()
    if not IsValid(weapon) then return nil end
    
    -- Проверяем, может ли оружие стрелять (имеет патроны)
    local clip1 = weapon:Clip1()  -- Патроны в магазине
    
    -- Для некоторых оружий (например, дробовики) может быть Clip2
    local clip2 = weapon:Clip2()
    
    -- Проверяем наличие патронов в резерве (только если в магазине нет)
    local hasReserveAmmo = false
    if clip1 == 0 or clip1 == nil then
        -- Получаем ID типа патронов для этого оружия
        local primaryAmmoType = weapon:GetPrimaryAmmoType()
        if primaryAmmoType and primaryAmmoType ~= -1 then
            local reserveAmmo = player:GetAmmoCount(primaryAmmoType)
            hasReserveAmmo = (reserveAmmo and reserveAmmo > 0)
        end
    end
    
    -- Если нет патронов ни в магазине, ни в запасе - не показываем оружие
    local hasAmmo = (clip1 and clip1 > 0) or (clip2 and clip2 > 0) or hasReserveAmmo
    
    if not hasAmmo then return nil end
    
    -- Получаем печатное название оружия
    local weaponClass = weapon:GetClass()
    local weaponName = weapons.Get(weaponClass)
    local displayName = weaponName and weaponName.PrintName or weaponClass
    
    -- Обрезаем длинные названия
    if #displayName > 15 then
        displayName = displayName:sub(1, 12) .. "..."
    end
    
    -- Получаем максимальное количество патронов в магазине
    local maxClip1 = weapon:GetMaxClip1() or 0
    
    -- Текущие патроны (берём Clip1, если есть, иначе Clip2)
    local currentAmmo = (clip1 and clip1 > 0) and clip1 or (clip2 or 0)
    
    return {
        name = displayName,
        ammo = currentAmmo,
        maxAmmo = maxClip1,
        weapon = weapon,
        hasReserve = hasReserveAmmo and currentAmmo == 0  -- Флаг что есть запас, но магазин пуст
    }
end

-- Поиск угроз (только видимые) с оружием
local function FindThreats()
    local threats = {}
    for _, plyCheck in ipairs(player.GetAll()) do
        if plyCheck == ply or not plyCheck:Alive() then continue end
        local isDirect, isNear = CheckAimProximity(plyCheck, ply)
        if isDirect or isNear then
            local weaponInfo = GetWeaponInfo(plyCheck)
            table.insert(threats, {
                player = plyCheck,
                isDirect = isDirect,
                weaponInfo = weaponInfo
            })
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

-- Отображение информации об оружии
local function DrawWeaponInfo(centerX, centerY, directionAngle, weaponInfo, color)
    if not weaponInfo then return end
    
    local screenAngle = directionAngle - math.pi / 2
    local textX = centerX + math.cos(screenAngle) * (config.radius + config.weapon_info_offset)
    local textY = centerY + math.sin(screenAngle) * (config.radius + config.weapon_info_offset)
    
    -- Добавляем индикатор, если есть запас но магазин пуст
    local ammoText = weaponInfo.ammo .. "/" .. weaponInfo.maxAmmo
    if weaponInfo.hasReserve and weaponInfo.ammo == 0 then
        ammoText = "0/" .. weaponInfo.maxAmmo .. " (R)"
    end
    
    local text = weaponInfo.name .. " [" .. ammoText .. "]"
    
    -- Фон для текста (для лучшей читаемости)
    surface.SetFont("Trebuchet18")
    local textW, textH = surface.GetTextSize(text)
    
    surface.SetDrawColor(0, 0, 0, config.weapon_info_bg_alpha)
    surface.DrawRect(textX - textW/2 - 2, textY - textH/2 - 1, textW + 4, textH + 2)
    
    -- Цвет текста зависит от количества патронов
    local textColor
    if weaponInfo.ammo == 0 and weaponInfo.hasReserve then
        textColor = Color(255, 100, 100, 255)  -- Красный (нужна перезарядка)
    elseif weaponInfo.ammo <= 3 then
        textColor = Color(255, 80, 80, 255)  -- Красный (мало патронов)
    elseif weaponInfo.ammo <= 10 then
        textColor = Color(255, 200, 80, 255) -- Жёлтый
    else
        textColor = Color(200, 255, 200, 255) -- Зелёный
    end
    
    draw.SimpleText(text, "Trebuchet18", textX, textY, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
                -- Сохраняем информацию об оружии для отображения (берём первого в группе)
                if not g.weaponInfo and threat.weaponInfo then
                    g.weaponInfo = threat.weaponInfo
                end
                found = true
                break
            end
        end
        if not found then
            table.insert(grouped, {
                angle = angle,
                count = 1,
                hasDirect = threat.isDirect,
                weaponInfo = threat.weaponInfo
            })
        end
    end
    
    for _, group in ipairs(grouped) do
        local color = group.hasDirect and config.color_aim or config.color_near
        DrawArc(centerX, centerY, group.angle, color)
        DrawTriangleArrow(centerX, centerY, group.angle, color)
        
        -- Отображаем информацию об оружии
        if group.weaponInfo then
            DrawWeaponInfo(centerX, centerY, group.angle, group.weaponInfo, color)
        end
        
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
    surface.DrawRect(0,0,550,30 + #threats * 24)
    draw.SimpleText("=== Wall-Aware Threat Detector ===", "Trebuchet24", 10,10, Color(255,255,255))
    for i, t in ipairs(threats) do
        local dist = ply:GetPos():Distance(t.player:GetPos())
        local weaponStr = "No weapon"
        if t.weaponInfo then
            local ammoStr = t.weaponInfo.ammo .. "/" .. t.weaponInfo.maxAmmo
            if t.weaponInfo.hasReserve and t.weaponInfo.ammo == 0 then
                ammoStr = ammoStr .. " (need reload)"
            end
            weaponStr = string.format("%s [%s]", t.weaponInfo.name, ammoStr)
        end
        draw.SimpleText(string.format("%s [%s] - %.0fm - %s", t.player:Nick(), t.isDirect and "DIRECT" or "NEAR", dist, weaponStr), 
            "Trebuchet18", 10, 30 + i*22, Color(255,180,100))
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
        
        -- Тестовое отображение оружия
        local testWeapon = {
            name = "AK-47",
            ammo = 30,
            maxAmmo = 30,
            hasReserve = false
        }
        DrawWeaponInfo(cx, cy, ang, testWeapon, Color(100,150,255,150))
    end
end

hook.Add("HUDPaint", "OutOfView", DrawThreatIndicator)
hook.Add("HUDPaint", "OutOfViewDebug", DrawDebugInfo)
hook.Add("HUDPaint", "OutOfViewTest", DrawTest)

concommand.Add("outofview_debug", function() debug_enabled = not debug_enabled end)
concommand.Add("outofview_test", function() test_mode = not test_mode end)

print("========================================")
print("[OutOfView] Loaded - Wall Check Enabled")
print("========================================")