#!/usr/bin/env python3
import os, sys

srcroot = os.environ.get('SRCROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
fbsrc   = f"{srcroot}/FBNeoCPSLib/fbneo/src"
capcom  = f"{fbsrc}/burn/drv/capcom"
sega    = f"{fbsrc}/burn/drv/sega"
toaplan = f"{fbsrc}/burn/drv/toaplan"
konami  = f"{fbsrc}/burn/drv/konami"
irem    = f"{fbsrc}/burn/drv/irem"
taito   = f"{fbsrc}/burn/drv/taito"
gendir  = f"{fbsrc}/dep/generated"

os.makedirs(gendir, exist_ok=True)

driver_files = [
    (capcom,  "d_cps1.cpp"),
    (capcom,  "d_cps2.cpp"),
    (sega,    "d_sys16a.cpp"),
    (sega,    "d_sys16b.cpp"),
    (sega,    "d_sys18.cpp"),
    (sega,    "d_hangon.cpp"),
    (sega,    "d_outrun.cpp"),
    (sega,    "d_xbrd.cpp"),
    (sega,    "d_ybrd.cpp"),
    # Toaplan 1
    (toaplan, "d_toaplan1.cpp"),
    (toaplan, "d_twincobr.cpp"),
    (toaplan, "d_wardner.cpp"),
    (toaplan, "d_ghox.cpp"),
    (toaplan, "d_slapfght.cpp"),
    (toaplan, "d_pipibibs.cpp"),
    # Toaplan 2
    (toaplan, "d_truxton2.cpp"),
    (toaplan, "d_batsugun.cpp"),
    (toaplan, "d_vfive.cpp"),
    (toaplan, "d_dogyuun.cpp"),
    (toaplan, "d_kbash.cpp"),
    (toaplan, "d_kbash2.cpp"),
    (toaplan, "d_shippumd.cpp"),
    (toaplan, "d_mahoudai.cpp"),
    (toaplan, "d_batrider.cpp"),
    (toaplan, "d_bbakraid.cpp"),
    (toaplan, "d_battleg.cpp"),
    (toaplan, "d_snowbro2.cpp"),
    (toaplan, "d_tekipaki.cpp"),
    (toaplan, "d_fixeight.cpp"),
    (toaplan, "d_enmadaio.cpp"),
    # Konami GX (Pre-GX: Mystic Warriors, Violent Storm, Metamorphic Force,
    #            Martial Champion, Gaiapolis, Monster Maulers, Dadandarn,
    #            Wild West COW-Boys of Moo Mesa, Bucky O'Hare)
    (konami,  "d_mystwarr.cpp"),
    (konami,  "d_moo.cpp"),
    # Irem M72 / M92
    (irem,    "d_m72.cpp"),
    (irem,    "d_m92.cpp"),
    # Taito F2 / F3
    (taito,   "d_taitof2.cpp"),
    (taito,   "d_taitof3.cpp"),
]

entries = []
for directory, drv in driver_files:
    with open(f"{directory}/{drv}", encoding='utf-8', errors='replace') as f:
        for line in f:
            if line.startswith("struct BurnDriver"):
                name = line.split()[2]
                entries.append(name)

lines = ["// Auto-generated driverlist.h — CPS-1/2 + Sega + Toaplan + Konami GX + Irem + Taito\n", "#include <wchar.h>\n\n"]
for n in entries:
    lines.append(f"extern struct BurnDriver {n};\n")
lines.append("\nstatic struct BurnDriver* pDriver[] = {\n")
for n in entries:
    lines.append(f"\t&{n},\n")
lines.append("};\n\nstruct game_sourcefile_entry { char game_name[32]; char sourcefile[32]; };\n")
lines.append('static game_sourcefile_entry sourcefile_table[] = { { "", "" } };\n')

with open(f"{gendir}/driverlist.h", 'w') as f:
    f.writelines(lines)
print(f"Generated driverlist.h with {len(entries)} entries")
