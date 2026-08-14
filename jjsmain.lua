-- jjsmain.lua - Jujutsu Shenanigans
-- Auto Block / Hitbox Expander / Auto Blackflash (Yuji) / Lock-On Dash Assist
-- UI: Obsidian (deividcomsono/Obsidian)

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Knit = require(game.ReplicatedStorage.Knit.Knit)
local MovementService = Knit.GetService("MovementService")
local BlockService = Knit.GetService("BlockService")
local ToolController = Knit.GetController("ToolController")
local MovementController = Knit.GetController("MovementController")

local GetControls = require(LocalPlayer.PlayerScripts.PlayerModule.ControlModule).GetMoveVector

getgenv().JJS = getgenv().JJS or {}
local CFG = getgenv().JJS

local running = true
local comboCount = 0
local blocking = false
local hookInstalled = false
local oldNamecall = nil
local wsMt = nil

local charExists = function()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") and c.Humanoid ~= nil
end

local function getHRP() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end

local function getNearestEnemy(range)
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestDist = nil, range
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local c = p.Character
			local hum = c and c:FindFirstChild("Humanoid")
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if c and hum and r and hum.Health > 0 and c:IsDescendantOf(workspace.Characters) then
				local d = (r.Position - hrp.Position).Magnitude
				if d < bestDist then best, bestDist = c, d end
			end
		end
	end
	return best
end

local function faceTarget(target, hrp)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	local myPos = hrp.Position
	local tPos = target.HumanoidRootPart.Position
	local look = Vector3.new(tPos.X - myPos.X, 0, tPos.Z - myPos.Z)
	if look.Magnitude > 0.01 then
		hrp.CFrame = CFrame.new(myPos, myPos + look.Unit)
	end
end

local function fireDash(dir)
	pcall(function()
		MovementService.Dash:Fire(dir)
	end)
	pcall(function()
		MovementController.Dash(LocalPlayer, LocalPlayer, LocalPlayer.Character, dir)
	end)
end

local function dashReady()
	local ch = LocalPlayer.Character
	if not ch then return false end
	local info = ch:FindFirstChild("Info")
	return info and not info:FindFirstChild("NoDash")
end

--[[ Auto Block ]]
local function releaseBlock()
	if blocking then
		blocking = false
		pcall(function() BlockService.Deactivated:Fire() end)
	end
end

task.spawn(function()
	while running do
		task.wait(0.05)
		if not Toggles.AutoBlock.Value then
			releaseBlock()
			continue
		end
		local hrp = getHRP()
		if not hrp then releaseBlock() else
			local enemy = getNearestEnemy(Options.BlockRange.Value)
			local shouldBlock = false
			local target = nil
			if enemy and enemy:FindFirstChild("HumanoidRootPart") then
				local toEnemy = enemy.HumanoidRootPart.Position - hrp.Position
				local dist = toEnemy.Magnitude
				toEnemy = toEnemy.Magnitude > 0.01 and toEnemy.Unit or Vector3.new(0, 0, 1)
				local facing = hrp.CFrame.LookVector
				local dot = (Vector3.new(facing.X, 0, facing.Z).Unit):Dot(Vector3.new(toEnemy.X, 0, toEnemy.Z).Unit)
				if dist <= Options.BlockRange.Value + 2 and dot >= math.cos(math.rad(Options.BlockAngle.Value)) then
					shouldBlock = true
					target = enemy
				end
			end
			if shouldBlock then
				if not blocking then
					blocking = true
					pcall(function() BlockService.Activated:Fire(target) end)
				end
			else
				releaseBlock()
			end
		end
	end
end)

--[[ Hitbox Expand ]] 
local function setupHitboxHook()
	if type(getrawmetatable) ~= "function" or type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		return false
	end
	local ws = workspace
	local ok, mt = pcall(getrawmetatable, ws)
	if not ok or not mt then return false end
	wsMt = mt
	local old = hookmetamethod(mt, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if method == "GetPartBoundsInRadius" and self == ws then
			local mult = Options.HitboxMult.Value
			if mult ~= 1 then
				local args = { ... }
				if type(args[2]) == "number" then
					args[2] = args[2] * mult
					return old(self, table.unpack(args))
				end
			end
		end
		return old(self, ...)
	end)
	oldNamecall = old
	return true
end

task.spawn(function()
	while running do
		task.wait(0.3)
		if Toggles.HitboxExpand.Value then
			if not hookInstalled then
				hookInstalled = setupHitboxHook()
				if not hookInstalled then
					Library:Notify({ Title = "jjsmain", Description = "Hitbox expander unsupported on this executor.", Time = 3 })
				end
			end
		elseif hookInstalled and oldNamecall and wsMt then
			pcall(function() hookmetamethod(wsMt, "__namecall", oldNamecall) end)
			hookInstalled = false
			oldNamecall = nil
			wsMt = nil
		end
	end
end)

--[[ Auto Lock-On ]]
task.spawn(function()
	while running do
		task.wait(0.15)
		if Toggles.AutoLock.Value then
			local cur = MovementController.LockOn
			local alive = cur and cur:FindFirstChild("Humanoid") and cur.Humanoid.Health > 0
			if not alive then
				MovementController.LockOn = getNearestEnemy(Options.LockRange.Value)
			end
		end
	end
end)

--[[ Dash Assist (front toward lock target / side around target) ]]
local oldDashRequest = MovementController.DashRequest
function MovementController:DashRequest()
	if Toggles.DashAssist.Value and dashReady() then
		local hrp = getHRP()
		local enemy = MovementController.LockOn or getNearestEnemy(Options.LockRange.Value)
		if hrp and enemy and enemy:FindFirstChild("HumanoidRootPart") then
			local dist = (enemy.HumanoidRootPart.Position - hrp.Position).Magnitude
			if dist <= Options.LockRange.Value then
				faceTarget(enemy, hrp)
				local mv = GetControls()
				if math.abs(mv.X) > 0.3 then
					fireDash(mv.X > 0 and "Right" or "Left")
				else
					fireDash("Front")
				end
				return
			end
		end
	end
	return oldDashRequest()
end

--[[ No Cooldown (Yuji black flash loop)
Loops: Cursed Strikes (feeds the M1 chain) -> dash behind enemy -> timed M1 = Black Flash.
Casts chain back to back - server still gates each individual cast. ]]
local function getSkillItem(key)
	local ch = LocalPlayer.Character
	if not ch or not ch:FindFirstChild("Moveset") then
		return nil
	end
	for _, item in ch.Moveset:GetChildren() do
		if item:GetAttribute("Key") == key and item:GetAttribute("Service") then
			return item
		end
	end
	return nil
end

local function fireCursedStrikes()
	local item = getSkillItem(3)
	if not item then
		return false
	end
	local ok, sv = pcall(function()
		return Knit.GetService(item:GetAttribute("Service"))
	end)
	if not ok or not sv or not sv.Activated then
		return false
	end
	local ok2, target = pcall(function() return ToolController:GetTarget() end)
	if not ok2 then target = nil end
	pcall(function() sv.Activated:Fire(item, target) end)
	return true
end

local function blackflashFinisher()
	local hrp = getHRP()
	local tgt = getNearestEnemy(12)
	if not (running and hrp and tgt and tgt:FindFirstChild("HumanoidRootPart")) then
		return
	end
	if Toggles.DashBehind.Value then
		faceTarget(tgt, hrp)
	end
	fireDash("Front")
	task.wait(0.02)
	if running and dashReady() then
		pcall(function() ToolController:Melee() end)
	end
end

task.spawn(function()
	while running do
		if Toggles.AutoBlackflash.Value then
			local hrp = getHRP()
			local tgt = getNearestEnemy(12)
			if hrp and tgt and dashReady() then
				fireCursedStrikes()
				task.wait(Options.BfInterval.Value)
				blackflashFinisher()
			end
			task.wait(Options.LoopDelay.Value)
		else
			task.wait(0.2)
		end
	end
end)

--[[ UI ]]
local Window = Library:CreateWindow({
	Title = "jjsmain",
	Footer = "Jujutsu Shenanigans",
	Icon = 95816097006870,
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local CombatTab = Window:AddTab("Combat", "sword")

local Defense = CombatTab:AddLeftGroupbox("Defense", "shield")
Defense:AddToggle("AutoBlock", {
	Text = "Auto Block",
	Default = false,
	Tooltip = "Blocks when an enemy is close and roughly in front of you. Failing to face the attack breaks your block (server rule).",
})
Defense:AddSlider("BlockRange", {
	Text = "Block Range",
	Default = 20, Min = 5, Max = 40, Rounding = 0, Suffix = "studs",
})
Defense:AddSlider("BlockAngle", {
	Text = "Block Facing Angle",
	Default = 75, Min = 20, Max = 120, Rounding = 0, Suffix = "deg",
})

local Offense = CombatTab:AddRightGroupbox("Offense", "zap")
Offense:AddToggle("AutoBlackflash", {
	Text = "No Cooldown",
	Default = false,
	Risky = true,
	Tooltip = "Loops Cursed Strikes -> dash behind + timed M1 (Black Flash) continuously, chaining casts with no cooldown between them (server still gates each cast).",
})
Offense:AddToggle("DashBehind", {
	Text = "Dash Behind Enemy",
	Default = true,
	Tooltip = "Faces the enemy and dashes through them before the Black Flash, hitting from behind. Off = dash in current facing (still blackflashes).",
})
Offense:AddSlider("BfInterval", {
	Text = "Flurry Time",
	Default = 0.55, Min = 0.3, Max = 1.0, Rounding = 2, Suffix = "s",
	Tooltip = "Time for Cursed Strikes' punches to feed the M1 chain before the Black Flash M1.",
})
Offense:AddSlider("LoopDelay", {
	Text = "Loop Delay",
	Default = 0.9, Min = 0.4, Max = 2.5, Rounding = 2, Suffix = "s",
	Tooltip = "Pause after each Black Flash before starting the next loop.",
})
Offense:AddLabel("Loops automatically while on - no key presses needed. Yuji only.")

local LockBox = CombatTab:AddLeftGroupbox("Lock Assist", "crosshair")
LockBox:AddToggle("AutoLock", {
	Text = "Auto Lock-On",
	Default = false,
	Tooltip = "Automatically locks onto the nearest enemy in range (movement shift-lock).",
})
LockBox:AddSlider("LockRange", {
	Text = "Lock Range",
	Default = 60, Min = 10, Max = 120, Rounding = 0, Suffix = "studs",
})
LockBox:AddToggle("DashAssist", {
	Text = "Dash Assist (Front/Side)",
	Default = true,
	Tooltip = "Dash key dashes toward the locked enemy; strafe (A/D) while dashing sidesteps around them.",
})

local HitboxBox = CombatTab:AddRightGroupbox("Hitbox", "target")
HitboxBox:AddToggle("HitboxExpand", {
	Text = "Hitbox Expander",
	Default = false,
	Risky = true,
	Tooltip = "Multiplies the client hitbox radius reported for your M1s/skills via GetPartBoundsInRadius.",
})
HitboxBox:AddSlider("HitboxMult", {
	Text = "Hitbox Multiplier",
	Default = 1.3, Min = 1, Max = 2, Rounding = 1, Suffix = "x",
})
HitboxBox:AddLabel("Requires executor metatable hooks (getrawmetatable).")

local UISettings = Window:AddTab("UI Settings", "settings")

SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("jjsmain")
SaveManager:SetFolder("jjsmain/Jujutsu Shenanigans")
SaveManager:BuildConfigSection(UISettings)
ThemeManager:ApplyToTab(UISettings)

SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	running = false
	if hookInstalled and oldNamecall and wsMt then
		pcall(function() hookmetamethod(wsMt, "__namecall", oldNamecall) end)
	end
	Library.Unloaded = true
end)