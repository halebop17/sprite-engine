// macOS compatibility stubs for FBNeo burn core.
// Provides the burner-level symbols that burn/ core files reference via extern,
// but which are normally defined in platform-specific burner front-end code.
#include "burnint.h"
#include <time.h>
#include <sys/time.h>

// ── String conversion (declared in burner_macos.h) ────────────────────────

TCHAR* ANSIToTCHAR(const char* pszInString, TCHAR* pszOutString, int /*nOutSize*/) {
    if (pszOutString) {
        _tcscpy(pszOutString, pszInString);
        return pszOutString;
    }
    return (TCHAR*)pszInString;
}

char* TCHARToANSI(const TCHAR* pszInString, char* pszOutString, int /*nOutSize*/) {
    if (pszOutString) {
        _tcscpy(pszOutString, pszInString);
        return pszOutString;
    }
    return (char*)pszInString;
}

TCHAR* GetIsoPath() { return nullptr; }

// ── SDL substitutes (declared in burner_macos.h) ─────────────────────────

unsigned int SDL_GetTicks() {
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    return (unsigned int)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

void SDL_Delay(unsigned int ms) {
    struct timespec ts = { (time_t)(ms / 1000), (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, nullptr);
}

// ── Burner-level globals (declared extern in burn.h / burnint.h) ──────────
// Normally defined in platform drv.cpp / romdata.cpp / input modules.

int  bDrvOkay = 0;

// ROM data viewer — not used in headless mode.
static RomDataInfo s_rdi = {};
RomDataInfo*  pRDI         = &s_rdi;
BurnRomInfo*  pDataRomDesc = nullptr;

// Input interface
INT32 nInputIntfMouseDivider = 1;

// Video re-init callbacks (declared in burn.h, called by some drivers after
// resolution change; no-ops in our headless session).
void Reinitialise()      {}
void ReinitialiseVideo() {}

// ── AppError / ProgressUpdateBurner (used by drv.cpp in some builds) ──────

int AppError(TCHAR* /*szText*/, int /*bWarning*/) { return 0; }
int ProgressUpdateBurner(double, const TCHAR*, bool) { return 0; }

// ── Recording / netgame helper (declared in burnint.h) ────────────────────

INT32 is_netgame_or_recording() { return 0; }

// ── FcrashSnd stubs (bootleg CPS-1 games; YM2203 chain excluded) ─────────
// d_cps1.cpp driver entries reference these for fcrash/cawingbl bootlegs.
// Returning failure causes those games to fail init gracefully.
#include "cps.h"

INT32  FcrashSoundInit()                           { return 1; }
INT32  FcrashSoundReset()                          { return 1; }
INT32  FcrashSoundExit()                           { return 0; }
void   FcrashSoundCommand(UINT16)                  {}
void   FcrashSoundFrameStart()                     {}
void   FcrashSoundFrameEnd()                       {}
INT32  FcrashScanSound(INT32, INT32*)               { return 0; }
