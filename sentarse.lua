--[[
	Sentarse (solo eso)
	Executor: Delta
	Uso: pega este código en Delta y dale Execute.
	Efecto: tu personaje se sienta una vez. Nada más.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Espera a que el personaje y su Humanoid existan
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Sentarse
humanoid.Sit = true
