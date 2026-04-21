// macOS compatibility stubs for FBNeo burn core.
// Replaces src/burner/macos/misc.cpp without pulling in the full burner.h frontend.
#include "burnint.h"
#include <time.h>
#include <sys/time.h>

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

// SDL_GetTicks / SDL_Delay stubs (declared in burner_macos.h)
unsigned int SDL_GetTicks() {
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    return (unsigned int)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

void SDL_Delay(unsigned int ms) {
    struct timespec ts = { (time_t)(ms / 1000), (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, nullptr);
}
