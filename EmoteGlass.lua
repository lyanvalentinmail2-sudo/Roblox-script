--[[
    Emote Glass  ·  GUI de emotes para Delta / executors moviles
    -------------------------------------------------------------
    · Vidrio (blur + translucidez), compacto y pensado para pulgar en telefono.
    · Catalogo: emotes UGC + emotes de Roblox (gratis) + clasicos /e.
    · Favoritos con estrellita dentro de cada emote (se guardan en archivo).
    · Al tocar un emote aparecen [Despegar] y [Comprar], con el precio abajo.
    · Ajustes del emote puesto: velocidad y "no se sale si te mueves".

    Todo es local (client-side): no toca RemoteEvents del juego.
    Nota honesta: en el cliente solo se pueden REPRODUCIR emotes gratis o que
    tu cuenta ya tenga; los UGC de pago se compran con el boton [Comprar].
]]

local EMOTE_GLASS_VERSION = "1.0.0"

------------------------------------------------------------------ services ---
local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")
local StarterGui          = game:GetService("StarterGui")
local HttpService         = game:GetService("HttpService")

local LP = Players.LocalPlayer

---------------------------------------------------------------- executor ---
-- donde viven las funciones del executor: depende del VM/executor, se busca en varios sitios
local G = _G
do
    local cands = {}
    if getfenv then
        local ok0, e0 = pcall(getfenv, 0)
        if ok0 and type(e0) == "table" then cands[#cands + 1] = e0 end
        local ok1, e1 = pcall(getfenv, 1)
        if ok1 and type(e1) == "table" then cands[#cands + 1] = e1 end
    end
    cands[#cands + 1] = _G
    if getrenv then
        local okr, er = pcall(getrenv)
        if okr and type(er) == "table" then cands[#cands + 1] = er end
    end
    for _, t in ipairs(cands) do
        if type(rawget(t, "writefile")) == "function" or type(rawget(t, "readfile")) == "function" then
            G = t
            break
        end
    end
end

local function fn(n)
    local v = rawget(G, n)
    return type(v) == "function" and v or nil
end
local writefile  = fn("writefile")  or fn("syn_writefile")  or fn("write_file")
local readfile   = fn("readfile")   or fn("syn_readfile")   or fn("read_file")
local isfile     = fn("isfile")     or fn("syn_isfile")     or fn("is_file")
local makefolder = fn("makefolder") or fn("make_folder")    or fn("createfolder")
local gethui     = fn("gethui")     or fn("getHiddenUI")
local setclip    = fn("setclipboard") or fn("toclipboard")  or fn("copytoclipboard")
local HAS_FS = writefile ~= nil and readfile ~= nil

local function guiParent()
    if gethui then local ok, h = pcall(gethui); if ok and h then return h end end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

------------------------------------------------------------------- config ---
local CFG = {
    FileName    = "EmoteGlass/config.json",
    Folder      = "EmoteGlass",
    Columns     = 3,        -- en pantallas anchas pasa a 4 solo
    WideFrom    = 420,      -- px de ancho para usar 4 columnas
    Gap         = 7,
    Pad         = 8,
    MinSpeed    = 0.25,
    MaxSpeed    = 3.00,
    SearchWait  = 0.18,
    HintTime    = 3.2,
}

-------------------------------------------------------------------- theme ---
-- iconos en bytes UTF-8 (Lua 5.1 no soporta \u{}), solo glifos BMP que Roblox dibuja
local STAR_ON  = "\226\152\133"   -- estrella rellena
local STAR_OFF = "\226\152\134"   -- estrella vacia
local ICON_GEAR = "\226\154\153"
local ICON_STOP = "\226\150\160"
local ICON_X    = "\226\156\149"
local ICON_OK   = "\226\156\147"
local ICON_MIN  = "-"

local C = {
    Glass   = Color3.fromRGB(17, 19, 27),
    Glass2  = Color3.fromRGB(27, 31, 44),
    Tile    = Color3.fromRGB(240, 244, 255),
    Line    = Color3.fromRGB(255, 255, 255),
    Text    = Color3.fromRGB(238, 242, 255),
    Dim     = Color3.fromRGB(150, 158, 182),
    Accent  = Color3.fromRGB(122, 168, 255),
    Gold    = Color3.fromRGB(255, 199, 92),
    Green   = Color3.fromRGB(120, 224, 168),
    Red     = Color3.fromRGB(255, 116, 128),
    Shadow  = Color3.fromRGB(0, 0, 0),
}

--[[<EMOTE_DATA>]]
local EMOTE_DATA = {
	"Wave (/e wave)|507770239|F|C",
	"Point (/e point)|507770453|F|C",
	"Cheer (/e cheer)|507770677|F|C",
	"Laugh (/e laugh)|507770818|F|C",
	"Dance (/e dance)|507771019|F|C",
	"Dance 2 (/e dance2)|507776043|F|C",
	"Dance 3 (/e dance3)|507777268|F|C",
	"Point2|3576823880|F|R",
	"Shrug|3576968026|F|R",
	"Hello|3576686446|F|R",
	"Stadium|3360686498|F|R",
	"Salute|3360689775|F|R",
	"Tilt|3360692915|F|R",
	"Applaud|5915779043|F|R",
	"/e fly|93511411593120|55|U",
	"/e sit|129668542320076|55|U",
	"[BEST] It's Gangnam Style!|104142334418357|55|U",
	"Alo Yoga Pose - Lotus Position|12507097350|55|U",
	"Baby Queen - Bouncy Twirl|14353423348|55|U",
	"Baby Queen - Face Frame|14353421343|55|U",
	"Baby Queen - Strut|14353425085|55|U",
	"Basketball Head|107282826166809|55|U",
	"Bored|5230661597|55|U",
	"Box|73500261613116|55|U",
	"Car|115407270129592|55|U",
	"Celebrate|3994127840|55|U",
	"Chill Bounce|132112297758791|55|U",
	"Confused|4940592718|55|U",
	"Cower|4940597758|55|U",
	"Cuco - Levitate|15698511500|55|U",
	"Curtsy|4646306583|55|U",
	"Cute Feet Kicking|78224683906191|55|U",
	"Cute Floating Fly|138591023414678|55|U",
	"Cute kawaii girly idle Profile pose|138515241510970|55|U",
	"Cute Kawaii Posing >-<|94064805002669|55|U",
	"cute levitating|101601077005248|55|U",
	"Cute Sit|82167506755506|55|U",
	"DARE - Gorillaz|136648387080677|55|U",
	"Dog|84198855496510|55|U",
	"Effortless Aura Pose|101573394483995|55|U",
	"Endless Aura Floating|106708015414624|55|U",
	"Fake MM2 Death|107498554725527|55|U",
	"Festive Dance|15679955281|55|U",
	"Floating Aura|79795305221612|55|U",
	"Floating in Love 🥰|97164262994588|55|U",
	"Floating on clouds|111426928948833|55|U",
	"Fry Dance|124799741487022|55|U",
	"Ghost Floating|75911227509248|55|U",
	"Godly Aura fly pose idle|76361248833307|55|U",
	"Greatest|3762654854|55|U",
	"Haha|4102315500|55|U",
	"Happy|4849499887|55|U",
	"Helicopter|110553756436163|55|U",
	"Hide|84868707350198|55|U",
	"High Wave|5915776835|55|U",
	"hip sway|80963950541052|55|U",
	"HIPMOTION - Amaarae|16572756230|55|U",
	"Jamal Brazil Groove|104131847054135|55|U",
	"Jumping Wave|4940602656|55|U",
	"Mae Stephens - Piano Hands|16553249658|55|U",
	"Monkey|3716636630|55|U",
	"Phase|79653736088166|55|U",
	"Plane|134913783169182|55|U",
	"Popular|71302743123422|55|U",
	"Ragdoll Push|91452077708399|55|U",
	"Rat Dance|83606297144428|55|U",
	"Rat Dance (v2)|98603994713783|55|U",
	"Sad|4849502101|55|U",
	"Secret Handshake Dance|120642514156293|55|U",
	"SHAKE|132367660388476|55|U",
	"Shy|3576717965|55|U",
	"Sleep|4689362868|55|U",
	"Spiderman Hang|108635834286627|55|U",
	"Stylish Floating|88425531063616|55|U",
	"Take The L|75633408126191|55|U",
	"Tank|85076031433488|55|U",
	"Telekinesis Head Floating Aura|81666519067619|55|U",
	"WOOF BARK WOOF|88859617281337|55|U",
	"Worm|108956933782219|55|U",
	"Yuji Jumping Edit|113702736944973|55|U",
	"Yungblud Happier Jump|15610015346|55|U",
	"🎃Pumpkin King👑|105381637724646|55|U",
	"💀MM2 Fake Dead|132384701706046|55|U",
	"🕷️ Hornet's Spider Dance 🕷️|74716792202343|55|U",
	"😝 L Dance|73039500693145|55|U",
	"Fast Hands|4272351660|80|U",
	"Floss Dance|5917570207|80|U",
	"Godlike|3823158750|80|U",
	"Hero Landing|5104377791|80|U",
	"Baby Dance|4272484885|100|U",
	"Break Dance|5915773992|100|U",
	"Dolphin Dance|5938365243|100|U",
	"KATSEYE - Touch|139021427684680|100|U",
	"Olivia Rodrigo Head Bop|15554010118|100|U",
	"Samba|6869813008|100|U",
	"Side to Side|3762641826|100|U",
	"TWICE Feel Special|14900153406|100|U",
	"TWICE LIKEY|14900151704|100|U",
	"Zombie|4212496830|100|U",
	"TWICE The Feels|12874468267|105|U",
	"TWICE What Is Love|13344121112|105|U",
	"Quiet Waves|7466046574|110|U",
	"Power Blast|4849497510|120|U",
	"Bone Chillin' Bop|15123050663|125|U",
	"Chappell Roan HOT TO GO!|79312439851071|125|U",
	"Sidekicks - George Ezra|10370922566|125|U",
	"Show Dem Wrists - KSI|7202898984|140|U",
	"Line Dance|4049646104|150|U",
	"T|3576719440|150|U",
	"Wake Up Call - KSI|7202900159|150|U",
	"Frosty Flair - Tommy Hilfiger|10214406616|170|U",
	"Hips Poppin' - Zara Larsson|6797919579|170|U",
	"Tommy - Archer|13823339506|170|U",
	"V Pose - Tommy Hilfiger|10214418283|170|U",
	"Dizzy|3934986896|175|U",
	"HOLIDAY Dance - Lil Nas X (LNX)|5938396308|190|U",
	"Old Town Road Dance - Lil Nas X (LNX)|5938394742|190|U",
	"Rodeo Dance - Lil Nas X (LNX)|5938397555|190|U",
	"Bodybuilder|3994130516|200|U",
	"Dorky Dance|4212499637|200|U",
	"Shuffle|4391208058|200|U",
	"Twirl|3716633898|250|U",
	"Sturdy Dance - Ice Spice|17746270218|300|U",
	"Fancy Feet|3934988903|500|U",
	"Fashionable|3576745472|750|U",
	"Top Rock|3570535774|750|U",
	"Around Town|3576747102|1000|U",
}
--[[</EMOTE_DATA>]]

--------------------------------------------------------------- mini json ---
-- (HttpService no siempre esta disponible fuera de Studio, asi que el script
--  trae su propio codec, pequeno y sin dependencias.)
local Json = {}

function Json.encode(v, indent, lvl)
    indent = indent or ""
    lvl = lvl or 0
    local t = type(v)
    if v == nil then
        return "null"
    elseif t == "boolean" then
        return tostring(v)
    elseif t == "number" then
        return tostring(v)
    elseif t == "string" then
        local s = v:gsub('[%c"\\]', function(ch)
            local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return map[ch] or string.format("\\u%04x", ch:byte())
        end)
        return '"' .. s .. '"'
    elseif t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        if n == 0 then return "{}" end
        local isArr = (#v == n)
        local pad, pad2 = string.rep(indent, lvl), string.rep(indent, lvl + 1)
        local parts = {}
        if isArr then
            for i = 1, #v do parts[i] = pad2 .. Json.encode(v[i], indent, lvl + 1) end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = pad2 .. Json.encode(k, indent, lvl + 1) .. ": " .. Json.encode(v[k], indent, lvl + 1)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
    return "null"
end

do
    local function skip(s, i)
        local b = s:sub(i, i)
        while b == " " or b == "\n" or b == "\r" or b == "\t" do
            i = i + 1
            b = s:sub(i, i)
        end
        return i
    end

    local parseValue

    local function parseString(s, i)
        i = i + 1
        local buf = {}
        while i <= #s do
            local ch = s:sub(i, i)
            if ch == '"' then
                return table.concat(buf), i + 1
            elseif ch == "\\" then
                local e = s:sub(i + 1, i + 1)
                if e == "n" then buf[#buf + 1] = "\n"
                elseif e == "r" then buf[#buf + 1] = "\r"
                elseif e == "t" then buf[#buf + 1] = "\t"
                elseif e == "b" then buf[#buf + 1] = "\b"
                elseif e == "f" then buf[#buf + 1] = "\f"
                elseif e == "u" then
                    local hex = s:sub(i + 2, i + 5)
                    local code = tonumber(hex, 16)
                    if code then
                        if code < 0x80 then
                            buf[#buf + 1] = string.char(code)
                        elseif code < 0x800 then
                            buf[#buf + 1] = string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
                        else
                            buf[#buf + 1] = string.char(
                                0xE0 + math.floor(code / 4096),
                                0x80 + math.floor(code / 64) % 64,
                                0x80 + code % 64)
                        end
                    end
                    i = i + 4
                else
                    buf[#buf + 1] = e
                end
                i = i + 2
            else
                buf[#buf + 1] = ch
                i = i + 1
            end
        end
        return table.concat(buf), i
    end

    local function parseArray(s, i)
        local arr, n = {}, 0
        i = skip(s, i + 1)
        if s:sub(i, i) == "]" then return arr, i + 1 end
        while true do
            local val
            val, i = parseValue(s, i)
            n = n + 1
            arr[n] = val
            i = skip(s, i)
            local ch = s:sub(i, i)
            if ch == "," then
                i = skip(s, i + 1)
            elseif ch == "]" then
                return arr, i + 1
            else
                error("se esperaba , o ] en la posicion " .. i)
            end
        end
    end

    local function parseObject(s, i)
        local obj = {}
        i = skip(s, i + 1)
        if s:sub(i, i) == "}" then return obj, i + 1 end
        while true do
            i = skip(s, i)
            if s:sub(i, i) ~= '"' then error("clave sin comillas en la posicion " .. i) end
            local key
            key, i = parseString(s, i)
            i = skip(s, i)
            if s:sub(i, i) ~= ":" then error("faltan dos puntos en la posicion " .. i) end
            i = skip(s, i + 1)
            local val
            val, i = parseValue(s, i)
            obj[key] = val
            i = skip(s, i)
            local ch = s:sub(i, i)
            if ch == "," then
                i = skip(s, i + 1)
            elseif ch == "}" then
                return obj, i + 1
            else
                error("se esperaba , o } en la posicion " .. i)
            end
        end
    end

    function parseValue(s, i)
        i = skip(s, i)
        local ch = s:sub(i, i)
        if ch == "{" then return parseObject(s, i) end
        if ch == "[" then return parseArray(s, i) end
        if ch == '"' then return parseString(s, i) end
        if s:sub(i, i + 3) == "true" then return true, i + 4 end
        if s:sub(i, i + 4) == "false" then return false, i + 5 end
        if s:sub(i, i + 3) == "null" then return nil, i + 4 end
        local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
        if num and num ~= "" and num ~= "-" and tonumber(num) then
            return tonumber(num), i + #num
        end
        error("valor no reconocido en la posicion " .. i)
    end

    function Json.decode(s)
        if type(s) ~= "string" or s == "" then return nil end
        local ok, val, i = pcall(parseValue, s, 1)
        if not ok then return nil end
        local j = skip(s, i or 1)
        if j <= #s then return nil end      -- quedo basura sin parsear
        return val
    end
end

------------------------------------------------------------------ storage ---
local Store = { data = nil, memory = {} }

function Store.defaults()
    return {
        v        = 1,
        favs     = {},
        speed    = 1.0,
        keepMove = false,
        loop     = true,
        pos      = nil,
        ball     = nil,
    }
end

function Store.load()
    local d = Store.defaults()
    if HAS_FS then
        local ok, raw = pcall(readfile, CFG.FileName)
        if ok and type(raw) == "string" and raw ~= "" then
            local parsed = Json.decode(raw)
            if type(parsed) == "table" then
                for k, v in pairs(parsed) do
                    if k ~= "v" then d[k] = v end
                end
            end
        end
    end
    if type(d.favs) ~= "table" then d.favs = {} end
    if type(d.speed) ~= "number" then d.speed = 1.0 end
    d.speed = math.max(CFG.MinSpeed, math.min(CFG.MaxSpeed, d.speed))
    d.keepMove = d.keepMove == true
    d.loop = (d.loop ~= false)
    Store.data = d
    return d
end

function Store.save()
    local d = Store.data
    if not d then return end
    local json = Json.encode(d, "\t")
    if HAS_FS then
        pcall(function()
            if makefolder and not (isfile and isfile(CFG.Folder)) then
                makefolder(CFG.Folder)
            end
        end)
        pcall(writefile, CFG.FileName, json)
    else
        Store.memory.json = json
    end
end

Store.load()
local S = Store.data

------------------------------------------------------------------ emotes ---
local Emotes, EmoteById, Favs = {}, {}, {}

do
    for _, row in ipairs(EMOTE_DATA) do
        local name, id, price, cat = row:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if name and id and price and cat then
            id = tostring(tonumber(id) or id)
            local p = tonumber(price)
            local e = {
                name = name,
                id   = id,
                num  = tonumber(id),
                free = (p == nil or p == 0),
                price = p or 0,
                cat  = cat,                     -- U = UGC · R = Roblox · C = clasico
                ugc  = (cat == "U"),
                thumb = "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150",
            }
            Emotes[#Emotes + 1] = e
            EmoteById[e.id] = e
        end
    end
    -- clasicos primero, luego Roblox, luego UGC (baratos -> caros)
    local order = { C = 1, R = 2, U = 3 }
    table.sort(Emotes, function(a, b)
        local oa, ob = order[a.cat] or 9, order[b.cat] or 9
        if oa ~= ob then return oa < ob end
        if a.price ~= b.price then return a.price < b.price end
        return a.name:lower() < b.name:lower()
    end)
end

function Emotes.priceText(e)
    if e.free then return "Gratis" end
    return tostring(e.price) .. " R$"
end

function Emotes.byId(id)
    id = tostring(id):match("%d+")
    return id and EmoteById[id] or nil
end

function Emotes.toggleFav(id)
    id = tostring(id)
    if Favs[id] then
        Favs[id] = nil
        local out = {}
        for _, f in ipairs(S.favs) do
            if tostring(f) ~= id then out[#out + 1] = f end
        end
        S.favs = out
        Store.save()
        return false
    end
    Favs[id] = true
    S.favs[#S.favs + 1] = id
    Store.save()
    return true
end

do
    local seen = {}
    for _, f in ipairs(S.favs or {}) do
        local id = tostring(f)
        if EmoteById[id] and not seen[id] then
            seen[id] = true
            Favs[id] = true
        end
    end
    local clean = {}
    for id in pairs(Favs) do clean[#clean + 1] = id end
    S.favs = clean
end

function Emotes.filter(tab, q)
    q = (q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local out = {}
    for _, e in ipairs(Emotes) do
        local ok = true
        if tab == "fav" then ok = Favs[e.id] == true
        elseif tab == "ugc" then ok = e.cat == "U"
        elseif tab == "rbx" then ok = (e.cat == "R" or e.cat == "C")
        elseif tab == "free" then ok = e.free end
        if ok and q ~= "" then
            ok = e.name:lower():find(q, 1, true) ~= nil or e.id:find(q, 1, true) ~= nil
        end
        if ok then out[#out + 1] = e end
    end
    return out
end

---------------------------------------------------------------- conexiones ---
local CONNECTIONS = {}
local function connect(sig, cb)
    local c = sig:Connect(cb)
    CONNECTIONS[#CONNECTIONS + 1] = c
    return c
end

------------------------------------------------------------------ engine ---
local selected = nil          -- emote elegido en la barra de detalle

local Engine = {
    track    = nil,
    emote    = nil,
    anim     = nil,
    speed    = S.speed,
    keepMove = S.keepMove,
    loop     = S.loop,
    playing  = false,
}

local lastTrackPos = 0
local trackStarted = false

local function getRig()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local rig = "R15"
    if char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso") then rig = "R6" end
    return hum, rig
end

function Engine.stop(quiet)
    if Engine.track then
        pcall(function() Engine.track:Stop(0.12) end)
        pcall(function() Engine.track:Destroy() end)
    end
    if Engine.anim then pcall(function() Engine.anim:Destroy() end) end
    Engine.track, Engine.anim, Engine.emote = nil, nil, nil
    Engine.playing = false
    lastTrackPos = 0
    trackStarted = false
    if not quiet and Engine.onStop then Engine.onStop() end
end

function Engine.setSpeed(v)
    v = math.max(CFG.MinSpeed, math.min(CFG.MaxSpeed, tonumber(v) or 1))
    Engine.speed = v
    S.speed = v
    Store.save()
    if Engine.track then pcall(function() Engine.track:AdjustSpeed(v) end) end
    return v
end

function Engine.setKeepMove(v)
    Engine.keepMove = (v == true)
    S.keepMove = Engine.keepMove
    Store.save()
    return Engine.keepMove
end

function Engine.setLoop(v)
    Engine.loop = (v == true)
    S.loop = Engine.loop
    Store.save()
    return Engine.loop
end

-- devuelve: ok, mensaje
function Engine.play(e)
    if type(e) ~= "table" or not e.id then return false, "Emote invalido" end
    local hum, rig = getRig()
    if not hum then return false, "Espera a tener personaje" end
    if rig == "R6" and e.ugc then
        return false, "Este juego usa R6: los emotes UGC no cargan ahi"
    end

    Engine.stop(true)

    local anim = Instance.new("Animation")
    anim.Name = "EmoteGlass_" .. e.id
    anim.AnimationId = "rbxassetid://" .. e.id

    local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
    if not ok or not track then
        pcall(function() anim:Destroy() end)
        if e.free then
            return false, "No se pudo cargar (" .. e.id .. ")"
        end
        return false, "Necesitas tenerlo: tocalo y dale a Comprar"
    end

    Engine.anim, Engine.track, Engine.emote = anim, track, e
    pcall(function() track.Priority = Enum.AnimationPriority.Action end)
    track.Looped = Engine.loop
    pcall(function() track:Play(0.15, 1, Engine.speed) end)
    Engine.playing = true
    lastTrackPos = track.TimePosition or 0
    trackStarted = false
    if Engine.onPlay then Engine.onPlay(e) end
    return true
end

function Engine.isPlaying(e)
    if not e then return Engine.playing end
    return Engine.playing and Engine.emote == e
end

function Engine.buy(e)
    if e.free then return false, "Ya es gratis" end
    local ok = pcall(function() MarketplaceService:PromptPurchase(LP, e.num or tonumber(e.id)) end)
    if ok then return true end
    return false, "No se abrio la tienda en este juego"
end

Engine.onStop = function()
    if refreshGrid then pcall(refreshGrid) end
    if showDetail and selected then pcall(showDetail, selected) end
end
Engine.onPlay = function()
    if refreshGrid then pcall(refreshGrid) end
end

-- vigila el track: si el juego lo corta al moverte, lo vuelve a poner
connect(RunService.RenderStepped, function()
    if not Engine.playing then return end
    local track = Engine.track
    if not track then return end

    local pos = track.TimePosition or 0
    if track.IsPlaying then
        -- al terminar, el track rebobina a 0: si no loopea, ahi se libera
        if trackStarted and not Engine.loop and pos < lastTrackPos then
            Engine.stop()
            return
        end
        trackStarted = true
        lastTrackPos = pos
        return
    end

    if not Engine.keepMove then
        Engine.stop()
        return
    end
    local hum = getRig()
    if not hum or hum.Health <= 0 then
        Engine.stop()
        return
    end
    pcall(function() track:Play(0.08, 1, Engine.speed) end)
    lastTrackPos = track.TimePosition or 0
    trackStarted = true
end)

-- al respawnear: limpia y, si estaba puesto, lo reanuda
connect(LP.CharacterAdded, function(char)
    local emote = Engine.emote
    Engine.stop(true)
    if emote then
        task.delay(0.6, function()
            if Engine.emote == nil then Engine.play(emote) end
        end)
    end
    _ = char
end)

------------------------------------------------------------------- gui ui ---
local function el(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(r, p) return el("UICorner", { CornerRadius = UDim.new(0, r or 12) }, p) end
local function stroke(color, thick, trans, p)
    return el("UIStroke", {
        Color = color or C.Line, Thickness = thick or 1,
        Transparency = trans or 0.88, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end
local function padding(p, t, r, b, l)
    return el("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
    }, p)
end
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function tween(obj, t, props, style, dir)
    local ok = pcall(function()
        TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props):Play()
    end)
    if not ok then for k, v in pairs(props) do obj[k] = v end end
end

local IS_TOUCH = UserInputService.TouchEnabled
local VIEW = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(380, 700)
local NARROW = VIEW.X < CFG.WideFrom
local COLS = NARROW and CFG.Columns or (CFG.Columns + 1)

--------------------------------------------------------------- gui frames ---
local oldGui = guiParent():FindFirstChild("EmoteGlass")
if oldGui then
    local prev = G and G.EmoteGlass
    if prev and prev.Engine then prev.Engine.playing = false end
    if prev and prev.Cleanup then pcall(prev.Cleanup) end
    oldGui:Destroy()
end

local gui = el("ScreenGui", {
    Name = "EmoteGlass", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true, DisplayOrder = 999999,
}, guiParent())

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)

if blur then
    connect(gui.Destroying, function()
        pcall(function() blur:Destroy() end)
    end)
end

local savedPos = (type(S.pos) == "table" and S.pos[1] and S.pos[2]) and S.pos or nil
local frameW = math.floor(clamp(VIEW.X * 0.94, 268, 392))
local frameH = math.floor(clamp(VIEW.Y * 0.72, 332, 566))
local startX = savedPos and savedPos[1] or math.floor((VIEW.X - frameW) / 2)
local startY = savedPos and savedPos[2] or math.floor(VIEW.Y * 0.10)

local frame = el("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(frameW, frameH),
    Position = UDim2.fromOffset(
        clamp(startX, 0, math.max(0, VIEW.X - frameW)),
        clamp(startY, 0, math.max(0, VIEW.Y - frameH))),
    BackgroundColor3 = C.Glass,
    BackgroundTransparency = 0.16,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, gui)
corner(18, frame)
stroke(C.Line, 1, 0.86, frame)
el("UIStroke", { Color = C.Accent, Thickness = 1, Transparency = 0.94 }, frame)

local blur = el("BlurEffect", { Size = 16, Enabled = true }, workspace.CurrentCamera or workspace)

local shadow = el("ImageLabel", {
    Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6105486455",
    ImageColor3 = C.Shadow, ImageTransparency = 0.55, ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(32, 32, 224, 224), ZIndex = 0,
    Size = UDim2.fromOffset(frameW + 46, frameH + 46),
    Position = UDim2.fromOffset(-23, -23),
}, frame)
_ = shadow

------------------------------------------------------------------ top bar ---
local top = el("TextButton", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, 46), Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.32, Text = "",
    AutoButtonColor = false, BorderSizePixel = 0,
}, frame)
el("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.93 }, top)

el("TextLabel", {
    Name = "Title", Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1, Text = "Emote Glass", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, top)

el("TextLabel", {
    Name = "Count", Size = UDim2.new(1, -150, 0, 12), Position = UDim2.new(0, 12, 1, -16),
    BackgroundTransparency = 1, Text = (#Emotes) .. " emotes del catalogo",
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.Dim,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local function topButton(name, text, x, color)
    local b = el("TextButton", {
        Name = name, Size = UDim2.fromOffset(40, 30), Position = UDim2.new(1, x, 0, 8),
        BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.15, Text = text,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = color or C.Text,
        AutoButtonColor = false, BorderSizePixel = 0,
    }, top)
    corner(9, b)
    stroke(C.Line, 1, 0.9, b)
    return b
end

local btnGear = topButton("Gear", ICON_GEAR, -136, C.Dim)
local btnStop = topButton("Stop", ICON_STOP, -92, C.Red)
local btnMin  = topButton("Min",  ICON_MIN,  -48, C.Dim)

-------------------------------------------------------------------- tabs ---
local TABS = {
    { id = "all",  label = "Todos" },
    { id = "ugc",  label = "UGC" },
    { id = "rbx",  label = "Roblox" },
    { id = "fav",  label = "Favs" },
    { id = "free", label = "Gratis" },
}

local tabRow = el("Frame", {
    Name = "Tabs", Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 0, 50),
    BackgroundTransparency = 1,
}, frame)
local tabLayout = el("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, tabRow)
_ = tabLayout

local tabButtons, currentTab = {}, "all"

------------------------------------------------------------------ search ---
local searchBox = el("Frame", {
    Name = "Search", Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 86),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.45, BorderSizePixel = 0,
}, frame)
corner(11, searchBox)
stroke(C.Line, 1, 0.92, searchBox)

local searchInput = el("TextBox", {
    Name = "Input", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "Buscar emote o ID",
    PlaceholderColor3 = C.Dim, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = C.Text, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
}, searchBox)

local searchClear = el("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -30, 0, 4),
    BackgroundColor3 = C.Glass, BackgroundTransparency = 0.3, Text = ICON_X,
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Dim,
    AutoButtonColor = false, BorderSizePixel = 0, Visible = false,
}, searchBox)
corner(8, searchClear)

------------------------------------------------------------------- hint ---
local hint = el("TextLabel", {
    Name = "Hint", Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, 124),
    BackgroundTransparency = 1, Text = "Toca un emote para ponertelo",
    Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.Dim,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, frame)

-------------------------------------------------------------- emote grid ---
local listFrame = el("Frame", {
    Name = "List", Size = UDim2.new(1, -16, 1, -214), Position = UDim2.new(0, 8, 0, 142),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.55, BorderSizePixel = 0,
    ClipsDescendants = true,
}, frame)
corner(14, listFrame)
stroke(C.Line, 1, 0.94, listFrame)

local scroll = el("ScrollingFrame", {
    Name = "Scroll", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
    ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
}, listFrame)
padding(scroll, 6, 4, 8, 6)

local emptyLabel = el("TextLabel", {
    Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 0.5, -30),
    BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = C.Dim, TextWrapped = true, Visible = false, ZIndex = 3,
}, listFrame)

------------------------------------------------------------- detail bar ---
local detail = el("Frame", {
    Name = "Detail", Size = UDim2.new(1, -16, 0, 58), Position = UDim2.new(0, 8, 1, -122),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.18, BorderSizePixel = 0,
    Visible = false, ZIndex = 5,
}, frame)
corner(14, detail)
stroke(C.Line, 1, 0.88, detail)

local detailName = el("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 5),
    BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
}, detail)

local detailInfo = el("TextButton", {
    Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, 22),
    BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
    ZIndex = 6,
}, detail)

local function actionButton(name, text, color, bg, x, w)
    local b = el("TextButton", {
        Name = name, Size = UDim2.fromOffset(w, 26), Position = UDim2.new(0, x, 1, -30),
        BackgroundColor3 = bg, BackgroundTransparency = 0.12, Text = text,
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = color,
        AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, detail)
    corner(9, b)
    stroke(C.Line, 1, 0.9, b)
    return b
end

local HALF = math.floor((frameW - 16 - 30) / 2)
local btnOff  = actionButton("Off",  "Despegar", C.Red,  C.Glass, 10, HALF)
local btnBuy  = actionButton("Buy",  "Comprar",  C.Glass, C.Gold, 16 + HALF, HALF)

--------------------------------------------------------------- settings ---
local settings = el("Frame", {
    Name = "Settings", Size = UDim2.new(1, 0, 0, 138), Position = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = C.Glass, BackgroundTransparency = 0.08, BorderSizePixel = 0,
    Visible = false, ZIndex = 8,
}, frame)
el("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.9 }, settings)

el("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1,
    Text = "Ajustes del emote puesto", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
}, settings)

local speedLabel = el("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1,
    Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Accent,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
}, settings)

local sliderTrack = el("TextButton", {
    Name = "Slider", Size = UDim2.new(1, -76, 0, 24), Position = UDim2.new(0, 10, 0, 44),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.25, Text = "",
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 9,
}, settings)
corner(12, sliderTrack)

local sliderFill = el("Frame", {
    Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.25,
    BorderSizePixel = 0, ZIndex = 10,
}, sliderTrack)
corner(12, sliderFill)

local sliderKnob = el("Frame", {
    Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0.5, -8, 0.5, -8),
    BackgroundColor3 = C.Text, BorderSizePixel = 0, ZIndex = 11,
}, sliderTrack)
corner(8, sliderKnob)

local speedReset = el("TextButton", {
    Size = UDim2.fromOffset(48, 24), Position = UDim2.new(1, -58, 0, 44),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.2, Text = "1x",
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Text,
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 9,
}, settings)
corner(9, speedReset)
stroke(C.Line, 1, 0.9, speedReset)

local keepLabel = el("TextLabel", {
    Size = UDim2.new(1, -84, 0, 30), Position = UDim2.new(0, 10, 0, 74), BackgroundTransparency = 1,
    Text = "No se sale si te mueves\n(el emote sigue puesto al caminar)",
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.Dim,
    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 9,
}, settings)

local keepToggle = el("TextButton", {
    Size = UDim2.fromOffset(58, 26), Position = UDim2.new(1, -68, 0, 76),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.15, Text = "OFF",
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Dim,
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 9,
}, settings)
corner(9, keepToggle)
stroke(C.Line, 1, 0.9, keepToggle)

local loopToggle = el("TextButton", {
    Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 108),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.3, Text = "",
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.Text,
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 9,
}, settings)
corner(9, loopToggle)
stroke(C.Line, 1, 0.92, loopToggle)

------------------------------------------------------------------ toast ---
local toast = el("TextLabel", {
    Name = "Toast", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 0, 52),
    BackgroundColor3 = C.Glass2, BackgroundTransparency = 0.06, Text = "",
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Text, TextWrapped = true,
    Visible = false, ZIndex = 20, TextTruncate = Enum.TextTruncate.AtEnd,
}, frame)
corner(10, toast)
stroke(C.Line, 1, 0.85, toast)
el("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, toast)

local toastTask = nil
local function say(text, color)
    toast.Text = text
    toast.TextColor3 = color or C.Text
    toast.Visible = true
    toast.BackgroundTransparency = 0.06
    if toastTask then pcall(task.cancel, toastTask) end
    toastTask = task.delay(CFG.HintTime, function()
        toast.Visible = false
        toastTask = nil
    end)
end

local function setHint(text, color)
    hint.Text = text
    hint.TextColor3 = color or C.Dim
end

--------------------------------------------------------------- floating ball ---
local ballPos = (type(S.ball) == "table" and S.ball[1] and S.ball[2]) and S.ball or nil
local ball = el("TextButton", {
    Name = "Ball",
    Size = UDim2.fromOffset(56, 56),
    Position = ballPos and UDim2.fromOffset(ballPos[1], ballPos[2])
        or UDim2.new(1, -74, 1, -150),
    BackgroundColor3 = C.Glass, BackgroundTransparency = 0.12,
    Text = "E", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = C.Accent,
    AutoButtonColor = false, BorderSizePixel = 0, Visible = false, Active = true,
}, gui)
corner(28, ball)
stroke(C.Accent, 1, 0.55, ball)

local ballCount = el("TextLabel", {
    Size = UDim2.new(1, 0, 0, 11), Position = UDim2.new(0, 0, 1, -14), BackgroundTransparency = 1,
    Text = (#Emotes) .. "", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.Dim,
}, ball)
_ = ballCount

---------------------------------------------------------------- dragging ---
local function clampPos(x, y, w, h)
    return clamp(x, -w * 0.35, math.max(0, VIEW.X - w * 0.65)),
           clamp(y, 0, math.max(0, VIEW.Y - 40))
end

local function makeDraggable(handle, target, onSave)
    local dragging, startTouch, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startTouch = Vector2.new(input.Position.X, input.Position.Y)
            local p = target.Position
            startPos = Vector2.new(p.X.Offset, p.Y.Offset)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = Vector2.new(input.Position.X, input.Position.Y) - startTouch
            if math.abs(d.X) + math.abs(d.Y) > 2 then
                local x, y = clampPos(startPos.X + d.X, startPos.Y + d.Y, target.Size.X.Offset, target.Size.Y.Offset)
                target.Position = UDim2.fromOffset(x, y)
            end
        end
    end)
    local function ended(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if onSave then
                local p = target.Position
                onSave(p.X.Offset, p.Y.Offset)
            end
        end
    end
    connect(UserInputService.InputEnded, ended)
    connect(handle.InputEnded, ended)
end

makeDraggable(top, frame, function(x, y)
    S.pos = { x, y }
    Store.save()
end)

------------------------------------------------------------- grid render ---
local LIST_W = frameW - 16
local TILE_W = math.floor((LIST_W - CFG.Pad * 2 - CFG.Gap * (COLS - 1)) / COLS)
if TILE_W < 56 then TILE_W = 56 end
local THUMB = TILE_W - 12
local TILE_H = THUMB + 48

local pool = {}          -- [tileIndex] = { frame = <Frame>, item = <emote> }
local view = {}          -- lista filtrada actual
local selected = nil
local lastScrollY = -1
local rows = 0

local function tilePos(i)
    local idx = i - 1
    local col = idx % COLS
    local row = math.floor(idx / COLS)
    return UDim2.fromOffset(CFG.Pad + col * (TILE_W + CFG.Gap), CFG.Pad + row * (TILE_H + CFG.Gap))
end

local function refreshFavStar(tileFrame, e)
    local star = tileFrame:FindFirstChild("Star")
    if not star then return end
    local on = Favs[e.id] == true
    star.Text = on and STAR_ON or STAR_OFF
    star.TextColor3 = on and C.Gold or C.Dim
    star.BackgroundTransparency = on and 0.15 or 0.45
end

local function newTile()
    local t = el("Frame", {
        Size = UDim2.fromOffset(TILE_W, TILE_H), BackgroundColor3 = C.Tile,
        BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 2,
    }, scroll)
    corner(12, t)
    stroke(C.Line, 1, 0.93, t)

    local thumb = el("ImageButton", {
        Name = "Thumb", Size = UDim2.fromOffset(THUMB, THUMB),
        Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1,
        Image = "", ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, ZIndex = 3,
    }, t)

    local star = el("TextButton", {
        Name = "Star", Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -30, 0, 2), BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.45, Text = STAR_OFF, Font = Enum.Font.GothamBold,
        TextSize = 15, TextColor3 = C.Dim, AutoButtonColor = false,
        BorderSizePixel = 0, ZIndex = 4,
    }, t)
    corner(13, star)

    local name = el("TextLabel", {
        Name = "Name", Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 0, THUMB + 8),
        BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = C.Text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 3,
    }, t)

    local price = el("TextLabel", {
        Name = "Price", Size = UDim2.new(1, -10, 0, 13), Position = UDim2.new(0, 5, 1, -16),
        BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    }, t)

    return { frame = t, thumb = thumb, star = star, name = name, price = price, item = nil }
end

local function bindTile(tile)
    tile.thumb.MouseButton1Click:Connect(function()
        if not tile.item then return end
        local ok, msg = Engine.play(tile.item)
        selected = tile.item
        showDetail(tile.item)
        if ok then
            setHint("Puesto: " .. tile.item.name .. "  ·  " .. Emotes.priceText(tile.item), C.Green)
        else
            setHint(msg, C.Red)
        end
        refreshGrid()
    end)
    tile.thumb.MouseButton2Click:Connect(function()
        if tile.item then showDetail(tile.item) end
    end)
    tile.star.MouseButton1Click:Connect(function()
        if not tile.item then return end
        local on = Emotes.toggleFav(tile.item.id)
        refreshFavStar(tile.frame, tile.item)
        setHint((on and "Anadido a favoritos: " or "Quitado de favoritos: ") .. tile.item.name,
            on and C.Gold or C.Dim)
        if currentTab == "fav" then rebuild() end
        refreshFavCount()
    end)
end

local function paintTile(tile, e, i)
    tile.item = e
    tile.frame.Position = tilePos(i)
    tile.thumb.Image = e.thumb
    tile.name.Text = e.name
    tile.price.Text = Emotes.priceText(e)
    tile.price.TextColor3 = e.free and C.Green or C.Gold
    refreshFavStar(tile.frame, e)
    local active = Engine.isPlaying(e)
    tile.frame.BackgroundTransparency = active and 0.72 or 0.9
    tile.frame.BackgroundColor3 = active and C.Accent or C.Tile
end

function refreshGrid()
    local y = scroll.CanvasPosition.Y
    local vh = scroll.AbsoluteSize.Y
    if vh <= 0 then vh = 200 end
    local top = math.max(1, math.floor((y - CFG.Pad) / (TILE_H + CFG.Gap)))
    local bottom = math.min(#view, math.ceil((y + vh + TILE_H) / (TILE_H + CFG.Gap)))

    for i = top, bottom do
        if view[i] then
            local tile = pool[i]
            if not tile then
                tile = newTile()
                bindTile(tile)
                pool[i] = tile
            end
            if tile.item ~= view[i] or not tile.painted then
                paintTile(tile, view[i], i)
                tile.painted = true
            else
                refreshFavStar(tile.frame, view[i])
                local active = Engine.isPlaying(view[i])
                tile.frame.BackgroundTransparency = active and 0.72 or 0.9
                tile.frame.BackgroundColor3 = active and C.Accent or C.Tile
            end
        end
    end
    local span = bottom - top + 1
    for i, tile in pairs(pool) do
        if i < top - span or i > bottom + span then
            tile.frame:Destroy()
            pool[i] = nil
        end
    end
    lastScrollY = y
end

function rebuild()
    view = Emotes.filter(currentTab, searchInput.Text)
    for i, tile in pairs(pool) do
        tile.frame:Destroy()
        pool[i] = nil
    end
    rows = math.ceil(#view / COLS)
    scroll.CanvasSize = UDim2.fromOffset(0, rows * (TILE_H + CFG.Gap) + CFG.Pad)
    scroll.CanvasPosition = Vector2.new(0, 0)
    lastScrollY = -1
    emptyLabel.Visible = (#view == 0)
    if #view == 0 then
        emptyLabel.Text = (currentTab == "fav")
            and "No tienes favoritos todavia.\nToca la estrellita de un emote."
            or "Sin resultados."
    end
    refreshGrid()
end

connect(scroll:GetPropertyChangedSignal("CanvasPosition"), function()
    if math.abs(scroll.CanvasPosition.Y - lastScrollY) > 6 then refreshGrid() end
end)

-------------------------------------------------------------- tab / count ---
local favCountLabel
local function buildTabs()
    for order, tab in ipairs(TABS) do
        local b = el("TextButton", {
            Name = tab.id, Size = UDim2.fromOffset(66, 28), BackgroundColor3 = C.Glass2,
            BackgroundTransparency = 0.4, Text = tab.label, Font = Enum.Font.GothamBold,
            TextSize = 11, TextColor3 = C.Dim, AutoButtonColor = false,
            BorderSizePixel = 0, LayoutOrder = order,
        }, tabRow)
        corner(10, b)
        local st = stroke(C.Line, 1, 0.92, b)
        tabButtons[tab.id] = { button = b, stroke = st }
        b.MouseButton1Click:Connect(function()
            currentTab = tab.id
            for id, t in pairs(tabButtons) do
                local on = (id == currentTab)
                t.button.BackgroundTransparency = on and 0.1 or 0.4
                t.button.TextColor3 = on and C.Glass or C.Dim
                t.button.BackgroundColor3 = on and C.Accent or C.Glass2
                t.stroke.Transparency = on and 0.75 or 0.92
            end
            rebuild()
        end)
        if tab.id == "fav" then favCountLabel = b end
    end
    tabButtons["all"].button.BackgroundTransparency = 0.1
    tabButtons["all"].button.TextColor3 = C.Glass
    tabButtons["all"].button.BackgroundColor3 = C.Accent
    tabButtons["all"].stroke.Transparency = 0.75
end

function refreshFavCount()
    local n = 0
    for _ in pairs(Favs) do n = n + 1 end
    if favCountLabel then favCountLabel.Text = "Favs " .. n end
end

--------------------------------------------------------------- detail bar ---
function showDetail(e)
    if not e then
        detail.Visible = false
        selected = nil
        return
    end
    selected = e
    detail.Visible = true
    detailName.Text = e.name
    local kind = e.ugc and "UGC" or (e.cat == "C" and "Roblox clasico" or "Roblox")
    detailInfo.Text = Emotes.priceText(e) .. "  ·  " .. kind .. "  ·  ID " .. e.id
    if e.free then
        btnBuy.Text = "Es gratis"
        btnBuy.TextColor3 = C.Green
    else
        btnBuy.Text = "Comprar " .. e.price .. " R$"
        btnBuy.TextColor3 = C.Glass
    end
end

btnOff.MouseButton1Click:Connect(function()
    Engine.stop()
    setHint("Emote despegado", C.Red)
    showDetail(selected)
    refreshGrid()
end)

btnBuy.MouseButton1Click:Connect(function()
    if not selected then return end
    local ok, msg = Engine.buy(selected)
    if ok then
        say("Abriendo la tienda de " .. selected.name, C.Gold)
    else
        say(msg, C.Red)
    end
end)

detailInfo.MouseButton1Click:Connect(function()
    if not selected then return end
    if setclip then
        pcall(setclip, selected.id)
        say("ID copiado: " .. selected.id, C.Accent)
    else
        say("ID: " .. selected.id, C.Accent)
    end
end)

---------------------------------------------------------------- settings ---
local function updateSpeedLabel()
    speedLabel.Text = string.format("Velocidad  %.2fx", Engine.speed)
    local ratio = (Engine.speed - CFG.MinSpeed) / (CFG.MaxSpeed - CFG.MinSpeed)
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    sliderKnob.Position = UDim2.new(ratio, -8, 0.5, -8)
end

local function speedFromX(x)
    local w = sliderTrack.AbsoluteSize.X
    if w <= 0 then w = 200 end
    local rel = clamp((x - sliderTrack.AbsolutePosition.X) / w, 0, 1)
    local raw = CFG.MinSpeed + rel * (CFG.MaxSpeed - CFG.MinSpeed)
    return math.floor(raw * 20 + 0.5) / 20
end

local function updateToggles()
    keepToggle.Text = Engine.keepMove and "ON" or "OFF"
    keepToggle.TextColor3 = Engine.keepMove and C.Glass or C.Dim
    keepToggle.BackgroundColor3 = Engine.keepMove and C.Green or C.Glass2
    loopToggle.Text = (Engine.loop and (ICON_OK .. " Repetir en bucle: ON")
        or (ICON_X .. " Repetir en bucle: OFF"))
    loopToggle.TextColor3 = Engine.loop and C.Green or C.Dim
end

local sliderActive = false
connect(sliderTrack.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        sliderActive = true
        Engine.setSpeed(speedFromX(input.Position.X))
        updateSpeedLabel()
    end
end)
connect(sliderTrack.InputChanged, function(input)
    if sliderActive and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        Engine.setSpeed(speedFromX(input.Position.X))
        updateSpeedLabel()
    end
end)
local function sliderEnd()
    if sliderActive then
        sliderActive = false
        setHint(string.format("Velocidad del emote: %.2fx", Engine.speed), C.Accent)
    end
end
connect(UserInputService.InputEnded, sliderEnd)
connect(sliderTrack.InputEnded, sliderEnd)

speedReset.MouseButton1Click:Connect(function()
    Engine.setSpeed(1)
    updateSpeedLabel()
    setHint("Velocidad normal (1.00x)", C.Accent)
end)

keepToggle.MouseButton1Click:Connect(function()
    local on = Engine.setKeepMove(not Engine.keepMove)
    updateToggles()
    setHint(on and "El emote ya no se sale al moverte" or "El emote se corta al moverte (normal)",
        on and C.Green or C.Dim)
end)

loopToggle.MouseButton1Click:Connect(function()
    Engine.setLoop(not Engine.loop)
    if Engine.track then Engine.track.Looped = Engine.loop end
    updateToggles()
    setHint(Engine.loop and "El emote se repite en bucle" or "El emote suena una sola vez", C.Accent)
end)

local settingsOpen = false
local function toggleSettings(force)
    settingsOpen = (force ~= nil) and force or (not settingsOpen)
    settings.Visible = true
    btnGear.TextColor3 = settingsOpen and C.Accent or C.Dim
    tween(settings, 0.22, {
        Position = settingsOpen and UDim2.new(0, 0, 1, -138) or UDim2.new(0, 0, 1, 0),
    })
    if not settingsOpen then
        task.delay(0.24, function()
            if not settingsOpen then settings.Visible = false end
        end)
    else
        updateSpeedLabel()
        updateToggles()
    end
end

btnGear.MouseButton1Click:Connect(function() toggleSettings() end)

btnStop.MouseButton1Click:Connect(function()
    if Engine.playing then
        local n = Engine.emote and Engine.emote.name or "emote"
        Engine.stop()
        setHint("Despegado: " .. n, C.Red)
    else
        setHint("No tienes ningun emote puesto", C.Dim)
    end
    if selected then showDetail(selected) end
    refreshGrid()
end)

------------------------------------------------------------------ search ---
local searchDebounce = nil
connect(searchInput:GetPropertyChangedSignal("Text"), function()
    searchClear.Visible = searchInput.Text ~= ""
    if searchDebounce then pcall(task.cancel, searchDebounce) end
    searchDebounce = task.delay(CFG.SearchWait, function()
        searchDebounce = nil
        rebuild()
        local digits = searchInput.Text:match("^%s*(%d+)%s*$")
        if digits and #digits >= 4 then
            setHint("Pulsa aqui para usar el ID " .. digits, C.Accent)
        end
    end)
end)

searchClear.MouseButton1Click:Connect(function()
    searchInput.Text = ""
    searchClear.Visible = false
    rebuild()
end)

-- con solo numeros en el buscador: jugar ese ID directo
connect(searchInput.FocusLost, function(entered)
    local digits = searchInput.Text:match("^%s*(%d+)%s*$")
    if digits and #digits >= 4 then
        local e = Emotes.byId(digits) or {
            name = "ID " .. digits, id = digits, num = tonumber(digits),
            free = false, price = 0, cat = "U", ugc = true,
            thumb = "rbxthumb://type=Asset&id=" .. digits .. "&w=150&h=150",
        }
        local ok, msg = Engine.play(e)
        selected = e
        showDetail(e)
        setHint(ok and ("Puesto: " .. e.name) or msg, ok and C.Green or C.Red)
    elseif entered then
        UserInputService.TextBoxReleased:Wait()
    end
end)

---------------------------------------------------------------- minimize ---
local function setMinimized(min)
    frame.Visible = not min
    ball.Visible = min
    if blur then blur.Enabled = not min end
    if min then
        local p = ball.Position
        S.ball = { p.X.Offset + 74, p.Y.Offset + 150 }
        Store.save()
    end
end

btnMin.MouseButton1Click:Connect(function() setMinimized(true) end)

local ballTapped, ballTimer = false, nil
ball.MouseButton1Click:Connect(function()
    if ballTapped then return end
    ballTapped = true
    setMinimized(false)
    ballTimer = task.delay(0.4, function() ballTapped = false end)
end)
_ = ballTimer

makeDraggable(ball, ball, function(x, y)
    S.ball = { x, y }
    Store.save()
end)

--------------------------------------------------------------- keyboard ---
connect(UserInputService.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        setMinimized(not ball.Visible)
    elseif input.KeyCode == Enum.KeyCode.Backspace and Engine.playing then
        Engine.stop()
        setHint("Emote despegado", C.Red)
        refreshGrid()
    end
end)

------------------------------------------------------------------- boot ---
buildTabs()
refreshFavCount()
updateSpeedLabel()
updateToggles()
rebuild()

if not HAS_FS then
    say("Sin writefile: favoritos y ajustes no se guardan", C.Red)
end
if #Emotes == 0 then
    say("El catalogo venia vacio", C.Red)
end

-- export minimo para pruebas / integraciones (getgenv)
local API = {
    Version   = EMOTE_GLASS_VERSION,
    Emotes    = Emotes,
    Filter    = Emotes.filter,
    ById      = Emotes.byId,
    ToggleFav = Emotes.toggleFav,
    Favs      = Favs,
    Engine    = Engine,
    Json      = Json,
    Store     = Store,
    Gui       = { gui = gui, frame = frame, ball = ball, scroll = scroll, list = listFrame, settings = settings, detail = detail },
    UI        = { rebuild = rebuild, refreshGrid = refreshGrid, showDetail = showDetail, setMinimized = setMinimized, toggleSettings = toggleSettings, say = say, setHint = setHint },
    Cleanup   = function()
        for _, c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end
        CONNECTIONS = {}
    end,
    TILE_W    = TILE_W,
    TILE_H    = TILE_H,
    COLS      = COLS,
}
if G then G.EmoteGlass = API end

return API
