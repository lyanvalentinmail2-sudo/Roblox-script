--[[
    Arnés de pruebas de EmoteGlass.lua.

    Corre el script REAL (no una copia) sobre un API de Roblox simulado, dentro
    de un VM Lua 5.1 (el mismo dialecto que usa Roblox). Verifica: catalogo,
    codec JSON, filtros, motor de emotes (poner/despegar/velocidad/bloqueo al
    moverte), favoritos persistidos, rejilla virtual y limpieza al re-ejecutar.

    Uso:  lua5.1 tests/harness.lua        (o: tools/run_tests.py)
]]

------------------------------------------------------------------ helpers ---
local failures, checks = {}, 0

local function check(name, cond, extra)
    checks = checks + 1
    if cond then
        print(string.format("  ok   %s", name))
    else
        print(string.format("  FAIL %s%s", name, extra and ("  -> " .. tostring(extra)) or ""))
        failures[#failures + 1] = name
    end
end

local function section(t) print("\n== " .. t .. " ==") end

local STAR_OFF_EXPECTED = "\226\152\134"   -- estrella vacia
local STAR_ON_EXPECTED = "\226\152\133"    -- estrella rellena

local function tableShallowCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- las senales del mock viven en inst._signals; esto las devuelve de verdad
local function sigOf(inst, name)
    local sg = rawget(inst, "_signals")
    return sg and sg[name]
end
local function click(inst, button)
    local sg = sigOf(inst, button or "MouseButton1Click")
    assert(sg, "sin senal " .. tostring(button) .. " en " .. tostring(inst.ClassName))
    sg:Fire()
end

-------------------------------------------------------------- mock roblox ---
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(fn)
    local sig = self
    sig.handlers[#sig.handlers + 1] = fn
    local conn = { Connected = true }
    function conn:Disconnect()
        conn.Connected = false
        for i, h in ipairs(sig.handlers) do
            if h == fn then table.remove(sig.handlers, i) break end
        end
    end
    return conn
end
function Signal:Fire(...)
    for _, h in ipairs(self.handlers) do
        local ok, err = pcall(h, ...)
        if not ok then print("  [handler error] " .. tostring(err)) end
    end
end
Signal.connect = Signal.Connect
Signal.wait = function() error("Signal:Wait no soportado en el arnes") end

local Enum = setmetatable({}, { __index = function(t, k)
    local cat = setmetatable({}, { __index = function(_, kk) return kk end })
    rawset(t, k, cat)
    return cat
end })

local UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
UDim.fromOffset = function(_, o) return UDim.new(0, o) end
UDim.fromScale = function(s, _) return UDim.new(s, 0) end

local UDim2 = {}
UDim2.new = function(sx, ox, sy, oy)
    return { X = UDim.new(sx or 0, ox or 0), Y = UDim.new(sy or 0, oy or 0) }
end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end

-- en Roblox Vector2/Vector3 son tablas con .new (no funciones)
local Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
local Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
local V2, V3 = Vector2.new, Vector3.new
local Color3 = {
    new = function(r, g, b) return { R = r, G = g, B = b } end,
    fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, _rgb = { r, g, b } } end,
}
local Rect = { new = function(a, b, c, d) return { a, b, c, d } end }
local TweenInfo = { new = function(t, s, d) return { Time = t, Style = s, Dir = d } end }

---------------------------------------------------------------- instance ---
local Instance = {}
local allInstances = {}

function Instance.new(class)
    local inst = {
        ClassName = class, Name = class, Parent = nil, _children = {},
        _props = {}, _signals = {}, Visible = true, Enabled = true, Text = "",
        IsPlaying = false, TimePosition = 0, Looped = false, Health = 100,
    }
    local props, signals, children = inst._props, inst._signals, inst._children
    props.AbsoluteSize = V2(300, 200)
    props.AbsolutePosition = V2(0, 0)
    props.CanvasPosition = V2(0, 0)
    props.CanvasSize = UDim2.new(0, 0, 0, 0)
    allInstances[#allInstances + 1] = inst

    local api = {}
    inst._api = api

    function api:FindFirstChild(name)
        for _, c in ipairs(children) do
            if c.Name == name and not rawget(c, "_destroyed") then return c end
        end
        return nil
    end

    function api:FindFirstChildOfClass(cls)
        for _, c in ipairs(children) do
            if c.ClassName == cls and not rawget(c, "_destroyed") then return c end
        end
        return nil
    end

    function api:GetChildren()
        local out = {}
        for _, c in ipairs(children) do
            if not rawget(c, "_destroyed") then out[#out + 1] = c end
        end
        return out
    end

    function api:GetDescendants()
        local out = {}
        local function walk(node)
            for _, c in ipairs(node:GetChildren()) do
                out[#out + 1] = c
                walk(c)
            end
        end
        walk(inst)
        return out
    end

    function api:IsA(cls) return inst.ClassName == cls end

    function api:GetPropertyChangedSignal(prop)
        local key = "prop_" .. tostring(prop)
        if not signals[key] then signals[key] = Signal.new() end
        return signals[key]
    end

    function api:Destroy()
        rawset(inst, "_destroyed", true)
        local par = rawget(inst, "Parent")
        if par and rawget(par, "_children") then
            for i, c in ipairs(par._children) do
                if c == inst then table.remove(par._children, i) break end
            end
        end
        inst.Parent = nil
        for _, c in ipairs(api:GetChildren()) do c:Destroy() end
    end

    function api:Clone()
        local c = Instance.new(inst.ClassName)
        c.Name = inst.Name
        return c
    end

    function api:ClearAllChildren()
        for _, c in ipairs(api:GetChildren()) do c:Destroy() end
    end

    setmetatable(inst, {
        __index = function(_, key)
            if key == "Parent" then return rawget(inst, "Parent") end
            if props[key] ~= nil then return props[key] end
            if api[key] ~= nil then return api[key] end
            local sig = signals[key]
            if not sig then
                sig = Signal.new()
                signals[key] = sig
            end
            return sig
        end,
        __newindex = function(_, key, value)
            if key == "Parent" then
                local old = inst.Parent
                if old then
                    for i, c in ipairs(old._children) do
                        if c == inst then table.remove(old._children, i) break end
                    end
                end
                rawset(inst, "Parent", value)
                if value then
                    if not rawget(value, "_children") then rawset(value, "_children", {}) end
                    local ch = rawget(value, "_children")
                    ch[#ch + 1] = inst
                end
                return
            end
            props[key] = value
            local sig = signals["prop_" .. tostring(key)]
            if sig then sig:Fire(key) end
        end,
    })

    return inst
end

--------------------------------------------------------- mock humanoid/rig ---
local Track = {}
Track.__index = Track
function Track.new(anim)
    return setmetatable({
        Animation = anim, IsPlaying = false, TimePosition = 0, Looped = false,
        Priority = nil, _stopped = 0, _plays = 0, _speeds = {},
    }, Track)
end
function Track:Play(fade, weight, speed)
    self.IsPlaying = true
    self._plays = self._plays + 1
    self._speeds[#self._speeds + 1] = speed
    return true
end
function Track:Stop(f) self.IsPlaying = false self._stopped = self._stopped + 1 self._fade = f end
function Track:AdjustSpeed(s) self._speed = s end
function Track:Destroy() self._destroyed = true end

local Humanoid = setmetatable({ ClassName = "Humanoid", Health = 100, tracks = {} }, {
    __index = function(self, k)
        if k == "LoadAnimation" then
            return function(_, anim)
                local t = Track.new(anim)
                self.tracks[#self.tracks + 1] = t
                return t
            end
        end
        if rawget(self, k) ~= nil then return rawget(self, k) end
        if not self._sig then self._sig = {} end
        if not self._sig[k] then self._sig[k] = Signal.new() end
        return self._sig[k]
    end,
    __newindex = function(self, k, v) rawset(self, k, v) end,
})

local function mockCharacter()
    local char = Instance.new("Model")
    char.Name = "Char"
    char._humanoid = Humanoid
    function char:FindFirstChildOfClass(class)
        if class == "Humanoid" then return Humanoid end
        return nil
    end
    function char:FindFirstChild(name)
        if name == "Humanoid" then return Humanoid end
        if name == "Torso" then return nil end       -- R15 (sin Torso)
        if name == "UpperTorso" then return Instance.new("Part") end
        return nil
    end
    return char
end

local CharacterAdded = Signal.new()
local playerGui
local player = {
    Name = "Tester", UserId = 1, Character = mockCharacter(),
    CharacterAdded = CharacterAdded,
}
player.WaitForChild = function(_, n) if n == "PlayerGui" then return playerGui end return nil end

--------------------------------------------------------------- mock services ---
local taskQueue = {}
local cancelled = {}
local task = {
    delay = function(_, f)
        local id = #taskQueue + 1
        taskQueue[id] = f
        return id
    end,
    wait = function() return 0 end,
    spawn = function(f) f() end,
    defer = function(f) f() end,
    cancel = function(id) cancelled[id] = true end,
}
local function flushTasks()
    local q = taskQueue
    taskQueue = {}
    for id, f in ipairs(q) do
        if not cancelled[id] then
            local ok, err = pcall(f)
            if not ok then print("  [task error] " .. tostring(err)) end
        end
    end
end

local purchases = {}
local coreGuiCalls = {}
local files = {}

local RenderStepped = Signal.new()
local InputBegan = Signal.new()
local InputEnded = Signal.new()

local camera = Instance.new("Camera")
camera.ViewportSize = V2(360, 640)

local workspace = Instance.new("Workspace")
workspace.CurrentCamera = camera
workspace._props.CurrentCamera = camera

playerGui = Instance.new("PlayerGui")

local services = {
    Players = { LocalPlayer = player, PlayerAdded = Signal.new() },
    UserInputService = {
        TouchEnabled = true, InputBegan = InputBegan, InputEnded = InputEnded,
        TextBoxReleased = Signal.new(),
    },
    RunService = { RenderStepped = RenderStepped, Heartbeat = Signal.new(), IsClient = function() return true end },
    TweenService = { Create = function(_, obj, info, props)
        return { Play = function() for k, v in pairs(props) do obj[k] = v end end }
    end },
    MarketplaceService = { PromptPurchase = function(_, who, id) purchases[#purchases + 1] = id return true end },
    StarterGui = { SetCoreGuiEnabled = function(_, t, v) coreGuiCalls[#coreGuiCalls + 1] = { t, v } return true end },
    HttpService = { GenerateGUID = function() return "guid" end },
    CoreGui = Instance.new("CoreGui"),
}

local gameObj = {
    GetService = function(_, n)
        if not services[n] then services[n] = { Name = n } end
        return services[n]
    end,
}

local writeCount = 0
local env = {}
for k, v in pairs({
    game = gameObj, workspace = workspace, Instance = Instance,
    UDim = UDim, UDim2 = UDim2, Vector2 = Vector2, Vector3 = Vector3, Color3 = Color3,
    Rect = Rect, TweenInfo = TweenInfo, Enum = Enum, task = task,
    tick = function() return 0 end, wait = function() return 0 end,
    spawn = function(f) f() end, delay = function(_, f) f() end,
    print = print, warn = function() end, typeof = function(v) return type(v) end,
    getfenv = function() return env end,
    writefile = function(path, content) files[path] = content writeCount = writeCount + 1 return true end,
    readfile = function(path)
        if files[path] then return files[path] end
        error("archivo no existe: " .. path)
    end,
    isfile = function(path) return files[path] ~= nil end,
    makefolder = function() return true end,
    setclipboard = function(s) env.__clip = s return true end,
}) do env[k] = v end
setmetatable(env, { __index = _G })

------------------------------------------------------------------ ejecutar ---
local SCRIPT = arg and arg[1] or "EmoteGlass.lua"
local src = assert(io.open(SCRIPT, "r")):read("*a")

local chunk, loadErr = loadstring(src, "EmoteGlass.lua")
if not chunk then
    print("FALLO DE SINTAXIS: " .. tostring(loadErr))
    os.exit(1)
end
setfenv(chunk, env)   -- el script corre con el API simulado como entorno

local ok, API = pcall(chunk)
if not ok then
    print("FALLO AL EJECUTAR EL SCRIPT: " .. tostring(API))
    os.exit(1)
end
if type(API) ~= "table" then
    print("El script no devolvio su API")
    os.exit(1)
end

print("EmoteGlass cargado (version " .. tostring(API.Version) .. ") sobre Lua " .. _VERSION)

------------------------------------------------------------- 1. catalogo ---
section("Catalogo")
local total = #API.Emotes
check("catalogo con emotes", total > 100, total)
local nUGC, nFree, nClassic, nRoblox = 0, 0, 0, 0
local seenIds = {}
local dupes = 0
for _, e in ipairs(API.Emotes) do
    if e.ugc then nUGC = nUGC + 1 end
    if e.free then nFree = nFree + 1 end
    if e.cat == "C" then nClassic = nClassic + 1 end
    if e.cat == "R" then nRoblox = nRoblox + 1 end
    if seenIds[e.id] then dupes = dupes + 1 end
    seenIds[e.id] = true
    if type(e.name) ~= "string" or e.name == "" then dupes = dupes + 1000 end
end
check("hay emotes UGC", nUGC > 100, nUGC)
check("hay emotes de Roblox (no UGC)", nRoblox == 7, nRoblox)
check("hay clasicos /e", nClassic == 7, nClassic)
check("hay emotes gratis", nFree == 14, nFree)
check("sin IDs repetidos ni nombres vacios", dupes == 0, dupes)

local fashionable = API.ById(3576745472)
check("busca por ID conocido (Fashionable)", fashionable ~= nil and fashionable.name == "Fashionable",
    fashionable and fashionable.name)
check("precio correcto (750 R$)", fashionable and fashionable.price == 750, fashionable and fashionable.price)
check("texto de precio", fashionable and API.Emotes and true)
local shrink = API.ById("3576968026")
check("busca por ID en texto (Shrug)", shrink ~= nil and shrink.name == "Shrug" and shrink.free,
    shrink and shrink.name)
check("ID inexistente -> nil", API.ById(1) == nil)

--------------------------------------------------------------- 2. json ---
section("Codec JSON")
local sample = { favs = { "111", "222" }, speed = 1.25, keepMove = true, loop = false, pos = { 12, 34 } }
local encoded = API.Json.encode(sample, "\t")
check("encode produce texto", type(encoded) == "string" and #encoded > 10)
local decoded = API.Json.decode(encoded)
check("roundtrip: speed", decoded and decoded.speed == 1.25, decoded and decoded.speed)
check("roundtrip: keepMove", decoded and decoded.keepMove == true)
check("roundtrip: loop false", decoded and decoded.loop == false)
check("roundtrip: favs[2]", decoded and decoded.favs and decoded.favs[2] == "222",
    decoded and decoded.favs and decoded.favs[2])
check("roundtrip: pos[1]", decoded and decoded.pos and decoded.pos[1] == 12)
check("decode de basura -> nil", API.Json.decode("{roto") == nil)
check("decode de vacio -> nil", API.Json.decode("") == nil)
check("encode/decode con comillas y saltos", (function()
    local o = { k = 'di"ce\nhola' }
    local d = API.Json.decode(API.Json.encode(o))
    return d ~= nil and d.k == 'di"ce\nhola'
end)())

------------------------------------------------------------ 3. filtros ---
section("Filtros y busqueda")
local all = API.Filter("all", "")
local ugc = API.Filter("ugc", "")
local rbx = API.Filter("rbx", "")
local free = API.Filter("free", "")
check("pestana Todos = catalogo", #all == total, #all .. " vs " .. total)
check("pestana UGC", #ugc == nUGC, #ugc)
check("pestana Roblox (oficial + clasico)", #rbx == 14, #rbx)
check("pestana Gratis", #free == nFree, #free)
check("buscar por nombre 'twice'", #API.Filter("all", "twice") >= 4, #API.Filter("all", "twice"))
check("buscar por ID parcial", #API.Filter("all", "507770239") == 1)
check("buscar sin resultados", #API.Filter("all", "zzzz-no-existe") == 0)
check("busqueda ignora mayusculas", #API.Filter("all", "FLOSS") == 1)
check("favoritos empieza vacio", #API.Filter("fav", "") == 0)

--------------------------------------------------------- 4. motor: poner ---
section("Motor de emotes")
local e = API.ById(3576745472)
local okPlay, msg = API.Engine.play(e)
check("poner emote", okPlay == true, msg)
local track = API.Engine.track
check("track creado", track ~= nil)
check("AnimationId correcto", track and track.Animation.AnimationId == "rbxassetid://3576745472",
    track and track.Animation.AnimationId)
check("prioridad Action", track and track.Priority == "Action", track and track.Priority)
check("esta sonando", track ~= nil and track.IsPlaying == true)
check("Engine.playing", API.Engine.playing == true)
check("isPlaying(emote)", API.Engine.isPlaying(e) == true)

-- el script Animate del juego corta el emote al moverte
track.IsPlaying = false
RenderStepped:Fire(0.016)
check("sin bloqueo: el emote se corta al moverte", API.Engine.playing == false)

API.Engine.play(e)
API.Engine.setKeepMove(true)
API.Engine.track.IsPlaying = false
RenderStepped:Fire(0.016)
check("con bloqueo: el emote sigue al moverte", API.Engine.track ~= nil and API.Engine.track.IsPlaying == true)
check("keepMove guardado en ajustes", API.Store.data.keepMove == true)
API.Engine.setKeepMove(false)

-- velocidad
API.Engine.setSpeed(2.5)
API.Engine.play(e)
local t2 = API.Engine.track
check("velocidad aplicada al reproducir", t2._speeds[#t2._speeds] == 2.5, t2._speeds[#t2._speeds])
check("velocidad guardada", API.Store.data.speed == 2.5)
t2.IsPlaying = false
RenderStepped:Fire(0.016)

-- bucle: una animacion que no loopea termina y se libera
API.Engine.setLoop(false)
API.Engine.play(e)
local t3 = API.Engine.track
check("looped en false cuando se apaga el bucle", t3.Looped == false)
t3.TimePosition = 1.4
RenderStepped:Fire(0.016)
t3.TimePosition = 0.0
RenderStepped:Fire(0.016)
check("emote no-bucle se libera al terminar", API.Engine.playing == false)
API.Engine.setLoop(true)

-- despegar
API.Engine.play(e)
API.Engine.stop()
check("despegar limpia el track", API.Engine.track == nil and API.Engine.playing == false)

-- compra
purchases = {}
local okBuy = API.Engine.buy(API.ById(3823158750))
check("comprar emote de pago abre la tienda", okBuy == true and purchases[1] == 3823158750, purchases[1])
purchases = {}
local okFree, msgFree = API.Engine.buy(API.ById(3576968026))
check("comprar uno gratis no abre tienda", okFree == false and #purchases == 0, msgFree)

------------------------------------------------------- 5. favoritos/archivo ---
section("Favoritos y guardado")
local before = writeCount
local on = API.ToggleFav("3576745472")
check("marcar favorito", on == true)
check("favorito en el filtro", #API.Filter("fav", "") == 1)
check("se escribio el archivo", writeCount > before)
check("archivo guardado en la ruta esperada", files["EmoteGlass/config.json"] ~= nil)
local saved = API.Json.decode(files["EmoteGlass/config.json"])
check("favorito persistido en JSON", saved and saved.favs and saved.favs[1] == "3576745472",
    saved and saved.favs and saved.favs[1])
local off = API.ToggleFav("3576745472")
check("quitar favorito", off == false)
check("filtro de favoritos vacio otra vez", #API.Filter("fav", "") == 0)
API.ToggleFav("3576745472")

-------------------------------------------------------------- 6. GUI ---
section("GUI (construccion y rejilla)")
local G = API.Gui
check("ScreenGui creado", G.gui ~= nil and G.gui.ClassName == "ScreenGui")
check("ventana con tamano compacto", G.frame.Size.X.Offset >= 268 and G.frame.Size.X.Offset <= 392,
    G.frame.Size.X.Offset)
check("ventana con alto suficiente", G.frame.Size.Y.Offset >= 332, G.frame.Size.Y.Offset)
check("blur activo", (function()
    for _, c in ipairs(camera:GetChildren()) do
        if c.ClassName == "BlurEffect" and c.Enabled then return true end
    end
    return false
end)())
check("rueda de emotes del core desactivada", #coreGuiCalls == 1 and coreGuiCalls[1][2] == false)

local function tileFrames()
    local out = {}
    for _, c in ipairs(G.scroll:GetChildren()) do
        if c.ClassName == "Frame" then out[#out + 1] = c end
    end
    return out
end
local tiles = tileFrames()
check("rejilla pinto baldosas", #tiles > 0, #tiles)
check("baldosas dentro del lienzo", (function()
    for _, t in ipairs(tiles) do
        if t.Position.Y.Offset > G.scroll.CanvasSize.Y.Offset then return false end
    end
    return true
end)())

-- la primera baldosa debe ser el primer emote de la lista
local firstTile
for _, t in ipairs(tiles) do
    if t.Position.Y.Offset == 8 and t.Position.X.Offset == 8 then firstTile = t end
end
check("primera baldosa arriba-izquierda", firstTile ~= nil)
if firstTile then
    local nameLabel = firstTile:FindFirstChild("Name")
    check("baldosa muestra el nombre del emote",
        nameLabel ~= nil and nameLabel.Text == API.Emotes[1].name, nameLabel and nameLabel.Text)
    local priceLabel = firstTile:FindFirstChild("Price")
    check("baldosa muestra el precio debajo", priceLabel ~= nil and priceLabel.Text ~= "",
        priceLabel and priceLabel.Text)
    local star = firstTile:FindFirstChild("Star")
    check("estrellita dentro del emote", star ~= nil and (star.Text:find("\226\152") ~= nil),
        star and star.Text)
end

-- barra de detalle
API.UI.showDetail(API.ById(3823158750))
local detail = G.detail
check("detalle visible al seleccionar", detail.Visible == true)
local detailName = detail:FindFirstChild("detailName") or (function()
    for _, c in ipairs(detail:GetChildren()) do
        if c.ClassName == "TextLabel" and c.Text == "Godlike" then return c end
    end
end)()
check("detalle muestra el nombre", detailName ~= nil, detailName and detailName.Text)
local buyBtn = detail:FindFirstChild("Buy")
check("boton Comprar con el precio", buyBtn ~= nil and buyBtn.Text == "Comprar 80 R$", buyBtn and buyBtn.Text)
local offBtn = detail:FindFirstChild("Off")
check("boton Despegar presente", offBtn ~= nil and offBtn.Text == "Despegar", offBtn and offBtn.Text)

API.UI.showDetail(API.ById(3576968026))
local buyFree = detail:FindFirstChild("Buy")
check("emote gratis: el boton no cobra", buyFree.Text == "Es gratis", buyFree.Text)

-- minimizar / restaurar
API.UI.setMinimized(true)
check("minimizar oculta la ventana", G.frame.Visible == false and G.ball.Visible == true)
API.UI.setMinimized(false)
check("restaurar muestra la ventana", G.frame.Visible == true and G.ball.Visible == false)

-- ajustes
API.UI.toggleSettings(true)
check("panel de ajustes se abre", G.settings.Position.Y.Offset == -138, G.settings.Position.Y.Offset)
API.UI.toggleSettings(false)

-- scroll virtual: bajar mucho no debe crear cientos de baldosas
G.scroll.CanvasPosition = V2(0, 2000)
API.UI.refreshGrid()
local afterScroll = #tileFrames()
check("scroll no dispara el numero de baldosas", afterScroll < 40, afterScroll)
local esperado = API.Filter("all", "")[15]
local encontrado
for _, t in ipairs(tileFrames()) do
    local nm = t:FindFirstChild("Name")
    if nm and nm.Text == esperado.name then encontrado = t end
end
check("tras el scroll pinta el emote que toca", encontrado ~= nil, esperado.name)
check("la baldosa nueva muestra su precio", encontrado ~= nil
    and encontrado:FindFirstChild("Price").Text ~= "", encontrado and encontrado:FindFirstChild("Price").Text)

-- la estrellita de una baldosa marca favorito al pulsarla
for id in pairs(tableShallowCopy(API.Favs)) do API.ToggleFav(id) end   -- empezar de cero
G.scroll.CanvasPosition = V2(0, 0)
API.UI.refreshGrid()
local conFav = tileFrames()[1]
local emoteDeLaBaldosa = conFav:FindFirstChild("Name").Text
click(conFav:FindFirstChild("Star"))
local favs = 0
for _ in pairs(API.Favs) do favs = favs + 1 end
check("la estrellita de la baldosa guarda el favorito", favs == 1, favs .. " (" .. emoteDeLaBaldosa .. ")")
check("la estrella se rellena al marcar", conFav:FindFirstChild("Star").Text == STAR_ON_EXPECTED,
    conFav:FindFirstChild("Star").Text)
click(conFav:FindFirstChild("Star"))
local favs2 = 0
for _ in pairs(API.Favs) do favs2 = favs2 + 1 end
check("segunda pulsacion quita el favorito", favs2 == 0, favs2)
check("la estrella vuelve a vaciarse", conFav:FindFirstChild("Star").Text == STAR_OFF_EXPECTED)

-- tocar el emote (miniatura) lo pone y muestra [Despegar] / [Comprar]
local nombreTocado = conFav:FindFirstChild("Name").Text
click(conFav:FindFirstChild("Thumb"))
check("tocar el emote lo pone", API.Engine.playing == true)
check("tocar el emote abre la barra con los 2 botones", G.detail.Visible == true)
check("la barra muestra el emote tocado", (function()
    for _, c in ipairs(G.detail:GetChildren()) do
        if c.ClassName == "TextLabel" and c.Text == nombreTocado then return true end
    end
    return false
end)(), nombreTocado)
check("el emote tocado queda resaltado", conFav.BackgroundTransparency == 0.72, conFav.BackgroundTransparency)

click(G.detail:FindFirstChild("Off"))
check("el boton Despegar quita el emote", API.Engine.playing == false)
check("lienzo mas alto que la vista", G.scroll.CanvasSize.Y.Offset > G.scroll.AbsoluteSize.Y)

------------------------------------------------------- 7. re-ejecucion ---
section("Re-ejecucion (sin fugas)")
setfenv(chunk, env)
local ok2, API2 = pcall(chunk)
flushTasks()
check("segunda ejecucion sin errores", ok2 == true, API2)
if ok2 then
    local guis = services.CoreGui:GetChildren()
    local count = 0
    for _, c in ipairs(guis) do
        if c.Name == "EmoteGlass" and not rawget(c, "_destroyed") then count = count + 1 end
    end
    check("queda una sola GUI", count == 1, count)
    check("motor anterior apagado", API.Engine.playing == false)
end

---------------------------------------------------------------- resumen ---
print(string.format("\n%d verificaciones, %d fallos", checks, #failures))
if #failures > 0 then
    for _, f in ipairs(failures) do print("  - " .. f) end
    os.exit(1)
end
print("TODO OK")
