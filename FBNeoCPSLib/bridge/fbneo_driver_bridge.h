#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── System identification constants ──────────────────────────────────────────
// Returned by fbneo_driver_identify(). Maps to EmulatorSystem on the Swift side.

#define FBNEO_SYSTEM_UNKNOWN    0
#define FBNEO_SYSTEM_CPS1       1
#define FBNEO_SYSTEM_CPS2       2
#define FBNEO_SYSTEM_NEO_GEO    3
#define FBNEO_SYSTEM_SEGA_S16   4
#define FBNEO_SYSTEM_SEGA_S18   5
#define FBNEO_SYSTEM_TOAPLAN1   6
#define FBNEO_SYSTEM_TOAPLAN2   7
#define FBNEO_SYSTEM_KONAMI_GX  8
#define FBNEO_SYSTEM_IREM       9
#define FBNEO_SYSTEM_TAITO      10
#define FBNEO_SYSTEM_KONAMI_68K 11

// ── ROM file verification types ───────────────────────────────────────────────
// Shared by both the CPS bridge and the generic driver bridge.

#define FBNEO_ROM_OK         0  // present and CRC matches
#define FBNEO_ROM_MISSING    1  // not found in any zip
#define FBNEO_ROM_WRONG_CRC  2  // found but CRC mismatch
#define FBNEO_ROM_OPTIONAL   3  // nType == 0 (no file required)

typedef struct {
    char     name[64];
    int      status;        // FBNEO_ROM_*
    uint32_t expectedCrc;
    uint32_t actualCrc;     // 0 if missing
} FBNeoRomFile;

// ── Input button bitmask ──────────────────────────────────────────────────────
// Superset layout used by the generic bridge (and matched on the Swift side).
//   bits 0-3  : up / down / left / right
//   bits 4-5  : coin / start
//   bits 6-9  : A / B / C / D  (fire 1-4)
//   bits 10-11: X / Y           (fire 5-6, for 6-button games like Konami GX)

#define FBNEO_BTN_UP    (1u <<  0)
#define FBNEO_BTN_DOWN  (1u <<  1)
#define FBNEO_BTN_LEFT  (1u <<  2)
#define FBNEO_BTN_RIGHT (1u <<  3)
#define FBNEO_BTN_COIN  (1u <<  4)
#define FBNEO_BTN_START (1u <<  5)
#define FBNEO_BTN_A     (1u <<  6)
#define FBNEO_BTN_B     (1u <<  7)
#define FBNEO_BTN_C     (1u <<  8)
#define FBNEO_BTN_D     (1u <<  9)
#define FBNEO_BTN_X     (1u << 10)
#define FBNEO_BTN_Y     (1u << 11)

// ── Library lifecycle ─────────────────────────────────────────────────────────

// Initialise BurnLib (idempotent — safe to call multiple times).
void fbneo_driver_lib_init(void);

// ── Driver identification ─────────────────────────────────────────────────────

// Look up a driver by short name (zip stem, lowercase).
// Returns one of the FBNEO_SYSTEM_* constants, or FBNEO_SYSTEM_UNKNOWN if the
// driver is not in the compiled driver list.
// This is fast — it only reads metadata, never loads a ROM.
int fbneo_driver_identify(const char* name);

// ── Game load / unload ────────────────────────────────────────────────────────

// Load any FBNeo driver from a zip path.  Parent/sibling zips in the same
// directory are opened automatically.  Returns 0 on success.
int  fbneo_driver_load(const char* zipPath);

// Unload the current game and free driver state (no-op if none loaded).
void fbneo_driver_unload(void);

// 1 if a game is currently loaded via this bridge, 0 otherwise.
int  fbneo_driver_is_loaded(void);

// ── Frame geometry ────────────────────────────────────────────────────────────

int fbneo_driver_frame_width(void);
int fbneo_driver_frame_height(void);

// 1 if the game's native orientation is vertical (needs 90° rotation in UI).
int fbneo_driver_is_vertical(void);

// ── Buffers ───────────────────────────────────────────────────────────────────

void fbneo_driver_set_video_buffer(uint32_t* buf);
void fbneo_driver_set_audio_buffer(int16_t* buf);
int  fbneo_driver_audio_sample_count(void);

// ── Input ─────────────────────────────────────────────────────────────────────

// player: 0 or 1.  buttons: bitmask using FBNEO_BTN_* constants above.
void fbneo_driver_set_input(int player, uint32_t buttons);

// ── Emulation ─────────────────────────────────────────────────────────────────

void fbneo_driver_run_frame(void);
void fbneo_driver_reset(void);

// ── Missing ROM report ────────────────────────────────────────────────────────

// Call after a failed fbneo_driver_load() to get a newline-separated list of
// ROM files that were not found.  Returns the count of missing files.
int fbneo_driver_missing_roms(char* buf, size_t bufSize);

// ── ROM verification ──────────────────────────────────────────────────────────

// Check all ROM slots for the game at zipPath without loading it.
// Fills outFiles (up to maxFiles entries).
// Returns the total ROM slot count, or -1 if the driver is not recognised.
int fbneo_driver_verify_game(const char*   zipPath,
                             FBNeoRomFile* outFiles,
                             int           maxFiles);

#ifdef __cplusplus
}
#endif
