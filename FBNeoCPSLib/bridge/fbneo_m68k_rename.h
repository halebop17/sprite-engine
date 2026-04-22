// Symbol rename header — makes FBNeo's Musashi symbols unique
// so they don't collide with Geolith's Musashi (a different version).
// #included via -include compiler flag when compiling m68kcpu.c, m68kops.c,
// and m68000_intf.cpp.
#pragma once

#define m68k_burn_until_irq             fbneo_m68k_burn_until_irq
#define m68k_check_shouldinterrupt      fbneo_m68k_check_shouldinterrupt
#define m68k_context_size               fbneo_m68k_context_size
#define m68k_context_size_no_pointers   fbneo_m68k_context_size_no_pointers
#define m68k_cycles_remaining           fbneo_m68k_cycles_remaining
#define m68k_cycles_remaining_set       fbneo_m68k_cycles_remaining_set
#define m68k_cycles_run                 fbneo_m68k_cycles_run
#define m68k_end_timeslice              fbneo_m68k_end_timeslice
#define m68k_execute                    fbneo_m68k_execute
#define m68k_executeMD                  fbneo_m68k_executeMD
#define m68k_get_context                fbneo_m68k_get_context
#define m68k_get_dar                    fbneo_m68k_get_dar
#define m68k_get_irq                    fbneo_m68k_get_irq
#define m68k_get_reg                    fbneo_m68k_get_reg
#define m68k_get_virq                   fbneo_m68k_get_virq
#define m68k_init                       fbneo_m68k_init
#define m68k_megadrive_sr_checkint_mode fbneo_m68k_megadrive_sr_checkint_mode
#define m68k_modify_timeslice           fbneo_m68k_modify_timeslice
#define m68k_pulse_halt                 fbneo_m68k_pulse_halt
#define m68k_pulse_reset                fbneo_m68k_pulse_reset
#define m68k_set_bkpt_ack_callback      fbneo_m68k_set_bkpt_ack_callback
#define m68k_set_cmpild_instr_callback  fbneo_m68k_set_cmpild_instr_callback
#define m68k_set_context                fbneo_m68k_set_context
#define m68k_set_cpu_type               fbneo_m68k_set_cpu_type
#define m68k_set_fc_callback            fbneo_m68k_set_fc_callback
#define m68k_set_insn_cb                fbneo_m68k_set_insn_cb
#define m68k_set_instr_hook_callback    fbneo_m68k_set_instr_hook_callback
#define m68k_set_int_ack_callback       fbneo_m68k_set_int_ack_callback
#define m68k_set_irq                    fbneo_m68k_set_irq
#define m68k_set_pc_changed_callback    fbneo_m68k_set_pc_changed_callback
#define m68k_set_reg                    fbneo_m68k_set_reg
#define m68k_set_reset_instr_callback   fbneo_m68k_set_reset_instr_callback
#define m68k_set_rte_instr_callback     fbneo_m68k_set_rte_instr_callback
#define m68k_set_tas_instr_callback     fbneo_m68k_set_tas_instr_callback
#define m68k_set_virq                   fbneo_m68k_set_virq
#define m68ki_address_space             fbneo_m68ki_address_space
#define m68ki_aerr_address              fbneo_m68ki_aerr_address
#define m68ki_aerr_fc                   fbneo_m68ki_aerr_fc
#define m68ki_aerr_write_mode           fbneo_m68ki_aerr_write_mode
#define m68040_fpu_op0                  fbneo_m68040_fpu_op0
#define m68040_fpu_op1                  fbneo_m68040_fpu_op1
#define m68ki_build_opcode_table        fbneo_m68ki_build_opcode_table
#define m68ki_cycles                    fbneo_m68ki_cycles
#define m68ki_instruction_jump_table    fbneo_m68ki_instruction_jump_table
// BSS/common section symbols (type S in nm)
#define m68ki_cpu                       fbneo_m68ki_cpu
#define m68ki_cpu_names                 fbneo_m68ki_cpu_names
#define m68ki_ea_idx_cycle_table        fbneo_m68ki_ea_idx_cycle_table
#define m68ki_exception_cycle_table     fbneo_m68ki_exception_cycle_table
#define m68ki_shift_8_table             fbneo_m68ki_shift_8_table
#define m68ki_shift_16_table            fbneo_m68ki_shift_16_table
#define m68ki_shift_32_table            fbneo_m68ki_shift_32_table
#define m68ki_tracing                   fbneo_m68ki_tracing
