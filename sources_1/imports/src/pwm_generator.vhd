--------------------------------------------------------------------------------
-- pwm_generator.vhd
-- Generador PWM con 3 frecuencias seleccionables y duty cycle variable
--
-- Placa: ArtyZ7-10  |  Clk sistema: 125 MHz
--
-- Frecuencias disponibles:
--   freq_sel = "01"  ->   1 kHz  (periodo = 125000 ciclos)
--   freq_sel = "10"  ->  10 kHz  (periodo =  12500 ciclos)
--   freq_sel = "11"  -> 100 kHz  (periodo =   1250 ciclos)
--
-- duty_cycle: valor 0-100 (porcentaje)
-- pwm_out: salida PWM
--
-- Cambios para cumplir timing a 125 MHz (8 ns):
--   * Se elimina el divisor "/ 100" combinacional. Como los periodos son
--     multiplos de 100 (salvo 1250, que da 12,5 ciclos por cada 1 %),
--     threshold = duty * (periodo / 100) se calcula con una multiplicacion
--     por constante:  1 kHz -> duty*1250,  10 kHz -> duty*125,
--     100 kHz -> (duty*25) >> 1.  El resultado es identico a
--     floor(periodo * duty / 100).
--   * El calculo de period / period-1 / threshold esta REGISTRADO
--     (1 ciclo de latencia) y cfg_valid se retrasa 1 ciclo (cfg_valid_d)
--     para cargar los valores ya calculados.
--   * El contador compara por igualdad con period_m1 (registro con
--     period - 1), en lugar de restar y comparar con >=.
--   * La carga de nueva configuracion reinicia el contador de verdad
--     (if / else), tal como decia el comentario original.
-- Los valores de multiplicacion asumen CLK_FREQ = 125 MHz.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_generator is
    generic (
        CLK_FREQ : integer := 125_000_000  -- 125 MHz (ArtyZ7-10)
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        freq_sel   : in  std_logic_vector(1 downto 0);  -- "01","10","11"
        duty_cycle : in  std_logic_vector(6 downto 0);  -- 0-100
        cfg_valid  : in  std_logic;                      -- carga nueva config
        pwm_out    : out std_logic;
        -- Senales de debug para ILA
        dbg_period : out std_logic_vector(19 downto 0); -- periodo actual
        dbg_thresh : out std_logic_vector(19 downto 0); -- umbral actual
        dbg_cnt    : out std_logic_vector(19 downto 0)  -- contador actual
    );
end entity pwm_generator;

architecture rtl of pwm_generator is

    -- Periodos para cada frecuencia (en ciclos de reloj de 125 MHz)
    constant PERIOD_1K   : integer := CLK_FREQ / 1_000;    -- 125000 ciclos
    constant PERIOD_10K  : integer := CLK_FREQ / 10_000;   --  12500 ciclos
    constant PERIOD_100K : integer := CLK_FREQ / 100_000;  --   1250 ciclos

    -- Ciclos por cada 1 % de duty
    constant STEP_1K   : integer := PERIOD_1K  / 100;      -- 1250
    constant STEP_10K  : integer := PERIOD_10K / 100;      --  125
    constant STEP_100K : integer := PERIOD_100K / 50;      --   25 (se desplaza 1 bit: 12,5 por %)

    -- Registros de trabajo (valores en uso)
    signal period    : unsigned(19 downto 0) := to_unsigned(PERIOD_1K, 20);
    signal period_m1 : unsigned(19 downto 0) := to_unsigned(PERIOD_1K - 1, 20);
    signal threshold : unsigned(19 downto 0) := to_unsigned(PERIOD_1K / 2, 20);
    signal counter   : unsigned(19 downto 0) := (others => '0');
    signal pwm_reg   : std_logic := '0';

    -- Valores nuevos ya calculados (registrados, 1 ciclo de latencia)
    signal new_period    : unsigned(19 downto 0) := to_unsigned(PERIOD_1K, 20);
    signal new_period_m1 : unsigned(19 downto 0) := to_unsigned(PERIOD_1K - 1, 20);
    signal new_threshold : unsigned(19 downto 0) := to_unsigned(PERIOD_1K / 2, 20);
    signal cfg_valid_d   : std_logic := '0';

begin

    -- Calculo registrado de periodo y umbral segun freq_sel y duty_cycle
    p_calc: process(clk)
        variable duty : unsigned(6 downto 0);
    begin
        if rising_edge(clk) then
            duty := unsigned(duty_cycle);
            case freq_sel is
                when "01" =>
                    new_period    <= to_unsigned(PERIOD_1K, 20);
                    new_period_m1 <= to_unsigned(PERIOD_1K - 1, 20);
                    new_threshold <= resize(duty * to_unsigned(STEP_1K, 11), 20);
                when "10" =>
                    new_period    <= to_unsigned(PERIOD_10K, 20);
                    new_period_m1 <= to_unsigned(PERIOD_10K - 1, 20);
                    new_threshold <= resize(duty * to_unsigned(STEP_10K, 11), 20);
                when "11" =>
                    new_period    <= to_unsigned(PERIOD_100K, 20);
                    new_period_m1 <= to_unsigned(PERIOD_100K - 1, 20);
                    new_threshold <= resize(shift_right(duty * to_unsigned(STEP_100K, 8), 1), 20);
                when others =>
                    new_period    <= to_unsigned(PERIOD_1K, 20);
                    new_period_m1 <= to_unsigned(PERIOD_1K - 1, 20);
                    new_threshold <= resize(duty * to_unsigned(STEP_1K, 11), 20);
            end case;
            -- cfg_valid se retrasa 1 ciclo para esperar el calculo registrado
            cfg_valid_d <= cfg_valid;
        end if;
    end process;

    -- Contador PWM y salida
    p_pwm: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter   <= (others => '0');
                period    <= to_unsigned(PERIOD_1K, 20);
                period_m1 <= to_unsigned(PERIOD_1K - 1, 20);
                threshold <= to_unsigned(PERIOD_1K / 2, 20);
                pwm_reg   <= '0';
            else
                if cfg_valid_d = '1' then
                    -- Carga de nueva configuracion y reinicio del contador
                    period    <= new_period;
                    period_m1 <= new_period_m1;
                    threshold <= new_threshold;
                    counter   <= (others => '0');
                else
                    -- Contador PWM: 0 .. period-1
                    if counter = period_m1 then
                        counter <= (others => '0');
                    else
                        counter <= counter + 1;
                    end if;
                end if;

                -- Comparacion para salida registrada
                if counter < threshold then
                    pwm_reg <= '1';
                else
                    pwm_reg <= '0';
                end if;
            end if;
        end if;
    end process;

    pwm_out    <= pwm_reg;
    dbg_period <= std_logic_vector(period);
    dbg_thresh <= std_logic_vector(threshold);
    dbg_cnt    <= std_logic_vector(counter);

end architecture rtl;