// FBNeo generic driver bridge — loads any FBNeo driver by zip path.
// Shares BurnLib with fbneo_cps_bridge.cpp but manages its own loaded state.
// Only one bridge can have a game loaded at a time (enforced by Swift lifecycle).

#include "fbneo_driver_bridge.h"
#include "burnint.h"
#include "unzip.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <libgen.h>

#ifndef BZIP_MAX
#define BZIP_MAX 20
#endif
#ifndef DIRS_MAX
#define DIRS_MAX 20
#endif

// ── BurnHighCol (BGRA) ───────────────────────────────────────────────────────
// Each TU that calls BurnLibInit needs to register this callback.
// The CPS bridge has its own static copy; we define one here as well.
// Both register the same pixel format; whichever runs last wins (harmless).
static UINT32 __cdecl highcol_bgra(INT32 r, INT32 g, INT32 b, INT32)
{
    return 0xFF000000u | ((UINT32)(UINT8)r << 16) | ((UINT32)(UINT8)g << 8) | (UINT32)(UINT8)b;
}

// ── Static bridge state ───────────────────────────────────────────────────────

static uint32_t* s_videoBuf   = nullptr;
static int16_t*  s_audioBuf   = nullptr;
static int       s_frameW     = 0;
static int       s_frameH     = 0;
static bool      s_vertical   = false;
static bool      s_loaded     = false;
static bool      s_libInited  = false;

static uint32_t s_input[2]    = {0, 0};

struct InputSlot { UINT8* pVal; int player; uint32_t mask; };
static InputSlot s_slots[64];
static int       s_slotCount  = 0;

#define MAX_BRIDGE_ZIPS 4
static unzFile s_zips[MAX_BRIDGE_ZIPS];
static int     s_zipCount     = 0;

#define MAX_MISSING 64
static char s_missingNames[MAX_MISSING][64];
static int  s_missingCount    = 0;

// ── ROM loader callback ───────────────────────────────────────────────────────

static INT32 __cdecl rom_loader(UINT8* Dest, INT32* pnWrote, INT32 i)
{
    struct BurnRomInfo ri;
    memset(&ri, 0, sizeof(ri));
    if (BurnDrvGetRomInfo(&ri, i)) return 0;
    if (ri.nType == 0)             return 0;
    if (ri.nLen  <= 0)             return 1;

    char* romName = nullptr;
    BurnDrvGetRomName(&romName, i, 0);
    if (!romName || !romName[0])   return 1;

    for (int z = 0; z < s_zipCount; ++z) {
        if (!s_zips[z]) continue;
        if (unzLocateFile(s_zips[z], romName, 0) != UNZ_OK) continue;
        if (unzOpenCurrentFile(s_zips[z]) != UNZ_OK) continue;

        INT32 got = unzReadCurrentFile(s_zips[z], Dest, (unsigned)ri.nLen);
        unzCloseCurrentFile(s_zips[z]);

        if (got > 0) {
            if (pnWrote) *pnWrote = got;
            return 0;
        }
    }

    if (s_missingCount < MAX_MISSING) {
        strncpy(s_missingNames[s_missingCount], romName, 63);
        s_missingNames[s_missingCount][63] = '\0';
        ++s_missingCount;
    }
    return 1;
}

// ── Input enumeration ─────────────────────────────────────────────────────────

static bool parse_input(const char* szInfo, int* outPlayer, uint32_t* outMask)
{
    struct { const char* info; int pl; uint32_t mask; } table[] = {
        {"p1 up",     0, FBNEO_BTN_UP},   {"p1 down",   0, FBNEO_BTN_DOWN},
        {"p1 left",   0, FBNEO_BTN_LEFT}, {"p1 right",  0, FBNEO_BTN_RIGHT},
        {"p1 coin",   0, FBNEO_BTN_COIN}, {"p1 start",  0, FBNEO_BTN_START},
        {"p1 fire 1", 0, FBNEO_BTN_A},    {"p1 fire 2", 0, FBNEO_BTN_B},
        {"p1 fire 3", 0, FBNEO_BTN_C},    {"p1 fire 4", 0, FBNEO_BTN_D},
        {"p1 fire 5", 0, FBNEO_BTN_X},    {"p1 fire 6", 0, FBNEO_BTN_Y},

        {"p2 up",     1, FBNEO_BTN_UP},   {"p2 down",   1, FBNEO_BTN_DOWN},
        {"p2 left",   1, FBNEO_BTN_LEFT}, {"p2 right",  1, FBNEO_BTN_RIGHT},
        {"p2 coin",   1, FBNEO_BTN_COIN}, {"p2 start",  1, FBNEO_BTN_START},
        {"p2 fire 1", 1, FBNEO_BTN_A},    {"p2 fire 2", 1, FBNEO_BTN_B},
        {"p2 fire 3", 1, FBNEO_BTN_C},    {"p2 fire 4", 1, FBNEO_BTN_D},
        {"p2 fire 5", 1, FBNEO_BTN_X},    {"p2 fire 6", 1, FBNEO_BTN_Y},
    };
    for (auto& e : table) {
        if (strcmp(szInfo, e.info) == 0) {
            *outPlayer = e.pl;
            *outMask   = e.mask;
            return true;
        }
    }
    return false;
}

static void build_input_slots()
{
    s_slotCount = 0;
    struct BurnInputInfo ii;
    for (UINT32 idx = 0; ; ++idx) {
        memset(&ii, 0, sizeof(ii));
        if (BurnDrvGetInputInfo(&ii, idx)) break;
        if (ii.nType != BIT_DIGITAL) continue;
        if (!ii.pVal || !ii.szInfo)  continue;

        int      pl;
        uint32_t mask;
        if (!parse_input(ii.szInfo, &pl, &mask)) continue;
        if (s_slotCount >= 64) break;

        s_slots[s_slotCount++] = {ii.pVal, pl, mask};
        *ii.pVal = 0;
    }
}

// ── System string → constant ──────────────────────────────────────────────────

static int system_from_string(const char* sys)
{
    if (!sys) return FBNEO_SYSTEM_UNKNOWN;
    // CPS  (FBNeo driver strings: "CPS-1", "CPS-2")
    if (strncmp(sys, "CPS-1", 5) == 0 || strncmp(sys, "CPS1", 4) == 0) return FBNEO_SYSTEM_CPS1;
    if (strncmp(sys, "CPS-2", 5) == 0 || strncmp(sys, "CPS2", 4) == 0) return FBNEO_SYSTEM_CPS2;
    // Neo-Geo
    if (strncmp(sys, "Neo-Geo", 7) == 0 || strncmp(sys, "Neo Geo", 7) == 0) return FBNEO_SYSTEM_NEO_GEO;
    // Sega
    if (strncmp(sys, "Sega System 16", 14) == 0) return FBNEO_SYSTEM_SEGA_S16;
    if (strncmp(sys, "Sega System 18", 14) == 0) return FBNEO_SYSTEM_SEGA_S18;
    // Toaplan
    if (strncmp(sys, "Toaplan 1", 9) == 0 || strncmp(sys, "Toaplan Version 1", 17) == 0) return FBNEO_SYSTEM_TOAPLAN1;
    if (strncmp(sys, "Toaplan 2", 9) == 0 || strncmp(sys, "Toaplan Version 2", 17) == 0) return FBNEO_SYSTEM_TOAPLAN2;
    // Konami GX
    if (strncmp(sys, "Konami GX", 9) == 0) return FBNEO_SYSTEM_KONAMI_GX;
    // Irem (M72, M90, M92 etc. — all start with "Irem")
    if (strncmp(sys, "Irem", 4) == 0) return FBNEO_SYSTEM_IREM;
    // Taito (F2, F3, B, X etc. — all start with "Taito")
    if (strncmp(sys, "Taito", 5) == 0) return FBNEO_SYSTEM_TAITO;
    return FBNEO_SYSTEM_UNKNOWN;
}

// ── Public API ────────────────────────────────────────────────────────────────

void fbneo_driver_lib_init()
{
    if (!s_libInited) {
        BurnHighCol = highcol_bgra;
        nBurnLayer  = 0xFF;
        BurnLibInit();
        s_libInited = true;
    }
}

int fbneo_driver_identify(const char* name)
{
    if (!name || !name[0]) return FBNEO_SYSTEM_UNKNOWN;
    fbneo_driver_lib_init();

    INT32 idx = BurnDrvGetIndex(const_cast<char*>(name));
    if (idx < 0 || (UINT32)idx >= nBurnDrvCount) return FBNEO_SYSTEM_UNKNOWN;

    UINT32 prev = nBurnDrvActive;
    nBurnDrvActive = (UINT32)idx;
    char* sys = BurnDrvGetTextA(DRV_SYSTEM);
    int result = system_from_string(sys);
    nBurnDrvActive = prev;
    return result;
}

int fbneo_driver_load(const char* zipPath)
{
    if (s_loaded) fbneo_driver_unload();

    s_missingCount = 0;
    for (int z = 0; z < MAX_BRIDGE_ZIPS; ++z) {
        if (s_zips[z]) { unzClose(s_zips[z]); s_zips[z] = nullptr; }
    }
    s_zipCount = 0;

    fbneo_driver_lib_init();

    s_zips[0] = unzOpen(zipPath);
    if (!s_zips[0]) return 1;
    s_zipCount = 1;

    char pathBuf[1024];
    strncpy(pathBuf, zipPath, sizeof(pathBuf) - 1);
    char* dir = dirname(pathBuf);

    char nameBuf[1024];
    strncpy(nameBuf, zipPath, sizeof(nameBuf) - 1);
    char* base = basename(nameBuf);

    char gameName[256] = {};
    strncpy(gameName, base, sizeof(gameName) - 1);
    char* dot = strrchr(gameName, '.');
    if (dot) *dot = '\0';
    for (char* p = gameName; *p; ++p) *p = (char)tolower((unsigned char)*p);

    INT32 drvIdx = BurnDrvGetIndex(gameName);
    if (drvIdx < 0 || (UINT32)drvIdx >= nBurnDrvCount) {
        unzClose(s_zips[0]); s_zips[0] = nullptr; s_zipCount = 0;
        return 1;
    }
    nBurnDrvActive = (UINT32)drvIdx;

    for (UINT32 z = 1; z < BZIP_MAX && s_zipCount < MAX_BRIDGE_ZIPS; ++z) {
        char* sibName = nullptr;
        if (BurnDrvGetZipName(&sibName, z)) break;
        if (!sibName || !sibName[0])        break;
        if (strcmp(sibName, gameName) == 0) continue;

        char sibPath[1024];
        snprintf(sibPath, sizeof(sibPath), "%s/%s.zip", dir, sibName);
        unzFile sib = unzOpen(sibPath);
        if (sib) s_zips[s_zipCount++] = sib;
    }

    BurnHighCol     = highcol_bgra;
    BurnExtLoadRom  = rom_loader;
    nBurnLayer      = 0xFF;
    nBurnSoundRate  = 44100;
    pBurnSoundOut   = s_audioBuf;
    pBurnDraw       = reinterpret_cast<UINT8*>(s_videoBuf);
    nBurnBpp        = 4;
    nBurnPitch      = 512 * 4;

    if (BurnDrvInit()) {
        BurnExtLoadRom = nullptr;
        for (int z = 0; z < MAX_BRIDGE_ZIPS; ++z) {
            if (s_zips[z]) { unzClose(s_zips[z]); s_zips[z] = nullptr; }
        }
        s_zipCount = 0;
        return 1;
    }

    INT32 fw = 0, fh = 0;
    BurnDrvGetVisibleSize(&fw, &fh);
    if (fw <= 0 || fh <= 0) BurnDrvGetFullSize(&fw, &fh);
    if (fw <= 0) fw = 320;
    if (fh <= 0) fh = 224;
    s_frameW = fw;
    s_frameH = fh;
    nBurnPitch = s_frameW * 4;

    // Detect vertical orientation via driver flags.
    s_vertical = (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL) != 0;

    build_input_slots();
    s_loaded = true;
    return 0;
}

void fbneo_driver_unload()
{
    if (!s_loaded) return;
    BurnDrvExit();
    BurnExtLoadRom = nullptr;
    for (int z = 0; z < MAX_BRIDGE_ZIPS; ++z) {
        if (s_zips[z]) { unzClose(s_zips[z]); s_zips[z] = nullptr; }
    }
    s_zipCount  = 0;
    s_slotCount = 0;
    s_frameW    = 0;
    s_frameH    = 0;
    s_vertical  = false;
    s_loaded    = false;
}

int  fbneo_driver_is_loaded()      { return s_loaded   ? 1 : 0; }
int  fbneo_driver_frame_width()    { return s_frameW; }
int  fbneo_driver_frame_height()   { return s_frameH; }
int  fbneo_driver_is_vertical()    { return s_vertical ? 1 : 0; }
int  fbneo_driver_audio_sample_count() { return nBurnSoundLen; }

void fbneo_driver_set_video_buffer(uint32_t* buf)
{
    s_videoBuf = buf;
    if (s_loaded) pBurnDraw = reinterpret_cast<UINT8*>(buf);
}

void fbneo_driver_set_audio_buffer(int16_t* buf)
{
    s_audioBuf = buf;
    if (s_loaded) pBurnSoundOut = buf;
}

void fbneo_driver_set_input(int player, uint32_t buttons)
{
    if (player < 0 || player > 1) return;
    s_input[player] = buttons;
}

void fbneo_driver_run_frame()
{
    if (!s_loaded) return;
    for (int i = 0; i < s_slotCount; ++i) {
        InputSlot& sl = s_slots[i];
        *sl.pVal = (s_input[sl.player] & sl.mask) ? 0xFF : 0x00;
    }
    BurnDrvFrame();
}

void fbneo_driver_reset()
{
    if (!s_loaded) return;
    BurnDrvInit();
}

int fbneo_driver_missing_roms(char* buf, size_t bufSize)
{
    if (!buf || bufSize == 0) return s_missingCount;
    buf[0] = '\0';
    size_t pos = 0;
    for (int i = 0; i < s_missingCount && pos + 1 < bufSize; ++i) {
        size_t len = strlen(s_missingNames[i]);
        if (pos + len + 2 >= bufSize) break;
        memcpy(buf + pos, s_missingNames[i], len);
        pos += len;
        buf[pos++] = '\n';
    }
    if (pos > 0 && buf[pos - 1] == '\n') buf[pos - 1] = '\0';
    else buf[pos] = '\0';
    return s_missingCount;
}

int fbneo_driver_verify_game(const char* zipPath, FBNeoRomFile* outFiles, int maxFiles)
{
    if (!zipPath || !zipPath[0]) return -1;
    fbneo_driver_lib_init();

    char nameBuf[1024];
    strncpy(nameBuf, zipPath, sizeof(nameBuf) - 1);
    char* base = basename(nameBuf);

    char gameName[256] = {};
    strncpy(gameName, base, sizeof(gameName) - 1);
    char* dot = strrchr(gameName, '.');
    if (dot) *dot = '\0';
    for (char* p = gameName; *p; ++p) *p = (char)tolower((unsigned char)*p);

    INT32 drvIdx = BurnDrvGetIndex(gameName);
    if (drvIdx < 0 || (UINT32)drvIdx >= nBurnDrvCount) return -1;

    UINT32 prev = nBurnDrvActive;
    nBurnDrvActive = (UINT32)drvIdx;

    char pathBuf[1024];
    strncpy(pathBuf, zipPath, sizeof(pathBuf) - 1);
    char* dir = dirname(pathBuf);

    unzFile zips[MAX_BRIDGE_ZIPS] = {};
    int zipCount = 0;
    zips[0] = unzOpen(zipPath);
    if (zips[0]) zipCount = 1;

    for (UINT32 z = 1; z < BZIP_MAX && zipCount < MAX_BRIDGE_ZIPS; ++z) {
        char* sibName = nullptr;
        if (BurnDrvGetZipName(&sibName, z)) break;
        if (!sibName || !sibName[0])        break;
        if (strcmp(sibName, gameName) == 0) continue;
        char sibPath[1024];
        snprintf(sibPath, sizeof(sibPath), "%s/%s.zip", dir, sibName);
        unzFile sib = unzOpen(sibPath);
        if (sib) zips[zipCount++] = sib;
    }

    int slotCount = 0;
    struct BurnRomInfo ri;
    for (UINT32 i = 0; ; ++i) {
        memset(&ri, 0, sizeof(ri));
        if (BurnDrvGetRomInfo(&ri, i)) break;

        if (ri.nType == 0) {
            if (outFiles && slotCount < maxFiles) {
                char* rn = nullptr;
                BurnDrvGetRomName(&rn, i, 0);
                FBNeoRomFile& f = outFiles[slotCount];
                strncpy(f.name, (rn && rn[0]) ? rn : "(empty)", 63);
                f.name[63]    = '\0';
                f.status      = FBNEO_ROM_OPTIONAL;
                f.expectedCrc = 0;
                f.actualCrc   = 0;
            }
            slotCount++;
            continue;
        }

        char* romName = nullptr;
        BurnDrvGetRomName(&romName, i, 0);

        FBNeoRomFile entry = {};
        strncpy(entry.name, (romName && romName[0]) ? romName : "?", 63);
        entry.name[63]    = '\0';
        entry.expectedCrc = ri.nCrc;
        entry.status      = FBNEO_ROM_MISSING;

        for (int z = 0; z < zipCount && entry.status == FBNEO_ROM_MISSING; ++z) {
            if (!zips[z]) continue;
            if (unzLocateFile(zips[z], romName, 0) != UNZ_OK) continue;
            unz_file_info fi;
            memset(&fi, 0, sizeof(fi));
            if (unzGetCurrentFileInfo(zips[z], &fi, nullptr, 0, nullptr, 0, nullptr, 0) == UNZ_OK) {
                entry.actualCrc = fi.crc;
                entry.status    = (fi.crc == ri.nCrc) ? FBNEO_ROM_OK : FBNEO_ROM_WRONG_CRC;
            }
        }

        if (outFiles && slotCount < maxFiles) outFiles[slotCount] = entry;
        slotCount++;
    }

    for (int z = 0; z < zipCount; ++z)
        if (zips[z]) unzClose(zips[z]);

    nBurnDrvActive = prev;
    return slotCount;
}
