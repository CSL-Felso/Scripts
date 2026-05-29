local art = [[
  ---  ____ ____  _     
--- / ___/ ___|| |    
---| |   \___ \| |    
---| |___ ___) | |___ 
--- \____|____/|_____|
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local log = game:GetService("TestService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- zoom
local zoom = 8
local minZoom = 4
local maxZoom = 15
local zoomSpeed = 1.5

local enabled = false
local target = nil
local renderConnection = nil
local inputConnection = nil
local diamond = nil
local lastSwitchTime = 0 -- Cooldown para trocar de alvo

-- GUI
local gui = Instance.new("ScreenGui")
gui.Parent = player:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(50,60)
button.Position = UDim2.new(1,-250,0,190)
button.Text = "Lock: ○ T"
button.BackgroundColor3 = Color3.fromRGB(30,30,30)
button.TextColor3 = Color3.new(1,1,1)
button.Font = Enum.Font.GothamBold
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 20)
corner.Parent = button

local function getClosest()
	local closest = nil
	local shortest = math.huge
	local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character then
			local hum = obj:FindFirstChild("Humanoid")
			local hrp = obj:FindFirstChild("HumanoidRootPart")

			if hum and hrp and hum.Health > 0 then
				local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)

				if onScreen then
					local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
					if dist < shortest then
						shortest = dist
						closest = obj
					end
				end
			end
		end
	end

	return closest
end

-- Função para criar a imagem de lock-on no alvo
local function createDiamond(hrp)
	if diamond then
		diamond:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 50, 0, 50)
	bb.Adornee = hrp
	bb.AlwaysOnTop = true
	bb.Parent = player.PlayerGui

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://113520624560741"
	img.ImageColor3 = Color3.fromRGB(255, 255, 255) 
	img.Parent = bb

	diamond = bb
end

local function cleanupConnections()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

local function disable()
	enabled = false
	target = nil
	button.Text = "Lock: ○ T"

	cleanupConnections()
	camera.CameraType = Enum.CameraType.Custom

	if diamond then
		diamond:Destroy()
		diamond = nil
	end

	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = true
		end
	end
end

-- Função para encontrar um novo alvo na direção em que o jogador moveu a câmera
local function switchTarget(deltaInput)
	if tick() - lastSwitchTime < 0.3 then return end -- Cooldown de 0.3s
	if not target then return end

	local currentHrp = target:FindFirstChild("HumanoidRootPart")
	if not currentHrp then return end

	local currentPos, onScreen = camera:WorldToViewportPoint(currentHrp.Position)
	if not onScreen then return end

	local closest = nil
	local shortest = math.huge
	local deltaDir = deltaInput.Unit

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character and obj ~= target then
			local hum = obj:FindFirstChild("Humanoid")
			local hrp = obj:FindFirstChild("HumanoidRootPart")

			if hum and hrp and hum.Health > 0 then
				local pos, isVis = camera:WorldToViewportPoint(hrp.Position)
				if isVis then
					local screenDir = Vector2.new(pos.X - currentPos.X, pos.Y - currentPos.Y)
					if screenDir.Magnitude > 0 then
						local dot = screenDir.Unit:Dot(deltaDir)
						-- Se o personagem está na mesma direção do movimento do mouse/dedo
						if dot > 0.5 then 
							local dist = screenDir.Magnitude
							if dist < shortest then
								shortest = dist
								closest = obj
							end
						end
					end
				end
			end
		end
	end

	if closest then
		target = closest
		createDiamond(closest:FindFirstChild("HumanoidRootPart"))
		lastSwitchTime = tick()
	end
end

local function onInputChanged(input, gameProcessed)
	if gameProcessed then return end

	-- Mouse wheel para o Zoom (PC)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom - input.Position.Z * zoomSpeed, minZoom, maxZoom)
	
	-- Detecta movimento da câmera (Mouse ou Dedo na tela) para trocar de alvo
	elseif enabled and target then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			-- Se o movimento for significativo (evita micro tremores)
			if input.Delta.Magnitude > 15 then 
				switchTarget(Vector2.new(input.Delta.X, input.Delta.Y))
			end
		end
	end
end

local function enable()
	inputConnection = UserInputService.InputChanged:Connect(onInputChanged)

	renderConnection = RunService.RenderStepped:Connect(function()
		if not enabled then return end

		if not target then
			target = getClosest()
			if target then
				local hrp = target:FindFirstChild("HumanoidRootPart")
				if hrp then
					createDiamond(hrp)
				end
			else
				return
			end
		end

		local myChar = player.Character
		if not myChar then
			disable()
			return
		end

		local myHRP = myChar:FindFirstChild("HumanoidRootPart")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		
		-- DESATIVA SE O JOGADOR MORRER
		if not myHRP or not myHum or myHum.Health <= 0 then
			disable()
			return
		end

		local hrp = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChild("Humanoid")

		-- DESATIVA SE O ALVO MORRER
		if not hrp or not hum or hum.Health <= 0 then
			disable() 
			return
		end

		local myPos = myHRP.Position
		local targetPos = hrp.Position
		local look = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)

		if myHum then
			myHum.AutoRotate = false
		end

		-- Rotaciona o personagem instantaneamente
		myHRP.CFrame = CFrame.new(myPos, look)

		camera.CameraType = Enum.CameraType.Scriptable

		-- Calcula posição da câmera
		local dir = (hrp.Position - myHRP.Position)
		local dirUnit = dir.Unit
		local camPos = myHRP.Position - dirUnit * zoom + Vector3.new(0, 3, 0)

		local lookCF = CFrame.new(camPos, hrp.Position)

		-- Fixa a câmera instantaneamente
		camera.CFrame = lookCF
	end)
end

-- Toggle do botão principal
button.MouseButton1Click:Connect(function()
	enabled = not enabled

	if enabled then
		button.Text = "Lock: ● T"
		enable()
	else
		disable()
	end
end)

-- Toggle PC
-- Coloque o código que deve acontecer quando o script LIGAR aqui dentro
local function ativarScript()
    enable()
	log:Message("Log: ENABLE")
end

-- Coloque o código que deve acontecer quando o script DESLIGAR aqui dentro
local function desativarScript()
    disable()
	log:Message("Log: DISABLE")
end

-- Toggle PC corrigido
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Verifica se a tecla pressionada foi o T
    if input.KeyCode == Enum.KeyCode.T then
        enabled = not enabled -- Usamos a variável 'enabled' que já existe no seu script
        
        if enabled then
            button.Text = "Lock: ON"
            enable()
            log:Message("Log: ENABLE")
        else
            button.Text = "Lock: OFF"
            disable()
            log:Message("Log: DISABLE")
        end
    end
end)


-- Teclas para ajustar zoom no teclado (PC)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.KeypadPlus then
		zoom = math.clamp(zoom - 1, minZoom, maxZoom)
	elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
		zoom = math.clamp(zoom + 1, minZoom, maxZoom)
	end
end)


log:Message(art)
