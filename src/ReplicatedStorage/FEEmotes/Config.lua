-- Configuración compartida. Los permisos se validan siempre en el servidor.
return {
	Title = "FE Emotes",
	MinSpeed = 0.25,
	MaxSpeed = 3,
	SpeedStep = 0.25,
	MaxEquipped = 8,
	MaxCacheEntries = 128,
	LoadTimeout = 15,
	-- Catálogo inicial: IDs de emote del catálogo, NO IDs internos de animación.
	Featured = {
		{ Id = 3576686446, Name = "Hello", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576823880, Name = "Point2", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576968026, Name = "Shrug", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576747102, Name = "Applaud", Creator = "Roblox", IsRoblox = true },
		{ Id = 3716636630, Name = "Tilt", Creator = "Roblox", IsRoblox = true },
		{ Id = 3360689775, Name = "Salute", Creator = "Roblox", IsRoblox = true },
	},
}
