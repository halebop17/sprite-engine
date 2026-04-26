#!/usr/bin/env python3
"""Phase 28 follow-up — Konami 68K linker dependency injection.

Adds CPU cores and sound chips required by the 68K driver files:
  - m6809 / hd6309   CPU cores (Nemesis, Contra, many Z80-era games)
  - mcs48             Intel MCS-48 (8035/8041) CPU core
  - vlm5030           Konami VLM5030 speech synthesizer
  - flt_rc            RC filter (used by VLM5030 / analog audio)
  - k007232           Konami 007232 PCM sample player
"""

import re, sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

FBSRC = "$(SRCROOT)/FBNeoCPSLib/fbneo/src"

FILES = [
    # CPU cores
    ("K68KDEP001A", "K68KDEP001B", "m6809.cpp",   "cpu/m6809",   f"{FBSRC}/cpu/m6809"),
    ("K68KDEP002A", "K68KDEP002B", "hd6309.cpp",  "cpu/hd6309",  f"{FBSRC}/cpu/hd6309"),
    ("K68KDEP003A", "K68KDEP003B", "mcs48.cpp",   "cpu/i8x41",   f"{FBSRC}/cpu/i8x41"),
    # Sound chips
    ("K68KDEP004A", "K68KDEP004B", "vlm5030.cpp", "burn/snd",    f"{FBSRC}/burn/snd"),
    ("K68KDEP005A", "K68KDEP005B", "flt_rc.cpp",  "burn/snd",    f"{FBSRC}/burn/snd"),
    ("K68KDEP006A", "K68KDEP006B", "k007232.cpp", "burn/snd",    f"{FBSRC}/burn/snd"),
]

# (header_path, srcroot_relative)  — added to HEADER_SEARCH_PATHS
NEW_HEADER_PATHS = [
    f"{FBSRC}/cpu/m6809",
    f"{FBSRC}/cpu/hd6309",
    f"{FBSRC}/cpu/i8x41",
]

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()

original = src

# ── 1. PBXBuildFile entries ───────────────────────────────────────────────────
build_lines = ""
for a, b, name, _, _ in FILES:
    if f"fileRef = {a}" not in src:
        build_lines += (
            f'\t\t\t{b} /* {name} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
        )
if build_lines:
    src = src.replace("/* End PBXBuildFile section */",
                      build_lines + "/* End PBXBuildFile section */")
    print("Added PBXBuildFile entries")

# ── 2. PBXFileReference entries ───────────────────────────────────────────────
ref_lines = ""
for a, b, name, subpath, _ in FILES:
    if f"{a} /* {name} */ = {{isa = PBXFileReference" not in src:
        ref_lines += (
            f'\t\t\t{a} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.cpp.cpp; '
            f'path = {name}; sourceTree = "<group>"; }};\n'
        )
if ref_lines:
    src = src.replace("/* End PBXFileReference section */",
                      ref_lines + "/* End PBXFileReference section */")
    print("Added PBXFileReference entries")

# ── 3. Add to PBXGroup ────────────────────────────────────────────────────────
anchor_ref = "KGXDRV001A /* d_mystwarr.cpp */,"
for a, b, name, _, _ in FILES:
    ref_entry = f"{a} /* {name} */,"
    if ref_entry not in src and anchor_ref in src:
        src = src.replace(anchor_ref,
                          f"{a} /* {name} */,\n\t\t\t\t{anchor_ref}", 1)
print("Added PBXGroup entries")

# ── 4. Add to PBXSourcesBuildPhase ───────────────────────────────────────────
sources_anchor = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"
for a, b, name, _, _ in FILES:
    build_entry = f"{b} /* {name} in Sources */,"
    if build_entry not in src and sources_anchor in src:
        src = src.replace(sources_anchor,
                          f"{b} /* {name} in Sources */,\n\t\t\t\t{sources_anchor}", 1)
print("Added PBXSourcesBuildPhase entries")

# ── 5. Add new CPU header search paths ───────────────────────────────────────
old_pattern = r'(HEADER_SEARCH_PATHS = ")(.*?)(";)'
def add_paths(m):
    existing = m.group(2)
    additions = ""
    for p in NEW_HEADER_PATHS:
        if p not in existing:
            additions += f" {p}"
    return m.group(1) + existing + additions + m.group(3)

new_src = re.sub(old_pattern, add_paths, src, flags=re.DOTALL)
if new_src != src:
    src = new_src
    print("Updated HEADER_SEARCH_PATHS with CPU core dirs")

# ── 6. Write ──────────────────────────────────────────────────────────────────
if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
