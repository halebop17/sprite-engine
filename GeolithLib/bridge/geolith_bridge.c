#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "geo.h"
#include "geo_lspc.h"
#include "geo_mixer.h"
#include "geo_neo.h"
#include "geolith_bridge.h"

// ── Input state ──────────────────────────────────────────────────────────────

static uint32_t s_input[2] = {0, 0};
static uint32_t s_sys_input = 0;

// Convert our active-high GEO_BTN_* bitmask to the active-low joystick byte
// that Geolith's P1CNT/P2CNT registers expect (0xff = all released).
static unsigned input_poll_js(uint32_t inp) {
    unsigned b = 0xff;
    if (inp & (1u << GEO_BTN_UP))    b &= ~(1u << 0);
    if (inp & (1u << GEO_BTN_DOWN))  b &= ~(1u << 1);
    if (inp & (1u << GEO_BTN_LEFT))  b &= ~(1u << 2);
    if (inp & (1u << GEO_BTN_RIGHT)) b &= ~(1u << 3);
    if (inp & (1u << GEO_BTN_A))     b &= ~(1u << 4);
    if (inp & (1u << GEO_BTN_B))     b &= ~(1u << 5);
    if (inp & (1u << GEO_BTN_C))     b &= ~(1u << 6);
    if (inp & (1u << GEO_BTN_D))     b &= ~(1u << 7);
    return b;
}

// Player joystick callbacks — argument is the port index (ignored; one callback per player)
static unsigned input_cb0(unsigned port) { (void)port; return input_poll_js(s_input[0]); }
static unsigned input_cb1(unsigned port) { (void)port; return input_poll_js(s_input[1]); }

// REG_STATUS_A: Coin-in and service buttons (active-low, bits 0-2)
static unsigned sys_cb0(void) {
    unsigned c = 0x07 | 0x18;  // coins 1-3 released; slots 3&4 always high (2-slot cab)
    if (s_sys_input & (1u << GEO_SYS_COIN1))   c &= ~(1u << 0);
    if (s_sys_input & (1u << GEO_SYS_COIN2))   c &= ~(1u << 1);
    if (s_sys_input & (1u << GEO_SYS_SERVICE)) c &= ~(1u << 2);
    return c;
}

// REG_STATUS_B: P1/P2 Select/Start (active-low, bits 0-3); no memory card (bits 4-5 = 1)
static unsigned sys_cb1(void) {
    unsigned s = 0x3f;  // bits 0-5 = 1 = all released; memcard not inserted
    if (s_input[0] & (1u << GEO_BTN_START))  s &= ~(1u << 0);  // P1 Start
    if (s_input[0] & (1u << GEO_BTN_SELECT)) s &= ~(1u << 1);  // P1 Select
    if (s_input[1] & (1u << GEO_BTN_START))  s &= ~(1u << 2);  // P2 Start
    if (s_input[1] & (1u << GEO_BTN_SELECT)) s &= ~(1u << 3);  // P2 Select
    return s;
}

// REG_SYSTYPE: Test button (bit 7, active-low) + slot count (bit 6, masked by hardware)
static unsigned sys_cb2(void) {
    unsigned t = 0xc0;  // test not pressed; 2-slot cabinet
    if (s_sys_input & (1u << GEO_SYS_TEST)) t &= ~(1u << 7);
    return t;
}

// REG_DIPSW: DIP switches (active-low; 0xff = all off = normal arcade settings)
static unsigned sys_cb3(void) { return 0xff; }

static unsigned sys_cb4(void) { return 0; }

// ── Audio bookkeeping ─────────────────────────────────────────────────────────

static size_t s_audio_count = 0;

static void audio_ready(size_t count) {
    s_audio_count = count;
}

// ── Log stub ──────────────────────────────────────────────────────────────────

static void geo_log_stub(int level, const char *fmt, ...) {
    (void)level; (void)fmt;
}

// ── Public API ────────────────────────────────────────────────────────────────

void geo_bridge_set_system(int system, int region) {
    geo_set_system(system);
    geo_set_region(region);
}

int geo_bridge_load_bios(const char *path) {
    // geo_bios_load_file calls geo_log internally; set a safe stub before it
    // is ever invoked so we don't crash on a NULL function pointer.
    geo_log_set_callback(geo_log_stub);
    return geo_bios_load_file(path);
}

int geo_bridge_load_neo(const void *data, size_t size) {
    return geo_neo_load((void *)data, size);
}

void geo_bridge_init(void) {
    geo_log_set_callback(geo_log_stub);

    geo_input_set_callback(0, input_cb0);
    geo_input_set_callback(1, input_cb1);

    geo_input_sys_set_callback(0, sys_cb0);
    geo_input_sys_set_callback(1, sys_cb1);
    geo_input_sys_set_callback(2, sys_cb2);
    geo_input_sys_set_callback(3, sys_cb3);
    geo_input_sys_set_callback(4, sys_cb4);

    geo_mixer_set_callback(audio_ready);

    geo_init();

    // Populate LSPC palette LUTs (resistor-network mode). Without this call
    // lut_normal[] and lut_shadow[] remain zero and every pixel renders black.
    geo_lspc_set_palette(0);
}

void geo_bridge_deinit(void) {
    geo_deinit();
    geo_mixer_deinit();
}

void geo_bridge_set_video_buffer(uint32_t *buf) {
    geo_lspc_set_buffer(buf);
}

void geo_bridge_set_audio_buffer(int16_t *buf, size_t rate) {
    geo_mixer_set_buffer(buf);
    geo_mixer_set_rate(rate);
    geo_mixer_init();
}

size_t geo_bridge_audio_sample_count(void) {
    size_t n = s_audio_count;
    s_audio_count = 0;
    return n;
}

void geo_bridge_set_input(unsigned player, uint32_t buttons) {
    if (player < 2)
        s_input[player] = buttons;
}

void geo_bridge_set_sys_input(uint32_t buttons) {
    s_sys_input = buttons;
}

void geo_bridge_exec(void) {
    geo_exec();
}

void geo_bridge_reset(int hard) {
    geo_reset(hard);
}

const void *geo_bridge_state_save(void) {
    return geo_state_save_raw();
}

size_t geo_bridge_state_size(void) {
    return geo_state_size();
}

int geo_bridge_state_load(const void *data) {
    return geo_state_load_raw(data);
}
