#!/usr/bin/env python3
"""Phase 28 — round 4 linker deps: M6800 intf, Konami CPU intf, watchdog."""

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

FILES = [
    ("K68KDEP015A", "K68KDEP015B", "m6800_intf.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/m6800_intf.cpp"),
    ("K68KDEP016A", "K68KDEP016B", "konami_intf.cpp",
     "FBNeoCPSLib/fbneo/src/cpu/konami_intf.cpp"),
    ("K68KDEP017A", "K68KDEP017B", "watchdog.cpp",
     "FBNeoCPSLib/fbneo/src/burn/devices/watchdog.cpp"),
]

SOURCES_ANCHOR = "KGXDRV001B /* d_mystwarr.cpp in Sources */,"
CPU_ANCHOR     = "K68K_HD6309GRP00 /* hd6309 */,"
DEV_ANCHOR     = "KGXDEV001A /* dtimer.cpp */,"

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
    is_device = "devices" in fullpath
    anchor = DEV_ANCHOR if is_device else CPU_ANCHOR
    child_entry = f"{a} /* {name} */,"
    if child_entry not in src and anchor in src:
        src = src.replace(anchor, f"{anchor}\n\t\t\t\t{child_entry}", 1)
    build_entry = f"{b} /* {name} in Sources */,"
    if build_entry not in src and SOURCES_ANCHOR in src:
        src = src.replace(SOURCES_ANCHOR, f"{build_entry}\n\t\t\t\t{SOURCES_ANCHOR}", 1)
    print(f"Processed {name}")

if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print("project.pbxproj updated.")
else:
    print("No changes needed.")
