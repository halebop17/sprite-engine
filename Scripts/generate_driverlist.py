#!/usr/bin/env python3
import os, sys

srcroot = os.environ.get('SRCROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
fbsrc   = f"{srcroot}/FBNeoCPSLib/fbneo/src"
capcom  = f"{fbsrc}/burn/drv/capcom"
sega    = f"{fbsrc}/burn/drv/sega"
gendir  = f"{fbsrc}/dep/generated"

os.makedirs(gendir, exist_ok=True)

driver_files = [
    (capcom, "d_cps1.cpp"),
    (capcom, "d_cps2.cpp"),
    (sega,   "d_sys16a.cpp"),
    (sega,   "d_sys16b.cpp"),
    (sega,   "d_sys18.cpp"),
    (sega,   "d_hangon.cpp"),
    (sega,   "d_outrun.cpp"),
    (sega,   "d_xbrd.cpp"),
    (sega,   "d_ybrd.cpp"),
]

entries = []
for directory, drv in driver_files:
    with open(f"{directory}/{drv}", encoding='utf-8', errors='replace') as f:
        for line in f:
            if line.startswith("struct BurnDriver"):
                name = line.split()[2]
                entries.append(name)

lines = ["// Auto-generated driverlist.h — CPS-1/2 + Sega Sys16/18/Hangon/Outrun/XBoard/YBoard\n", "#include <wchar.h>\n\n"]
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
