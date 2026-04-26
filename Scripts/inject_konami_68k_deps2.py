#!/usr/bin/env python3
"""Phase 28 — round 2 linker deps: m6809_intf.cpp and hd6309_intf.cpp."""

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

FILES = [
    ("K68KDEP007A", "K68KDEP007B", "m6809_intf.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/m6809_intf.cpp"),
    ("K68KDEP008A", "K68KDEP008B", "hd6309_intf.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/hd6309_intf.cpp"),
]

SOURCES_ANCHOR = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"
CPU_ANCHOR     = "K68K_HD6309GRP00 /* hd6309 */,"

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()
original = src

for a, b, name, fullpath in FILES:
    # PBXBuildFile
    if f"fileRef = {a}" not in src:
        src = src.replace(
            "/* End PBXBuildFile section */",
            f'\t\t\t{b} /* {name} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {a} /* {name} */; }};\n'
            "/* End PBXBuildFile section */"
        )
    # PBXFileReference (SOURCE_ROOT absolute path)
    if f"{a} /* {name} */ = {{isa = PBXFileReference" not in src:
        src = src.replace(
            "/* End PBXFileReference section */",
            f'\t\t\t{a} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.cpp.cpp; '
            f'name = {name}; path = {fullpath}; sourceTree = SOURCE_ROOT; }};\n'
            "/* End PBXFileReference section */"
        )
    # PBXGroup — attach to cpu group tail
    if f"{a} /* {name} */," not in src and CPU_ANCHOR in src:
        src = src.replace(
            CPU_ANCHOR,
            f"{CPU_ANCHOR}\n\t\t\t\t{a} /* {name} */,",
            1
        )
    # Sources build phase
    if f"{b} /* {name} in Sources */," not in src and SOURCES_ANCHOR in src:
        src = src.replace(
            SOURCES_ANCHOR,
            f"{b} /* {name} in Sources */,\n\t\t\t\t{SOURCES_ANCHOR}",
            1
        )
    print(f"Processed {name}")

if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
