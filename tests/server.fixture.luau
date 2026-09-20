-- Dobles mínimos de Roblox: prueban lógica, no replicación/renderizado del motor.
local clock = 0
local queue = {}
local task = {}
local os = {
	clock = function()
		return clock
	end,
}
local function schedule(thread, when, ...)
	table.insert(queue, { thread = thread, when = when, args = { ... } })
end
function task.spawn(fn, ...)
	schedule(coroutine.create(fn), clock, ...)
end
function task.delay(delay, fn)
	schedule(coroutine.create(fn), clock + delay)
end
function task.wait(delay)
	return coroutine.yield(delay or 0.03)
end
local function advance(seconds)
	local target = clock + seconds
	while true do
		local index, soonest = nil, math.huge
		for i, job in ipairs(queue) do
			if job.when < soonest then
				index, soonest = i, job.when
			end
		end
		if not index or soonest > target then
			break
		end
		local job = table.remove(queue, index)
		clock = job.when
		local ok, delay = coroutine.resume(job.thread, table.unpack(job.args))
		assert(ok, delay)
		if coroutine.status(job.thread) ~= "dead" then
			schedule(job.thread, clock + delay)
		end
	end
	clock = target
end
local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(callback)
		local connection = { connected = true }
		function connection:Disconnect()
			self.connected = false
		end
		table.insert(listeners, { connection, callback })
		return connection
	end
	function event:Fire(...)
		for _, entry in ipairs(listeners) do
			if entry[1].connected then
				task.spawn(entry[2], ...)
			end
		end
	end
	return event
end
local Enum = {
	InfoType = { Asset = "Asset" },
	AssetType = { EmoteAnimation = { Value = 61 } },
	HumanoidRigType = { R15 = "R15", R6 = "R6" },
	AnimationPriority = { Action = "Action" },
	HumanoidStateType = { Jumping = "Jumping", Freefall = "Freefall", Swimming = "Swimming" },
}
local Vector3 = {
	new = function(x, y, z)
		return { Magnitude = math.sqrt(x * x + y * y + z * z) }
	end,
}
local fixture =
	{ remote = nil, tracks = {}, snapshots = {}, delay = 0, length = 2, denied = false, reads = 0 }
local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers()
	return {}
end
local shared = {}
function shared:WaitForChild(name)
	return name == "Config" and Config or Validation
end
local services = {
	Players = Players,
	ReplicatedStorage = {
		WaitForChild = function()
			return shared
		end,
	},
	MarketplaceService = {
		GetProductInfoAsync = function(_, id)
			fixture.reads = fixture.reads + 1
			if fixture.delay > 0 then
				task.wait(fixture.delay)
			end
			return {
				Name = "Emote " .. id,
				AssetTypeId = id == 999 and 10 or 61,
				Creator = { Name = "Roblox", CreatorTargetId = 1, CreatorType = "User" },
			}
		end,
	},
	InsertService = {
		LoadAsset = function(_, id)
			if fixture.denied then
				error("Permission denied")
			end
			return {
				FindFirstChildWhichIsA = function()
					return { AnimationId = "rbxassetid://" .. id }
				end,
				Destroy = function() end,
			}
		end,
	},
}
local game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
local require = function(module)
	return module
end
local Instance = {}
function Instance.new(class)
	if class == "RemoteEvent" then
		local remote = { OnServerEvent = signal() }
		function remote:FireClient(player, snapshot)
			fixture.snapshots[player] = snapshot
		end
		fixture.remote = remote
		return remote
	end
	return { Destroy = function() end }
end
local function makePlayer()
	local animator = {}
	function animator:LoadAnimation()
		local track = { Length = fixture.length, Stopped = signal(), destroyed = false, playing = false }
		function track:Play(_, _, speed)
			self.playing = true
			self.speed = speed
		end
		function track:Stop()
			self.playing = false
			self.Stopped:Fire()
		end
		function track:AdjustSpeed(speed)
			self.speed = speed
		end
		function track:Destroy()
			self.destroyed = true
		end
		table.insert(fixture.tracks, track)
		return track
	end
	local humanoid = {
		Health = 100,
		RigType = "R15",
		Running = signal(),
		StateChanged = signal(),
		Died = signal(),
		RootPart = { AssemblyLinearVelocity = { X = 0, Z = 0 } },
		FindFirstChildOfClass = function()
			return animator
		end,
	}
	local character = {
		WaitForChild = function()
			return humanoid
		end,
		FindFirstChildOfClass = function()
			return humanoid
		end,
	}
	local player =
		{ Parent = Players, Character = character, CharacterAdded = signal(), CharacterRemoving = signal() }
	Players.PlayerAdded:Fire(player)
	advance(0)
	return player, humanoid
end
local function send(player, action, id, settings)
	local payload = settings or {}
	payload.action, payload.id = action, id
	fixture.remote.OnServerEvent:Fire(player, payload)
	advance(0)
	return fixture.snapshots[player]
end
local function snapshot(player)
	return fixture.snapshots[player]
end
local function track()
	return fixture.tracks[#fixture.tracks]
end
local assertions = 0
local function check(condition, message)
	assert(condition, message)
	assertions = assertions + 1
end
local warn = function() end -- Los errores esperados no contaminan la salida.
