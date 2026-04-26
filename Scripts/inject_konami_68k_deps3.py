#!/usr/bin/env python3
"""Phase 28 — round 3 linker deps: Konami CPU, M6800, SN76496, K051649, K053260, K005289."""

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# (id_a, id_b, filename, full path from project root)
FILES = [
    # CPU cores
    ("K68KDEP009A", "K68KDEP009B", "konami.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/konami/konami.cpp"),
    ("K68KDEP010A", "K68KDEP010B", "m6800.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/m6800/m6800.cpp"),
    # Sound chips
    ("K68KDEP011A", "K68KDEP011B", "sn76496.cpp",
     "FBNeoCPSLib/fbneo/src/burn/snd/sn76496.cpp"),
    ("K68KDEP012A", "K68KDEP012B", "k051649.cpp",
     "FBNeoCPSLib/fbneo/src/burn/snd/k051649.cpp"),
    ("K68KDEP013A", "K68KDEP013B", "k053260.cpp",
     "FBNeoCPSLib/fbneo/src/burn/snd/k053260.cpp"),
    ("K68KDEP014A", "K68KDEP014B", "k005289.cpp",
     "FBNeoCPSLib/fbneo/src/burn/snd/k005289.cpp"),
]

SOURCES_ANCHOR = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"
SND_ANCHOR     = "KGXSND001A /* k054539.cpp */,"
CPU_ANCHOR     = "K68K_HD6309GRP00 /* hd6309 */,"

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()
original = src

for a, b, name, fullpath in FILES:
    if f"fileRef = {a}" not in src:
        src = src.replace(
            "/* End PBXBuildFile section */",
            f'\t\t\t{b} /* {name} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
            "/* End PBXBuildFile section */"
        )
    if f"{a} /* {name} */ = {{isa = PBXFileReference" not in src:
        src = src.replace(
            "/* End PBXFileReference section */",
            f'\t\t\t{a} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.cpp.cpp; '
            f'name = {name}; path = {fullpath}; sourceTree = SOURCE_ROOT; }};\n'
            "/* End PBXFileReference section */"
        )
    # Group placement
    is_snd = "burn/snd" in fullpath
    anchor  = SND_ANCHOR if is_snd else CPU_ANCHOR
    child_entry = f"{a} /* {name} */,"
    if child_entry not in src and anchor in src:
        src = src.replace(anchor, f"{anchor}\n\t\t\t\t{child_entry}", 1)
    # Sources build phase
    build_entry = f"{b} /* {name} in Sources */,"
    if build_entry not in src and SOURCES_ANCHOR in src:
        src = src.replace(
            SOURCES_ANCHOR,
            f"{build_entry}\n\t\t\t\t{SOURCES_ANCHOR}",
            1
        )
    print(f"Processed {name}")

if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
