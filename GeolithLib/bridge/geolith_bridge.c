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

// Geolith queries each bit individually via these callbacks
static unsigned input_cb0(unsigned bit) { return (s_input[0] >> bit) & 1; }
static unsigned input_cb1(unsigned bit) { return (s_input[1] >> bit) & 1; }

// System inputs: Coin1, Coin2, Service, Test (indices 0-3)
static unsigned sys_cb0(void) { return (s_sys_input >> 0) & 1; }
static unsigned sys_cb1(void) { return (s_sys_input >> 1) & 1; }
static unsigned sys_cb2(void) { return (s_sys_input >> 2) & 1; }
static unsigned sys_cb3(void) { return (s_sys_input >> 3) & 1; }
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
