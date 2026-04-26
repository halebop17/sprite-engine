#!/usr/bin/env python3
"""Phase 28 — Konami 68K / full Konami roster pbxproj injection.

Adds all Konami System 68K, Twin 16, and Z80-era driver files plus
the chip support files that are not yet in the project (k007121,
k007342_k007420, k007452, timeplt_snd).
"""

import re, sys

PBXPROJ = "/Volumes/Media 2TB/git repos 2/sprite-engine/SpriteEngine.xcodeproj/project.pbxproj"

# ── file table ────────────────────────────────────────────────────────────────
# (fileID_A, buildID_B, filename, sub-path under fbneo/src)
FILES = [
    # ── Konami System 68K: beat-em-ups & run-n-guns ───────────────────────────
    ("K68KDRV001A", "K68KDRV001B", "d_tmnt.cpp",      "burn/drv/konami"),
    ("K68KDRV002A", "K68KDRV002B", "d_simpsons.cpp",  "burn/drv/konami"),
    ("K68KDRV003A", "K68KDRV003B", "d_xmen.cpp",      "burn/drv/konami"),
    ("K68KDRV004A", "K68KDRV004B", "d_aliens.cpp",    "burn/drv/konami"),
    ("K68KDRV005A", "K68KDRV005B", "d_vendetta.cpp",  "burn/drv/konami"),
    ("K68KDRV006A", "K68KDRV006B", "d_contra.cpp",    "burn/drv/konami"),
    ("K68KDRV007A", "K68KDRV007B", "d_gijoe.cpp",     "burn/drv/konami"),
    ("K68KDRV008A", "K68KDRV008B", "d_crimfght.cpp",  "burn/drv/konami"),
    ("K68KDRV009A", "K68KDRV009B", "d_asterix.cpp",   "burn/drv/konami"),
    ("K68KDRV010A", "K68KDRV010B", "d_dbz.cpp",       "burn/drv/konami"),
    ("K68KDRV011A", "K68KDRV011B", "d_lethal.cpp",    "burn/drv/konami"),
    ("K68KDRV012A", "K68KDRV012B", "d_gbusters.cpp",  "burn/drv/konami"),
    ("K68KDRV013A", "K68KDRV013B", "d_hcastle.cpp",   "burn/drv/konami"),
    ("K68KDRV014A", "K68KDRV014B", "d_battlnts.cpp",  "burn/drv/konami"),
    ("K68KDRV015A", "K68KDRV015B", "d_ajax.cpp",      "burn/drv/konami"),
    ("K68KDRV016A", "K68KDRV016B", "d_thunderx.cpp",  "burn/drv/konami"),
    ("K68KDRV017A", "K68KDRV017B", "d_surpratk.cpp",  "burn/drv/konami"),
    ("K68KDRV018A", "K68KDRV018B", "d_jackal.cpp",    "burn/drv/konami"),
    ("K68KDRV019A", "K68KDRV019B", "d_mainevt.cpp",   "burn/drv/konami"),
    ("K68KDRV020A", "K68KDRV020B", "d_bladestl.cpp",  "burn/drv/konami"),
    ("K68KDRV021A", "K68KDRV021B", "d_bottom9.cpp",   "burn/drv/konami"),
    ("K68KDRV022A", "K68KDRV022B", "d_blockhl.cpp",   "burn/drv/konami"),
    ("K68KDRV023A", "K68KDRV023B", "d_rollerg.cpp",   "burn/drv/konami"),
    ("K68KDRV024A", "K68KDRV024B", "d_flkatck.cpp",   "burn/drv/konami"),
    ("K68KDRV025A", "K68KDRV025B", "d_hexion.cpp",    "burn/drv/konami"),
    ("K68KDRV026A", "K68KDRV026B", "d_parodius.cpp",  "burn/drv/konami"),
    ("K68KDRV027A", "K68KDRV027B", "d_xexex.cpp",     "burn/drv/konami"),
    # ── Twin 16 (dual-68K shooters) ───────────────────────────────────────────
    ("K68KDRV028A", "K68KDRV028B", "d_gradius3.cpp",  "burn/drv/konami"),
    ("K68KDRV029A", "K68KDRV029B", "d_twin16.cpp",    "burn/drv/konami"),
    # ── Z80-era Konami ────────────────────────────────────────────────────────
    ("K68KDRV030A", "K68KDRV030B", "d_nemesis.cpp",   "burn/drv/konami"),
    ("K68KDRV031A", "K68KDRV031B", "d_timeplt.cpp",   "burn/drv/konami"),
    ("K68KDRV032A", "K68KDRV032B", "d_trackfld.cpp",  "burn/drv/konami"),
    ("K68KDRV033A", "K68KDRV033B", "d_hyperspt.cpp",  "burn/drv/konami"),
    ("K68KDRV034A", "K68KDRV034B", "d_megazone.cpp",  "burn/drv/konami"),
    ("K68KDRV035A", "K68KDRV035B", "d_gyruss.cpp",    "burn/drv/konami"),
    ("K68KDRV036A", "K68KDRV036B", "d_circusc.cpp",   "burn/drv/konami"),
    ("K68KDRV037A", "K68KDRV037B", "d_mikie.cpp",     "burn/drv/konami"),
    ("K68KDRV038A", "K68KDRV038B", "d_pingpong.cpp",  "burn/drv/konami"),
    ("K68KDRV039A", "K68KDRV039B", "d_tp84.cpp",      "burn/drv/konami"),
    ("K68KDRV040A", "K68KDRV040B", "d_yiear.cpp",     "burn/drv/konami"),
    ("K68KDRV041A", "K68KDRV041B", "d_labyrunr.cpp",  "burn/drv/konami"),
    ("K68KDRV042A", "K68KDRV042B", "d_rockrage.cpp",  "burn/drv/konami"),
    ("K68KDRV043A", "K68KDRV043B", "d_ironhors.cpp",  "burn/drv/konami"),
    ("K68KDRV044A", "K68KDRV044B", "d_jailbrek.cpp",  "burn/drv/konami"),
    ("K68KDRV045A", "K68KDRV045B", "d_finalzr.cpp",   "burn/drv/konami"),
    ("K68KDRV046A", "K68KDRV046B", "d_rocnrope.cpp",  "burn/drv/konami"),
    ("K68KDRV047A", "K68KDRV047B", "d_shaolins.cpp",  "burn/drv/konami"),
    ("K68KDRV048A", "K68KDRV048B", "d_junofrst.cpp",  "burn/drv/konami"),
    ("K68KDRV049A", "K68KDRV049B", "d_tutankhm.cpp",  "burn/drv/konami"),
    ("K68KDRV050A", "K68KDRV050B", "d_pooyan.cpp",    "burn/drv/konami"),
    ("K68KDRV051A", "K68KDRV051B", "d_gberet.cpp",    "burn/drv/konami"),
    ("K68KDRV052A", "K68KDRV052B", "d_pandoras.cpp",  "burn/drv/konami"),
    ("K68KDRV053A", "K68KDRV053B", "d_ddribble.cpp",  "burn/drv/konami"),
    ("K68KDRV054A", "K68KDRV054B", "d_88games.cpp",   "burn/drv/konami"),
    ("K68KDRV055A", "K68KDRV055B", "d_fastlane.cpp",  "burn/drv/konami"),
    ("K68KDRV056A", "K68KDRV056B", "d_chqflag.cpp",   "burn/drv/konami"),
    ("K68KDRV057A", "K68KDRV057B", "d_spy.cpp",       "burn/drv/konami"),
    ("K68KDRV058A", "K68KDRV058B", "d_wecleman.cpp",  "burn/drv/konami"),
    ("K68KDRV059A", "K68KDRV059B", "d_combatsc.cpp",  "burn/drv/konami"),
    ("K68KDRV060A", "K68KDRV060B", "d_sbasketb.cpp",  "burn/drv/konami"),
    ("K68KDRV061A", "K68KDRV061B", "d_scotrsht.cpp",  "burn/drv/konami"),
    ("K68KDRV062A", "K68KDRV062B", "d_divebomb.cpp",  "burn/drv/konami"),
    ("K68KDRV063A", "K68KDRV063B", "d_mogura.cpp",    "burn/drv/konami"),
    ("K68KDRV064A", "K68KDRV064B", "d_kontest.cpp",   "burn/drv/konami"),
    ("K68KDRV065A", "K68KDRV065B", "d_ultraman.cpp",  "burn/drv/konami"),
    ("K68KDRV066A", "K68KDRV066B", "d_bishi.cpp",     "burn/drv/konami"),
    # ── Chip support files not yet compiled ───────────────────────────────────
    ("K68KSUP001A", "K68KSUP001B", "k007121.cpp",           "burn/drv/konami"),
    ("K68KSUP002A", "K68KSUP002B", "k007342_k007420.cpp",   "burn/drv/konami"),
    ("K68KSUP003A", "K68KSUP003B", "k007452.cpp",           "burn/drv/konami"),
    ("K68KSUP004A", "K68KSUP004B", "timeplt_snd.cpp",       "burn/drv/konami"),
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

# ── 3. Add files to FBNeoCPSLib PBXGroup ─────────────────────────────────────
anchor_ref = "KGXDRV001A /* d_mystwarr.cpp */,"
for a, b, name, _ in FILES:
    ref_entry = f"{a} /* {name} */,"
    if ref_entry not in src and anchor_ref in src:
        src = src.replace(
            anchor_ref,
            f"{a} /* {name} */,\n\t\t\t\t{anchor_ref}",
            1
        )

print("Added PBXGroup membership entries")

# ── 4. Add files to PBXSourcesBuildPhase ─────────────────────────────────────
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

# ── 5. Write ──────────────────────────────────────────────────────────────────
if src != original:
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(src)
    print(f"project.pbxproj updated — {len(FILES)} files injected.")
else:
    print("No changes needed.")
