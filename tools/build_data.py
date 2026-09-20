#!/usr/bin/env python3
"""Genera el bloque de datos de emotes (EMOTE_DATA) e inyecta en EmoteGlass.lua.

Formato por linea:  Nombre|Id|PrecioRobux|Categoria
    Categoria: U = UGC (creadores)   R = Roblox oficial del catalogo (gratis)
               C = clasico /e (viene en el script Animate, no es item del catalogo)
    Precio:    entero en Robux, o F = gratis

Fuente: catalogo oficial de Roblox (categoria Emotes, assetType 61 EmoteAnimation).
Los IDs clasicos salen del script Animate.client.lua de Roblox.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "EmoteGlass.lua"

FREE_ROBLOX = [  # publicados por Roblox a 0 Robux
    ("Point2", 3576823880),
    ("Shrug", 3576968026),
    ("Hello", 3576686446),
    ("Stadium", 3360686498),
    ("Salute", 3360689775),
    ("Tilt", 3360692915),
    ("Applaud", 5915779043),
]

CLASSIC = [  # /e del script Animate por defecto
    ("Wave (/e wave)", 507770239),
    ("Point (/e point)", 507770453),
    ("Cheer (/e cheer)", 507770677),
    ("Laugh (/e laugh)", 507770818),
    ("Dance (/e dance)", 507771019),
    ("Dance 2 (/e dance2)", 507776043),
    ("Dance 3 (/e dance3)", 507777268),
]

UGC = [
    ("Floating Aura", 79795305221612, 55),
    ("Monkey", 3716636630, 55),
    ("Curtsy", 4646306583, 55),
    ("Godlike", 3823158750, 80),
    ("Helicopter", 110553756436163, 55),
    ("Happy", 4849499887, 55),
    ("TWICE The Feels", 12874468267, 105),
    ("Baby Queen - Bouncy Twirl", 14353423348, 55),
    ("Rat Dance", 83606297144428, 55),
    ("Plane", 134913783169182, 55),
    ("Sleep", 4689362868, 55),
    ("Tank", 85076031433488, 55),
    ("Hero Landing", 5104377791, 80),
    ("Shy", 3576717965, 55),
    ("Car", 115407270129592, 55),
    ("Floss Dance", 5917570207, 80),
    ("/e sit", 129668542320076, 55),
    ("Quiet Waves", 7466046574, 110),
    ("Fake MM2 Death", 107498554725527, 55),
    ("Yungblud Happier Jump", 15610015346, 55),
    ("Baby Dance", 4272484885, 100),
    ("Baby Queen - Face Frame", 14353421343, 55),
    ("Box", 73500261613116, 55),
    ("Top Rock", 3570535774, 750),
    ("Hide", 84868707350198, 55),
    ("Baby Queen - Strut", 14353425085, 55),
    ("Bored", 5230661597, 55),
    ("KATSEYE - Touch", 139021427684680, 100),
    ("Dog", 84198855496510, 55),
    ("\U0001F61D L Dance", 73039500693145, 55),
    ("Ragdoll Push", 91452077708399, 55),
    ("Take The L", 75633408126191, 55),
    ("Fry Dance", 124799741487022, 55),
    ("Twirl", 3716633898, 250),
    ("Fashionable", 3576745472, 750),
    ("Line Dance", 4049646104, 150),
    ("Cower", 4940597758, 55),
    ("High Wave", 5915776835, 55),
    ("Worm", 108956933782219, 55),
    ("TWICE Feel Special", 14900153406, 100),
    ("V Pose - Tommy Hilfiger", 10214418283, 170),
    ("Alo Yoga Pose - Lotus Position", 12507097350, 55),
    ("Frosty Flair - Tommy Hilfiger", 10214406616, 170),
    ("Effortless Aura Pose", 101573394483995, 55),
    ("Chappell Roan HOT TO GO!", 79312439851071, 125),
    ("Dolphin Dance", 5938365243, 100),
    ("Old Town Road Dance - Lil Nas X (LNX)", 5938394742, 190),
    ("Phase", 79653736088166, 55),
    ("Sturdy Dance - Ice Spice", 17746270218, 300),
    ("Mae Stephens - Piano Hands", 16553249658, 55),
    ("Around Town", 3576747102, 1000),
    ("Olivia Rodrigo Head Bop", 15554010118, 100),
    ("Celebrate", 3994127840, 55),
    ("SHAKE", 132367660388476, 55),
    ("Show Dem Wrists - KSI", 7202898984, 140),
    ("Side to Side", 3762641826, 100),
    ("Dorky Dance", 4212499637, 200),
    ("cute levitating", 101601077005248, 55),
    ("TWICE LIKEY", 14900151704, 100),
    ("Chill Bounce", 132112297758791, 55),
    ("Telekinesis Head Floating Aura", 81666519067619, 55),
    ("\U0001F577\ufe0f Hornet's Spider Dance \U0001F577\ufe0f", 74716792202343, 55),
    ("Spiderman Hang", 108635834286627, 55),
    ("Shuffle", 4391208058, 200),
    ("Fancy Feet", 3934988903, 500),
    ("Dizzy", 3934986896, 175),
    ("TWICE What Is Love", 13344121112, 105),
    ("Jamal Brazil Groove", 104131847054135, 55),
    ("HOLIDAY Dance - Lil Nas X (LNX)", 5938396308, 190),
    ("hip sway", 80963950541052, 55),
    ("Stylish Floating", 88425531063616, 55),
    ("Tommy - Archer", 13823339506, 170),
    ("Cute Floating Fly", 138591023414678, 55),
    ("DARE - Gorillaz", 136648387080677, 55),
    ("Bodybuilder", 3994130516, 200),
    ("Endless Aura Floating", 106708015414624, 55),
    ("Haha", 4102315500, 55),
    ("Hips Poppin' - Zara Larsson", 6797919579, 170),
    ("HIPMOTION - Amaarae", 16572756230, 55),
    ("Sad", 4849502101, 55),
    ("Sidekicks - George Ezra", 10370922566, 125),
    ("Popular", 71302743123422, 55),
    ("[BEST] It's Gangnam Style!", 104142334418357, 55),
    ("Secret Handshake Dance", 120642514156293, 55),
    ("Godly Aura fly pose idle", 76361248833307, 55),
    ("Cute Kawaii Posing >-<", 94064805002669, 55),
    ("Break Dance", 5915773992, 100),
    ("Samba", 6869813008, 100),
    ("\U0001F480MM2 Fake Dead", 132384701706046, 55),
    ("Zombie", 4212496830, 100),
    ("Rat Dance (v2)", 98603994713783, 55),
    ("Greatest", 3762654854, 55),
    ("Cute Feet Kicking", 78224683906191, 55),
    ("Floating on clouds", 111426928948833, 55),
    ("Fast Hands", 4272351660, 80),
    ("/e fly", 93511411593120, 55),
    ("Floating in Love \U0001F970", 97164262994588, 55),
    ("Wake Up Call - KSI", 7202900159, 150),
    ("Rodeo Dance - Lil Nas X (LNX)", 5938397555, 190),
    ("Basketball Head", 107282826166809, 55),
    ("Power Blast", 4849497510, 120),
    ("Cuco - Levitate", 15698511500, 55),
    ("Jumping Wave", 4940602656, 55),
    ("Bone Chillin' Bop", 15123050663, 125),
    ("Confused", 4940592718, 55),
    ("WOOF BARK WOOF", 88859617281337, 55),
    ("Yuji Jumping Edit", 113702736944973, 55),
    ("T", 3576719440, 150),
    ("Ghost Floating", 75911227509248, 55),
    ("Cute kawaii girly idle Profile pose", 138515241510970, 55),
    ("Festive Dance", 15679955281, 55),
    ("\U0001F383Pumpkin King\U0001F451", 105381637724646, 55),
    ("Cute Sit", 82167506755506, 55),
]

MARK_START = "--[[<EMOTE_DATA>]]"
MARK_END = "--[[</EMOTE_DATA>]]"


def build_block() -> str:
    lines = []
    for name, asset_id in CLASSIC:
        lines.append(f'"{name}|{asset_id}|F|C"')
    for name, asset_id in FREE_ROBLOX:
        lines.append(f'"{name}|{asset_id}|F|R"')
    for name, asset_id, price in sorted(UGC, key=lambda e: (e[2], e[0].lower())):
        lines.append(f'"{name}|{asset_id}|{price}|U"')
    body = ",\n".join("\t" + ln for ln in lines)
    return f"{MARK_START}\nlocal EMOTE_DATA = {{\n{body},\n}}\n{MARK_END}"


def main() -> int:
    src = TARGET.read_text(encoding="utf-8")
    if MARK_START not in src or MARK_END not in src:
        print(f"no se encuentran los marcadores en {TARGET}", file=sys.stderr)
        return 1
    block = build_block()
    out = re.sub(
        re.escape(MARK_START) + r".*?" + re.escape(MARK_END),
        block.replace("\\", "\\\\"),
        src,
        count=1,
        flags=re.S,
    )
    TARGET.write_text(out, encoding="utf-8")
    total = len(CLASSIC) + len(FREE_ROBLOX) + len(UGC)
    ids = [e[1] for e in CLASSIC + FREE_ROBLOX] + [e[1] for e in UGC]
    dupes = {i for i in ids if ids.count(i) > 1}
    print(
        f"datos inyectados: {total} emotes "
        f"({len(UGC)} UGC, {len(FREE_ROBLOX)} Roblox gratis, {len(CLASSIC)} clasicos)"
    )
    if dupes:
        print(f"IDs duplicados: {sorted(dupes)}", file=sys.stderr)
        return 2
    print("IDs unicos: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
