--------------------------------------------------------------------------------
-- uart_cmd_parser.vhd
-- Parser de comandos UART para configuracion del PWM
--
-- Protocolo de comandos (ASCII, terminado con CR o LF):
--
--   Seleccion de frecuencia:
--     "F1\n"  -> frecuencia 1 kHz
--     "F2\n"  -> frecuencia 10 kHz
--     "F3\n"  -> frecuencia 100 kHz
--
--   Configuracion de duty cycle (0-100):
--     "D<NN>\n"  -> duty cycle en porcentaje, p.ej. "D75\n" = 75%
--
--   La FPGA responde con "OK\n" ante un comando valido,
--   o "ERR\n" ante uno invalido.
--
-- Nota: los numeros se reciben en ASCII decimal, hasta 3 digitos.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_cmd_parser is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- Interface con UART RX
        rx_data     : in  std_logic_vector(7 downto 0);
        rx_rdy      : in  std_logic;
        -- Interface con UART TX (respuesta)
        tx_data     : out std_logic_vector(7 downto 0);
        tx_send     : out std_logic;
        tx_busy     : in  std_logic;
        -- Configuracion del PWM
        freq_sel    : out std_logic_vector(1 downto 0);  -- "01"=1kHz, "10"=10kHz, "11"=100kHz
        duty_cycle  : out std_logic_vector(6 downto 0);  -- 0 a 100
        cfg_valid   : out std_logic                       -- pulso al aplicar nueva config
    );
end entity uart_cmd_parser;

architecture rtl of uart_cmd_parser is

    -- FSM del parser
    type t_parse_state is (
        ST_IDLE,        -- esperando primer caracter del comando
        ST_CMD_F,       -- recibio 'F', espera digito
        ST_CMD_D,       -- recibio 'D', acumulando numero
        ST_RESP,        -- enviando respuesta (hasta 4 bytes)
        ST_ERROR        -- comando invalido, enviar ERR
    );
    signal parse_state : t_parse_state := ST_IDLE;

    -- Acumulador del numero decimal del duty cycle
    signal num_acc      : integer range 0 to 999 := 0;
    signal digit_cnt    : integer range 0 to 3   := 0;

    -- Latches de configuracion pendiente
    signal freq_latch   : std_logic_vector(1 downto 0) := "01";
    signal duty_latch   : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(50, 7));
    signal tx_send_reg  : std_logic := '0';

    -- Respuesta a enviar: "OK\r\n" o "ERR\r\n"
    type t_resp_arr is array (0 to 4) of std_logic_vector(7 downto 0);
    signal resp_buf     : t_resp_arr;
    signal resp_len     : integer range 0 to 5 := 0;
    signal resp_idx     : integer range 0 to 4 := 0;

    -- Constantes ASCII
    constant CR  : std_logic_vector(7 downto 0) := x"0D";
    constant LF  : std_logic_vector(7 downto 0) := x"0A";

begin

    -- Outputs registrados
    freq_sel   <= freq_latch;
    duty_cycle <= duty_latch;
    tx_send    <= tx_send_reg;

    p_parser: process(clk)
        variable ch : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            tx_send_reg <= '0';
            cfg_valid   <= '0';

            if rst = '1' then
                parse_state <= ST_IDLE;
                freq_latch  <= "01";
                duty_latch  <= std_logic_vector(to_unsigned(50, 7));
                num_acc     <= 0;
                digit_cnt   <= 0;
                resp_idx    <= 0;
                tx_send_reg <= '0';

            else
                case parse_state is

                    -- --------------------------------------------------------
                    when ST_IDLE =>
                        if rx_rdy = '1' then
                            ch := rx_data;
                            if ch = x"46" then      -- 'F'
                                parse_state <= ST_CMD_F;
                            elsif ch = x"44" then   -- 'D'
                                num_acc     <= 0;
                                digit_cnt   <= 0;
                                parse_state <= ST_CMD_D;
                            elsif ch = CR or ch = LF then
                                null;               -- ignorar linea vacia
                            else
                                -- Caracter inesperado -> error
                                parse_state <= ST_ERROR;
                            end if;
                        end if;

                    -- --------------------------------------------------------
                    when ST_CMD_F =>
                        if rx_rdy = '1' then
                            ch := rx_data;
                            if ch = x"31" then      -- '1' -> 1 kHz
                                freq_latch  <= "01";
                                cfg_valid   <= '1';
                                -- preparar respuesta "OK\r\n"
                                resp_buf(0) <= x"4F"; -- 'O'
                                resp_buf(1) <= x"4B"; -- 'K'
                                resp_buf(2) <= CR;
                                resp_buf(3) <= LF;
                                resp_len    <= 4;
                                resp_idx    <= 0;
                                parse_state <= ST_RESP;
                            elsif ch = x"32" then   -- '2' -> 10 kHz
                                freq_latch  <= "10";
                                cfg_valid   <= '1';
                                resp_buf(0) <= x"4F";
                                resp_buf(1) <= x"4B";
                                resp_buf(2) <= CR;
                                resp_buf(3) <= LF;
                                resp_len    <= 4;
                                resp_idx    <= 0;
                                parse_state <= ST_RESP;
                            elsif ch = x"33" then   -- '3' -> 100 kHz
                                freq_latch  <= "11";
                                cfg_valid   <= '1';
                                resp_buf(0) <= x"4F";
                                resp_buf(1) <= x"4B";
                                resp_buf(2) <= CR;
                                resp_buf(3) <= LF;
                                resp_len    <= 4;
                                resp_idx    <= 0;
                                parse_state <= ST_RESP;
                            else
                                parse_state <= ST_ERROR;
                            end if;
                        end if;

                    -- --------------------------------------------------------
                    when ST_CMD_D =>
                        if rx_rdy = '1' then
                            ch := rx_data;
                            if ch >= x"30" and ch <= x"39" then  -- '0'..'9'
                                num_acc   <= num_acc * 10 + (to_integer(unsigned(ch)) - 48);
                                digit_cnt <= digit_cnt + 1;
                                if digit_cnt = 2 then
                                    -- Ya tenemos hasta 3 digitos; esperamos CR/LF
                                    null;
                                end if;
                            elsif (ch = CR or ch = LF) and digit_cnt > 0 then
                                -- Fin del numero
                                if num_acc <= 100 then
                                    duty_latch  <= std_logic_vector(to_unsigned(num_acc, 7));
                                    cfg_valid   <= '1';
                                    resp_buf(0) <= x"4F";
                                    resp_buf(1) <= x"4B";
                                    resp_buf(2) <= CR;
                                    resp_buf(3) <= LF;
                                    resp_len    <= 4;
                                    resp_idx    <= 0;
                                    parse_state <= ST_RESP;
                                else
                                    parse_state <= ST_ERROR;
                                end if;
                            else
                                parse_state <= ST_ERROR;
                            end if;
                        end if;

                    -- --------------------------------------------------------
                    -- Envio de respuesta byte a byte
                    when ST_RESP =>
                        if tx_busy = '0' and tx_send_reg = '0' then
                            tx_data     <= resp_buf(resp_idx);
                            tx_send_reg <= '1';
                            if resp_idx = resp_len - 1 then
                                parse_state <= ST_IDLE;
                            else
                                resp_idx    <= resp_idx + 1;
                            end if;
                        end if;

                    -- --------------------------------------------------------
                    -- Envio de "ERR\r\n"
                    when ST_ERROR =>
                        resp_buf(0) <= x"45"; -- 'E'
                        resp_buf(1) <= x"52"; -- 'R'
                        resp_buf(2) <= x"52"; -- 'R'
                        resp_buf(3) <= CR;
                        resp_buf(4) <= LF;
                        resp_len    <= 5;
                        resp_idx    <= 0;
                        parse_state <= ST_RESP;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
