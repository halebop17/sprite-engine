#!/usr/bin/env python3
import os, sys

srcroot = os.environ.get('SRCROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
capcom = f"{srcroot}/FBNeoCPSLib/fbneo/src/burn/drv/capcom"
gendir = f"{srcroot}/FBNeoCPSLib/fbneo/src/dep/generated"

os.makedirs(gendir, exist_ok=True)

entries = []
for drv in ["d_cps1.cpp", "d_cps2.cpp"]:
    with open(f"{capcom}/{drv}") as f:
        for line in f:
            if line.startswith("struct BurnDriver"):
                name = line.split()[2]
                entries.append(name)

lines = ["// Auto-generated driverlist.h — CPS-1 and CPS-2 subset only\n", "#include <wchar.h>\n\n"]
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
