if _G.ESP_RAINBOW_DELUXE_UNLOAD and type(_G.ESP_RAINBOW_DELUXE_UNLOAD) == "function" then
	pcall(_G.ESP_RAINBOW_DELUXE_UNLOAD)
end

local Connections, Services, Settings, PlayerData, ScreenGui = {}, setmetatable({}, {
	__index = function(self, name)
		local success, service = pcall(game.GetService, game, name)
		if success then
			rawset(self, name, service)
			return service
		end
		error("Invalid Service: " .. tostring(name))
	end
}), {
	TeamMode = 0,
	ESPEnabled = true,
	HealthBarEnabled = true,
	XRayEnabled = false,
	TracersEnabled = true,
	BoxesEnabled = true,
	BoxStyle = "Corner",
	BoxThickness = 1.6,
	NamesEnabled = true,
	ShowDistance = true,
	ShowHealth = true,
	RainbowMode = true,
	ChamsEnabled = false,
	HeadDotEnabled = false,
	SkeletonEnabled = false
}, {
	Tracers = {},
	InfoTexts = {},
	Hitboxes = {},
	HealthBars = {},
	HeadDots = {},
	Skeletons = {}
}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Connections, connection)
	return connection
end

local function unload()
	for _, connection in ipairs(Connections) do
		if connection.Connected then connection:Disconnect() end
	end
	table.clear(Connections)
	if ScreenGui then ScreenGui:Destroy() end
end
_G.ESP_RAINBOW_DELUXE_UNLOAD = unload

local lpr, camera = Services.Players.LocalPlayer, Services.Workspace.CurrentCamera
local worldToViewportPoint = camera.WorldToViewportPoint

local function rainbowColor(t)
	return Color3.fromRGB(
		math.floor(math.sin(t) * 127 + 128),
		math.floor(math.sin(t + 2) * 127 + 128),
		math.floor(math.sin(t + 4) * 127 + 128)
	)
end

local function getColor(t, id)
	return Settings.RainbowMode and rainbowColor(t + (id or 0) * 0.1) or Color3.fromRGB(255, 40, 40)
end

local function getTeamModeText()
	return Settings.TeamMode == 1 and "Enemies" or Settings.TeamMode == 2 and "Team" or "All"
end

local function applyXRay()
	pcall(function()
		for _, v in pairs(Services.Workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				local char = v.Parent
				if not (char and char:FindFirstChildWhichIsA("Humanoid")) and not (char and char.Parent and char.Parent:FindFirstChildWhichIsA("Humanoid")) then
					v.LocalTransparencyModifier = Settings.XRayEnabled and 0.7 or 0
				end
			end
		end
	end)
end

local function createBillboard(player, adornee)
	local success, result = pcall(function()
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance, gui.Adornee = UDim2.new(0, 260, 0, 88), Vector3.new(0, 3.6, 0), true, 1000, adornee

		local name = Instance.new("TextLabel")
		name.Size, name.BackgroundTransparency, name.TextStrokeTransparency, name.TextSize, name.TextColor3, name.Font, name.Text, name.Parent =
			UDim2.new(1, 0, 0.34, 0), 1, 0.3, 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, player.Name, gui

		local dist = Instance.new("TextLabel")
		dist.Size, dist.Position, dist.BackgroundTransparency, dist.TextStrokeTransparency, dist.TextSize, dist.TextColor3, dist.Font, dist.Parent =
			UDim2.new(1, 0, 0.33, 0), UDim2.new(0, 0, 0.34, 0), 1, 0.3, 13, Color3.fromRGB(255, 255, 255), Enum.Font.Gotham, gui

		local hp = Instance.new("TextLabel")
		hp.Size, hp.Position, hp.BackgroundTransparency, hp.TextStrokeTransparency, hp.TextSize, hp.TextColor3, hp.Font, hp.Parent =
			UDim2.new(1, 0, 0.33, 0), UDim2.new(0, 0, 0.67, 0), 1, 0.3, 13, Color3.fromRGB(255, 255, 255), Enum.Font.Gotham, gui

		return {gui = gui, name = name, dist = dist, hp = hp}
	end)
	return success and result or nil
end

local function createHealthBar()
	local success, result = pcall(function()
		local bg, bar = Drawing.new("Square"), Drawing.new("Square")
		bg.Filled, bg.Thickness, bg.Color, bg.Transparency = true, 1, Color3.fromRGB(15, 0, 0), 0.35
		bar.Filled, bar.Thickness, bar.Transparency = true, 1, 1
		return {bg = bg, bar = bar}
	end)
	return success and result or nil
end

local function createBox()
	local success, result = pcall(function()
		if Settings.BoxStyle == "Corner" then
			local lines = {}
			for i = 1, 8 do
				local l = Drawing.new("Line")
				l.Thickness, l.Transparency, l.Visible = Settings.BoxThickness, 1, false
				lines[i] = l
			end
			return {type = "Corner", lines = lines}
		else
			local b = Drawing.new("Square")
			b.Thickness, b.Filled, b.Transparency, b.Visible = Settings.BoxThickness, false, 1, false
			return {type = "2D", box = b}
		end
	end)
	return success and result or nil
end

local function createDot()
	local success, d = pcall(function()
		local c = Drawing.new("Circle")
		c.Thickness, c.Filled, c.Radius, c.Transparency = 1, true, 3.5, 1
		return c
	end)
	return success and d or nil
end

local function createSkeleton()
	local lines = {}
	for i = 1, 12 do
		local success, line = pcall(function()
			local l = Drawing.new("Line")
			l.Thickness, l.Transparency = 1.6, 1
			return l
		end)
		if success then lines[i] = line end
	end
	return lines
end

local function applyChams(player, on, col)
	pcall(function()
		if not player.Character then return end
		for _, part in pairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Material = on and Enum.Material.ForceField or Enum.Material.Plastic
				if on then part.Color = col or Color3.fromRGB(255, 40, 40) end
			end
		end
	end)
end

local function shouldShow(player)
	return Settings.TeamMode == 0 or (Settings.TeamMode == 1 and player.Team ~= lpr.Team) or (Settings.TeamMode == 2 and player.Team == lpr.Team)
end

local function getBones(char)
	local function p(name)
		local o = char:FindFirstChild(name)
		return o and o.Position
	end
	return {
		Head = p("Head"),
		Torso = p("UpperTorso") or p("Torso"),
		Lower = p("LowerTorso") or p("Torso"),
		LArm = p("LeftUpperArm") or p("Left Arm"),
		RArm = p("RightUpperArm") or p("Right Arm"),
		LLeg = p("LeftUpperLeg") or p("Left Leg"),
		RLeg = p("RightUpperLeg") or p("Right Leg"),
		LHand = p("LeftHand") or p("Left Arm"),
		RHand = p("RightHand") or p("Right Arm"),
		LFoot = p("LeftFoot") or p("Left Leg"),
		RFoot = p("RightFoot") or p("Right Leg")
	}
end

local function hideBox(boxData)
	if not boxData then return end
	if boxData.type == "Corner" and boxData.lines then
		for _, l in ipairs(boxData.lines) do if l then l.Visible = false end end
	elseif boxData.box then
		boxData.box.Visible = false
	end
end

local function destroyBox(boxData)
	if not boxData then return end
	if boxData.type == "Corner" and boxData.lines then
		for _, l in ipairs(boxData.lines) do if l then l:Remove() end end
	elseif boxData.box then
		boxData.box:Remove()
	end
end

local function update()
	pcall(function()
		camera = Services.Workspace.CurrentCamera or camera
		if not camera then return end
		worldToViewportPoint = camera.WorldToViewportPoint

		if not Settings.ESPEnabled or not lpr.Character or not lpr.Character:FindFirstChild("HumanoidRootPart") then
			for _, v in pairs(PlayerData.Tracers) do if v then v.Visible = false end end
			for _, v in pairs(PlayerData.InfoTexts) do if v and v.gui then v.gui.Enabled = false end end
			for _, v in pairs(PlayerData.Hitboxes) do hideBox(v) end
			for _, v in pairs(PlayerData.HealthBars) do if v then v.bg.Visible, v.bar.Visible = false, false end end
			for _, v in pairs(PlayerData.HeadDots) do if v then v.Visible = false end end
			for _, sk in pairs(PlayerData.Skeletons) do for _, l in pairs(sk) do if l then l.Visible = false end end end
			return
		end

		local time = tick()

		for _, player in pairs(Services.Players:GetPlayers()) do
			if player ~= lpr and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local root, head = player.Character.HumanoidRootPart, player.Character:FindFirstChild("Head")
				local sp, onScreen = worldToViewportPoint(camera, root.Position)
				local hp, headOn = Vector3.zero, false
				if head then hp, headOn = worldToViewportPoint(camera, head.Position) end

				if not shouldShow(player) then
					if PlayerData.Tracers[player] then PlayerData.Tracers[player].Visible = false end
					if PlayerData.InfoTexts[player] then PlayerData.InfoTexts[player].gui.Enabled = false end
					hideBox(PlayerData.Hitboxes[player])
					if PlayerData.HealthBars[player] then PlayerData.HealthBars[player].bg.Visible, PlayerData.HealthBars[player].bar.Visible = false, false end
					if PlayerData.HeadDots[player] then PlayerData.HeadDots[player].Visible = false end
					if PlayerData.Skeletons[player] then for _, l in pairs(PlayerData.Skeletons[player]) do if l then l.Visible = false end end end
				else
					if not PlayerData.Tracers[player] then PlayerData.Tracers[player] = Drawing.new("Line") end
					if not PlayerData.InfoTexts[player] then
						local data = createBillboard(player, head or root)
						if data then
							data.gui.Parent = lpr:WaitForChild("PlayerGui")
							PlayerData.InfoTexts[player] = data
						end
					end

					if not PlayerData.Hitboxes[player] or PlayerData.Hitboxes[player].type ~= Settings.BoxStyle then
						if PlayerData.Hitboxes[player] then destroyBox(PlayerData.Hitboxes[player]) end
						PlayerData.Hitboxes[player] = createBox()
					end

					if not PlayerData.HealthBars[player] then PlayerData.HealthBars[player] = createHealthBar() end
					if not PlayerData.HeadDots[player] then PlayerData.HeadDots[player] = createDot() end
					if not PlayerData.Skeletons[player] then PlayerData.Skeletons[player] = createSkeleton() end

					local tracer, info, boxData, hbar, dot, skel = PlayerData.Tracers[player], PlayerData.InfoTexts[player], PlayerData.Hitboxes[player], PlayerData.HealthBars[player], PlayerData.HeadDots[player], PlayerData.Skeletons[player]
					local col = getColor(time, player.UserId)

					if onScreen then
						if Settings.TracersEnabled and tracer then
							tracer.From, tracer.To, tracer.Color, tracer.Thickness, tracer.Visible = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y), Vector2.new(sp.X, sp.Y), col, 2, true
						elseif tracer then
							tracer.Visible = false
						end

						if headOn then
							if info then
								info.gui.Enabled = true
								if Settings.NamesEnabled then
									info.name.Text, info.name.TextColor3, info.name.Visible = player.Name, col, true
								else
									info.name.Visible = false
								end
								if Settings.ShowDistance then
									info.dist.Text = string.format("%.1f studs", (root.Position - lpr.Character.HumanoidRootPart.Position).Magnitude)
									info.dist.TextColor3, info.dist.Visible = col, true
								else
									info.dist.Visible = false
								end
								if Settings.ShowHealth then
									local hum = player.Character:FindFirstChildOfClass("Humanoid")
									if hum then
										local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) * 100
										info.hp.Text = string.format("Health: %.0f%%  |  %.0f/%.0f HP", pct, hum.Health, hum.MaxHealth)
										info.hp.TextColor3, info.hp.Visible = col, true
									else
										info.hp.Visible = false
									end
								else
									info.hp.Visible = false
								end
							end

							if Settings.BoxesEnabled and boxData then
								local size = math.clamp((hp - sp).Magnitude * 2.1, 18, 120)
								local boxW, boxH = size, size * 2.15
								local boxX, boxY = sp.X - boxW / 2, sp.Y - boxH * 0.55

								if boxData.type == "Corner" and boxData.lines then
									local cl = math.clamp(boxW * 0.25, 5, 20)
									local x1, y1, x2, y2 = boxX, boxY, boxX + boxW, boxY + boxH
									local lines = boxData.lines

									lines[1].From, lines[1].To = Vector2.new(x1, y1), Vector2.new(x1 + cl, y1)
									lines[2].From, lines[2].To = Vector2.new(x1, y1), Vector2.new(x1, y1 + cl)
									lines[3].From, lines[3].To = Vector2.new(x2, y1), Vector2.new(x2 - cl, y1)
									lines[4].From, lines[4].To = Vector2.new(x2, y1), Vector2.new(x2, y1 + cl)
									lines[5].From, lines[5].To = Vector2.new(x1, y2), Vector2.new(x1 + cl, y2)
									lines[6].From, lines[6].To = Vector2.new(x1, y2), Vector2.new(x1, y2 - cl)
									lines[7].From, lines[7].To = Vector2.new(x2, y2), Vector2.new(x2 - cl, y2)
									lines[8].From, lines[8].To = Vector2.new(x2, y2), Vector2.new(x2, y2 - cl)

									for i = 1, 8 do
										lines[i].Color, lines[i].Thickness, lines[i].Visible = col, Settings.BoxThickness, true
									end
								elseif boxData.type == "2D" and boxData.box then
									boxData.box.Size, boxData.box.Position, boxData.box.Color, boxData.box.Thickness, boxData.box.Visible =
										Vector2.new(boxW, boxH), Vector2.new(boxX, boxY), col, Settings.BoxThickness, true
								end
							else
								hideBox(boxData)
							end

							if Settings.HealthBarEnabled and hbar then
								local hum = player.Character:FindFirstChildOfClass("Humanoid")
								if hum then
									local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
									local w, pos = 58, Vector2.new(hp.X - 29, hp.Y - 30)
									hbar.bg.Size, hbar.bg.Position, hbar.bg.Visible = Vector2.new(w, 5), pos, true
									hbar.bar.Size, hbar.bar.Position, hbar.bar.Color, hbar.bar.Visible = Vector2.new(w * pct, 5), pos, col, true
								end
							elseif hbar then
								hbar.bg.Visible, hbar.bar.Visible = false, false
							end

							if Settings.HeadDotEnabled and dot then
								dot.Position, dot.Color, dot.Visible = Vector2.new(hp.X, hp.Y), col, true
							elseif dot then
								dot.Visible = false
							end

							if Settings.SkeletonEnabled and skel then
								local b = getBones(player.Character)
								local function line(i, a, c)
									if a and c and skel[i] then
										local s1, o1 = worldToViewportPoint(camera, a)
										local s2, o2 = worldToViewportPoint(camera, c)
										if o1 and o2 then
											skel[i].From, skel[i].To, skel[i].Color, skel[i].Visible = Vector2.new(s1.X, s1.Y), Vector2.new(s2.X, s2.Y), col, true
										else
											skel[i].Visible = false
										end
									elseif skel[i] then
										skel[i].Visible = false
									end
								end
								line(1, b.Head, b.Torso)
								line(2, b.Torso, b.Lower)
								line(3, b.Torso, b.LArm)
								line(4, b.Torso, b.RArm)
								line(5, b.LArm, b.LHand)
								line(6, b.RArm, b.RHand)
								line(7, b.Lower, b.LLeg)
								line(8, b.Lower, b.RLeg)
								line(9, b.LLeg, b.LFoot)
								line(10, b.RLeg, b.RFoot)
							elseif skel then
								for _, l in pairs(skel) do if l then l.Visible = false end end
							end
						else
							if info then info.gui.Enabled = false end
							hideBox(boxData)
							if hbar then hbar.bg.Visible, hbar.bar.Visible = false, false end
							if dot then dot.Visible = false end
							if skel then for _, l in pairs(skel) do if l then l.Visible = false end end end
						end
					else
						if tracer then tracer.Visible = false end
						if info then info.gui.Enabled = false end
						hideBox(boxData)
						if hbar then hbar.bg.Visible, hbar.bar.Visible = false, false end
						if dot then dot.Visible = false end
						if skel then for _, l in pairs(skel) do if l then l.Visible = false end end end
					end

					if Settings.ChamsEnabled then applyChams(player, true, col) end
				end
			end
		end
	end)
end

-- GUI
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name, ScreenGui.ResetOnSpawn, ScreenGui.ZIndexBehavior, ScreenGui.Parent = "ESPRainbowDeluxe", false, Enum.ZIndexBehavior.Sibling, lpr:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name, mainFrame.Size, mainFrame.Position, mainFrame.BackgroundColor3, mainFrame.BorderSizePixel, mainFrame.Active, mainFrame.Parent =
	"Main", UDim2.new(0, 520, 0, 540), UDim2.new(0.5, -260, 0.5, -270), Color3.fromRGB(10, 10, 10), 0, true, ScreenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color, stroke.Thickness, stroke.Transparency = Color3.fromRGB(180, 0, 0), 2.5, 0.25

local TitleBar = Instance.new("Frame")
TitleBar.Size, TitleBar.BackgroundColor3, TitleBar.BorderSizePixel, TitleBar.Parent = UDim2.new(1, 0, 0, 68), Color3.fromRGB(22, 0, 0), 0, mainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleFix = Instance.new("Frame")
TitleFix.Size, TitleFix.Position, TitleFix.BackgroundColor3, TitleFix.BorderSizePixel, TitleFix.Parent =
	UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 1, -16), Color3.fromRGB(22, 0, 0), 0, TitleBar

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size, VersionLabel.Position, VersionLabel.BackgroundTransparency, VersionLabel.Text, VersionLabel.TextColor3, VersionLabel.Font, VersionLabel.TextSize, VersionLabel.TextXAlignment, VersionLabel.Parent =
	UDim2.new(0, 90, 0, 16), UDim2.new(0, 16, 0, 6), 1, "Version 1.3", Color3.fromRGB(255, 50, 50), Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left, TitleBar

local CreditLabel = Instance.new("TextLabel")
CreditLabel.Size, CreditLabel.Position, CreditLabel.BackgroundTransparency, CreditLabel.Text, CreditLabel.TextColor3, CreditLabel.Font, CreditLabel.TextSize, CreditLabel.TextXAlignment, CreditLabel.Parent =
	UDim2.new(1, -60, 0, 16), UDim2.new(0, 16, 0, 24), 1, "By MaxproGlitcher  •  Discord : maxproglitcher", Color3.fromRGB(255, 55, 55), Enum.Font.Gotham, 12, Enum.TextXAlignment.Left, TitleBar

local Title = Instance.new("TextLabel")
Title.Size, Title.Position, Title.BackgroundTransparency, Title.Text, Title.TextColor3, Title.Font, Title.TextSize, Title.TextXAlignment, Title.Parent =
	UDim2.new(1, -50, 0, 22), UDim2.new(0, 16, 0, 42), 1, "ESP RAINBOW DELUXE", Color3.fromRGB(255, 45, 45), Enum.Font.GothamBold, 17, Enum.TextXAlignment.Left, TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size, CloseBtn.Position, CloseBtn.BackgroundColor3, CloseBtn.Text, CloseBtn.TextColor3, CloseBtn.Font, CloseBtn.TextSize, CloseBtn.Parent =
	UDim2.new(0, 32, 0, 32), UDim2.new(1, -40, 0, 10), Color3.fromRGB(45, 0, 0), "X", Color3.fromRGB(255, 80, 80), Enum.Font.GothamBold, 16, TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
connect(CloseBtn.MouseButton1Click, unload)

local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	pcall(function()
		local delta = input.Position - dragStart
		Services.TweenService:Create(mainFrame, TweenInfo.new(0.12), {
			Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		}):Play()
	end)
end

connect(mainFrame.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, input.Position, mainFrame.Position
		connect(input.Changed, function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

connect(mainFrame.InputChanged, function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

connect(Services.UserInputService.InputChanged, function(input)
	if dragging and input == dragInput then updateDrag(input) end
end)

local resizeBtn = Instance.new("TextButton")
resizeBtn.Size, resizeBtn.Position, resizeBtn.BackgroundTransparency, resizeBtn.Text, resizeBtn.TextColor3, resizeBtn.TextSize, resizeBtn.ZIndex, resizeBtn.Parent =
	UDim2.new(0, 20, 0, 20), UDim2.new(1, -18, 1, -18), 1, "◢", Color3.fromRGB(180, 0, 0), 14, 10, mainFrame

local resizing, resizeStart, startSize = false
connect(resizeBtn.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing, resizeStart, startSize = true, input.Position, mainFrame.AbsoluteSize
		connect(input.Changed, function()
			if input.UserInputState == Enum.UserInputState.End then resizing = false end
		end)
	end
end)

connect(Services.UserInputService.InputChanged, function(input)
	if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - resizeStart
		mainFrame.Size = UDim2.new(0, math.clamp(startSize.X + delta.X, 400, 900), 0, math.clamp(startSize.Y + delta.Y, 350, 800))
	end
end)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size, scrollFrame.Position, scrollFrame.BackgroundTransparency, scrollFrame.BorderSizePixel, scrollFrame.ScrollBarThickness, scrollFrame.ScrollBarImageColor3, scrollFrame.CanvasSize, scrollFrame.AutomaticCanvasSize, scrollFrame.Parent =
	UDim2.new(1, -12, 1, -78), UDim2.new(0, 6, 0, 72), 1, 0, 5, Color3.fromRGB(170, 0, 0), UDim2.new(0, 0, 0, 0), Enum.AutomaticSize.Y, mainFrame

local content = Instance.new("Frame")
content.Size, content.BackgroundTransparency, content.AutomaticSize, content.Parent = UDim2.new(1, -10, 0, 0), 1, Enum.AutomaticSize.Y, scrollFrame

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding, mainLayout.SortOrder, mainLayout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, content

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop, contentPadding.PaddingBottom, contentPadding.PaddingLeft, contentPadding.PaddingRight, contentPadding.Parent =
	UDim.new(0, 8), UDim.new(0, 12), UDim.new(0, 6), UDim.new(0, 6), content

local function makeSection(title)
	local section = Instance.new("Frame")
	section.Size, section.BackgroundColor3, section.BorderSizePixel, section.AutomaticSize, section.Parent =
		UDim2.new(1, 0, 0, 0), Color3.fromRGB(16, 16, 16), 0, Enum.AutomaticSize.Y, content
	Instance.new("UICorner", section).CornerRadius = UDim.new(0, 8)

	local s = Instance.new("UIStroke", section)
	s.Color, s.Thickness = Color3.fromRGB(50, 0, 0), 1

	local header = Instance.new("TextLabel")
	header.Size, header.Position, header.BackgroundTransparency, header.Text, header.TextColor3, header.Font, header.TextSize, header.TextXAlignment, header.Parent =
		UDim2.new(1, -16, 0, 28), UDim2.new(0, 10, 0, 4), 1, title, Color3.fromRGB(200, 40, 40), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left, section

	local row = Instance.new("Frame")
	row.Size, row.Position, row.BackgroundTransparency, row.Parent = UDim2.new(1, -12, 0, 0), UDim2.new(0, 6, 0, 32), 1, section

	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding, grid.FillDirection, grid.HorizontalAlignment, grid.SortOrder, grid.Parent =
		UDim2.new(0.5, -6, 0, 38), UDim2.new(0, 8, 0, 8), Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.SortOrder.LayoutOrder, row

	connect(grid:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		row.Size = UDim2.new(1, -12, 0, grid.AbsoluteContentSize.Y)
	end)
	row.Size = UDim2.new(1, -12, 0, grid.AbsoluteContentSize.Y)

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom, pad.Parent = UDim.new(0, 10), section

	return row
end

local function makeToggle(parent, name, default, callback)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3, frame.BorderSizePixel, frame.Parent = Color3.fromRGB(24, 24, 24), 0, parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.Size, label.Position, label.BackgroundTransparency, label.Text, label.TextColor3, label.Font, label.TextSize, label.TextXAlignment, label.TextTruncate, label.Parent =
		UDim2.new(1, -58, 1, 0), UDim2.new(0, 10, 0, 0), 1, name, Color3.fromRGB(230, 230, 230), Enum.Font.Gotham, 13, Enum.TextXAlignment.Left, Enum.TextTruncate.AtEnd, frame

	local toggle = Instance.new("TextButton")
	toggle.Size, toggle.Position, toggle.BackgroundColor3, toggle.Text, toggle.Parent =
		UDim2.new(0, 42, 0, 22), UDim2.new(1, -50, 0.5, -11), default and Color3.fromRGB(160, 0, 0) or Color3.fromRGB(45, 45, 45), "", frame
	Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

	local circle = Instance.new("Frame")
	circle.Size, circle.Position, circle.BackgroundColor3, circle.BorderSizePixel, circle.Parent =
		UDim2.new(0, 16, 0, 16), default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8), Color3.fromRGB(255, 255, 255), 0, toggle
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local state = default
	connect(toggle.MouseButton1Click, function()
		state = not state
		Services.TweenService:Create(circle, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
		Services.TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(160, 0, 0) or Color3.fromRGB(45, 45, 45)}):Play()
		pcall(callback, state)
	end)
end

local function makeButton(parent, name, callback)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3, btn.Text, btn.TextColor3, btn.Font, btn.TextSize, btn.Parent =
		Color3.fromRGB(40, 0, 0), name, Color3.fromRGB(255, 80, 80), Enum.Font.GothamBold, 13, parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local s = Instance.new("UIStroke", btn)
	s.Color, s.Thickness = Color3.fromRGB(120, 0, 0), 1

	connect(btn.MouseButton1Click, function() pcall(callback) end)
	connect(btn.MouseEnter, function()
		Services.TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 0, 0)}):Play()
	end)
	connect(btn.MouseLeave, function()
		Services.TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 0, 0)}):Play()
	end)
	return btn
end

local left = makeSection("ESP CONTROLS")
makeToggle(left, "ESP Enabled", true, function(v) Settings.ESPEnabled = v end)
makeToggle(left, "Health Bar", true, function(v) Settings.HealthBarEnabled = v end)
makeToggle(left, "X-Ray", false, function(v) Settings.XRayEnabled = v applyXRay() end)
makeToggle(left, "Tracers", true, function(v) Settings.TracersEnabled = v end)
makeToggle(left, "Boxes", true, function(v) Settings.BoxesEnabled = v end)
makeToggle(left, "Names", true, function(v) Settings.NamesEnabled = v end)

local right = makeSection("TEAM & FILTER")
local teamBtn = makeButton(right, "Mode: " .. getTeamModeText(), function()
	Settings.TeamMode = (Settings.TeamMode + 1) % 3
	teamBtn.Text = "Mode: " .. getTeamModeText()
end)
makeToggle(right, "Enemies Only", false, function(v)
	Settings.TeamMode = v and 1 or 0
	teamBtn.Text = "Mode: " .. getTeamModeText()
end)
makeToggle(right, "Team Only", false, function(v)
	Settings.TeamMode = v and 2 or 0
	teamBtn.Text = "Mode: " .. getTeamModeText()
end)
makeToggle(right, "Show Distance", true, function(v) Settings.ShowDistance = v end)
makeToggle(right, "Show Health", true, function(v) Settings.ShowHealth = v end)
makeToggle(right, "Rainbow Mode", true, function(v) Settings.RainbowMode = v end)

local extra = makeSection("EXTRA OPTIONS")
makeToggle(extra, "Chams", false, function(v)
	Settings.ChamsEnabled = v
	for _, p in pairs(Services.Players:GetPlayers()) do
		if p ~= lpr then applyChams(p, v, getColor(tick(), p.UserId)) end
	end
end)
makeToggle(extra, "Head Dot", false, function(v) Settings.HeadDotEnabled = v end)
makeToggle(extra, "Skeleton", false, function(v) Settings.SkeletonEnabled = v end)

local boxStyleBtn = makeButton(extra, "Box Style: " .. Settings.BoxStyle, function()
	Settings.BoxStyle = Settings.BoxStyle == "Corner" and "2D" or "Corner"
	boxStyleBtn.Text = "Box Style: " .. Settings.BoxStyle
	for player, boxData in pairs(PlayerData.Hitboxes) do
		destroyBox(boxData)
		PlayerData.Hitboxes[player] = nil
	end
end)

connect(Services.UserInputService.InputBegan, function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		mainFrame.Visible = not mainFrame.Visible
	end
end)

local function cleanPlayer(player)
	pcall(function()
		if PlayerData.Tracers[player] then PlayerData.Tracers[player]:Remove() PlayerData.Tracers[player] = nil end
		if PlayerData.InfoTexts[player] then PlayerData.InfoTexts[player].gui:Destroy() PlayerData.InfoTexts[player] = nil end
		if PlayerData.Hitboxes[player] then destroyBox(PlayerData.Hitboxes[player]) PlayerData.Hitboxes[player] = nil end
		if PlayerData.HealthBars[player] then
			PlayerData.HealthBars[player].bg:Remove()
			PlayerData.HealthBars[player].bar:Remove()
			PlayerData.HealthBars[player] = nil
		end
		if PlayerData.HeadDots[player] then PlayerData.HeadDots[player]:Remove() PlayerData.HeadDots[player] = nil end
		if PlayerData.Skeletons[player] then
			for _, l in pairs(PlayerData.Skeletons[player]) do if l then l:Remove() end end
			PlayerData.Skeletons[player] = nil
		end
		applyChams(player, false)
	end)
end

local function onPlayerAdded(player)
	connect(player.CharacterAdded, function()
		task.wait(1)
		cleanPlayer(player)
	end)
end

connect(Services.Players.PlayerAdded, onPlayerAdded)
connect(Services.Players.PlayerRemoving, cleanPlayer)

for _, player in pairs(Services.Players:GetPlayers()) do
	onPlayerAdded(player)
end

connect(Services.RunService.RenderStepped, update)
