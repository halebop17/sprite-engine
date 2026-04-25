#!/usr/bin/env python3
"""Phase 27 — Taito F2 / F3 pbxproj injection.

Adds d_taitof2.cpp, d_taitof3.cpp, taito.cpp (shared hw), taito_ic.cpp,
taitof3_snd.cpp, taitof3_video.cpp, and es5506.cpp (F3 sound) to the
FBNeoCPSLib target.

taito_m68705.cpp, burn_ym2610.cpp, burn_ym2203.cpp, and eeprom.cpp are
already in the project from earlier phases and are not re-added.
"""

import re, sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# ── file table ────────────────────────────────────────────────────────────────
FILES = [
    # drivers
    ("TAITODRV001A", "TAITODRV001B", "d_taitof2.cpp",   "burn/drv/taito"),
    ("TAITODRV002A", "TAITODRV002B", "d_taitof3.cpp",   "burn/drv/taito"),
    # shared Taito hardware layer
    ("TAITOSUP001A", "TAITOSUP001B", "taito.cpp",        "burn/drv/taito"),
    ("TAITOSUP002A", "TAITOSUP002B", "taito_ic.cpp",     "burn/drv/taito"),
    # F3 video / sound subsystems
    ("TAITOSUP003A", "TAITOSUP003B", "taitof3_snd.cpp",  "burn/drv/taito"),
    ("TAITOSUP004A", "TAITOSUP004B", "taitof3_video.cpp","burn/drv/taito"),
    # ES5506 sound chip (F3 era)
    ("TAITOSND001A", "TAITOSND001B", "es5506.cpp",       "burn/snd"),
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

# ── 3. PBXGroup membership ────────────────────────────────────────────────────
anchor_ref = "KGXDRV001A /* d_mystwarr.cpp */"
for a, b, name, _ in FILES:
    ref_entry = f"{a} /* {name} */,"
    if ref_entry not in src and anchor_ref in src:
        src = src.replace(
            anchor_ref,
            f"{a} /* {name} */,\n\t\t\t\t{anchor_ref}"
        )
print("Added PBXGroup membership entries")

# ── 4. PBXSourcesBuildPhase ───────────────────────────────────────────────────
sources_anchor = "KGXDRV001B /* d_mystwarr.cpp in Sources */"
for a, b, name, _ in FILES:
    build_entry = f"{b} /* {name} in Sources */,"
    if build_entry not in src and sources_anchor in src:
        src = src.replace(
            sources_anchor,
            f"{b} /* {name} in Sources */,\n\t\t\t\t{sources_anchor}"
        )
print("Added PBXSourcesBuildPhase entries")

# ── 5. Write ──────────────────────────────────────────────────────────────────
if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
