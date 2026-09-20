-- Geometría compartida y comprobable sin el motor: ventanas pequeñas, tarjetas 1:1.
local HubLayout = {
	MaxWidth = 400,
	MaxHeight = 560,
	Margin = 12,
	Gap = 6,
}

function HubLayout.window(width, height)
	return math.max(1, math.min(HubLayout.MaxWidth, width - HubLayout.Margin * 2)),
		math.max(1, math.min(HubLayout.MaxHeight, height - HubLayout.Margin * 2))
end

function HubLayout.grid(width, count)
	local columns = width >= 360 and 4 or (width >= 258 and 3 or (width >= 170 and 2 or 1))
	local side = math.max(1, math.floor((width - HubLayout.Gap * (columns - 1)) / columns))
	local rows = math.ceil(math.max(0, count) / columns)
	return columns, side, math.max(0, rows * (side + HubLayout.Gap) - HubLayout.Gap)
end

return HubLayout
