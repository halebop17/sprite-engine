#!/usr/bin/env python3
"""Add upd7810.cpp (uPD7810 CPU core) to FBNeoCPSLib target.

cchip.cpp (Taito C-Chip protection emulation) drives a uPD7810
microcontroller, so without this core the linker reports
upd7810SetIRQLine, upd7810Open, etc. as undefined.

The 7810tbl.c / 7810ops.c / 7810dasm.c files are #included from
upd7810.cpp itself, so they don't need separate compile entries.

A new PBXGroup `upd7810` is added under the `cpu` group, mirroring how
m68k / z80 / etc. are organized.
"""

import sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

FILE_REF      = "UPD7810CPU001A"
BUILD_FILE    = "UPD7810CPU001B"
SUBGROUP_ID   = "UPD7810CPU_GRP00"
NAME          = "upd7810.cpp"

CPU_GROUP_TAIL  = "LDEP_M6805_GRP000 /* m6805 */,"
SOURCES_ANCHOR  = "TAITODRV001B /* d_taitof2.cpp in Sources */,"

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()
original = src

# 1. PBXBuildFile
needle = f"{BUILD_FILE} /* {NAME} in Sources */ = {{isa = PBXBuildFile"
if needle not in src:
    src = src.replace(
        "/* End PBXBuildFile section */",
        f'\t\t\t{BUILD_FILE} /* {NAME} in Sources */ = '
        f'{{isa = PBXBuildFile; fileRef = {FILE_REF} /* {NAME} */; }};\n'
        "/* End PBXBuildFile section */"
    )
    print("Added PBXBuildFile entry")

# 2. PBXFileReference
needle = f"{FILE_REF} /* {NAME} */ = {{isa = PBXFileReference"
if needle not in src:
    src = src.replace(
        "/* End PBXFileReference section */",
        f'\t\t\t{FILE_REF} /* {NAME} */ = {{isa = PBXFileReference; '
        f'lastKnownFileType = sourcecode.cpp.cpp; '
        f'path = {NAME}; sourceTree = "<group>"; }};\n'
        "/* End PBXFileReference section */"
    )
    print("Added PBXFileReference entry")

# 3. New subgroup `upd7810` containing upd7810.cpp
subgroup_def = (
    f'\t\t{SUBGROUP_ID} /* upd7810 */ = {{\n'
    f'\t\t\tisa = PBXGroup;\n'
    f'\t\t\tchildren = (\n'
    f'\t\t\t\t{FILE_REF} /* {NAME} */,\n'
    f'\t\t\t);\n'
    f'\t\t\tpath = upd7810;\n'
    f'\t\t\tsourceTree = "<group>";\n'
    f'\t\t}};\n'
)
if f"{SUBGROUP_ID} /* upd7810 */ = {{" not in src:
    src = src.replace(
        "/* End PBXGroup section */",
        subgroup_def + "/* End PBXGroup section */"
    )
    print("Added upd7810 PBXGroup")

# 4. Reference the new subgroup from the cpu group.
cpu_child_entry = f"{SUBGROUP_ID} /* upd7810 */,"
if cpu_child_entry not in src:
    if CPU_GROUP_TAIL not in src:
        sys.exit(f"ERROR: cpu group anchor not found: {CPU_GROUP_TAIL!r}")
    src = src.replace(
        CPU_GROUP_TAIL,
        f"{CPU_GROUP_TAIL}\n\t\t\t\t{cpu_child_entry}",
        1
    )
    print("Added upd7810 to cpu group children")

# 5. PBXSourcesBuildPhase
sources_entry = f"{BUILD_FILE} /* {NAME} in Sources */,"
if sources_entry not in src:
    if SOURCES_ANCHOR not in src:
        sys.exit(f"ERROR: sources anchor not found: {SOURCES_ANCHOR!r}")
    src = src.replace(
        SOURCES_ANCHOR,
        f"{sources_entry}\n\t\t\t\t{SOURCES_ANCHOR}",
        1
    )
    print("Added PBXSourcesBuildPhase entry")

if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
