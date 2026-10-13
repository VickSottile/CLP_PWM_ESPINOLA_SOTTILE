## ArtyZ7-10 Master XDC File
## PWM configurable por UART
## Proyecto: TPFinal CLP - Sottile / Espinola
## Vivado 2018.3

# ============================================================
# RELOJ DE SISTEMA
# ArtyZ7-10: El reloj de 125 MHz viene del Processing System (PS)
# Para el PL se usa FCLK_CLK0 del PS, conectado internamente.
# ============================================================
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk_125mhz]
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports clk_125mhz]
#set_input_delay -clock [get_clocks  "*"] -max 3.0 [get_ports uart_rx]    
# ============================================================
# RESET - BTN0 (activo alto)
# ============================================================
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports rst_btn]

# ============================================================
# UART
# ============================================================
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# ============================================================
# SALIDA PWM - Pmod JB pin 1
# ============================================================
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports pwm_out]

# ============================================================
# LEDs RGB / Normales (ArtyZ7-10 tiene 4 LEDs LD0-LD3)
# ============================================================
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]

# ============================================================
# Configuracion de velocidad y corriente de pines de salida
# ============================================================
set_property SLEW SLOW [get_ports uart_tx]
set_property DRIVE 4 [get_ports uart_tx]
set_property SLEW FAST [get_ports pwm_out]
set_property DRIVE 8 [get_ports pwm_out]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 32768 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_buf]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 20 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dbg_thresh[0]} {dbg_thresh[1]} {dbg_thresh[2]} {dbg_thresh[3]} {dbg_thresh[4]} {dbg_thresh[5]} {dbg_thresh[6]} {dbg_thresh[7]} {dbg_thresh[8]} {dbg_thresh[9]} {dbg_thresh[10]} {dbg_thresh[11]} {dbg_thresh[12]} {dbg_thresh[13]} {dbg_thresh[14]} {dbg_thresh[15]} {dbg_thresh[16]} {dbg_thresh[17]} {dbg_thresh[18]} {dbg_thresh[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 20 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dbg_cnt[0]} {dbg_cnt[1]} {dbg_cnt[2]} {dbg_cnt[3]} {dbg_cnt[4]} {dbg_cnt[5]} {dbg_cnt[6]} {dbg_cnt[7]} {dbg_cnt[8]} {dbg_cnt[9]} {dbg_cnt[10]} {dbg_cnt[11]} {dbg_cnt[12]} {dbg_cnt[13]} {dbg_cnt[14]} {dbg_cnt[15]} {dbg_cnt[16]} {dbg_cnt[17]} {dbg_cnt[18]} {dbg_cnt[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 20 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dbg_period[0]} {dbg_period[1]} {dbg_period[2]} {dbg_period[3]} {dbg_period[4]} {dbg_period[5]} {dbg_period[6]} {dbg_period[7]} {dbg_period[8]} {dbg_period[9]} {dbg_period[10]} {dbg_period[11]} {dbg_period[12]} {dbg_period[13]} {dbg_period[14]} {dbg_period[15]} {dbg_period[16]} {dbg_period[17]} {dbg_period[18]} {dbg_period[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list pwm_sig]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_buf]
