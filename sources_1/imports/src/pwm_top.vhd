--------------------------------------------------------------------------------
-- pwm_top.vhd
-- Top-level del sistema PWM configurable por UART
-- Placa: ArtyZ7-10  |  Clk: 125 MHz (PS clock via BUFG)
--
-- Estrategia de debug ILA:
--   Las señales marcadas con atributo MARK_DEBUG son detectadas automaticamente
--   por Vivado luego de la sintesis.
--
-- Pinout utilizado:
--   CLK  -> pin H16 (125 MHz oscilador placa)
--   RST  -> BTN0 (D19) - activo alto
--   RX   -> JA1 (Y18)  - UART RX desde USB-TTL
--   TX   -> JA2 (Y19)  - UART TX hacia USB-TTL
--   PWM  -> JB1 (W14)  - salida PWM
--   LED0 -> LD0 (R14)  - freq_sel bit 0
--   LED1 -> LD1 (P14)  - freq_sel bit 1
--   LED2 -> LD2 (N16)  - replica de pwm_out
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pwm_top is
    port (
        clk_125mhz : in  std_logic;
        rst_btn    : in  std_logic;
        uart_rx    : in  std_logic;
        uart_tx    : out std_logic;
        pwm_out    : out std_logic;
        led        : out std_logic_vector(2 downto 0)
    );
end entity pwm_top;

architecture rtl of pwm_top is

    signal clk_buf  : std_logic;
    signal rst_sync : std_logic_vector(1 downto 0) := "11";
    signal rst      : std_logic;

    -- Senales UART
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_rdy   : std_logic;
    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_send  : std_logic;
    signal tx_busy  : std_logic;

    -- Configuracion PWM
    signal freq_sel   : std_logic_vector(1 downto 0);
    signal duty_cycle : std_logic_vector(6 downto 0);
    signal cfg_valid  : std_logic;

    -- Senales de debug: marcadas con MARK_DEBUG para que Vivado
    -- las detecte automaticamente en el asistente "Set Up Debug"
    -- y conecte el ILA sin instanciacion manual en VHDL.
    attribute mark_debug : string;

    signal pwm_sig    : std_logic;
    signal dbg_cnt    : std_logic_vector(19 downto 0);
    signal dbg_thresh : std_logic_vector(19 downto 0);
    signal dbg_period : std_logic_vector(19 downto 0);

    attribute mark_debug of pwm_sig    : signal is "true";
    attribute mark_debug of dbg_cnt    : signal is "true";
    attribute mark_debug of dbg_thresh : signal is "true";
    attribute mark_debug of dbg_period : signal is "true";

begin
   
    -- Buffer de reloj global
    u_bufg: BUFG
        port map (I => clk_125mhz, O => clk_buf);

    -- Sincronizacion del reset
    p_rst: process(clk_buf)
    begin
        if rising_edge(clk_buf) then
            rst_sync <= rst_sync(0) & rst_btn;
        end if;
    end process;
    rst <= rst_sync(1);

    -- UART Receptor
    u_uart_rx: entity work.uart_rx
        generic map (CLK_FREQ => 125_000_000, BAUD_RATE => 115_200)
        port map (
            clk      => clk_buf,
            rst      => rst,
            rx       => uart_rx,
            data_out => rx_data,
            data_rdy => rx_rdy
        );

    -- UART Transmisor
    u_uart_tx: entity work.uart_tx
        generic map (CLK_FREQ => 125_000_000, BAUD_RATE => 115_200)
        port map (
            clk     => clk_buf,
            rst     => rst,
            data_in => tx_data,
            send    => tx_send,
            tx      => uart_tx,
            busy    => tx_busy
        );

    -- Parser de comandos
    u_parser: entity work.uart_cmd_parser
        port map (
            clk        => clk_buf,
            rst        => rst,
            rx_data    => rx_data,
            rx_rdy     => rx_rdy,
            tx_data    => tx_data,
            tx_send    => tx_send,
            tx_busy    => tx_busy,
            freq_sel   => freq_sel,
            duty_cycle => duty_cycle,
            cfg_valid  => cfg_valid
        );

    -- Generador PWM
    u_pwm: entity work.pwm_generator
        generic map (CLK_FREQ => 125_000_000)
        port map (
            clk        => clk_buf,
            rst        => rst,
            freq_sel   => freq_sel,
            duty_cycle => duty_cycle,
            cfg_valid  => cfg_valid,
            pwm_out    => pwm_sig,
            dbg_period => dbg_period,
            dbg_thresh => dbg_thresh,
            dbg_cnt    => dbg_cnt
        );

    -- Salidas
    pwm_out <= pwm_sig;
    led(0)  <= freq_sel(0);
    led(1)  <= freq_sel(1);
    led(2)  <= pwm_sig;

end architecture rtl;
