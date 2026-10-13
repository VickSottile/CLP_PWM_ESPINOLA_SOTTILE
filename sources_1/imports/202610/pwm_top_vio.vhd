--------------------------------------------------------------------------------
-- pwm_top_vio.vhd
-- Igual que pwm_top.vhd, pero con un VIO (Virtual Input/Output) para probar
-- el diseno en placa desde el Hardware Manager de Vivado 2018.3:
--
--   * probe_out0 (1 bit)  -> reset virtual, se combina (OR) con el boton BTN0
--   * probe_in0  (3 bits) -> monitorea led[2:0] (freq_sel(0), freq_sel(1), pwm)
--   * uart_rx / uart_tx   -> siguen en los pines JA1 / JA2 (sin cambios en XDC)
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pwm_top_vio is
    port (
        clk_125mhz : in  std_logic;
        rst_btn    : in  std_logic;
        uart_rx    : in  std_logic;
        uart_tx    : out std_logic;
        pwm_out    : out std_logic;
        led        : out std_logic_vector(2 downto 0)
    );
end entity pwm_top_vio;

architecture rtl of pwm_top_vio is

    -- IP VIO 
    COMPONENT vio_0
        port (
            clk        : in  std_logic;
            probe_in0  : in  std_logic_vector(2 downto 0);
            probe_out0 : out std_logic_vector(0 downto 0)
        );
    END COMPONENT;

    signal clk_buf  : std_logic;
    signal rst_sync : std_logic_vector(1 downto 0) := "11";
    signal rst      : std_logic;

    -- VIO
    signal vio_rst  : std_logic_vector(0 downto 0);
    signal led_int  : std_logic_vector(2 downto 0);

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

    -- Senales de debug (ILA via mark_debug)
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

    -- VIO: reloj = clk_buf (125 MHz, libre)
    u_vio: vio_0
        port map (
            clk        => clk_buf,
            probe_in0  => led_int,
            probe_out0 => vio_rst
        );

    -- Sincronizacion del reset: boton fisico OR reset virtual del VIO
    p_rst: process(clk_buf)
    begin
        if rising_edge(clk_buf) then
            rst_sync <= rst_sync(0) & (rst_btn or vio_rst(0));
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
    led_int(0) <= freq_sel(0);
    led_int(1) <= freq_sel(1);
    led_int(2) <= pwm_sig;

    pwm_out <= pwm_sig;
    led     <= led_int;

end architecture rtl;
