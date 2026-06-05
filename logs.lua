-- =====================================================
-- KILL FEED - Minimalist death notifications (Under crosshair)
-- =====================================================

-- Cleanup previous instances
hook.Remove("entity_killed", "KillFeedEntity")
hook.Remove("OnScreenSizeChanged", "RepositionKillFeed")
hook.Remove("ShutDown", "CleanKillFeed")
timer.Remove("HideKillFeed")

concommand.Remove("test_kill_feed")
concommand.Remove("test_death_feed")
concommand.Remove("test_other_feed")
concommand.Remove("test_suicide_feed")

if killFeedPanel and IsValid(killFeedPanel) then
    killFeedPanel:Remove()
end

-- =====================================================
-- CONFIGURATION
-- =====================================================
local CONFIG = {
    maxLogs = 4,
    duration = 3.5,
    panelWidth = 340,
    rowHeight = 22,
    padding = 4,
    offsetFromCenter = 25,
    fadeTime = 0.2,
    slideTime = 0.15
}

-- Colors
local COLORS = {
    text = Color(220, 210, 240, 200),
    name = Color(200, 180, 240, 220),
    entity = Color(255, 150, 100, 220),
    weapon = Color(180, 160, 220, 200),
    weaponAlt = Color(140, 120, 180, 160),
    death = Color(255, 100, 100, 220),
    kill = Color(100, 200, 100, 220),
    bg = Color(0, 0, 0, 120)
}

-- Fonts
surface.CreateFont("KillFeedNormal", {
    font = "Jura Light",
    size = 14,
    weight = 400,
    shadow = true,
    shadowoffset = 1,
    antialias = true
})

surface.CreateFont("KillFeedBold", {
    font = "Jura Regular",
    size = 14,
    weight = 700,
    shadow = true,
    shadowoffset = 1,
    antialias = true
})

surface.CreateFont("KillFeedSmall", {
    font = "Jura Light",
    size = 11,
    weight = 400,
    shadow = true,
    shadowoffset = 1,
    antialias = true
})

-- =====================================================
-- UTILITIES
-- =====================================================
local function getSteamIDNum(ply)
    if not IsValid(ply) then return "?????" end
    local steamid = ply:SteamID()
    local id = string.match(steamid or "", "STEAM_%d:%d:(%d+)")
    return id or "?????"
end

local function getAttackerName(attacker)
    if not IsValid(attacker) then return nil, false end
    
    -- Player
    if attacker:IsPlayer() then
        return attacker:Nick(), false
    end
    
    -- Entity - return raw class name
    local className = attacker:GetClass()
    if className and className ~= "" then
        return className, true
    end
    
    return "entity", true
end

local function getWeaponClass(ent)
    if not IsValid(ent) then return "?" end
    
    local class = ent:GetClass()
    
    if class and class ~= "" then
        return class
    end
    
    if ent:IsPlayer() then
        return "player"
    end
    
    return "?"
end

local function getWeaponInfo(attacker, victim, inflictor)
    local activeWeapon = "?"
    local inflictorWeapon = "?"
    local hasAdditional = false
    
    -- Get attacker's active weapon (if attacker is player)
    if IsValid(attacker) and attacker:IsPlayer() then
        local active = attacker:GetActiveWeapon()
        if IsValid(active) then
            activeWeapon = getWeaponClass(active)
        end
    elseif IsValid(attacker) and not attacker:IsPlayer() then
        -- For NPC/Entity attackers, show their class as weapon
        activeWeapon = attacker:GetClass()
        if activeWeapon == "" then activeWeapon = "?"
        end
    end
    
    -- Get inflictor entity
    if IsValid(inflictor) then
        inflictorWeapon = getWeaponClass(inflictor)
        if activeWeapon ~= inflictorWeapon and inflictorWeapon ~= "?" and not inflictor:IsPlayer() then
            hasAdditional = true
        end
    end
    
    if IsValid(inflictor) and inflictor:GetClass() == "worldspawn" then
        inflictorWeapon = "worldspawn"
        hasAdditional = true
    end
    
    return activeWeapon, inflictorWeapon, hasAdditional
end

local function playSound(eventType)
    local soundFolder = ""
    local fallbackSound = ""
    if eventType == "my_kill" then
        soundFolder = "kills/"
        fallbackSound = "weapons/ar2/ar2_explode.wav"
    elseif eventType == "my_death" then
        soundFolder = "deaths/"
        fallbackSound = "npc/turret_floor/die1.wav"
    end
    local files, folders = file.Find("sound/" .. soundFolder .. "*.wav", "GAME")
    if files and #files > 0 then
        local randomSound = soundFolder .. files[math.random(#files)]
        surface.PlaySound(randomSound)
    else
        surface.PlaySound(fallbackSound)
    end
end

-- =====================================================
-- UI PANEL
-- =====================================================
killFeedPanel = nil
killFeedEntries = {}
hideTimer = nil

local function getPanelPosition()
    local centerX = ScrW() / 2
    local centerY = ScrH() / 2
    local panelX = centerX - CONFIG.panelWidth / 2
    local panelY = centerY + CONFIG.offsetFromCenter
    return panelX, panelY
end

local function updatePanel()
    if not IsValid(killFeedPanel) then return end
    
    local y = CONFIG.padding
    for i, entry in ipairs(killFeedEntries) do
        if IsValid(entry.container) then
            entry.container:SetPos(CONFIG.padding, y)
            y = y + CONFIG.rowHeight
        end
    end
    
    local height = #killFeedEntries * CONFIG.rowHeight + CONFIG.padding * 2
    killFeedPanel:SetTall(height)
    
    local panelX, panelY = getPanelPosition()
    killFeedPanel:SetPos(panelX, panelY)
end

local function hidePanel()
    if IsValid(killFeedPanel) and #killFeedEntries == 0 then
        killFeedPanel:AlphaTo(0, CONFIG.fadeTime, 0, function()
            if IsValid(killFeedPanel) then 
                killFeedPanel:SetTall(0)
                killFeedPanel:SetVisible(false)
            end
        end)
    end
end

local function resetTimer()
    if hideTimer then 
        timer.Remove(hideTimer)
        hideTimer = nil
    end
    
    hideTimer = timer.Create("HideKillFeed", CONFIG.duration, 1, function()
        for _, entry in ipairs(killFeedEntries) do
            if IsValid(entry.container) then 
                entry.container:Remove() 
            end
        end
        killFeedEntries = {}
        updatePanel()
        hidePanel()
        hideTimer = nil
    end)
end

local function animateRemove(entry)
    if not IsValid(entry.container) then return end
    
    entry.container:AlphaTo(0, CONFIG.fadeTime, 0, function()
        if IsValid(entry.container) then 
            entry.container:Remove() 
        end
        
        for i, e in ipairs(killFeedEntries) do
            if e == entry then 
                table.remove(killFeedEntries, i)
                break 
            end
        end
        
        updatePanel()
        if #killFeedEntries == 0 then
            hidePanel()
        end
    end)
end

local function createPanel()
    if IsValid(killFeedPanel) then return end
    
    killFeedPanel = vgui.Create("Panel")
    killFeedPanel:SetSize(CONFIG.panelWidth, 0)
    killFeedPanel:SetAlpha(0)
    killFeedPanel:SetKeyboardInputEnabled(false)
    killFeedPanel:SetMouseInputEnabled(false)
    killFeedPanel:SetVisible(false)
    killFeedPanel.Paint = function(_, w, h)
        if h > 0 then
            draw.RoundedBox(3, 0, 0, w, h, COLORS.bg)
        end
    end
end

-- =====================================================
-- MESSAGE CREATION
-- =====================================================
local function createLabels(container, labels)
    local x = 0
    local y = 2
    
    for _, lbl in ipairs(labels) do
        local label = vgui.Create("DLabel", container)
        label:SetText(lbl.text)
        label:SetColor(lbl.color)
        label:SetFont(lbl.font)
        label:SizeToContents()
        label:SetPos(x, y)
        x = x + label:GetWide()
    end
end

local function createMessage(attacker, victim, weapon, secondaryWeapon, hasSecondary, isLocalDeath, isLocalKill, isEntityAttacker)
    local container = vgui.Create("Panel", killFeedPanel)
    container:SetSize(CONFIG.panelWidth - CONFIG.padding * 2, 18)
    container.Paint = function() end
    
    local labels = {}
    
    if attacker and victim then
        local victimColor = isLocalDeath and COLORS.death or COLORS.name
        local attackerColor = isLocalKill and COLORS.kill or (isEntityAttacker and COLORS.entity or COLORS.name)
        local arrowColor = isLocalDeath and COLORS.death or COLORS.text
        
        -- Shorten names only for players
        local attackerName = attacker.name
        local victimName = victim.name
        if not isEntityAttacker and #attackerName > 12 then 
            attackerName = string.sub(attackerName, 1, 10) .. ".." 
        end
        if #victimName > 12 then 
            victimName = string.sub(victimName, 1, 10) .. ".." 
        end
        
        labels = {
            {text = attackerName, color = attackerColor, font = "KillFeedBold"},
            {text = " → ", color = arrowColor, font = "KillFeedNormal"},
            {text = victimName, color = victimColor, font = "KillFeedBold"}
        }
        
        -- Add weapon info
        if hasSecondary and secondaryWeapon and secondaryWeapon ~= "?" and secondaryWeapon ~= weapon then
            labels[#labels + 1] = {text = " [", color = COLORS.weapon, font = "KillFeedNormal"}
            labels[#labels + 1] = {text = weapon, color = COLORS.kill, font = "KillFeedBold"}
            labels[#labels + 1] = {text = " → ", color = COLORS.weaponAlt, font = "KillFeedSmall"}
            labels[#labels + 1] = {text = secondaryWeapon, color = COLORS.weaponAlt, font = "KillFeedSmall"}
            labels[#labels + 1] = {text = "]", color = COLORS.weapon, font = "KillFeedNormal"}
        else
            labels[#labels + 1] = {text = " [", color = COLORS.weapon, font = "KillFeedNormal"}
            labels[#labels + 1] = {text = weapon, color = COLORS.weapon, font = "KillFeedBold"}
            labels[#labels + 1] = {text = "]", color = COLORS.weapon, font = "KillFeedNormal"}
        end
        
    elseif victim then
        local victimColor = isLocalDeath and COLORS.death or COLORS.text
        local victimName = victim.name
        if #victimName > 16 then 
            victimName = string.sub(victimName, 1, 14) .. ".." 
        end
        
        labels = {
            {text = victimName, color = victimColor, font = "KillFeedBold"},
            {text = " died", color = COLORS.text, font = "KillFeedNormal"}
        }
        
        if weapon and weapon ~= "?" then
            labels[#labels + 1] = {text = " [", color = COLORS.weapon, font = "KillFeedNormal"}
            labels[#labels + 1] = {text = weapon, color = COLORS.weapon, font = "KillFeedBold"}
            labels[#labels + 1] = {text = "]", color = COLORS.weapon, font = "KillFeedNormal"}
        end
    end
    
    createLabels(container, labels)
    return container
end

local function addMessage(attacker, victim, weapon, secondaryWeapon, hasSecondary, soundType, isLocalDeath, isLocalKill, isEntityAttacker)
    createPanel()
    
    local entry = {
        container = createMessage(attacker, victim, weapon, secondaryWeapon, hasSecondary, isLocalDeath, isLocalKill, isEntityAttacker),
        soundType = soundType or "other"
    }
    
    table.insert(killFeedEntries, entry)
    
    while #killFeedEntries > CONFIG.maxLogs do
        local oldest = table.remove(killFeedEntries, 1)
        if IsValid(oldest.container) then 
            oldest.container:Remove()
        end
    end
    
    updatePanel()
    
    if not killFeedPanel:IsVisible() then
        killFeedPanel:SetVisible(true)
        killFeedPanel:SetAlpha(0)
        killFeedPanel:AlphaTo(255, CONFIG.fadeTime)
    elseif killFeedPanel:GetAlpha() < 255 then
        killFeedPanel:AlphaTo(255, CONFIG.fadeTime)
    end
    
    entry.container:SetAlpha(0)
    entry.container:AlphaTo(255, CONFIG.slideTime)
    
    if soundType ~= "other" then 
        playSound(soundType) 
    end
    
    resetTimer()
    
    timer.Simple(CONFIG.duration, function()
        if entry.container and IsValid(entry.container) then
            local stillExists = false
            for _, e in ipairs(killFeedEntries) do
                if e == entry then
                    stillExists = true
                    break
                end
            end
            if stillExists then
                animateRemove(entry)
            end
        end
    end)
end

-- =====================================================
-- EVENT HANDLER
-- =====================================================
gameevent.Listen("entity_killed")

hook.Add("entity_killed", "KillFeedEntity", function(data)
    local victim = Entity(data.entindex_killed)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    
    local attacker = Entity(data.entindex_attacker)
    local inflictor = Entity(data.entindex_inflictor)
    local localPlayer = LocalPlayer()
    
    if not IsValid(localPlayer) then return end
    
    local isSuicide = (not IsValid(attacker) or attacker == victim)
    local isMyDeath = (victim == localPlayer)
    local isMyKill = (IsValid(attacker) and attacker == localPlayer and not isSuicide)
    
    local weapon = "?"
    local secondaryWeapon = "?"
    local hasSecondary = false
    local isEntityAttacker = false
    
    if not isSuicide and IsValid(attacker) then
        local activeWeapon, inflictorWeapon, hasAdditional = getWeaponInfo(attacker, victim, inflictor)
        weapon = activeWeapon
        secondaryWeapon = inflictorWeapon
        hasSecondary = hasAdditional
        
        -- Check if attacker is an entity (not a player)
        if not attacker:IsPlayer() then
            isEntityAttacker = true
        end
    elseif isSuicide and IsValid(victim) then
        if IsValid(inflictor) then
            weapon = getWeaponClass(inflictor)
        end
    end
    
    local victimData = {
        name = victim:Nick(),
        steamid = getSteamIDNum(victim)
    }
    
    local soundType = "other"
    local isLocalDeath = false
    local isLocalKill = false
    
    if isSuicide then
        isLocalDeath = isMyDeath
        if isMyDeath then soundType = "my_death" end
        addMessage(nil, victimData, weapon, nil, false, soundType, isLocalDeath, false, false)
        
    elseif isMyKill then
        local attackerData = {
            name = localPlayer:Nick(),
            steamid = getSteamIDNum(localPlayer)
        }
        soundType = "my_kill"
        isLocalKill = true
        addMessage(attackerData, victimData, weapon, secondaryWeapon, hasSecondary, soundType, false, isLocalKill, false)
        
    elseif isMyDeath then
        local attackerName, isEntity = getAttackerName(attacker)
        local attackerData = {
            name = attackerName,
            steamid = isEntity and "NPC" or getSteamIDNum(attacker)
        }
        soundType = "my_death"
        isLocalDeath = true
        addMessage(attackerData, victimData, weapon, secondaryWeapon, hasSecondary, soundType, isLocalDeath, false, isEntity)
        
    else
        local attackerName, isEntity = getAttackerName(attacker)
        local attackerData = {
            name = attackerName,
            steamid = isEntity and "NPC" or getSteamIDNum(attacker)
        }
        addMessage(attackerData, victimData, weapon, secondaryWeapon, hasSecondary, "other", false, false, isEntity)
    end
end)

-- =====================================================
-- RESIZE HANDLER
-- =====================================================
hook.Add("OnScreenSizeChanged", "RepositionKillFeed", function()
    if IsValid(killFeedPanel) then
        updatePanel()
        local panelX, panelY = getPanelPosition()
        killFeedPanel:SetPos(panelX, panelY)
    end
end)

-- =====================================================
-- CLEANUP ON SHUTDOWN
-- =====================================================
hook.Add("ShutDown", "CleanKillFeed", function()
    hook.Remove("entity_killed", "KillFeedEntity")
    hook.Remove("OnScreenSizeChanged", "RepositionKillFeed")
    timer.Remove("HideKillFeed")
    if hideTimer then timer.Remove(hideTimer) end
    if killFeedPanel and IsValid(killFeedPanel) then killFeedPanel:Remove() end
end)

print("[Kill Feed] Loaded!")