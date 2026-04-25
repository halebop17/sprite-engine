#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialise the FBNeo library (call once at startup).
int  fbneo_cps_init(void);

// Tear down the FBNeo library.
void fbneo_cps_exit(void);

// Load a CPS-1/2 game from a ROM zip file.
// zipPath: full path to the primary ROM zip (e.g. "/roms/sf2.zip").
// Parent/sibling zips are looked up in the same directory.
// Returns 0 on success, non-zero on failure.
int  fbneo_cps_load_game(const char* zipPath);

// Unload the currently running game (no-op if none loaded).
void fbneo_cps_unload_game(void);

// Returns 1 if a game is currently loaded, 0 otherwise.
int  fbneo_cps_is_loaded(void);

// Frame pixel dimensions. Valid after a successful fbneo_cps_load_game().
int fbneo_cps_frame_width(void);
int fbneo_cps_frame_height(void);

// Set the video output buffer.
// Must hold frame_width * frame_height uint32 pixels in BGRA format.
void fbneo_cps_set_video_buffer(uint32_t* buf);

// Set the audio output buffer.
// Must hold at least fbneo_cps_audio_sample_count() * 2 int16 values
// (stereo interleaved: L0,R0,L1,R1,...).
void fbneo_cps_set_audio_buffer(int16_t* buf);

// Stereo samples written per frame (valid after load_game).
int fbneo_cps_audio_sample_count(void);

// Audio sample rate (always 44100 Hz).
int fbneo_cps_audio_sample_rate(void);

// Set digital input state for player 0 or 1.
// Bitmask:
//   bit 0 = up        bit 1 = down    bit 2 = left    bit 3 = right
//   bit 4 = coin      bit 5 = start
//   bit 6 = A (fire1) bit 7 = B (fire2) bit 8 = C (fire3) bit 9 = D (fire4)
void fbneo_cps_set_input(int player, uint32_t buttons);

// Run one emulated frame, updating the video and audio buffers.
void fbneo_cps_run_frame(void);

// Soft-reset the currently loaded game.
void fbneo_cps_reset(void);

// In-memory save-state support.
size_t fbneo_cps_state_size(void);
int    fbneo_cps_state_save(void* buf, size_t bufSize);
int    fbneo_cps_state_load(const void* buf, size_t bufSize);

#ifdef __cplusplus
}
#endif
