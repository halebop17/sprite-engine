#!/usr/bin/env python3
"""Phase 27 follow-up — add Taito custom-chip .cpp files.

taito_ic.cpp is only a dispatcher; each chip lives in its own translation
unit. Without these, the linker reports undefined references for
TC0100SCN*, TC0220IOC*, cchip_*, mb87078_*, etc.

Files go into the correct PBXGroup directly (taito drv group, devices
group) so we don't repeat the konami-group mistake from earlier phases.
"""

import sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# (file_ref_id, build_file_id, filename, group_anchor_line)
# group_anchor_line: a unique substring inside the target PBXGroup's
# children list — the new entry is inserted just before it.
TAITO_GROUP_ANCHOR  = "TAITODRV001A /* d_taitof2.cpp */,"
DEVICE_GROUP_ANCHOR = "LDEP_NMK112_REF00 /* nmk112.cpp */,"

FILES = [
    # Taito custom chips — taito drv group
    ("TAITOCHP001A", "TAITOCHP001B", "cchip.cpp",     TAITO_GROUP_ANCHOR),
    ("TAITOCHP002A", "TAITOCHP002B", "pc080sn.cpp",   TAITO_GROUP_ANCHOR),
    ("TAITOCHP003A", "TAITOCHP003B", "pc090oj.cpp",   TAITO_GROUP_ANCHOR),
    ("TAITOCHP004A", "TAITOCHP004B", "tc0100scn.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP005A", "TAITOCHP005B", "tc0110pcr.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP006A", "TAITOCHP006B", "tc0140syt.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP007A", "TAITOCHP007B", "tc0150rod.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP008A", "TAITOCHP008B", "tc0180vcu.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP009A", "TAITOCHP009B", "tc0220ioc.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP010A", "TAITOCHP010B", "tc0280grd.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP011A", "TAITOCHP011B", "tc0360pri.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP012A", "TAITOCHP012B", "tc0480scp.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP013A", "TAITOCHP013B", "tc0510nio.cpp", TAITO_GROUP_ANCHOR),
    ("TAITOCHP014A", "TAITOCHP014B", "tc0640fio.cpp", TAITO_GROUP_ANCHOR),
    # mb87078 volume controller — devices group
    ("TAITOCHP015A", "TAITOCHP015B", "mb87078.cpp",   DEVICE_GROUP_ANCHOR),
]

SOURCES_ANCHOR = "TAITODRV001B /* d_taitof2.cpp in Sources */,"

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()
original = src

# 1. PBXBuildFile entries
build_lines = ""
for a, b, name, _ in FILES:
    if f"{b} /* {name} in Sources */ = {{isa = PBXBuildFile" not in src:
        build_lines += (
            f'\t\t\t{b} /* {name} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
        )
if build_lines:
    src = src.replace(
        "/* End PBXBuildFile section */",
        build_lines + "/* End PBXBuildFile section */"
    )
    print(f"Added {build_lines.count(chr(10))} PBXBuildFile entries")

# 2. PBXFileReference entries
ref_lines = ""
for a, b, name, _ in FILES:
    if f"{a} /* {name} */ = {{isa = PBXFileReference" not in src:
        ref_lines += (
            f'\t\t\t{a} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.cpp.cpp; '
            f'path = {name}; sourceTree = "<group>"; }};\n'
        )
if ref_lines:
    src = src.replace(
        "/* End PBXFileReference section */",
        ref_lines + "/* End PBXFileReference section */"
    )
    print(f"Added {ref_lines.count(chr(10))} PBXFileReference entries")

# 3. Group membership — taito group + devices group
for a, b, name, anchor in FILES:
    entry = f"{a} /* {name} */,"
    if entry in src:
        continue
    if anchor not in src:
        sys.exit(f"ERROR: anchor not found for {name}: {anchor!r}")
    src = src.replace(
        anchor,
        f"{entry}\n\t\t\t\t{anchor}",
        1
    )
print("Added PBXGroup membership entries")

# 4. PBXSourcesBuildPhase
for a, b, name, _ in FILES:
    entry = f"{b} /* {name} in Sources */,"
    if entry in src:
        continue
    if SOURCES_ANCHOR not in src:
        sys.exit(f"ERROR: sources anchor not found: {SOURCES_ANCHOR!r}")
    src = src.replace(
        SOURCES_ANCHOR,
        f"{entry}\n\t\t\t\t{SOURCES_ANCHOR}",
        1
    )
print("Added PBXSourcesBuildPhase entries")

if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
