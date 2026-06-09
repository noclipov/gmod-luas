if not DarkRP then print("[Misc] Not Loaded! There is no DarkRP.") return end
surface.CreateFont("PromptTitleFont", {font = "Jura Regular",size = 24,weight = 700,antialias = true,shadow = false})
surface.CreateFont("PromptQuestionFont", {font = "Jura Regular",size = 18,weight = 500,antialias = true,shadow = false})
surface.CreateFont("PromptButtonFont", {font = "Jura Regular",size = 14,weight = 600,antialias = true,shadow = false})
local sf = string.format
local me = LocalPlayer()
local copy = SetClipboardText
local con = RunConsoleCommand
local jobs_presets, known_jobs, hooks_to_remove, panels_callback, sweps_to_ignore, commands_base, commands, hooks, disguise_team, last_preset, rainbow_psys_state, OGPhysColor
local function printBox(c,w)
	table.sort(c)w=w or 40
	local s=string.rep
	local function snf(e)print((e and"╔"or"╚")..s("═",w)..(e and"╗"or"╝"))end
	local function divider()print("╠"..s("═",w).."╣")end
	local function p(t,f)local x=w-#t local l=f and math.floor(x/2)or 0 print("║"..s(" ",l)..t..s(" ",x-l).."║")end
	snf(true)p("Noclipov Loaded",1)divider()p("Commands",1)divider(); for _,v in pairs(c)do print("║"..v..s(" ",w-#v).."║")end; snf(false)
end
local function EyeEnt()
    local ent = me:GetEyeTrace().Entity or me
	return ent
end
local function EyePlayer()
    local target = EyeEnt()
	if !target:IsPlayer() then return end
	return target
end
local function get_target(steam_id, ent, fallback_to_self)
	ent = ent or false
	fallback_to_self = fallback_to_self or true
	return steam_id and player.GetBySteamID(steam_id) or ent and EyeEnt() or !ent and EyePlayer() or fallback_to_self and me or nil
end
local function Call(target)
	net.Start( 'phone' )
	net.WriteTable({ply=player.GetBySteamID(target) or target, act='call'})
	net.SendToServer()
end
local function notify(text)
	notification.AddLegacy(text, NOTIFY_HINT, 3)
end
local function get_swep(ply)
	return IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or nil
end
local function convar_getbool(varname)
	return GetConVar(varname):GetBool()
end
local function convar_toggle(varname)
	GetConVar(varname):SetBool(!convar_getbool(varname))
	notify(sf("%s changed to %s", varname, convar_getbool(varname)))
end
local function say(text)
    con("say", text)
end
local function act(emote)
    con("act2", emote)
end
local function use(class, silent)
	silent = silent or false
	local spawned = false
	if !me:HasWeapon(class) then con("gm_giveswep", class); spawned = true end
    if me:HasWeapon(class) and get_swep(me) ~= class and !silent then notify(sf("%s %s", spawned and "Gave" or "Equipped", class)) end
	con("use", class)
end
local function CreateDynamicPrompt(title, question, buttons, callback, closebtn)
    closebtn = closebtn or false
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSize(500, 200)
    frame:Center()
    frame:MakePopup()
    local colors = {
        bg = Color(30, 30, 35, 245),
        text = Color(240, 240, 245, 255),
        textMuted = Color(180, 180, 200, 255),
        border = Color(50, 50, 60, 255),
    }
    function frame:Paint(w, h)
        draw.RoundedBox(12, 0, 0, w, h, colors.bg)
        draw.RoundedBox(2, 20, h - 2, w - 40, 1, colors.border)
        surface.SetFont("PromptTitleFont")
        local textW, textH = surface.GetTextSize(title)
        surface.SetTextColor(colors.text)
        surface.SetTextPos(w / 2 - textW / 2, 1)
        surface.DrawText(title)
        surface.SetDrawColor(colors.border)
        surface.DrawLine(20, textH+7, w - 20, textH+7)
    end
    if closebtn then
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetText("")
        closeBtn:SetSize(40,23)
        closeBtn:SetPos(frame:GetWide() - 41, 5)
        closeBtn.DoClick = function() frame:Close() end
        
        function closeBtn:Paint(w, h)
            local color = self:IsHovered() and Color(255, 100, 100, 200) or Color(150, 150, 160, 150)
            surface.SetFont("marlett")
            local s,s1 = surface.GetTextSize("r")
            surface.SetTextPos(w/2-s/2,0)
            surface.SetTextColor(color)
            surface.DrawText("r")
        end

        frame.PerformLayout = function(self, w, h) closeBtn:SetPos(w-41, 5) end
    end
    local questionLabel = vgui.Create("DLabel", frame)
    questionLabel:SetText(question)
    questionLabel:SetFont("PromptQuestionFont")
    questionLabel:SetTextColor(colors.textMuted)
    questionLabel:SetWrap(true)
    questionLabel:SetAutoStretchVertical(true)
    questionLabel:SetSize(frame:GetWide() - 40, 60)
    questionLabel:SetPos(20, 45)
    local buttonPanel = vgui.Create("DPanel", frame)
    buttonPanel:SetPos(20, frame:GetTall() - 65)
    buttonPanel:SetSize(frame:GetWide() - 40, 50)
    function buttonPanel:Paint() end    
    local fontCache = {}
    local function GetFontOfSize(size)
        local fontName = "PromptButtonFont_" .. size
        if not fontCache[size] then
            surface.CreateFont(fontName, {
                font = "Roboto",
                size = size,
                weight = 600,
                antialias = true,
                shadow = false
            })
            fontCache[size] = fontName
        end
        return fontCache[size]
    end    
    local function GetOptimalFontSize(text, maxWidth, maxHeight)
        for size = 14, 8, -1 do
            local fontName = GetFontOfSize(size)
            surface.SetFont(fontName)
            local textW, textH = surface.GetTextSize(text)
            if textW <= maxWidth - 20 and textH <= maxHeight then
                return fontName
            end
        end
        return GetFontOfSize(8)
    end    
    local function CreateButtons()
        buttonPanel:Clear()        
        local btnCount = #buttons
        if btnCount == 0 then return end        
        local btnHeight = 38
        local spacing = 10
        local btnsPerRow = 4        
        -- Вычисляем количество строк
        local rows = math.ceil(btnCount / btnsPerRow)
        local btnsInLastRow = btnCount % btnsPerRow
        if btnsInLastRow == 0 then btnsInLastRow = btnsPerRow end        
        -- Динамическая высота панели кнопок
        local panelHeight = (rows * btnHeight) + ((rows - 1) * 5) + 12
        buttonPanel:SetTall(panelHeight)        
        -- Обновляем высоту окна
        local newHeight = 40 + questionLabel:GetTall() + panelHeight
        frame:SetTall(newHeight)
        frame:Center()        
        -- Перемещаем панель кнопок вниз
        buttonPanel:SetPos(20, frame:GetTall() - panelHeight - 15)        
        local availableWidth = buttonPanel:GetWide()
        local btnWidth = math.min(140, (availableWidth - ((btnsPerRow - 1) * spacing)) / btnsPerRow)
        btnWidth = math.max(90, btnWidth)        
        for row = 0, rows - 1 do
            local btnsInThisRow = (row == rows - 1) and btnsInLastRow or btnsPerRow
            local totalWidth = (btnsInThisRow * btnWidth) + ((btnsInThisRow - 1) * spacing)
            local startX = (availableWidth - totalWidth) / 2
            local yOffset = 6 + (row * (btnHeight + 5))
            
            for i = 1, btnsInThisRow do
                local btnIndex = (row * btnsPerRow) + i
                if btnIndex <= btnCount then
                    local btn = buttons[btnIndex]
                    local btnX = startX + ((i - 1) * (btnWidth + spacing))
                    
                    local button = vgui.Create("DButton", buttonPanel)
                    button:SetText("")
                    button:SetSize(btnWidth, btnHeight)
                    button:SetPos(btnX, yOffset)
                    
                    local btnName = btn.name
                    local btnCallback = btn.callback
                    local buttonFont = GetOptimalFontSize(btnName, btnWidth, btnHeight)
                    
                    function button:Paint(w, h)
                        if self:IsHovered() then
                            draw.RoundedBox(12, 0, 0, w, h, Color(0, 0, 0, 130))
                        end
                        draw.RoundedBox(12, 0, 0, w, h, Color(0, 0, 0, 100))
                        
                        local textColor = self:IsHovered() and Color(255, 255, 255, 255) or Color(200, 200, 210, 220)
                        draw.SimpleText(btnName, buttonFont, w/2, h/2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    
                    function button:DoClick()
                        frame:Close()
                        if btnCallback and isfunction(btnCallback) then 
                            btnCallback()
                        end
                        if callback and isfunction(callback) then
                            callback(btn)
                        end
                    end
                end
            end
        end
    end    
    local function AdjustWindowSize()
        local btnCount = #buttons
        local minWidth = math.max(400, 80 + (math.min(btnCount, 4) * 100) + ((math.min(btnCount, 4) - 1) * 10))
        
        -- Увеличиваем ширину для длинных слов
        local maxNameLength = 0
        for _, btn in ipairs(buttons) do
            maxNameLength = math.max(maxNameLength, #btn.name)
        end
        
        if maxNameLength > 15 then
            minWidth = math.max(minWidth, 550)
        elseif maxNameLength > 10 then
            minWidth = math.max(minWidth, 480)
        end
        
        local newWidth = math.min(minWidth, ScrW() - 100)
        
        -- Рассчитываем высоту в зависимости от количества строк
        local btnsPerRow = 4
        local rows = math.ceil(btnCount / btnsPerRow)
        local panelHeight = (rows * 38) + ((rows - 1) * 5) + 12
        local newHeight = 130 + questionLabel:GetTall() + panelHeight
        
        frame:SetSize(newWidth, newHeight)
        frame:Center()
        
        if IsValid(questionLabel) then 
            questionLabel:SetSize(newWidth - 40, 60) 
            questionLabel:SetPos(20, 45)
        end
        
        if IsValid(buttonPanel) then
            buttonPanel:SetSize(newWidth - 40, panelHeight)
            buttonPanel:SetPos(20, newHeight - panelHeight - 15)
        end
        
        CreateButtons()
    end
    
    AdjustWindowSize()
    return frame
end
local function job_menu()
	if me:GetUserGroup() ~= "superadmin" then return end
	CreateDynamicPrompt("Выбор профессии", "Какую профессию сетаем?", {
		{name="Годжо", callback=function() con("ba", "setjob", me:SteamID(), "Satoru Gojo") end},
		{name="Агент ЦРУ", callback=function() con("ba", "setjob", me:SteamID(), "Агент ЦРУ") end},
		{name="Супер Гёрл", callback=function() con("ba", "setjob", me:SteamID(), "Супергёрл") end},
	}, nil, true)
end
local function preset(actual_preset, changed_binds)
	if !jobs_presets[actual_preset] then return end
	local preset = table.Copy(jobs_presets[actual_preset] )
	if changed_binds and #changed_binds>0 then
		for action, callback in pairs(changed_binds) do
			preset[action] = callback
		end
	end
	return preset
end
local function physgun_color(color_vector, console)
	console = console or true
	me:SetWeaponColor(color_vector)
	if console then RunConsoleCommand("cl_weaponcolor", color_vector:Unpack()) end
end
local function rainbow()
	local base_value = CurTime() * 0.1 + 0
	local r = ( 0.5 * (math.sin(base_value - 2)	+ 1) )
	local g = ( 0.5 * (math.sin(base_value + 2)	+ 1) )
	local b = ( 0.5 * (math.sin(base_value)		+ 1) )
    if rainbow_psys_state then
        physgun_color(Vector(r, g, b), false)
    end
end
local function ToggleRainbowPhysgun()
    if !rainbow_psys_state then
        OGPhysColor = me:GetWeaponColor()
        hook.Add("CreateMove", "Noclipov_RainbowPsysgun", rainbow)
    else
        hook.Remove("CreateMove", "Noclipov_RainbowPsysgun")
		physgun_color(OGPhysColor)
		OGPhysColor = nil
    end
	rainbow_psys_state = not rainbow_psys_state
end
-- Removing useless magicrp's keybinds
hooks_to_remove = {
    ["Think"] = {"HandleF11UniversalHUD", "rp.KeyBinds.Think"},
    ["PreRender"] = {"BATTLEPASS_F7", "MagicArena::BindMenu", "ToggleHelpHints", "MB_OpenBonuses", "BindCrafts"}
}
panels_callback = {
	["hud.task"] = function(panel) panel:Remove() end,
	["hud.stats"] = function(panel) panel:Remove() end,
	["donate.bonus"] = function(panel) panel:Remove() end,
}
for Event, Hooks in pairs(hooks_to_remove) do
    for _, Name in pairs(Hooks) do hook.Remove(Event, Name) end
end
for _, panel in pairs(vgui.GetAll()) do
    if panel and panel.GetName then if panels_callback[panel:GetName()] then panels_callback[panel:GetName()](panel) end end
end
local tallbar = ScrH() * .02314815
local tallbar_c = tallbar * .5
local function DrawShadowText(text, font, x, y, color, x_a, y_a, color_shadow)
	color_shadow = color_shadow or Color(0, 0, 0,255)
	draw.SimpleText(text, font, x + 1, y + 1, color_shadow, x_a, y_a)
	local w,h = draw.SimpleText(text, font, x, y, color, x_a, y_a)
	return w,h
end
local function DrawBox(x,y,w,h,col,col_o)
	col_o = col_o or Color(0, 0, 0, 255)
	col = col or Color(10, 10, 10, 150)

	surface.SetDrawColor(col)
	surface.DrawRect(x,y,w,h)

	surface.SetDrawColor(col_o)
	surface.DrawOutlinedRect(x,y,w,h)
end
local blur = Material("pp/blurscreen")
local function DrawBlur(panel, amount)
	local x, y = panel:LocalToScreen(0, 0)
	local scrW, scrH = ScrW(), ScrH()

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(blur)
	for i = 1, 3 do
		blur:SetFloat("$blur", (i / 3) * (amount or 6))
		blur:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(x * -1, y * -1, scrW, scrH)
	end
end
local report_answers = {
	"Приветствую, игрок. Слежу за вами и скоро телепортирую, если не увижу у вас РП.",
	"Здравствуйте, вскоре телепортирую вас, если не увижу у вас РП-Процесса.",
	"Доброго времени суток, наблюдаю и скоро телепортирую вас в админ-зону (Если у вас нет РП).",
}
local function RepChat(text)
	net.Start("freports.message") net.WriteString(text) net.SendToServer()
end
net.Receive("freports.accept", function()
	local rep = net.ReadEntity()
	local admin = net.ReadEntity()
	if not admin:IsPlayer() then admin = nil end
	if admin and IsValid(admin) then
		if admin == me then
			local data = net.ReadTable()
			freports.OpenAdminMenu(data)
			PrintTable(data)
            say("!spectate "..rep:SteamID())
			hook.Run("ThirdPersonChanged", true)
			local reason = data.report_chat[1][2]
			if reason:find("застрял") then RepChat("Скоро помогу вам, ожидайте.")
			elseif reason:find("тп") then RepChat("Ожидайте, телепортируюсь к вам в скоро времени, если не замечу у вас РП-процесса.")
			else RepChat(report_answers[math.random(1, 3)]) end
            copy(rep:SteamID())
		end
		if IsValid(freports.m) and rep == me then
			freports.m.report.admin = admin
			surface.PlaySound("kills/kill4.wav")
		end
	end

	if IsValid(freports.r) and IsValid(freports.r.created_reports[rep]) then
		freports.r.created_reports[rep]:Remove()
	end
end)
net.Receive("freports.send", function()
	local tb = net.ReadTable()
	if not tb then return end
	if not tb.reporter then return end
	if not tb.reporter:IsPlayer() then return end
	if tb.reporter == me then
		if IsValid(freports.m) then freports.m:Remove() end
		freports.m = vgui.Create("DFrame")
		freports.m:SetSize(ScrW()*.25, ScrH()*.12 + tallbar + tallbar + 4)
		freports.m:SetPos(2, 2)
		freports.m:SetTitle("")
		freports.m.report = tb
		freports.m.OnClose = function()
			net.Start("freports.close")
			net.SendToServer()
		end
		freports.m.Paint = function(self, w, h)
			DrawBlur(self, 5)
			DrawBox(0,0,w,h)
			DrawBox(0,0,w,tallbar)
			DrawShadowText("Жалоба", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
		end

		local report_chat = vgui.Create("RichText", freports.m)
		report_chat:SetPos(2, tallbar + 2)
		report_chat:SetSize(freports.m:GetWide() - 4, freports.m:GetTall() - tallbar*3 - 8)
		function report_chat:PerformLayout()
			self:SetFontInternal("reports_8")
			self:SetBGColor(Color(0,0,0,100))
		end

		freports.m.Chat = function(msg)
			local ply = msg[1]
			if not IsValid(ply) then return end
			local text = msg[2]

			local job_col = team.GetColor(ply:Team())
			report_chat:InsertColorChange(job_col.r, job_col.g, job_col.b, 255)
			report_chat:AppendText(ply:Nick())
			report_chat:InsertColorChange(255, 255, 255, 255)
			report_chat:AppendText(": "..text.."\n")
		end

		local message = vgui.Create("DButton", freports.m)
		message:SetText("")
		message:SetPos(2, freports.m:GetTall() - tallbar - tallbar - 4)
		message:SetSize(freports.m:GetWide() - 4, tallbar)
		message.DoClick = function()
			Derma_StringRequest(
				"Сообщение в репорт",
				"Введите сообщение которое хотели бы отправить",
				"",
				function(text) net.Start("freports.message") net.WriteString(text) net.SendToServer() end
			)
		end
		message.Paint = function(self, w, h)
			DrawBox(0, 0, w, h, Color(0, 0, 0, 100))
			DrawShadowText("Написать сообщение", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
		end

		local info_bar = vgui.Create("DPanel", freports.m)
		info_bar:SetPos(2, freports.m:GetTall() - tallbar - 2)
		info_bar:SetSize(freports.m:GetWide() - 4, tallbar)
		info_bar.Paint = function(self, w, h)
			DrawBox(0, 0, w, h, Color(0, 0, 0, 100))
			if IsValid(freports.m.report.admin) and freports.m.report.admin.Nick then
				DrawShadowText(freports.m.report.admin:Nick(), "reports_10", w*.5, h*.5, team.GetColor(freports.m.report.admin:Team()), 1, 1)
			else
				DrawShadowText("Ожидаем администратора...", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
			end
		end
		for k,v in ipairs(freports.m.report.report_chat) do
			freports.m.Chat(v)
		end
	end

    if not IsValid(freports.r) then
        freports.CreateMain()
		timer.Simple(0.3, function () freports.r.fHide() end)
    end
    freports.r.AddReport(tb)
	timer.Simple(0.15, function () 
		if me:Team() == TEAM_ADMIN then
			net.Start("freports.accept") net.WriteEntity(tb.reporter) net.SendToServer()
		end
	end)
end)
net.Receive("freports.message", function()
	local tb = net.ReadTable()
	if IsValid(freports.m) then 
		freports.m.Chat(tb) 
		local ply = tb[1]
		if ply ~= me then
			local text = tb[2]
			text = string.gsub(text, "!", "")
			local words = string.Split(text, " ")
			if table.HasValue(words, "сит") or table.HasValue(words, "sit") then
				RepChat("В процессе.")
			end
		end
	end
	if IsValid(freports.a) then freports.a.Chat(tb) end
end)
local last_preset_change_time = CurTime()
local function toggle_preset(target_preset, name)
	if last_preset_change_time<=CurTime() then
		last_preset_change_time = CurTime()+2
		if last_preset then
			known_jobs[me:Team()] = last_preset
			last_preset = nil
		else
			last_preset = known_jobs[me:Team()]
			known_jobs[me:Team()] = target_preset
		end 
		notify(sf("%s changed to %s", name, last_preset ~= nil))
	end
end
commands = {
	adminmode = function() toggle_preset(preset("admin"), "Admin-mode") end,
	rainbow_psysgun = function() ToggleRainbowPhysgun() end,
	job_menu = function() job_menu() end,
    ent_class = function() local target = get_target(nil, true); copy(target:GetClass()) end,
    ent_mat = function() local target = get_target(nil, true); copy(EyeEnt():GetMaterial()) end,
    ent_model = function() local target = get_target(nil, true); copy(EyeEnt():GetModel()) end,
	ply_sweps = function(ply, cmd, args) local target = get_target(args[1]); table.ForEach(target:GetWeapons(), function(i, swep) print(swep:GetClass()) end) end,
    ply_swep_class = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon():GetClass()) end,
	ply_swep_ammo1 = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon().Primary.Ammo) end,
	ply_swep_ammo2 = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon().Secondary.Ammo) end,
	ply_hit = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("На игрока \"%s\" %s заказ%s", target:Name(), target:HasHit() and "есть" or "нет", target:HasHit() and "" or "а")) end,
	ply_job = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("%s является %s (%s).", target:Name(), target:getDarkRPVar( "job" ), team.GetName(target:Team()))) end,
	ply_job_cmd = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("Скопирована команда для профессии игрока \"%s\".", target:Name())); copy(target:GetTeamTable().command) end,
	ply_nick = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("Скопирован никнейм игрока \"%s\".", target:Name())); copy(target:Name()) end,
	ply_usergroup = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("Скопирована привилегия игрока \"%s\".", target:Name())); copy(target:GetUserGroup()) end,
	ply_steamid = function() local target = get_target(); notify(sf("Скопирован steamid игрока \"%s\".", target:Name())); copy(target:SteamID()) end,
	call = function(ply, cmd, args) Call(args[1]) end,
	toggle_convar = function(ply,cmd,args) convar_toggle(args[1]) end,
}
for cmd,callback in pairs(commands) do
    concommand.Remove(cmd)
    concommand.Add(cmd, callback)
end
local disguise_team = TEAM_SATORU
local main_weapon = "m9k_dbarrel"
local function tasered(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return target:HasWeapon("weapon_tasered")
end
local function handcuffed_p(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return target:GetNWBool("isHandcuffed")
end
local function can_disguise(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return target:GetTeamTable().candisguise
end
local function disguised(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return target:IsDisguised()
end
local function disguise(job)
	if !can_disguise(me) then return end
	job = job or disguise_team or TEAM_HOBO
	net.Start("PlayerDisguise")
	net.WriteInt(job, 8)
	net.SendToServer()
	timer.Simple(0.2, function() if disguised(me) then say("/job "..me:GetJobTable().name) end end)
end
local function IsCP(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return rp.CivilProtection[target:Team()]
end
local function disguise_menu(callback)
	if disguised(me) then
		local cur_dis = me:GetJobTable()
		disguise_team=cur_dis.team
		notify("Disguise was set to "..cur_dis.name)
		callback()
		return
	end
	local insta_disguise = me:GetVelocity():Length() > 70
	if !insta_disguise then
		CreateDynamicPrompt("Выбор маскировки", "Под какую профессию будем маскироваться?", {
			{name="Годжо", callback=function() disguise_team = TEAM_SATORU end},
			{name="Madara", callback=function() disguise_team = TEAM_MADARA end},
			{name="Девочка Мафиози", callback=function() disguise_team = TEAM_MAFIOZI end},
			{name="Шэдоу Гёрл", callback=function() disguise_team = TEAM_SHADOWGIRL end},
			{name="Захватчица", callback=function() disguise_team = TEAM_ZAHVAT end},
			{name="Little Evil", callback=function() disguise_team = TEAM_LITTLE end},
			{name="Kokona Shiki", callback=function() disguise_team = TEAM_KOKONA end},
			{name="Ghost", callback=function() disguise_team = TEAM_GHOSTZ end},
			{name="Вермейл", callback=function() disguise_team = TEAM_WARMALE end},
			{name="Агент ЦРУ", callback=function() disguise_team = TEAM_CRU end},
			{name="Немезис", callback=function() disguise_team = TEAM_NEMEZIS end},
		}, function() disguise(disguise_team); if callback then callback() end end, true)
	else
		disguise(disguise_team)
	end
end
local function weapon_menu(callback)
	CreateDynamicPrompt("Выбор оружия", "Каким основным оружием будем пользоваться?", {
		{name="Дабла", callback=function() main_weapon = "m9k_dbarrel" end},
		{name="Драгон Дигл", callback=function() main_weapon = "pist_deagon" end},
		{name="Бландергат", callback=function() main_weapon = "deika_blundergat" end},
		{name="Супер Бландергат", callback=function() main_weapon = "deika_super_blundergat" end},
	}, function() local last_swep = get_swep(me); use(main_weapon, true); use(last_swep, true) if callback then callback() end end, true)
end
local function physgun_menu(callback)
	CreateDynamicPrompt("Выбор цвета", "Какой цвет физгана поставим (для себя)?", {
		{name="Фиолетовый", callback=function() me:SetWeaponColor(Vector(0.62, 0.43, 1)) end},
		{name="Белый", callback=function() me:SetWeaponColor(Vector(1, 1, 1)) end},
		{name="Черный", callback=function() me:SetWeaponColor(Vector(0, 0, 0)) end},
		{name="Радужный", callback=function() ToggleRainbowPhysgun() end},
	}, function() use("weapon_physgun", true) if callback then callback() end end, true)
end
weapon_menu(physgun_menu)
hooks = {
	KeyPress = {name="CuffsToArrest", callback = function( ply, key )
		if key == IN_ATTACK then
			if !EyePlayer() then return end
			if get_swep(me) == "handcuffs" and handcuffed_p() then use("arrest_baton", true)
			elseif get_swep(me) == "arrest_baton" and not handcuffed_p() then use("handcuffs", true) end
		end
	end},
}
for Event, Data in pairs(hooks) do
	hook.Remove(Event, Data.name)
	hook.Add(Event, Data.name, Data.callback)
end
jobs_presets = {
	crime = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) use("the_hand") end, 
		action3 = function(ply, cmd, args) use("moneychecker") end,
		action4 =  function(ply, cmd, args) if get_swep(me) == "the_hand" then return end convar_toggle("sitting_allow_on_me") end,
		action5 =  function(ply, cmd, args) use(main_weapon) end,
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	police = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) use("the_hand") end,
		action3 = function(ply, cmd, args) if !IsCP() then use(main_weapon); say("Лицом к стене/в пол! 1... 2... 3...") end end,
		action4 = function(ply, cmd, args) if get_swep(me) == "the_hand" then return end use("handcuffs") end,
		action5 =  function(ply, cmd, args) use(main_weapon) end,
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	civil = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) act("dance") end,
		action3 = function(ply, cmd, args) con("job_menu") end,
		action4 = function(ply, cmd, args) if get_swep(me) == "the_hand" then return end con("toggle_convar", "sitting_allow_on_me") end,
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	mayor = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) say("/lottery 1e6") end,
		action3 = function(ply, cmd, args) say("/lockdown ПНН") end,
		action5 = function(ply, cmd, args) say("/givelicense") end, 
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	fbi = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) if !disguised(me) and can_disguise(me) then disguise_menu() else use("the_hand") end end,
		action3 = function(ply, cmd, args) if !IsCP() then use(main_weapon); say("Лицом к стене/в пол! 1... 2... 3...") else say(sf("/me | Предъявил удостоверение(%s) человеку напротив.", team.GetName(me:Team()))); use("handcuffs", true) timer.Simple(0.7, function() use("keys", true) end) end end,
		action4 = function(ply, cmd, args) if get_swep(me) == "the_hand" then return end use("handcuffs")end,
		action5 =  function(ply, cmd, args) use(main_weapon) end,
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	maniac = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) if !disguised(me) and can_disguise(me) then disguise() else use("csgo_butterfly_slaughter") end end,
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	hitman = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) toggle_preset(preset("admin"), "Admin-mode") end,
		action2 = function(ply, cmd, args) if !disguised(me) then disguise_menu() else use("weapon_nahida_e") end end,
		action3 = function(ply, cmd, args) use(main_weapon); say("Лицом к стене/в пол! 1... 2... 3...") end,
		action4 = function(ply, cmd, args) if get_swep(me) == "the_hand" then return end use("blink")end,
		action5 = function(ply, cmd, args) use(main_weapon) end, 
		action6 =  function(ply, cmd, args) use("weapon_taser") end,
	},
	admin = {
		action0 = function(ply, cmd, args) use("keys", true) end,
		action1 = function(ply, cmd, args) say("!spectate") end, 
		action2 = function(ply, cmd, args) local target = get_target(args[1], false, false) if !target then return end say("!return "..target:SteamID()) end, 
		action3 = function(ply, cmd, args) con("noclip") end,
		action4 = function(ply, cmd, args) if get_swep(me) == "the_hand" then return end toggle_preset(preset("admin"), "Admin-mode") end,
		action5 = function(ply, cmd, args) con("ply_steamid") end,
		action6 =  function(ply, cmd, args) use("weapon_physgun", true) end,
	},
}
known_jobs = {
	-- Police
	[TEAM_POLICE] = preset("police"),
	[TEAM_POLICE2] = preset("police"),
	[TEAM_CHIEF] = preset("police"),
	[TEAM_SWAT] = preset("police"),
	[TEAM_LSWAT] = preset("police"),
	[TEAM_BULL] = preset("police"),
	[TEAM_LEGION] = preset("police"),
	[TEAM_SUPERGIRL] = preset("police", {action2 = function(arg) use("sm_weapon_homelander") end,}),
	[TEAM_FBI] = preset("fbi"),
	[TEAM_CEOFBI] = preset("fbi"),
	[TEAM_CRU] = preset("fbi"),
	[TEAM_MAYOR] = preset("mayor"),
	-- Hitmans
	[TEAM_HITMAN] = preset("hitman"),
	[TEAM_VIPER] =  preset("hitman"),
	[TEAM_CHROMIUM] = preset("hitman", {action2 = function(ply, cmd, args) use("weapon_nahida_e") end,action3=function(ply, cmd, args) toggle_preset(preset("maniac", {action4=function(ply, cmd, args) toggle_preset(preset("maniac"), "Maniac-mode") end, action5=function() use("weapon_camo") end}), "Maniac-mode"); use("csgo_butterfly_slaughter") end,}),
	-- Maniacs
	-- Crime
	[TEAM_MAFIA] = preset("crime"),
	[TEAM_EMAFIA] = preset("crime"),
	[TEAM_MOB] = preset("crime"),
	[TEAM_CYBER] = preset("crime"),
	[TEAM_LORDE] = preset("crime"),
	[TEAM_KILLA] = preset("crime"),
	[TEAM_VOR] = preset("crime", {action3 = function(ply, cmd, args) use("swep_pickpocket") end,}),
	[TEAM_REBECCA] = preset("crime", {action2 = function(ply, cmd, args) use("weapon_blanchammer") end,}),
	-- Civil
	[TEAM_CASINO] = preset("civil"),
	[TEAM_GUN] = preset("civil"),
	[TEAM_DOG] = preset("civil"),
	[TEAM_NARKOS] = preset("civil"),
	[TEAM_MINER] = preset("civil"),
	[TEAM_CITIZEN] = preset("civil"),
	[TEAM_GUARD] = preset("civil"),
	[TEAM_HOBO] = preset("civil"),
	-- Other
	[TEAM_BANNED] = preset("civil", {action3 = nil}),
	[TEAM_ADMIN] = preset("admin", {action4 = nil}),
}
for i=0,10 do
	concommand.Remove(("job_action"..i))
	concommand.Add(("job_action"..i), function(lp, cl, args)
		local job = me:Team()
		if !known_jobs[job] or !known_jobs[job]["action"..i] then return end
		known_jobs[job]["action"..i](lp, cl, args)
	end)
end
printBox(table.GetKeys(commands))