if _G.ESP_RAINBOW_DELUXE_UNLOAD and type(_G.ESP_RAINBOW_DELUXE_UNLOAD) == "function" then
	pcall(_G.ESP_RAINBOW_DELUXE_UNLOAD)
end

local Connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Connections, connection)
	return connection
end

local function unload()
	for _, connection in ipairs(Connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(Connections)
	if ScreenGui then
		ScreenGui:Destroy()
	end
end
_G.ESP_RAINBOW_DELUXE_UNLOAD = unload

local Services = setmetatable({}, {
	__index = function(self, name)
		local success, service = pcall(function()
			return game:GetService(name)
		end)
		if success then
			rawset(self, name, service)
			return service
		end
		error("Invalid Service: " .. tostring(name))
	end
})

local lpr = Services.Players.LocalPlayer
local camera = Services.Workspace.CurrentCamera
local worldToViewportPoint = camera.WorldToViewportPoint

local Settings = {
	TeamMode = 0,
	ESPEnabled = true,
	HealthBarEnabled = true,
	XRayEnabled = false,
	TracersEnabled = true,
	BoxesEnabled = true,
	NamesEnabled = true,
	ShowDistance = true,
	ShowHealth = true,
	RainbowMode = true,
	ChamsEnabled = false,
	HeadDotEnabled = false,
	SkeletonEnabled = false
}

local PlayerData = {
	Tracers = {},
	InfoTexts = {},
	Hitboxes = {},
	HealthBars = {},
	HeadDots = {},
	Skeletons = {}
}

local function rainbowColor(t)
	local r = math.floor(math.sin(t + 0) * 127 + 128)
	local g = math.floor(math.sin(t + 2) * 127 + 128)
	local b = math.floor(math.sin(t + 4) * 127 + 128)
	return Color3.fromRGB(r, g, b)
end

local function getColor(t, id)
	if Settings.RainbowMode then
		return rainbowColor(t + (id or 0) * 0.1)
	end
	return Color3.fromRGB(255, 40, 40)
end

local function getTeamModeText()
	if Settings.TeamMode == 1 then return "Enemies"
	elseif Settings.TeamMode == 2 then return "Team"
	else return "All" end
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
		gui.Size = UDim2.new(0, 260, 0, 88)
		gui.StudsOffset = Vector3.new(0, 3.6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 1000
		gui.Adornee = adornee

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, 0, 0.34, 0)
		name.BackgroundTransparency = 1
		name.TextStrokeTransparency = 0.3
		name.TextSize = 15
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.Font = Enum.Font.GothamBold
		name.Text = player.Name
		name.Parent = gui

		local dist = Instance.new("TextLabel")
		dist.Size = UDim2.new(1, 0, 0.33, 0)
		dist.Position = UDim2.new(0, 0, 0.34, 0)
		dist.BackgroundTransparency = 1
		dist.TextStrokeTransparency = 0.3
		dist.TextSize = 13
		dist.TextColor3 = Color3.fromRGB(255, 255, 255)
		dist.Font = Enum.Font.Gotham
		dist.Parent = gui

		local hp = Instance.new("TextLabel")
		hp.Size = UDim2.new(1, 0, 0.33, 0)
		hp.Position = UDim2.new(0, 0, 0.67, 0)
		hp.BackgroundTransparency = 1
		hp.TextStrokeTransparency = 0.3
		hp.TextSize = 13
		hp.TextColor3 = Color3.fromRGB(255, 255, 255)
		hp.Font = Enum.Font.Gotham
		hp.Parent = gui

		return {gui = gui, name = name, dist = dist, hp = hp}
	end)
	if success then return result end
end

local function createHealthBar()
	local success, result = pcall(function()
		local bg = Drawing.new("Square")
		local bar = Drawing.new("Square")
		bg.Filled = true
		bg.Thickness = 1
		bg.Color = Color3.fromRGB(15, 0, 0)
		bg.Transparency = 0.35
		bar.Filled = true
		bar.Thickness = 1
		bar.Transparency = 1
		return {bg = bg, bar = bar}
	end)
	if success then return result end
end

local function createBox()
	local success, box = pcall(function()
		local b = Drawing.new("Square")
		b.Thickness = 2
		b.Filled = false
		b.Transparency = 1
		return b
	end)
	if success then return box end
end

local function createDot()
	local success, d = pcall(function()
		local c = Drawing.new("Circle")
		c.Thickness = 1
		c.Filled = true
		c.Radius = 3.5
		c.Transparency = 1
		return c
	end)
	if success then return d end
end

local function createSkeleton()
	local lines = {}
	for i = 1, 12 do
		local success, line = pcall(function()
			local l = Drawing.new("Line")
			l.Thickness = 1.6
			l.Transparency = 1
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
				if on then
					part.Material = Enum.Material.ForceField
					part.Color = col or Color3.fromRGB(255, 40, 40)
				else
					part.Material = Enum.Material.Plastic
				end
			end
		end
	end)
end

local function shouldShow(player)
	if Settings.TeamMode == 0 then return true end
	if Settings.TeamMode == 1 then return player.Team ~= lpr.Team end
	if Settings.TeamMode == 2 then return player.Team == lpr.Team end
	return true
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

local function update()
	pcall(function()
		camera = Services.Workspace.CurrentCamera or camera
		if not camera then return end
		worldToViewportPoint = camera.WorldToViewportPoint
		if not Settings.ESPEnabled or not lpr.Character or not lpr.Character:FindFirstChild("HumanoidRootPart") then
			for _, v in pairs(PlayerData.Tracers) do if v then v.Visible = false end end
			for _, v in pairs(PlayerData.InfoTexts) do if v and v.gui then v.gui.Enabled = false end end
			for _, v in pairs(PlayerData.Hitboxes) do if v then v.Visible = false end end
			for _, v in pairs(PlayerData.HealthBars) do if v then v.bg.Visible = false v.bar.Visible = false end end
			for _, v in pairs(PlayerData.HeadDots) do if v then v.Visible = false end end
			for _, sk in pairs(PlayerData.Skeletons) do for _, l in pairs(sk) do if l then l.Visible = false end end end
			return
		end

		local time = tick()
		for _, player in pairs(Services.Players:GetPlayers()) do
			if player ~= lpr and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local root = player.Character.HumanoidRootPart
				local head = player.Character:FindFirstChild("Head")
				local sp, onScreen = worldToViewportPoint(camera, root.Position)
				local hp, headOn = Vector3.zero, false
				if head then
					hp, headOn = worldToViewportPoint(camera, head.Position)
				end

				if not shouldShow(player) then
					if PlayerData.Tracers[player] then PlayerData.Tracers[player].Visible = false end
					if PlayerData.InfoTexts[player] then PlayerData.InfoTexts[player].gui.Enabled = false end
					if PlayerData.Hitboxes[player] then PlayerData.Hitboxes[player].Visible = false end
					if PlayerData.HealthBars[player] then PlayerData.HealthBars[player].bg.Visible = false PlayerData.HealthBars[player].bar.Visible = false end
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
					if not PlayerData.Hitboxes[player] then PlayerData.Hitboxes[player] = createBox() end
					if not PlayerData.HealthBars[player] then PlayerData.HealthBars[player] = createHealthBar() end
					if not PlayerData.HeadDots[player] then PlayerData.HeadDots[player] = createDot() end
					if not PlayerData.Skeletons[player] then PlayerData.Skeletons[player] = createSkeleton() end

					local tracer = PlayerData.Tracers[player]
					local info = PlayerData.InfoTexts[player]
					local box = PlayerData.Hitboxes[player]
					local hbar = PlayerData.HealthBars[player]
					local dot = PlayerData.HeadDots[player]
					local skel = PlayerData.Skeletons[player]
					local col = getColor(time, player.UserId)

					if onScreen then
						if Settings.TracersEnabled and tracer then
							tracer.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
							tracer.To = Vector2.new(sp.X, sp.Y)
							tracer.Color = col
							tracer.Thickness = 2
							tracer.Visible = true
						elseif tracer then
							tracer.Visible = false
						end

						if headOn then
							if info then
								info.gui.Enabled = true
								if Settings.NamesEnabled then
									info.name.Text = player.Name
									info.name.TextColor3 = col
									info.name.Visible = true
								else
									info.name.Visible = false
								end
								if Settings.ShowDistance then
									local d = (root.Position - lpr.Character.HumanoidRootPart.Position).Magnitude
									info.dist.Text = string.format("%.1f studs", d)
									info.dist.TextColor3 = col
									info.dist.Visible = true
								else
									info.dist.Visible = false
								end
								if Settings.ShowHealth then
									local hum = player.Character:FindFirstChildOfClass("Humanoid")
									if hum then
										local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) * 100
										info.hp.Text = string.format("Health: %.0f%%  |  %.0f/%.0f HP", pct, hum.Health, hum.MaxHealth)
										info.hp.TextColor3 = col
										info.hp.Visible = true
									else
										info.hp.Visible = false
									end
								else
									info.hp.Visible = false
								end
							end

							if Settings.BoxesEnabled and box then
								local size = math.clamp((hp - sp).Magnitude * 2.1, 18, 120)
								box.Size = Vector2.new(size, size * 2.15)
								box.Position = Vector2.new(sp.X - size/2, sp.Y - size * 1.05)
								box.Color = col
								box.Visible = true
							elseif box then
								box.Visible = false
							end

							if Settings.HealthBarEnabled and hbar then
								local hum = player.Character:FindFirstChildOfClass("Humanoid")
								if hum then
									local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
									local w = 58
									local pos = Vector2.new(hp.X - w/2, hp.Y - 30)
									hbar.bg.Size = Vector2.new(w, 5)
									hbar.bg.Position = pos
									hbar.bg.Visible = true
									hbar.bar.Size = Vector2.new(w * pct, 5)
									hbar.bar.Position = pos
									hbar.bar.Color = col
									hbar.bar.Visible = true
								end
							elseif hbar then
								hbar.bg.Visible = false
								hbar.bar.Visible = false
							end

							if Settings.HeadDotEnabled and dot then
								dot.Position = Vector2.new(hp.X, hp.Y)
								dot.Color = col
								dot.Visible = true
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
											skel[i].From = Vector2.new(s1.X, s1.Y)
											skel[i].To = Vector2.new(s2.X, s2.Y)
											skel[i].Color = col
											skel[i].Visible = true
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
							if box then box.Visible = false end
							if hbar then hbar.bg.Visible = false hbar.bar.Visible = false end
							if dot then dot.Visible = false end
							if skel then for _, l in pairs(skel) do if l then l.Visible = false end end end
						end
					else
						if tracer then tracer.Visible = false end
						if info then info.gui.Enabled = false end
						if box then box.Visible = false end
						if hbar then hbar.bg.Visible = false hbar.bar.Visible = false end
						if dot then dot.Visible = false end
						if skel then for _, l in pairs(skel) do if l then l.Visible = false end end end
					end

					if Settings.ChamsEnabled then
						applyChams(player, true, col)
					end
				end
			end
		end
	end)
end

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESPRainbowDeluxe"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = lpr:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 520, 0, 510)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -255)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = ScreenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(180, 0, 0)
stroke.Thickness = 2.5
stroke.Transparency = 0.25

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 68)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 0, 0)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = mainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 16)
TitleFix.Position = UDim2.new(0, 0, 1, -16)
TitleFix.BackgroundColor3 = Color3.fromRGB(22, 0, 0)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(0, 90, 0, 16)
VersionLabel.Position = UDim2.new(0, 16, 0, 6)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "Version 1.2"
VersionLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
VersionLabel.Font = Enum.Font.GothamBold
VersionLabel.TextSize = 12
VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.Parent = TitleBar

local CreditLabel = Instance.new("TextLabel")
CreditLabel.Size = UDim2.new(1, -60, 0, 16)
CreditLabel.Position = UDim2.new(0, 16, 0, 24)
CreditLabel.BackgroundTransparency = 1
CreditLabel.Text = "By MaxproGlitcher  •  Discord : maxproglitcher"
CreditLabel.TextColor3 = Color3.fromRGB(255, 55, 55)
CreditLabel.Font = Enum.Font.Gotham
CreditLabel.TextSize = 12
CreditLabel.TextXAlignment = Enum.TextXAlignment.Left
CreditLabel.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 0, 22)
Title.Position = UDim2.new(0, 16, 0, 42)
Title.BackgroundTransparency = 1
Title.Text = "ESP RAINBOW DELUXE"
Title.TextColor3 = Color3.fromRGB(255, 45, 45)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

connect(CloseBtn.MouseButton1Click, function()
	unload()
end)

local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	pcall(function()
		local delta = input.Position - dragStart
		local pos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		Services.TweenService:Create(mainFrame, TweenInfo.new(0.12), {Position = pos}):Play()
	end)
end

connect(mainFrame.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
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
resizeBtn.Size = UDim2.new(0, 20, 0, 20)
resizeBtn.Position = UDim2.new(1, -18, 1, -18)
resizeBtn.BackgroundTransparency = 1
resizeBtn.Text = "◢"
resizeBtn.TextColor3 = Color3.fromRGB(180, 0, 0)
resizeBtn.TextSize = 14
resizeBtn.ZIndex = 10
resizeBtn.Parent = mainFrame

local resizing = false
local resizeStart, startSize

connect(resizeBtn.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStart = input.Position
		startSize = mainFrame.AbsoluteSize
		connect(input.Changed, function()
			if input.UserInputState == Enum.UserInputState.End then resizing = false end
		end)
	end
end)

connect(Services.UserInputService.InputChanged, function(input)
	if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - resizeStart
		local newX = math.clamp(startSize.X + delta.X, 400, 900)
		local newY = math.clamp(startSize.Y + delta.Y, 350, 800)
		mainFrame.Size = UDim2.new(0, newX, 0, newY)
	end
end)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -12, 1, -78)
scrollFrame.Position = UDim2.new(0, 6, 0, 72)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 0)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 0, 0)
content.BackgroundTransparency = 1
content.AutomaticSize = Enum.AutomaticSize.Y
content.Parent = scrollFrame

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 10)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = content

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 8)
contentPadding.PaddingBottom = UDim.new(0, 12)
contentPadding.PaddingLeft = UDim.new(0, 6)
contentPadding.PaddingRight = UDim.new(0, 6)
contentPadding.Parent = content

local function makeSection(title)
	local section = Instance.new("Frame")
	section.Size = UDim2.new(1, 0, 0, 0)
	section.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	section.BorderSizePixel = 0
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.Parent = content
	Instance.new("UICorner", section).CornerRadius = UDim.new(0, 8)

	local s = Instance.new("UIStroke", section)
	s.Color = Color3.fromRGB(50, 0, 0)
	s.Thickness = 1

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -16, 0, 28)
	header.Position = UDim2.new(0, 10, 0, 4)
	header.BackgroundTransparency = 1
	header.Text = title
	header.TextColor3 = Color3.fromRGB(200, 40, 40)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = section

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -12, 0, 0)
	row.Position = UDim2.new(0, 6, 0, 32)
	row.BackgroundTransparency = 1
	row.Parent = section

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 38)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row

	local function updateGridSize()
		row.Size = UDim2.new(1, -12, 0, grid.AbsoluteContentSize.Y)
	end
	connect(grid:GetPropertyChangedSignal("AbsoluteContentSize"), updateGridSize)
	updateGridSize()

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = section

	return row
end

local function makeToggle(parent, name, default, callback)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -58, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = frame

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 42, 0, 22)
	toggle.Position = UDim2.new(1, -50, 0.5, -11)
	toggle.BackgroundColor3 = default and Color3.fromRGB(160, 0, 0) or Color3.fromRGB(45, 45, 45)
	toggle.Text = ""
	toggle.Parent = frame
	Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 16, 0, 16)
	circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
	circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	circle.BorderSizePixel = 0
	circle.Parent = toggle
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local state = default
	connect(toggle.MouseButton1Click, function()
		state = not state
		local goalPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		local goalColor = state and Color3.fromRGB(160, 0, 0) or Color3.fromRGB(45, 45, 45)
		Services.TweenService:Create(circle, TweenInfo.new(0.15), {Position = goalPos}):Play()
		Services.TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundColor3 = goalColor}):Play()
		local ok, err = xpcall(function()
			callback(state)
		end, debug.traceback)
		if not ok then warn("[ESP Rainbow Deluxe] Toggle error: " .. tostring(err)) end
	end)
end

local function makeButton(parent, name, callback)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(255, 80, 80)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local s = Instance.new("UIStroke", btn)
	s.Color = Color3.fromRGB(120, 0, 0)
	s.Thickness = 1

	connect(btn.MouseButton1Click, function()
		local ok, err = xpcall(function()
			callback()
		end, debug.traceback)
		if not ok then warn("[ESP Rainbow Deluxe] Button error: " .. tostring(err)) end
	end)
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
local teamBtn
teamBtn = makeButton(right, "Mode: " .. getTeamModeText(), function()
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

connect(Services.UserInputService.InputBegan, function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		mainFrame.Visible = not mainFrame.Visible
	end
end)

local function cleanPlayer(player)
	pcall(function()
		if PlayerData.Tracers[player] then PlayerData.Tracers[player]:Remove() PlayerData.Tracers[player] = nil end
		if PlayerData.InfoTexts[player] then
			PlayerData.InfoTexts[player].gui:Destroy()
			PlayerData.InfoTexts[player] = nil
		end
		if PlayerData.Hitboxes[player] then PlayerData.Hitboxes[player]:Remove() PlayerData.Hitboxes[player] = nil end
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
