#pragma once
#include <stddef.h>
#include <stdint.h>

// Rendered frame dimensions (LSPC active drawing area)
#define GEO_FRAME_WIDTH  320
#define GEO_FRAME_HEIGHT 256

// Visible pixel region (no border overscan)
#define GEO_VISIBLE_WIDTH  320
#define GEO_VISIBLE_HEIGHT 224

// System constants (mirror geo.h values without requiring geo.h in Swift)
#define GEO_SYSTEM_AES 0
#define GEO_SYSTEM_MVS 1
#define GEO_REGION_US  0
#define GEO_REGION_JP  1

// Input bit positions for geo_bridge_set_input bitmask
#define GEO_BTN_UP     0
#define GEO_BTN_DOWN   1
#define GEO_BTN_LEFT   2
#define GEO_BTN_RIGHT  3
#define GEO_BTN_SELECT 4
#define GEO_BTN_START  5
#define GEO_BTN_A      6
#define GEO_BTN_B      7
#define GEO_BTN_C      8
#define GEO_BTN_D      9

// System input bit positions for geo_bridge_set_sys_input bitmask
#define GEO_SYS_COIN1   0
#define GEO_SYS_COIN2   1
#define GEO_SYS_SERVICE 2
#define GEO_SYS_TEST    3

// Configure system type and region (call before geo_bridge_load_bios)
void geo_bridge_set_system(int system, int region);

// Load BIOS from file path — returns 1 on success
int geo_bridge_load_bios(const char *path);

// Load a .neo ROM from memory — returns 1 on success
int geo_bridge_load_neo(const void *data, size_t size);

// Initialize hardware after BIOS + ROM are loaded; call once per session
void geo_bridge_init(void);

// Tear down emulator state
void geo_bridge_deinit(void);

// Set the RGBA pixel buffer the LSPC renders into (GEO_FRAME_WIDTH * GEO_FRAME_HEIGHT uint32_t)
void geo_bridge_set_video_buffer(uint32_t *buf);

// Set the stereo int16 audio buffer and sample rate; call before geo_bridge_init
void geo_bridge_set_audio_buffer(int16_t *buf, size_t rate);

// Returns the number of int16 samples written since the last call (stereo interleaved)
size_t geo_bridge_audio_sample_count(void);

// Set controller buttons bitmask for player 0 or 1
void geo_bridge_set_input(unsigned player, uint32_t buttons);

// Set system inputs (coins, service) bitmask
void geo_bridge_set_sys_input(uint32_t buttons);

// Run one emulated frame
void geo_bridge_exec(void);

// Reset the emulator (hard=1 for cold reset, hard=0 for soft reset)
void geo_bridge_reset(int hard);

// Save state: returns pointer to internal buffer valid until next call; copy it
const void *geo_bridge_state_save(void);
size_t      geo_bridge_state_size(void);

// Load state from raw bytes — returns 1 on success
int geo_bridge_state_load(const void *data);
