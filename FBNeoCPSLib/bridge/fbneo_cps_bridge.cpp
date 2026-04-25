// FBNeo CPS-1/2 bridge — wraps the burn library with a pure-C API.
// Provides ROM loading (minizip), video/audio output, and digital input.

#include "fbneo_cps_bridge.h"
#include "burnint.h"   // burn internal API (includes burn.h)
#include "unzip.h"     // minizip

// Constants defined in burner.h but we avoid including that header.
#ifndef DIRS_MAX
#define DIRS_MAX 20
#endif
#ifndef BZIP_MAX
#define BZIP_MAX 20
#endif

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>     // tolower
#include <libgen.h>    // dirname / basename

// ── Globals required by the burn library ─────────────────────────────────
// Declared extern in burn.h; defined here since we supply no burner front-end.

TCHAR szAppHiscorePath[MAX_PATH]  = _T("");
TCHAR szAppSamplesPath[MAX_PATH]  = _T("");
TCHAR szAppHDDPath[MAX_PATH]      = _T("");
TCHAR szAppBlendPath[MAX_PATH]    = _T("");
TCHAR szAppEEPROMPath[MAX_PATH]   = _T("");

// IPS patch support — disabled; stubs satisfy linker.
bool   bDoIpsPatch              = false;
UINT32 nIpsDrvDefine            = 0;
UINT32 nIpsMemExpLen[SND2_ROM + 1] = {};

void IpsApplyPatches(UINT8*, char*, UINT32, bool) {}

// szAppRomPaths — only needed by the bzip front-end (not compiled here),
// but provided in case any translation unit pulls in burner_macos.h.
char szAppRomPaths[DIRS_MAX][MAX_PATH] = {};

// nAppVirtualFps, bRunPause — referenced by some burner_macos.h headers.
int  nAppVirtualFps             = 60;
bool bRunPause                  = false;
bool bAlwaysProcessKeyboardInput = false;

// ZipLoadOneFile stub — samples.cpp forward-declares this with C++ linkage.
// CPS games don't use external WAV samples; return failure silently.
INT32 __cdecl ZipLoadOneFile(char*, const char*, void**, INT32* pnWrote)
{
    if (pnWrote) *pnWrote = 0;
    return 1;
}

// ── BurnHighCol ───────────────────────────────────────────────────────────
// Convert r,g,b (0-255) to 32-bit BGRA (0xFF in alpha, native endian).
// This matches the MTLPixelFormatBGRA8Unorm texture format used by Metal.
static UINT32 __cdecl highcol_bgra(INT32 r, INT32 g, INT32 b, INT32)
{
    return 0xFF000000u | ((UINT32)(UINT8)r << 16) | ((UINT32)(UINT8)g << 8) | (UINT32)(UINT8)b;
}

// ── BurnLib shared init ───────────────────────────────────────────────────
// BurnLibInit() must be called EXACTLY ONCE per process; calling it a second
// time triggers BurnLibExit() internally, which frees per-driver string copies
// and corrupts the driver list.  Always delegate to fbneo_driver_lib_init() in
// fbneo_driver_bridge.cpp — it owns the single process-wide s_libInited guard.
extern "C" void fbneo_driver_lib_init();

// ── Static bridge state ───────────────────────────────────────────────────

static uint32_t* s_videoBuf   = nullptr;
static int16_t*  s_audioBuf   = nullptr;
static int       s_frameW     = 0;
static int       s_frameH     = 0;
static bool      s_loaded     = false;

// Player input state (bitmask using our button layout).
static uint32_t s_input[2]    = {0, 0};

// Cached pointers into the driver's input bytes + associated button mask.
struct InputSlot {
    UINT8*   pVal;
    int      player; // 0 or 1
    uint32_t mask;   // our button bit
};
static InputSlot s_slots[64];
static int       s_slotCount = 0;

// Open zip handles (primary + parent ROMs).
#define MAX_BRIDGE_ZIPS 4
static unzFile s_zips[MAX_BRIDGE_ZIPS];
static int     s_zipCount = 0;

// Missing-ROM tracking (populated by rom_loader on cache miss).
#define MAX_MISSING 64
static char  s_missingNames[MAX_MISSING][64];
static int   s_missingCount = 0;

// ── ROM loader callback ───────────────────────────────────────────────────

static INT32 __cdecl rom_loader(UINT8* Dest, INT32* pnWrote, INT32 i)
{
    struct BurnRomInfo ri;
    memset(&ri, 0, sizeof(ri));
    if (BurnDrvGetRomInfo(&ri, i)) return 0;    // empty slot = success
    if (ri.nType == 0)              return 0;
    if (ri.nLen  <= 0)              return 1;

    char* romName = nullptr;
    BurnDrvGetRomName(&romName, i, 0);
    if (!romName || !romName[0])    return 1;

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

    // Record this missing file for diagnostic reporting.
    if (s_missingCount < MAX_MISSING) {
        strncpy(s_missingNames[s_missingCount], romName, 63);
        s_missingNames[s_missingCount][63] = '\0';
        ++s_missingCount;
    }
    return 1; // not found in any zip
}

// ── Input enumeration ─────────────────────────────────────────────────────
// Button bit layout (shared with Swift side):
//  0=up  1=down  2=left  3=right  4=coin  5=start
//  6=A   7=B     8=C     9=D
#define BTN_UP    (1u <<  0)
#define BTN_DOWN  (1u <<  1)
#define BTN_LEFT  (1u <<  2)
#define BTN_RIGHT (1u <<  3)
#define BTN_COIN  (1u <<  4)
#define BTN_START (1u <<  5)
#define BTN_A     (1u <<  6)
#define BTN_B     (1u <<  7)
#define BTN_C     (1u <<  8)
#define BTN_D     (1u <<  9)

// Map a BurnInputInfo szInfo string to our button mask and player index.
// Returns false if this entry is not one we care about.
static bool parse_input(const char* szInfo, int* outPlayer, uint32_t* outMask)
{
    struct { const char* info; int pl; uint32_t mask; } table[] = {
        {"p1 up",     0, BTN_UP},   {"p1 down",   0, BTN_DOWN},
        {"p1 left",   0, BTN_LEFT}, {"p1 right",  0, BTN_RIGHT},
        {"p1 coin",   0, BTN_COIN}, {"p1 start",  0, BTN_START},
        {"p1 fire 1", 0, BTN_A},    {"p1 fire 2", 0, BTN_B},
        {"p1 fire 3", 0, BTN_C},    {"p1 fire 4", 0, BTN_D},

        {"p2 up",     1, BTN_UP},   {"p2 down",   1, BTN_DOWN},
        {"p2 left",   1, BTN_LEFT}, {"p2 right",  1, BTN_RIGHT},
        {"p2 coin",   1, BTN_COIN}, {"p2 start",  1, BTN_START},
        {"p2 fire 1", 1, BTN_A},    {"p2 fire 2", 1, BTN_B},
        {"p2 fire 3", 1, BTN_C},    {"p2 fire 4", 1, BTN_D},
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
        if (!ii.pVal || !ii.szInfo)   continue;

        int      pl;
        uint32_t mask;
        if (!parse_input(ii.szInfo, &pl, &mask)) continue;
        if (s_slotCount >= 64) break;

        s_slots[s_slotCount++] = {ii.pVal, pl, mask};
        *ii.pVal = 0; // ensure released on load
    }
}

// ── DIP switch defaults ──────────────────────────────────────────────────────
// Apply factory-default DIP settings shipped by FBNeo drivers (entries with
// nFlags == 0xFF). Without this, DIP bytes stay at zero, which puts many
// games into degenerate states (test mode, locked-out coinage, etc.).
static void apply_dip_defaults()
{
    struct BurnDIPInfo bdi;
    int dipOffset = 0;
    for (int i = 0; ; ++i) {
        memset(&bdi, 0, sizeof(bdi));
        if (BurnDrvGetDIPInfo(&bdi, i)) break;
        if (bdi.nFlags == 0xF0) { dipOffset = bdi.nInput; break; }
    }
    for (int i = 0; ; ++i) {
        memset(&bdi, 0, sizeof(bdi));
        if (BurnDrvGetDIPInfo(&bdi, i)) break;
        if (bdi.nFlags != 0xFF) continue;

        struct BurnInputInfo ii;
        memset(&ii, 0, sizeof(ii));
        if (BurnDrvGetInputInfo(&ii, bdi.nInput + dipOffset)) continue;
        if (!ii.pVal) continue;

        *ii.pVal = (*ii.pVal & ~bdi.nMask) | (bdi.nSetting & bdi.nMask);
    }
}

// ── Public API ────────────────────────────────────────────────────────────

int fbneo_cps_init()
{
    fbneo_driver_lib_init();
    return 0;
}

void fbneo_cps_exit()
{
    fbneo_cps_unload_game();
    // Do NOT call BurnLibExit() here. BurnGameListExit() frees game-list string
    // pointers without nulling them; a subsequent BurnLibInit() calls BurnLibExit()
    // internally and hits those stale pointers → double-free SIGABRT.
    // Keep the library initialised for the lifetime of the process.
}

int fbneo_cps_load_game(const char* zipPath)
{
    if (s_loaded) fbneo_cps_unload_game();

    s_missingCount = 0;

    // Close any stale zip handles.
    for (int z = 0; z < MAX_BRIDGE_ZIPS; ++z) {
        if (s_zips[z]) { unzClose(s_zips[z]); s_zips[z] = nullptr; }
    }
    s_zipCount = 0;

    // Open the primary zip.
    s_zips[0] = unzOpen(zipPath);
    if (!s_zips[0]) return 1;
    s_zipCount = 1;

    // Derive the ROM directory and game name from the zip path.
    char pathBuf[1024];
    strncpy(pathBuf, zipPath, sizeof(pathBuf) - 1);
    char* dir = dirname(pathBuf);

    char nameBuf[1024];
    strncpy(nameBuf, zipPath, sizeof(nameBuf) - 1);
    char* base = basename(nameBuf);

    // Strip .zip extension to get the game name, forcing lowercase so it matches
    // FBNeo's driver table regardless of how the user named the zip file.
    char gameName[256] = {};
    strncpy(gameName, base, sizeof(gameName) - 1);
    char* dot = strrchr(gameName, '.');
    if (dot) *dot = '\0';
    for (char* p = gameName; *p; ++p) *p = (char)tolower((unsigned char)*p);

    // Find the driver index.
    INT32 drvIdx = BurnDrvGetIndex(gameName);
    if (drvIdx < 0 || (UINT32)drvIdx >= nBurnDrvCount) {
        unzClose(s_zips[0]); s_zips[0] = nullptr; s_zipCount = 0;
        return 1;
    }
    nBurnDrvActive = (UINT32)drvIdx;

    // Open any additional parent/sibling zips listed by the driver.
    for (UINT32 z = 1; z < BZIP_MAX && s_zipCount < MAX_BRIDGE_ZIPS; ++z) {
        char* sibName = nullptr;
        if (BurnDrvGetZipName(&sibName, z)) break;
        if (!sibName || !sibName[0])        break;
        if (strcmp(sibName, gameName) == 0) continue; // already have it

        char sibPath[1024];
        snprintf(sibPath, sizeof(sibPath), "%s/%s.zip", dir, sibName);
        unzFile sib = unzOpen(sibPath);
        if (sib) s_zips[s_zipCount++] = sib;
    }

    // Configure burn globals before driver init.
    BurnHighCol     = highcol_bgra;
    BurnExtLoadRom  = rom_loader;
    nBurnLayer      = 0xFF;
    nBurnSoundRate  = 44100;
    pBurnSoundOut   = s_audioBuf;
    pBurnDraw       = reinterpret_cast<UINT8*>(s_videoBuf);
    nBurnBpp        = 4;
    nBurnPitch      = 512 * 4; // conservative default; updated to actual width after init

    if (BurnDrvInit()) {
        BurnExtLoadRom = nullptr;
        for (int z = 0; z < MAX_BRIDGE_ZIPS; ++z) {
            if (s_zips[z]) { unzClose(s_zips[z]); s_zips[z] = nullptr; }
        }
        s_zipCount = 0;
        return 1;
    }

    // Query actual frame dimensions after init.
    INT32 fw = 0, fh = 0;
    BurnDrvGetVisibleSize(&fw, &fh);
    if (fw <= 0 || fh <= 0) {
        BurnDrvGetFullSize(&fw, &fh);
    }
    if (fw <= 0) fw = 384;
    if (fh <= 0) fh = 224;
    s_frameW = fw;
    s_frameH = fh;

    // Re-set pitch now that we know the width.
    nBurnPitch = s_frameW * 4;

    // Apply factory DIP defaults, then enumerate and cache all digital input slots.
    apply_dip_defaults();
    build_input_slots();

    s_loaded = true;
    return 0;
}

void fbneo_cps_unload_game()
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
    s_loaded    = false;
}

int fbneo_cps_is_loaded()  { return s_loaded ? 1 : 0; }
int fbneo_cps_frame_width()  { return s_frameW; }
int fbneo_cps_frame_height() { return s_frameH; }
int fbneo_cps_audio_sample_count() { return nBurnSoundLen; }
int fbneo_cps_audio_sample_rate()  { return 44100; }

void fbneo_cps_set_video_buffer(uint32_t* buf)
{
    s_videoBuf = buf;
    if (s_loaded) pBurnDraw = reinterpret_cast<UINT8*>(buf);
}

void fbneo_cps_set_audio_buffer(int16_t* buf)
{
    s_audioBuf = buf;
    if (s_loaded) pBurnSoundOut = buf;
}

void fbneo_cps_set_input(int player, uint32_t buttons)
{
    if (player < 0 || player > 1) return;
    s_input[player] = buttons;
}

void fbneo_cps_run_frame()
{
    if (!s_loaded) return;

    // Push digital button state into driver input bytes.
    for (int i = 0; i < s_slotCount; ++i) {
        InputSlot& sl = s_slots[i];
        *sl.pVal = (s_input[sl.player] & sl.mask) ? 0xFF : 0x00;
    }

    BurnDrvFrame();
}

void fbneo_cps_reset()
{
    if (!s_loaded) return;
    BurnDrvInit(); // re-init is a hard reset; soft reset via driver reset if available
}

size_t fbneo_cps_state_size()
{
    if (!s_loaded) return 0;
    return 0;
}

int fbneo_cps_state_save(void*, size_t) { return 1; }
int fbneo_cps_state_load(const void*, size_t) { return 1; }

int fbneo_cps_missing_roms(char* buf, size_t bufSize)
{
    if (!buf || bufSize == 0) return s_missingCount;
    buf[0] = '\0';
    size_t pos = 0;
    for (int i = 0; i < s_missingCount && pos + 1 < bufSize; ++i) {
        size_t nameLen = strlen(s_missingNames[i]);
        if (pos + nameLen + 2 >= bufSize) break; // +2 for '\n' + '\0'
        memcpy(buf + pos, s_missingNames[i], nameLen);
        pos += nameLen;
        buf[pos++] = '\n';
    }
    if (pos > 0 && buf[pos - 1] == '\n') buf[pos - 1] = '\0'; // trim trailing newline
    else buf[pos] = '\0';
    return s_missingCount;
}

int fbneo_cps_driver_type(const char* name)
{
    if (!name || !name[0]) return 0;

    fbneo_driver_lib_init();

    INT32 idx = BurnDrvGetIndex(const_cast<char*>(name));
    if (idx < 0 || (UINT32)idx >= nBurnDrvCount) return 0;

    UINT32 prev = nBurnDrvActive;
    nBurnDrvActive = (UINT32)idx;

    int result = 1; // default CPS-1 if system string is unreadable
    char* sys = BurnDrvGetTextA(DRV_SYSTEM);
    if (sys) {
        if (strncmp(sys, "CPS2", 4) == 0) result = 2;
        else                               result = 1;
    }

    nBurnDrvActive = prev;
    return result;
}

int fbneo_cps_verify_game(const char* zipPath, FBNeoRomFile* outFiles, int maxFiles)
{
    if (!zipPath || !zipPath[0]) return -1;

    fbneo_driver_lib_init();

    // Derive game name and ROM directory from the zip path.
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

    // Open zips: primary + siblings.
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

    // Walk every ROM slot in the driver and verify presence + CRC.
    int slotCount = 0;
    struct BurnRomInfo ri;
    for (UINT32 i = 0; ; ++i) {
        memset(&ri, 0, sizeof(ri));
        if (BurnDrvGetRomInfo(&ri, i)) break;

        if (ri.nType == 0) {
            // Optional / empty slot — record but don't count as required.
            if (outFiles && slotCount < maxFiles) {
                char* rn = nullptr;
                BurnDrvGetRomName(&rn, i, 0);
                FBNeoRomFile& f = outFiles[slotCount];
                strncpy(f.name, (rn && rn[0]) ? rn : "(empty)", 63);
                f.name[63]     = '\0';
                f.status       = FBNEO_ROM_OPTIONAL;
                f.expectedCrc  = 0;
                f.actualCrc    = 0;
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

        // Search all zips for this file and read its CRC from the central directory.
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
