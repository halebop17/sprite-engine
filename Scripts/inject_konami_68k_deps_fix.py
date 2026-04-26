#!/usr/bin/env python3
"""Fix the K68KDEP file references that inject_konami_68k_deps.py placed in
the wrong group, and add CPU subgroups / snd group wiring correctly.

CPU files (m6809, hd6309, mcs48) get their own subgroups under the cpu group.
Snd files (vlm5030, flt_rc, k007232) go into the existing snd group.
The K68KDEP entries are removed from the konami group children list.
"""

import re

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# anchors already established in the project
CPU_GROUP_TAIL   = "UPD7810CPU_GRP00 /* upd7810 */,"   # add CPU sub-groups after this
SND_ANCHOR       = "KGXSND001A /* k054539.cpp */,"      # add snd files after this in snd group
SOURCES_ANCHOR   = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"

CPU_FILES = [
    ("K68KDEP001A", "K68KDEP001B", "m6809.cpp",  "m6809",  "K68K_M6809_GRP00"),
    ("K68KDEP002A", "K68KDEP002B", "hd6309.cpp", "hd6309", "K68K_HD6309GRP00"),
    ("K68KDEP003A", "K68KDEP003B", "mcs48.cpp",  "i8x41",  "K68K_I8X41_GRP00"),
]

SND_FILES = [
    ("K68KDEP004A", "K68KDEP004B", "vlm5030.cpp"),
    ("K68KDEP005A", "K68KDEP005B", "flt_rc.cpp"),
    ("K68KDEP006A", "K68KDEP006B", "k007232.cpp"),
]

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()

original = src

# ── 1. Fix PBXFileReference path/sourceTree for every dep file ────────────────
# They were added with path = <basename>; sourceTree = "<group>" which resolves
# relative to the konami group — wrong for cpu and snd files.
# Fix: add name = <basename>; path = <full relative path>; sourceTree = SOURCE_ROOT

PATH_MAP = {
    "K68KDEP001A": "FBNeoCPSLib/fbneo/src/cpu/m6809/m6809.cpp",
    "K68KDEP002A": "FBNeoCPSLib/fbneo/src/cpu/hd6309/hd6309.cpp",
    "K68KDEP003A": "FBNeoCPSLib/fbneo/src/cpu/i8x41/mcs48.cpp",
    "K68KDEP004A": "FBNeoCPSLib/fbneo/src/burn/snd/vlm5030.cpp",
    "K68KDEP005A": "FBNeoCPSLib/fbneo/src/burn/snd/flt_rc.cpp",
    "K68KDEP006A": "FBNeoCPSLib/fbneo/src/burn/snd/k007232.cpp",
}

for a, fullpath in PATH_MAP.items():
    basename = fullpath.split("/")[-1]
    old = (f'{a} /* {basename} */ = {{isa = PBXFileReference; '
           f'lastKnownFileType = sourcecode.cpp.cpp; '
           f'path = {basename}; sourceTree = "<group>"; }};')
    new = (f'{a} /* {basename} */ = {{isa = PBXFileReference; '
           f'lastKnownFileType = sourcecode.cpp.cpp; '
           f'name = {basename}; path = {fullpath}; sourceTree = SOURCE_ROOT; }};')
    if old in src:
        src = src.replace(old, new)
        print(f"Fixed file reference for {basename}")
    elif f'sourceTree = SOURCE_ROOT' in src and a in src:
        print(f"{basename} already fixed")
    else:
        print(f"WARNING: could not find reference for {a} / {basename}")

# ── 2. Remove K68KDEP entries from the konami group children ─────────────────
for a, b, name, _, _ in CPU_FILES:
    bad_entry = f"{a} /* {name} */,\n\t\t\t\t"
    src = src.replace(bad_entry, "", 1)
for a, b, name in SND_FILES:
    bad_entry = f"{a} /* {name} */,\n\t\t\t\t"
    src = src.replace(bad_entry, "", 1)
print("Removed dep entries from konami group")

# ── 3. Create CPU subgroups and add to cpu group ──────────────────────────────
for file_a, file_b, name, dir_name, grp_id in CPU_FILES:
    # Create the subgroup
    subgroup_def = (
        f'\t\t{grp_id} /* {dir_name} */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t{file_a} /* {name} */,\n'
        f'\t\t\t);\n'
        f'\t\t\tname = {dir_name};\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};\n'
    )
    if f'{grp_id} /* {dir_name} */ = {{' not in src:
        src = src.replace(
            "/* End PBXGroup section */",
            subgroup_def + "/* End PBXGroup section */"
        )
        print(f"Created PBXGroup for {dir_name}")

    # Wire subgroup into the cpu group
    child_entry = f"{grp_id} /* {dir_name} */,"
    if child_entry not in src and CPU_GROUP_TAIL in src:
        src = src.replace(
            CPU_GROUP_TAIL,
            f"{CPU_GROUP_TAIL}\n\t\t\t\t{child_entry}",
            1
        )
        print(f"Added {dir_name} to cpu group")

# ── 4. Add snd files to the snd group ────────────────────────────────────────
for a, b, name in SND_FILES:
    child_entry = f"{a} /* {name} */,"
    if child_entry not in src and SND_ANCHOR in src:
        src = src.replace(
            SND_ANCHOR,
            f"{SND_ANCHOR}\n\t\t\t\t{child_entry}",
            1
        )
        print(f"Added {name} to snd group")

# ── 5. Write ──────────────────────────────────────────────────────────────────
if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
