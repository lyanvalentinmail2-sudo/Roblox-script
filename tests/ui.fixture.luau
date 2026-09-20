-- Doble estructural de GUI. No simula renderizado, layout automático ni Roblox real.
-- Reutiliza únicamente scheduler, signal y check del fixture base.
task.defer = task.spawn
local baseSignal = signal
signal = function()
	local event = baseSignal()
	function event:Once(callback)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end
	return event
end
local function vector(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, {
		__index = function(t, key)
			if key == "Magnitude" then
				return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
			end
		end,
		__sub = function(a, b)
			return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
		end,
	})
end
local Vector2 = { new = vector }
Vector3 = { new = vector }
local UDim = {
	new = function(scale, offset)
		return { Scale = scale or 0, Offset = offset or 0 }
	end,
}
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
	end,
	fromScale = function(x, y)
		return { X = UDim.new(x, 0), Y = UDim.new(y, 0) }
	end,
	fromOffset = function(x, y)
		return { X = UDim.new(0, x), Y = UDim.new(0, y) }
	end,
}
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
local ColorSequence = {
	new = function(...)
		return { ... }
	end,
}
local NumberSequence = {
	new = function(value)
		return value
	end,
}
local NumberSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}
local TweenInfo = {
	new = function(duration)
		return { duration = duration }
	end,
}
local function enum(prefix)
	return setmetatable({}, {
		__index = function(t, key)
			local value = enum(prefix .. "." .. key)
			rawset(t, key, value)
			return value
		end,
	})
end
Enum = enum("Enum")
local viewport = vector(390, 740)
local instances = {}
local methods = {}
local eventNames = {
	Activated = true,
	InputBegan = true,
	MouseEnter = true,
	MouseLeave = true,
	FocusLost = true,
	Destroying = true,
}
Instance = {}
local function absoluteSize(object)
	if object._properties.Name == "PlayerGui" then
		return viewport
	end
	local parent = object._properties.Parent
	local parentSize = parent and parent.AbsoluteSize or vector(390, 740)
	local size = object._properties.Size or UDim2.fromScale(1, 1)
	return vector(parentSize.X * size.X.Scale + size.X.Offset, parentSize.Y * size.Y.Scale + size.Y.Offset)
end
local instanceMeta = {
	__index = function(object, key)
		if methods[key] then
			return methods[key]
		end
		if key == "AbsoluteSize" then
			return absoluteSize(object)
		end
		if key == "AbsolutePosition" then
			local parent = object.Parent
			local origin = parent and parent.AbsolutePosition or vector(0, 0)
			local size = parent and parent.AbsoluteSize or vector(390, 740)
			local position = object.Position or UDim2.new()
			return vector(
				origin.X + size.X * position.X.Scale + position.X.Offset,
				origin.Y + size.Y * position.Y.Scale + position.Y.Offset
			)
		end
		if eventNames[key] then
			object._events[key] = object._events[key] or signal()
			return object._events[key]
		end
		return object._properties[key]
	end,
	__newindex = function(object, key, value)
		local previous = object._properties[key]
		if key == "Parent" and previous ~= value then
			if previous then
				local index = table.find(previous._children, object)
				if index then
					table.remove(previous._children, index)
				end
			end
			if value then
				table.insert(value._children, object)
			end
		end
		object._properties[key] = value
		if previous ~= value and object._propertiesSignals[key] then
			object._propertiesSignals[key]:Fire()
		end
	end,
}
function Instance.new(class)
	local object = setmetatable({
		_properties = {
			ClassName = class,
			Name = class,
			Visible = true,
			Position = UDim2.new(),
			Text = "",
			Scale = 1,
			GroupTransparency = 0,
		},
		_children = {},
		_events = {},
		_attributes = {},
		_propertiesSignals = {},
		_destroyed = false,
	}, instanceMeta)
	table.insert(instances, object)
	return object
end
function methods:GetChildren()
	return table.clone(self._children)
end
function methods:GetDescendants()
	local descendants = {}
	for _, child in ipairs(self._children) do
		table.insert(descendants, child)
		for _, descendant in ipairs(child:GetDescendants()) do
			table.insert(descendants, descendant)
		end
	end
	return descendants
end
function methods:FindFirstChild(name)
	for _, child in ipairs(self._children) do
		if child.Name == name then
			return child
		end
	end
end
function methods:WaitForChild(name)
	return assert(self:FindFirstChild(name), name)
end
function methods:FindFirstChildOfClass(class)
	for _, child in ipairs(self._children) do
		if child.ClassName == class then
			return child
		end
	end
end
function methods:IsA(class)
	return self.ClassName == class or (class == "GuiObject" and not self.ClassName:match("^UI"))
end
function methods:GetPropertyChangedSignal(property)
	self._propertiesSignals[property] = self._propertiesSignals[property] or signal()
	return self._propertiesSignals[property]
end
function methods:SetAttribute(key, value)
	self._attributes[key] = value
end
function methods:GetAttribute(key)
	return self._attributes[key]
end
function methods:IsFocused()
	return false
end
function methods:ReleaseFocus() end
function methods:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self.Destroying:Fire()
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
	self.Parent = nil
end
local playerGui = Instance.new("PlayerGui")
local localPlayer = {
	CharacterAdded = signal(),
	WaitForChild = function()
		return playerGui
	end,
}
local requests = {}
local uiState =
	{ equipped = {}, speed = 1, locked = false, paused = false, loading = false, settingsRevision = 0 }
local remote = { OnClientEvent = signal() }
function remote:FireServer(request)
	table.insert(requests, request)
	if request.action == "Stop" then
		uiState.active = nil
	end
	if request.action == "Settings" then
		uiState.speed, uiState.locked, uiState.paused = request.speed, request.locked, request.paused
		uiState.settingsRevision = request.settingsRevision
	end
	self.OnClientEvent:Fire(table.clone(uiState))
end
local sharedModules = {
	Config = Config,
	Validation = Validation,
	Favorites = Favorites,
	HubState = HubState,
	HubLayout = HubLayout,
	EmoteDetails = EmoteDetails,
	Request = remote,
}
local tweenCount = 0
local liveTweens = 0
local jsonStore = {}
local input = {
	InputBegan = signal(),
	InputChanged = signal(),
	InputEnded = signal(),
	GetFocusedTextBox = function()
		return nil
	end,
}
local catalogCalls = 0
local officialPrompts = {}
local market = { PromptPurchaseFinished = signal(), owned = false, forSale = true }
function market:GetProductInfoAsync(id)
	return {
		AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
		Name = id == 123 and "Dance" or "Wave",
		IsForSale = self.forSale,
		PriceInRobux = 50,
		Creator = { Name = "Creator", CreatorTargetId = 55, CreatorType = "User" },
	}
end
function market:PlayerOwnsAssetAsync()
	return self.owned
end
function market:PromptPurchase(player, id)
	table.insert(officialPrompts, { player = player, id = id })
end
local uiServices = {
	MarketplaceService = market,
	Players = { LocalPlayer = localPlayer },
	ReplicatedStorage = {
		WaitForChild = function()
			return {
				WaitForChild = function(_, name)
					return assert(sharedModules[name], name)
				end,
			}
		end,
	},
	AvatarEditorService = {
		SearchCatalogAsync = function()
			catalogCalls = catalogCalls + 1
			return {
				IsFinished = true,
				GetCurrentPage = function()
					return {
						{
							Id = 123,
							Name = "Dance",
							CreatorName = "Creator",
							CreatorTargetId = 55,
							CreatorType = "User",
						},
						{
							Id = 124,
							Name = "Wave",
							CreatorName = "Roblox",
							CreatorTargetId = 1,
							CreatorType = "User",
						},
					}
				end,
			}
		end,
	},
	UserInputService = input,
	TweenService = {
		Create = function(_, object, info, properties)
			local animation = { Completed = signal(), playing = false, cancelled = false }
			function animation:Play()
				self.playing = true
				liveTweens = liveTweens + 1
				tweenCount = tweenCount + 1
				task.delay(info.duration, function()
					if self.playing then
						self.playing = false
						liveTweens = liveTweens - 1
						for key, value in pairs(properties) do
							object[key] = value
						end
						self.Completed:Fire()
					end
				end)
			end
			function animation:Cancel()
				if self.playing then
					self.playing = false
					self.cancelled = true
					liveTweens = liveTweens - 1
					self.Completed:Fire()
				end
			end
			return animation
		end,
	},
	HttpService = {
		JSONEncode = function(_, value)
			local key = "json_" .. tostring(#jsonStore + 1)
			table.insert(jsonStore, value)
			jsonStore[key] = value
			return key
		end,
		JSONDecode = function(_, value)
			return assert(jsonStore[value])
		end,
	},
}
game = {
	GetService = function(_, name)
		return assert(uiServices[name], name)
	end,
}
local CatalogSearchParams = {
	new = function()
		return {}
	end,
}
local function find(root, name)
	if root.Name == name then
		return root
	end
	for _, object in ipairs(root:GetDescendants()) do
		if object.Name == name then
			return object
		end
	end
	error("Falta GUI: " .. name)
end
local function click(object, elapsed)
	object.Activated:Fire()
	advance(elapsed or 0)
end
