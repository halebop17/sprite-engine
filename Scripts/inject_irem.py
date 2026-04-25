#!/usr/bin/env python3
"""Phase 26 — Irem M72 / M92 pbxproj injection.

Adds d_m72.cpp, d_m92.cpp, irem_cpu.cpp, iremga20.cpp (IremGA20 sound),
and pic8259.cpp (PIC interrupt controller for M92) to the FBNeoCPSLib target.

Also adds $(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/irem to
HEADER_SEARCH_PATHS so that irem_cpu.h resolves.
"""

import re, sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# ── file table ────────────────────────────────────────────────────────────────
# (fileID_A, buildID_B, filename, sub-path under fbneo/src)
FILES = [
    # drivers
    ("IREMDRV001A", "IREMDRV001B", "d_m72.cpp",     "burn/drv/irem"),
    ("IREMDRV002A", "IREMDRV002B", "d_m92.cpp",     "burn/drv/irem"),
    # Irem CPU aggregator
    ("IREMSUP001A", "IREMSUP001B", "irem_cpu.cpp",  "burn/drv/irem"),
    # sound chips
    ("IREMSND001A", "IREMSND001B", "iremga20.cpp",  "burn/snd"),
    # devices
    ("IREMDEV001A", "IREMDEV001B", "pic8259.cpp",   "burn/devices"),
]

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()

original = src

# ── 1. PBXBuildFile entries ───────────────────────────────────────────────────
build_lines = ""
for a, b, name, _ in FILES:
    if f"fileRef = {a}" not in src:
        build_lines += (
            f'\t\t\t{b} /* {name} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
        )

if build_lines:
    src = src.replace(
        "/* End PBXBuildFile section */",
        build_lines + "/* End PBXBuildFile section */"
    )
    print("Added PBXBuildFile entries")

# ── 2. PBXFileReference entries ───────────────────────────────────────────────
# Check the *full* PBXFileReference signature, not the bare token — step 1
# already inserted the bare token inside PBXBuildFile lines.
ref_lines = ""
for a, b, name, subpath in FILES:
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
    print("Added PBXFileReference entries")

# ── 3. Add files to FBNeoCPSLib PBXGroup ─────────────────────────────────────
# Anchor on the group-membership form (with trailing comma) — the bare token
# "KGXDRV001A /* d_mystwarr.cpp */" also appears inside PBXBuildFile and
# PBXFileReference entries, and a global replace would corrupt those.
anchor_ref = "KGXDRV001A /* d_mystwarr.cpp */,"
for a, b, name, _ in FILES:
    ref_entry = f"{a} /* {name} */,"
    if ref_entry not in src and anchor_ref in src:
        src = src.replace(
            anchor_ref,
            f"{a} /* {name} */,\n\t\t\t\t{anchor_ref}",
            1  # first occurrence only — group section
        )

print("Added PBXGroup membership entries")

# ── 4. Add files to PBXSourcesBuildPhase ────────────────────────────────────
# Anchor on the Sources-phase form (with trailing comma). Without the comma the
# token also appears in PBXBuildFile entries and a global replace corrupts them.
sources_anchor = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"
for a, b, name, _ in FILES:
    build_entry = f"{b} /* {name} in Sources */,"
    if build_entry not in src and sources_anchor in src:
        src = src.replace(
            sources_anchor,
            f"{b} /* {name} in Sources */,\n\t\t\t\t{sources_anchor}",
            1
        )

print("Added PBXSourcesBuildPhase entries")

# ── 5. Add drv/irem to HEADER_SEARCH_PATHS ───────────────────────────────────
irem_path = "$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/irem"
if irem_path not in src:
    # The header paths are set as a single long string; append before the closing "
    old_pattern = r'(HEADER_SEARCH_PATHS = ")(.*?)(";)'
    def add_irem_path(m):
        return m.group(1) + m.group(2) + f" {irem_path}" + m.group(3)
    new_src = re.sub(old_pattern, add_irem_path, src, flags=re.DOTALL)
    if new_src != src:
        src = new_src
        print("Added irem to HEADER_SEARCH_PATHS")
    else:
        print("WARNING: could not find HEADER_SEARCH_PATHS pattern to update")
else:
    print("irem already in HEADER_SEARCH_PATHS")

# ── 6. Write ──────────────────────────────────────────────────────────────────
if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
