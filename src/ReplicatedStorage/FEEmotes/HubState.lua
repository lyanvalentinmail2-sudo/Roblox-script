-- Tickets de transición: un tween antiguo nunca debe ocultar una ventana reabierta.
local HubState = {}
function HubState.new()
	local state = { mode = "minimized", revision = 0 }
	function state:set(mode)
		if self.mode == "destroyed" or (mode ~= "open" and mode ~= "minimized" and mode ~= "closed") then
			return nil
		end
		self.mode = mode
		self.revision = self.revision + 1
		return self.revision
	end
	function state:current(ticket)
		return self.mode ~= "destroyed" and self.revision == ticket
	end
	function state:destroy()
		self.mode = "destroyed"
		self.revision = self.revision + 1
	end
	return state
end
return HubState
