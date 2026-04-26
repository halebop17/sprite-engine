#!/usr/bin/env python3
import os, sys

srcroot = os.environ.get('SRCROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
fbsrc   = f"{srcroot}/FBNeoCPSLib/fbneo/src"
capcom  = f"{fbsrc}/burn/drv/capcom"
sega    = f"{fbsrc}/burn/drv/sega"
toaplan = f"{fbsrc}/burn/drv/toaplan"
konami  = f"{fbsrc}/burn/drv/konami"
irem    = f"{fbsrc}/burn/drv/irem"
taito   = f"{fbsrc}/burn/drv/taito"
gendir  = f"{fbsrc}/dep/generated"

os.makedirs(gendir, exist_ok=True)

driver_files = [
    (capcom,  "d_cps1.cpp"),
    (capcom,  "d_cps2.cpp"),
    (sega,    "d_sys16a.cpp"),
    (sega,    "d_sys16b.cpp"),
    (sega,    "d_sys18.cpp"),
    (sega,    "d_hangon.cpp"),
    (sega,    "d_outrun.cpp"),
    (sega,    "d_xbrd.cpp"),
    (sega,    "d_ybrd.cpp"),
    # Toaplan 1
    (toaplan, "d_toaplan1.cpp"),
    (toaplan, "d_twincobr.cpp"),
    (toaplan, "d_wardner.cpp"),
    (toaplan, "d_ghox.cpp"),
    (toaplan, "d_slapfght.cpp"),
    (toaplan, "d_pipibibs.cpp"),
    # Toaplan 2
    (toaplan, "d_truxton2.cpp"),
    (toaplan, "d_batsugun.cpp"),
    (toaplan, "d_vfive.cpp"),
    (toaplan, "d_dogyuun.cpp"),
    (toaplan, "d_kbash.cpp"),
    (toaplan, "d_kbash2.cpp"),
    (toaplan, "d_shippumd.cpp"),
    (toaplan, "d_mahoudai.cpp"),
    (toaplan, "d_batrider.cpp"),
    (toaplan, "d_bbakraid.cpp"),
    (toaplan, "d_battleg.cpp"),
    (toaplan, "d_snowbro2.cpp"),
    (toaplan, "d_tekipaki.cpp"),
    (toaplan, "d_fixeight.cpp"),
    (toaplan, "d_enmadaio.cpp"),
    # Konami GX 32-bit (Phase 24)
    (konami,  "d_mystwarr.cpp"),
    (konami,  "d_moo.cpp"),
    # Konami System 68K — beat-em-ups & run-n-guns (Phase 28)
    (konami,  "d_tmnt.cpp"),
    (konami,  "d_simpsons.cpp"),
    (konami,  "d_xmen.cpp"),
    (konami,  "d_aliens.cpp"),
    (konami,  "d_vendetta.cpp"),
    (konami,  "d_contra.cpp"),
    (konami,  "d_gijoe.cpp"),
    (konami,  "d_crimfght.cpp"),
    (konami,  "d_asterix.cpp"),
    (konami,  "d_dbz.cpp"),
    (konami,  "d_lethal.cpp"),
    (konami,  "d_gbusters.cpp"),
    (konami,  "d_hcastle.cpp"),
    (konami,  "d_battlnts.cpp"),
    (konami,  "d_ajax.cpp"),
    (konami,  "d_thunderx.cpp"),
    (konami,  "d_surpratk.cpp"),
    (konami,  "d_jackal.cpp"),
    (konami,  "d_mainevt.cpp"),
    (konami,  "d_bladestl.cpp"),
    (konami,  "d_bottom9.cpp"),
    (konami,  "d_blockhl.cpp"),
    (konami,  "d_rollerg.cpp"),
    (konami,  "d_flkatck.cpp"),
    (konami,  "d_hexion.cpp"),
    (konami,  "d_parodius.cpp"),
    (konami,  "d_xexex.cpp"),
    # Konami Twin 16 dual-68K (Phase 28)
    (konami,  "d_gradius3.cpp"),
    (konami,  "d_twin16.cpp"),
    # Konami Z80-era (Phase 28)
    (konami,  "d_nemesis.cpp"),
    (konami,  "d_timeplt.cpp"),
    (konami,  "d_trackfld.cpp"),
    (konami,  "d_hyperspt.cpp"),
    (konami,  "d_megazone.cpp"),
    (konami,  "d_gyruss.cpp"),
    (konami,  "d_circusc.cpp"),
    (konami,  "d_mikie.cpp"),
    (konami,  "d_pingpong.cpp"),
    (konami,  "d_tp84.cpp"),
    (konami,  "d_yiear.cpp"),
    (konami,  "d_labyrunr.cpp"),
    (konami,  "d_rockrage.cpp"),
    (konami,  "d_ironhors.cpp"),
    (konami,  "d_jailbrek.cpp"),
    (konami,  "d_finalzr.cpp"),
    (konami,  "d_rocnrope.cpp"),
    (konami,  "d_shaolins.cpp"),
    (konami,  "d_junofrst.cpp"),
    (konami,  "d_tutankhm.cpp"),
    (konami,  "d_pooyan.cpp"),
    (konami,  "d_gberet.cpp"),
    (konami,  "d_pandoras.cpp"),
    (konami,  "d_ddribble.cpp"),
    (konami,  "d_88games.cpp"),
    (konami,  "d_fastlane.cpp"),
    (konami,  "d_chqflag.cpp"),
    (konami,  "d_spy.cpp"),
    (konami,  "d_wecleman.cpp"),
    (konami,  "d_combatsc.cpp"),
    (konami,  "d_sbasketb.cpp"),
    (konami,  "d_scotrsht.cpp"),
    (konami,  "d_divebomb.cpp"),
    (konami,  "d_mogura.cpp"),
    (konami,  "d_kontest.cpp"),
    (konami,  "d_ultraman.cpp"),
    (konami,  "d_bishi.cpp"),
    # Irem M72 / M92
    (irem,    "d_m72.cpp"),
    (irem,    "d_m92.cpp"),
    # Taito F2 / F3
    (taito,   "d_taitof2.cpp"),
    (taito,   "d_taitof3.cpp"),
]

entries = []
for directory, drv in driver_files:
    with open(f"{directory}/{drv}", encoding='utf-8', errors='replace') as f:
        for line in f:
            if line.startswith("struct BurnDriver"):
                name = line.split()[2]
                entries.append(name)

lines = ["// Auto-generated driverlist.h — CPS-1/2 + Sega + Toaplan + Konami (all) + Irem + Taito\n", "#include <wchar.h>\n\n"]
for n in entries:
    lines.append(f"extern struct BurnDriver {n};\n")
lines.append("\nstatic struct BurnDriver* pDriver[] = {\n")
for n in entries:
    lines.append(f"\t&{n},\n")
lines.append("};\n\nstruct game_sourcefile_entry { char game_name[32]; char sourcefile[32]; };\n")
lines.append('static game_sourcefile_entry sourcefile_table[] = { { "", "" } };\n')

with open(f"{gendir}/driverlist.h", 'w') as f:
    f.writelines(lines)
print(f"Generated driverlist.h with {len(entries)} entries")
