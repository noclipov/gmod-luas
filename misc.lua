if not DarkRP then print("[Misc] Not Loaded! There is no DarkRP.") return end
local sf = string.format
local me = LocalPlayer()
local copy = SetClipboardText
local con = RunConsoleCommand
local function EyeEnt()
    local ent = me:GetEyeTrace().Entity or me
	return ent
end
local function EyePlayer()
    local target = EyeEnt()
	if !target:IsPlayer() then return end
	return target
end
local function get_target(steam_id, ent)
	ent = ent or false
	return steam_id and player.GetBySteamID(steam_id) or ent and EyeEnt() or !ent and EyePlayer() or me
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
local function use(class, silent, give)
	silent = silent or false
	give = give or false
	local spawned = false
	if !me:HasWeapon(class) and give then con("gm_giveswep", class); spawned = true end
    if me:HasWeapon(class) and get_swep(me) ~= class and !silent then notify(sf("%s %s", spawned and "Gave" or "Equipped", class)) end
	con("use", class)
end
function CreateDynamicPrompt(title, question, buttons)
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSize(500, 200)
    frame:Center()
    frame:MakePopup()
    
    -- Цветовая схема
    local colors = {
        bg = Color(30, 30, 35, 245),
        text = Color(240, 240, 245, 255),
        textMuted = Color(180, 180, 200, 255),
        border = Color(50, 50, 60, 255),
    }
    
    -- Блокируем ввод
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
    
    -- Отрисовка окна
    function frame:Paint(w, h)
        draw.RoundedBox(12, 0, 0, w, h, colors.bg)
        draw.RoundedBox(2, 20, h - 2, w - 40, 1, colors.border)
        surface.SetFont("PromptTitleFont")
        local x,y = surface.GetTextSize(title)
        surface.SetTextColor(colors.text)
        surface.SetDrawColor(colors.text)
        surface.SetTextPos(w/2-x/2.2, 1)
        surface.DrawText(title)
        surface.DrawLine(0, 25, w, 25)
    end
    
    local questionLabel = vgui.Create("DLabel", frame)
    questionLabel:SetText(question)
    questionLabel:SetFont("PromptQuestionFont")
    questionLabel:SetTextColor(colors.textMuted)
    questionLabel:SetWrap(true)
    questionLabel:SetAutoStretchVertical(true)
    questionLabel:SetSize(frame:GetWide() - 40, 60)
    questionLabel:SetPos(20, 50)
    
    local buttonPanel = vgui.Create("DPanel", frame)
    buttonPanel:SetPos(20, frame:GetTall() - 65)
    buttonPanel:SetSize(frame:GetWide() - 40, 50)
    function buttonPanel:Paint() end
    
    -- Создаём переменную для результата
    local selectedResult = nil
    local waiting = true
    
    local function CreateButtons()
        buttonPanel:Clear()
        local btnCount = #buttons
        if btnCount == 0 then return end
        local btnHeight = 38
        local spacing = 10
        local availableWidth = buttonPanel:GetWide()
        local btnWidth = math.min(140, (availableWidth - ((btnCount - 1) * spacing)) / btnCount)
        btnWidth = math.max(90, btnWidth)
        local totalWidth = (btnCount * btnWidth) + ((btnCount - 1) * spacing)
        local startX = (availableWidth - totalWidth) / 2
        for i, btn in ipairs(buttons) do
            local btnX = startX + ((i - 1) * (btnWidth + spacing))
            local button = vgui.Create("DButton", buttonPanel)
            button:SetText("")
            button:SetSize(btnWidth, btnHeight)
            button:SetPos(btnX, 6)
            local btnName = btn.name
            local btnCallback = btn.callback
            function button:Paint(w, h)
                if self:IsHovered() then
                    draw.RoundedBox(12, 0, 0, w, h, Color(0, 0, 0, 130))
                end
                draw.RoundedBox(12, 0, 0, w, h, Color(0, 0, 0, 100))
                local textColor = self:IsHovered() and Color(255, 255, 255, 255) or Color(200, 200, 210, 220)
                draw.SimpleText(btnName, "PromptButtonFont", w/2, h/2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function button:DoClick()
                selectedResult = btn
                waiting = false
                frame:Close()
                if btnCallback and isfunction(btnCallback) then 
                    btnCallback() 
                end
            end
        end
    end
    
    local function AdjustWindowSize()
        local btnCount = #buttons
        local minWidth = math.max(400, 80 + (btnCount * 100) + ((btnCount - 1) * 10))
        local newWidth = math.min(minWidth, ScrW() - 100)
        local newHeight = 180
        if btnCount > 4 then newHeight = 210 end
        frame:SetSize(newWidth, newHeight)
        frame:Center()
        if IsValid(questionLabel) then questionLabel:SetSize(newWidth - 40, 60) end
        if IsValid(buttonPanel) then
            buttonPanel:SetSize(newWidth - 40, 50)
            buttonPanel:SetPos(20, newHeight - 65)
        end
        CreateButtons()
    end
    
    AdjustWindowSize()
    
    -- Блокируем выполнение через таймер
    timer.Create("WaitForPrompt_" .. tostring(frame), 0.1, 0, function()
        if not IsValid(frame) then
            timer.Remove("WaitForPrompt_" .. tostring(frame))
            return
        end
        
        if not waiting then
            timer.Remove("WaitForPrompt_" .. tostring(frame))
        end
    end)
    
    -- Ожидание выбора
    while waiting and IsValid(frame) do
        timer.Sleep(0.01)
        game.RunFrame()
    end
    
    return selectedResult
end
local jobs_presets, known_jobs, hooks_to_remove, panels_to_remove, sweps_to_ignore, commands_base, commands, hooks, disguise_team, last_preset
-- Removing useless magicrp's keybinds
hooks_to_remove = {
    ["Think"] = {"HandleF11UniversalHUD", "rp.KeyBinds.Think"},
    ["PreRender"] = {"BATTLEPASS_F7", "MagicArena::BindMenu", "ToggleHelpHints", "MB_OpenBonuses", "BindCrafts"}
}
panels_to_remove = {
	["hud.task"] = true
}
for Event, Hooks in pairs(hooks_to_remove) do
    for _, Name in pairs(Hooks) do hook.Remove(Event, Name) end
end
for _, panel in pairs(vgui.GetAll()) do
    if panel and panel.GetName then if panels_to_remove[panel:GetName()] then panel:Remove() end end
end
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
local function DrawBlur(panel, amount)
	local x, y = panel:LocalToScreen(0, 0)
	local scrW, scrH = ScrW(), ScrH()

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(Material("pp/blurscreen"))
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
			DrawShadowText("Жалоба", "reports_8", w * .5, ScrH() * .02314815 * .5, Color(255,255,255), 1, 1)
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
commands = {
	adminmode = function() if known_jobs[me:Team()] == jobs_presets.admin_preset then known_jobs[me:Team()] = last_preset; else last_preset = known_jobs[me:Team()]; known_jobs[me:Team()] = jobs_presets.admin_preset end notify(sf("Adminmode changed to %s", known_jobs[me:Team()] == jobs_presets.admin_preset)) end,
    ent_class = function() local target = get_target(nil, true); copy(target:GetClass()) end,
    ent_mat = function() local target = get_target(nil, true); copy(EyeEnt():GetMaterial()) end,
    ent_model = function() local target = get_target(nil, true); copy(EyeEnt():GetModel()) end,
	ply_sweps = function(ply, cmd, args) local target = get_target(args[1]); table.ForEach(target:GetWeapons(), function(i, swep) print(swep:GetClass()) end) end,
    ply_swep_class = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon():GetClass()) end,
	ply_swep_ammo1 = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon().Primary.Ammo) end,
	ply_swep_ammo2 = function(ply, cmd, args) local target = get_target(args[1]); copy(target:GetActiveWeapon().Secondary.Ammo) end,
	ply_job = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("%s является %s (%s).", target:Name(), target:getDarkRPVar( "job" ), team.GetName(target:Team()))) end,
	ply_job_cmd = function(ply, cmd, args) local target = get_target(args[1]); notify(sf("Скопирована команда для профессии игрока \"%s\".", target:Name())); copy(target:getJobTable().command) end,
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
CreateDynamicPrompt("Маскировка", "Выберите профессию для маскировки:", {
    {name="Годжо", callback=function() disguise_team = TEAM_SATORU end},
    {name="Забаненный", callback=function() disguise_team = TEAM_BANNED end},
    {name="Девочка Мафиози", callback=function() disguise_team = TEAM_MAFIOZI end},
})
local main_weapon = "m9k_dbarrel"
CreateDynamicPrompt("Оружие", "Выберите основное оружие:", {
    {name="dbarrel", callback=function() main_weapon = "m9k_dbarrel" end},
    {name="бландергат", callback=function() main_weapon = "deika_super_blundergat" end},
})
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
local function disguised(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return target:IsDisguised()
end
local function disguise(job)
	job = job or disguise_team or TEAM_HOBO
	net.Start("PlayerDisguise")
	net.WriteInt(job, 8)
	net.SendToServer()
	if disguised(me) then say("/job "..team.GetAllTeams()[job].Name) end
end
local function IsCP(target)
	target = target or EyePlayer()
	if !IsValid(target) then return end
	return rp.CivilProtection[target:Team()]
end
hooks = {
	KeyPress = {name="CuffsToArrest", callback = function( ply, key )
		if key == IN_ATTACK then
			if !EyePlayer() then return end
			if known_jobs[me:Team()] == jobs_presets.police_preset or known_jobs[me:Team()] == jobs_presets.fbi_preset then
				if get_swep(me) == "handcuffs" and handcuffed_p() then use("arrest_baton", true)
				elseif get_swep(me) == "arrest_baton" and not handcuffed_p() then use("handcuffs", true) end
			end
		end
	end},
	KeyRelease = {name="CuffsToArrest", callback = function( ply, key )
		if key == IN_ATTACK then
			if !EyePlayer() then return end
			if known_jobs[me:Team()] == jobs_presets.police_preset or known_jobs[me:Team()] == jobs_presets.fbi_preset then
				if get_swep(me) == "handcuffs" and handcuffed_p() then use("arrest_baton", true)
				elseif get_swep(me) == "arrest_baton" and not handcuffed_p() then use("handcuffs", true) end
			end
		end
	end},
}
for Event, Data in pairs(hooks) do
	hook.Remove(Event, Data.name)
	hook.Add(Event, Data.name, Data.callback)
end
jobs_presets = {
	crime_preset = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) use("the_hand") end, 
		action3 = function(arg) use("moneychecker"); use("swep_pickpocket") end,
		action4 =  function(arg) if get_swep(me) == "the_hand" then return end convar_toggle("sitting_allow_on_me") end,
		action5 =  function(arg) use("m9k_dbarrel", false, true) end,
	},
	police_preset = {
		action1 = function(arg) con("adminmode") end,
		action3 = function(arg) if !IsCP() then use("m9k_dbarrel", false, true); say("Лицом к стене/в пол! 1... 2... 3...") end end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end use("handcuffs") end,
		action5 =  function(arg) use("m9k_dbarrel", false, true) end,
	},
	civil_preset = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) act("dance") end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end con("toggle_convar", "sitting_allow_on_me") end,
	},
	mayor_preset = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) say("/lottery 1e6") end,
		action3 = function(arg) say("/lockdown ПНН") end,
		action5 = function(arg) say("/givelicense") end, 
	},
	fbi_preset = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) if !disguised(me) then disguise() end use("the_hand") end,
		action3 = function(arg) if !IsCP() then use("m9k_dbarrel", false, true); say("Лицом к стене/в пол! 1... 2... 3...") else say("/me | Предъявил удостоверение FBI человеку напротив."); use("handcuffs", true) timer.Simple(0.7, function() use("keys", true) end) end end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end use("handcuffs")end,
		action5 =  function(arg) use("m9k_dbarrel", false, true) end,
	},
	hitman_preset = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) if !disguised(me) then disguise() end end,
		action3 = function(arg) use("m9k_dbarrel", false, true); say("Лицом к стене/в пол! 1... 2... 3...") end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end use("m9k_barret_m82")end,
		action5 = function(arg) use("m9k_dbarrel", false, true) end, 
	},
	admin_preset = {
		action1 = function(arg) say("!spectate") end, 
		action2 = function(arg) local target = get_target(args[1]); say("!return "..EyePlayer():SteamID()) end, 
		action3 = function(arg) con("noclip") end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end con("adminmode") end,
		action5 = function(arg) con("ply_steamid") end,
	},
}
known_jobs = {
	-- Police
	[TEAM_POLICE] = jobs_presets.police_preset,
	[TEAM_POLICE2] = jobs_presets.police_preset,
	[TEAM_CHIEF] = jobs_presets.police_preset,
	[TEAM_SWAT] = jobs_presets.police_preset,
	[TEAM_LSWAT] = jobs_presets.police_preset,
	[TEAM_BULL] = jobs_presets.police_preset,
	[TEAM_LEGION] = jobs_presets.police_preset,
	[TEAM_FBI] = jobs_presets.fbi_preset,
	[TEAM_CEOFBI] = jobs_presets.fbi_preset,
	[TEAM_MAYOR] = mayor_preset,
	[TEAM_SUPERGIRL] = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) use("sm_weapon_homelander") end,
		action3 = function(arg) if !IsCP() then use("m9k_dbarrel", false, true); say("Лицом к стене/в пол! 1... 2... 3...") end end,
		action4 = function(arg) if get_swep(me) == "the_hand" then return end use("handcuffs")end,
		action5 = function(arg) use("m9k_dbarrel", false, true) end, 
	},
	-- Hitmans
	[TEAM_VIPER] = hitman_preset,
	[TEAM_HITMAN] = hitman_preset,
	-- Maniacs
	[TEAM_JASON] = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) if !disguised(me) then disguise() else use("csgo_m9_crimsonwebs") end end,
		action3 = function(arg) say("Лицом к стене/в пол! 1... 2... 3...") end,
	},
	-- Crime
	[TEAM_MAFIA] = jobs_presets.crime_preset,
	[TEAM_EMAFIA] = jobs_presets.crime_preset,
	[TEAM_MOB] = jobs_presets.crime_preset,
	[TEAM_CYBER] = jobs_presets.crime_preset,
	[TEAM_LORDE] = jobs_presets.crime_preset,
	[TEAM_KILLA] = jobs_presets.crime_preset,
	[TEAM_VOR] = jobs_presets.crime_preset,
	-- Civil
	[TEAM_CASINO] = jobs_presets.civil_preset,
	[TEAM_GUN] = jobs_presets.civil_preset,
	[TEAM_DOG] = jobs_presets.civil_preset,
	[TEAM_NARKOS] = jobs_presets.civil_preset,
	[TEAM_MINER] = jobs_presets.civil_preset,
	[TEAM_CITIZEN] = jobs_presets.civil_preset,
	[TEAM_GUARD] = jobs_presets.civil_preset,
	[TEAM_HOBO] = jobs_presets.civil_preset,
	-- Other
	[TEAM_BANNED] = {
		action1 = function(arg) con("adminmode") end,
		action2 = function(arg) act("dance") end,
		action4 = function(arg) con("toggle_convar", "sitting_allow_on_me") end,
	},
	[TEAM_ADMIN] = jobs_presets.admin_preset,
}
for i=1,10 do
	concommand.Remove(("job_action"..i))
	concommand.Add(("job_action"..i), function(lp, cl, args)
		local job = me:Team()
		if !known_jobs[job] or !known_jobs[job]["action"..i] then return end
		known_jobs[job]["action"..i](#args==1 and args[1] or nil)
	end)
end
print("[Misc] Loaded!")