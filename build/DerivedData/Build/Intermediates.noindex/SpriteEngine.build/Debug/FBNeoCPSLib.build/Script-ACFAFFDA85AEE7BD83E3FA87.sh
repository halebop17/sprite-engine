#!/bin/sh
set -e
SRCROOT_FBNEO="${SRCROOT}/FBNeoCPSLib/fbneo/src"
GENDIR="${SRCROOT_FBNEO}/dep/generated"
CAPCOM="${SRCROOT_FBNEO}/burn/drv/capcom"
mkdir -p "${GENDIR}"

# m68kops.c — regenerate if source is newer
if [ "${SRCROOT_FBNEO}/cpu/m68k/m68k_in.c" -nt "${GENDIR}/m68kops.c" ]; then
  clang "${SRCROOT_FBNEO}/cpu/m68k/m68kmake.c" -o "${GENDIR}/m68kmake"
  "${GENDIR}/m68kmake" "${GENDIR}" "${SRCROOT_FBNEO}/cpu/m68k/m68k_in.c"
fi

# ctv.h — regenerate if make source is newer
if [ "${CAPCOM}/ctv_make.cpp" -nt "${CAPCOM}/ctv.h" ]; then
  clang++ "${CAPCOM}/ctv_make.cpp" -o "${GENDIR}/ctv_make"
  "${GENDIR}/ctv_make" > "${CAPCOM}/ctv.h"
fi

# driverlist.h — generate CPS-1/2 driver list if missing
if [ ! -f "${GENDIR}/driverlist.h" ]; then
  python3 "${SRCROOT}/Scripts/generate_driverlist.py"
fi

