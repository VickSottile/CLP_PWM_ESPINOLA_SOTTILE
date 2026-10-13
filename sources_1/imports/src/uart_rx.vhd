--------------------------------------------------------------------------------
-- uart_rx.vhd
-- Receptor UART simple (8N1)
-- Baud rate configurado via generico: CLK_FREQ / BAUD_RATE
-- Placa: ArtyZ7-10  |  Clk: 125 MHz  |  Baud: 115200
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 125_000_000;
        BAUD_RATE : integer := 115_200
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        rx       : in  std_logic;           -- linea serie entrada
        data_out : out std_logic_vector(7 downto 0);
        data_rdy : out std_logic            -- pulso 1 ciclo al recibir byte
    );
end entity uart_rx;

architecture rtl of uart_rx is

    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;  -- 1085 @ 125 MHz / 115200

    type t_state is (IDLE, START, DATA, STOP);
    signal state    : t_state := IDLE;

    signal clk_cnt  : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx  : integer range 0 to 7                 := 0;
    signal rx_shift : std_logic_vector(7 downto 0)         := (others => '0');
    signal rx_sync  : std_logic_vector(1 downto 0)         := "11"; -- sincronizador 2-FF

begin

    -- Sincronizacion de rx al dominio del reloj local
    p_sync: process(clk)
    begin
        if rising_edge(clk) then
            rx_sync <= rx_sync(0) & rx;
        end if;
    end process;

    -- Maquina de estados receptora
    p_rx: process(clk)
    begin
        if rising_edge(clk) then
            data_rdy <= '0';

            if rst = '1' then
                state   <= IDLE;
                clk_cnt <= 0;
                bit_idx <= 0;
            else
                case state is

                    -- Espera flanco descendente (bit de start)
                    when IDLE =>
                        if rx_sync(1) = '0' then
                            clk_cnt <= 0;
                            state   <= START;
                        end if;

                    -- Muestreo en el centro del bit de start
                    when START =>
                        if clk_cnt = (CLKS_PER_BIT / 2) - 1 then
                            if rx_sync(1) = '0' then
                                clk_cnt <= 0;
                                bit_idx <= 0;
                                state   <= DATA;
                            else
                                state   <= IDLE;  -- false start
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    -- Captura de 8 bits de datos (LSB primero)
                    when DATA =>
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt               <= 0;
                            rx_shift(bit_idx)     <= rx_sync(1);
                            if bit_idx = 7 then
                                bit_idx <= 0;
                                state   <= STOP;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    -- Verificacion bit de stop
                    when STOP =>
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            data_rdy <= '1';
                            data_out <= rx_shift;
                            clk_cnt  <= 0;
                            state    <= IDLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
