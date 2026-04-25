#!/usr/bin/env python3
"""Phase 24 – Konami GX pbxproj injection.

Adds d_mystwarr.cpp, d_moo.cpp and all required Konami custom-chip files to
the FBNeoCPSLib Xcode target.  Also adds dtimer.cpp (needed by k054539.cpp)
and k054539.cpp (K054539 audio chip used by both GX drivers).

Additionally adds $(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/konami to
HEADER_SEARCH_PATHS (both Debug and Release) so that konamiic.h resolves.
"""

import re, sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# ── file table ────────────────────────────────────────────────────────────────
# (fileID_A, buildID_B, filename, group)
# group: "konami" | "snd" | "devices"
FILES = [
    # --- drivers ---
    ("KGXDRV001A", "KGXDRV001B", "d_mystwarr.cpp", "konami"),
    ("KGXDRV002A", "KGXDRV002B", "d_moo.cpp",      "konami"),
    # --- Konami IC aggregator + GX mixer ---
    ("KGXSUP001A", "KGXSUP001B", "konamiic.cpp",   "konami"),
    ("KGXSUP002A", "KGXSUP002B", "konamigx.cpp",   "konami"),
    # --- individual Konami custom chips ---
    ("KGXSUP003A", "KGXSUP003B", "k051960.cpp",    "konami"),
    ("KGXSUP004A", "KGXSUP004B", "k052109.cpp",    "konami"),
    ("KGXSUP005A", "KGXSUP005B", "k051316.cpp",    "konami"),
    ("KGXSUP006A", "KGXSUP006B", "k053245.cpp",    "konami"),
    ("KGXSUP007A", "KGXSUP007B", "k053247.cpp",    "konami"),
    ("KGXSUP008A", "KGXSUP008B", "k053936.cpp",    "konami"),
    ("KGXSUP009A", "KGXSUP009B", "k053250.cpp",    "konami"),
    ("KGXSUP010A", "KGXSUP010B", "k055555.cpp",    "konami"),
    ("KGXSUP011A", "KGXSUP011B", "k054338.cpp",    "konami"),
    ("KGXSUP012A", "KGXSUP012B", "k056832.cpp",    "konami"),
    ("KGXSUP013A", "KGXSUP013B", "k053251.cpp",    "konami"),
    ("KGXSUP014A", "KGXSUP014B", "k054000.cpp",    "konami"),
    # --- audio chip (snd group) ---
    ("KGXSND001A", "KGXSND001B", "k054539.cpp",    "snd"),
    # --- discrete timer (devices group) ---
    ("KGXDEV001A", "KGXDEV001B", "dtimer.cpp",     "devices"),
]

KONAMI_PATH = "$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/konami"

# ── load ──────────────────────────────────────────────────────────────────────
with open(PBXPROJ, encoding='utf-8') as f:
    src = f.read()

original = src  # for diff check at end

# ── 1. PBXBuildFile entries ───────────────────────────────────────────────────
build_file_lines = ""
for a, b, name, _ in FILES:
    entry = f'\t\t{b} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
    if b not in src:
        build_file_lines += entry

# Insert before the closing of the PBXBuildFile section
src = src.replace(
    "\t\t/* End PBXBuildFile section */",
    build_file_lines + "\t\t/* End PBXBuildFile section */"
)

# ── 2. PBXFileReference entries ───────────────────────────────────────────────
ref_lines = ""
for a, b, name, _ in FILES:
    entry = f'\t\t{a} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = {name}; sourceTree = "<group>"; }};\n'
    if a not in src:
        ref_lines += entry

src = src.replace(
    "\t\t/* End PBXFileReference section */",
    ref_lines + "\t\t/* End PBXFileReference section */"
)

# ── 3. PBXGroup – konami group ────────────────────────────────────────────────
konami_children = ""
for a, b, name, grp in FILES:
    if grp == "konami":
        konami_children += f'\t\t\t\t{a} /* {name} */,\n'

konami_group = f"""
\t\tKGX_KONAMI_GROUP000000 /* konami */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{konami_children}\t\t\t);
\t\t\tpath = konami;
\t\t\tsourceTree = "<group>";
\t\t}};"""

if "KGX_KONAMI_GROUP000000" not in src:
    # Insert after toaplan group
    src = src.replace(
        "\t\t\tpath = toaplan;\n\t\t\tsourceTree = \"<group>\";\n\t\t};",
        "\t\t\tpath = toaplan;\n\t\t\tsourceTree = \"<group>\";\n\t\t};" + konami_group
    )

# ── 4. Add konami group as child of drv group ─────────────────────────────────
if "KGX_KONAMI_GROUP000000" not in src or "A796D23D0C03E596CE900D35" not in src:
    print("WARNING: could not find drv group or konami group")
else:
    # Add konami + toaplan as children of drv group (A796D23D0C03E596CE900D35)
    # Find drv group and add konami child if not present
    drv_group_pattern = r'(A796D23D0C03E596CE900D35 /\* drv \*/ = \{[^}]*?children = \()'
    match = re.search(drv_group_pattern, src, re.DOTALL)
    if match:
        insert_pos = match.end()
        additions = ""
        if "TPLAN_GROUP000000000000" not in src[match.start():match.start()+500]:
            additions += "\n\t\t\t\tTPLAN_GROUP000000000000 /* toaplan */,"
        if "KGX_KONAMI_GROUP000000" not in src[match.start():match.start()+500]:
            additions += "\n\t\t\t\tKGX_KONAMI_GROUP000000 /* konami */,"
        if additions:
            src = src[:insert_pos] + additions + src[insert_pos:]

# ── 5. Add dtimer.cpp to devices group ───────────────────────────────────────
if "KGXDEV001A" not in src or "dtimer.cpp" not in src:
    print("WARNING: dtimer entry missing after step 2")
else:
    # Add to devices PBXGroup (AF9A9310E22F0E9879C06BF3)
    if "KGXDEV001A /* dtimer.cpp */" not in src:
        src = src.replace(
            "B5824B35411FE6A1CB513000 /* eeprom.cpp */,\n\t\t\t\tAF0F41C4F16B26D6EEDD54BE",
            "B5824B35411FE6A1CB513000 /* eeprom.cpp */,\n\t\t\t\tKGXDEV001A /* dtimer.cpp */,\n\t\t\t\tAF0F41C4F16B26D6EEDD54BE"
        )

# ── 6. Add k054539.cpp to snd group ──────────────────────────────────────────
if "KGXSND001A /* k054539.cpp */" not in src:
    src = src.replace(
        "TPYM3812AA /* burn_ym3812.cpp */,\n\t\t\t);\n\t\t\tpath = snd;",
        "TPYM3812AA /* burn_ym3812.cpp */,\n\t\t\t\tKGXSND001A /* k054539.cpp */,\n\t\t\t);\n\t\t\tpath = snd;"
    )

# ── 7. Add to Sources build phase (FBNeoCPSLib) ───────────────────────────────
sources_entries = ""
for a, b, name, _ in FILES:
    entry = f'\t\t\t\t{b} /* {name} in Sources */,\n'
    if b not in src:
        sources_entries += entry

# Insert before TMS32010AB in Sources (last Toaplan-era entry)
src = src.replace(
    "\t\t\t\tTMS32010AB /* tms32010.cpp in Sources */,",
    sources_entries + "\t\t\t\tTMS32010AB /* tms32010.cpp in Sources */,"
)

# ── 8. Update HEADER_SEARCH_PATHS (Debug + Release for FBNeoCPSLib) ──────────
OLD_PATH = "$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/sega"
NEW_PATH = f"$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/sega {KONAMI_PATH}"

src = src.replace(
    f'$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/sega $(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/snd',
    f'$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/sega {KONAMI_PATH} $(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/snd'
)

# ── write ─────────────────────────────────────────────────────────────────────
if src == original:
    print("WARNING: no changes made – check anchor strings")
    sys.exit(1)

with open(PBXPROJ, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"Done – {len(FILES)} files injected into project.pbxproj")
