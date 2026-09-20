-- Extiende los dobles compartidos sin simular APIs privilegiadas reales.
local baseNew = Instance.new
fixture.objectsDestroyed = 0
fixture.getObjectsCalls = 0
fixture.noAnimation = false
function Instance.new(class)
	if class == "BindableEvent" then
		local event = signal()
		local binding = { Event = event, destroyed = false }
		function binding:Fire(value)
			if not self.destroyed then
				event:Fire(value)
			end
		end
		function binding:Destroy()
			self.destroyed = true
		end
		return binding
	end
	return baseNew(class)
end
function game:GetObjects(uri)
	fixture.getObjectsCalls = fixture.getObjectsCalls + 1
	if fixture.denied then
		error("GetObjects no disponible")
	end
	local asset = { AnimationId = uri }
	function asset:IsA(class)
		return class == "Animation" and not fixture.noAnimation
	end
	function asset:FindFirstChildWhichIsA()
		return nil
	end
	function asset:Destroy()
		fixture.objectsDestroyed = fixture.objectsDestroyed + 1
	end
	return { asset }
end
local function localClient()
	local player, humanoid = makePlayer()
	local controller = createController(player, Config, Validation)
	local snapshot
	controller.Changed:Connect(function(value)
		snapshot = value
	end)
	advance(0)
	local function dispatch(action, id, settings)
		local payload = settings or {}
		payload.action, payload.id = action, id
		controller:Dispatch(payload)
		advance(0)
		return snapshot
	end
	return {
		controller = controller,
		player = player,
		humanoid = humanoid,
		send = dispatch,
		snapshot = function()
			return snapshot
		end,
	}
end
