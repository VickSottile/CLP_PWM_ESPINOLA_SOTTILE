--------------------------------------------------------------------------------
-- uart_tx.vhd
-- Transmisor UART simple (8N1)
-- Se usa para eco de confirmacion de comandos recibidos
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ  : integer := 125_000_000;
        BAUD_RATE : integer := 115_200
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        data_in  : in  std_logic_vector(7 downto 0);
        send     : in  std_logic;           -- pulso 1 ciclo para iniciar TX
        tx       : out std_logic;
        busy     : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is

    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    type t_state is (IDLE, START, DATA, STOP);
    signal state    : t_state := IDLE;

    signal clk_cnt  : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx  : integer range 0 to 7                 := 0;
    signal tx_shift : std_logic_vector(7 downto 0)         := (others => '0');

begin

    p_tx: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= IDLE;
                tx      <= '1';
                busy    <= '0';
                clk_cnt <= 0;
                bit_idx <= 0;
            else
                case state is

                    when IDLE =>
                        tx   <= '1';
                        busy <= '0';
                        if send = '1' then
                            tx_shift <= data_in;
                            clk_cnt  <= 0;
                            busy     <= '1';
                            state    <= START;
                        end if;

                    when START =>
                        tx <= '0';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= DATA;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA =>
                        tx <= tx_shift(bit_idx);
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            if bit_idx = 7 then
                                state <= STOP;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when STOP =>
                        tx <= '1';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            busy    <= '0';
                            state   <= IDLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
