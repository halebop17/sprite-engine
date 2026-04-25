#!/usr/bin/env python3
"""Fix Phase 24 injection — adds missing PBXBuildFile / PBXFileReference entries."""

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

FILES = [
    ("KGXDRV001A", "KGXDRV001B", "d_mystwarr.cpp", "konami"),
    ("KGXDRV002A", "KGXDRV002B", "d_moo.cpp",      "konami"),
    ("KGXSUP001A", "KGXSUP001B", "konamiic.cpp",   "konami"),
    ("KGXSUP002A", "KGXSUP002B", "konamigx.cpp",   "konami"),
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
    ("KGXSND001A", "KGXSND001B", "k054539.cpp",    "snd"),
    ("KGXDEV001A", "KGXDEV001B", "dtimer.cpp",     "devices"),
]

with open(PBXPROJ, encoding='utf-8') as f:
    src = f.read()

original = src

# ── 1. PBXBuildFile entries (3 tabs, no leading \t\t) ─────────────────────────
build_lines = ""
for a, b, name, _ in FILES:
    # Only add if fileRef = aGUID pattern is missing (means PBXBuildFile entry absent)
    marker = f"fileRef = {a}"
    if marker not in src:
        build_lines += f'\t\t\t{b} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'

if build_lines:
    src = src.replace(
        "/* End PBXBuildFile section */",
        build_lines + "/* End PBXBuildFile section */"
    )
    print(f"Added PBXBuildFile entries")

# ── 2. PBXFileReference entries ───────────────────────────────────────────────
ref_lines = ""
for a, b, name, _ in FILES:
    marker = f'{a} /* {name} */ = {{isa = PBXFileReference'
    if marker not in src:
        ref_lines += f'\t\t\t{a} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = {name}; sourceTree = "<group>"; }};\n'

if ref_lines:
    src = src.replace(
        "/* End PBXFileReference section */",
        ref_lines + "/* End PBXFileReference section */"
    )
    print(f"Added PBXFileReference entries")

# ── 3. Add dtimer.cpp to devices PBXGroup ────────────────────────────────────
if "KGXDEV001A /* dtimer.cpp */" not in src:
    src = src.replace(
        "\t\t\t\tB5824B35411FE6A1CB513000 /* eeprom.cpp */,\n\t\t\t\tAF0F41C4F16B26D6EEDD54BE",
        "\t\t\t\tB5824B35411FE6A1CB513000 /* eeprom.cpp */,\n\t\t\t\tKGXDEV001A /* dtimer.cpp */,\n\t\t\t\tAF0F41C4F16B26D6EEDD54BE"
    )
    print("Added dtimer.cpp to devices group")

# write
if src != original:
    with open(PBXPROJ, 'w', encoding='utf-8') as f:
        f.write(src)
    print("project.pbxproj updated")
else:
    print("No changes needed")
