-------------------------------------------------------------------------------------------------
-- Encoder interface logic--------------------
-- DATA       :    2024. 03. 14.
-- Author     :    Andy Kim.
-- Desc.      :    encoder interface logic
-- Last Fix:  :    2024. 03. 14.
-- Tartget    :    XC7S25-1FTGB196
-- Contens    :    
-- History :
-- 1) 2024. 03. 14  -. First coding.
-- 2) 2024. xx. xx  -. 
-- 3) 
-- 4) 
-- 5) 
-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- Description : counter unit with external encoder signals.
-- 1) counter_config(1)(LSB)
--    0 bit : reverse.(0: normal, 1:reverse)
--    2~1 bit : count source selection.
--              "00" : A/B 2 phase signal,
--              "01" : Z phase signal
--              "10" : hall w 
--              "11" : reserved.
--    3   bit : reserved.
--    5~4 bit : count mode
--            "00" up/Down mode 
--            "01" 2 phase, 1times
--            "10" 2 phase, 2times
--            "11" 2 phase, 4times
--    7~6 bit : reserved.
-- 2) counter_config(MSB) : Filter setting
---------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;
use work.typedef_servo_enc.all;

entity servo_encoder_con is
    port(
        reset               : in std_logic;
        clk                 : in std_logic;
        soft_reset          : in std_logic;                        -- Software reset signal.

    ---- encoder #1 input interface --------------------------------------------
        enc_a               : in std_logic;
        enc_b               : in std_logic;
        enc_c               : in std_logic;
        hall_w              : in std_logic;

        enc_a_filtered      : out std_logic;
        enc_b_filtered      : out std_logic;
        enc_c_filtered      : out std_logic;
        hall_w_filtered     : out std_logic;

        uart_rx_cnt1_1      : in std_logic;
        uart_tx_cnt1_1      : out std_logic;
        uart_dir_cnt1_1     : out std_logic;

        uart_rx_cnt1_2      : in std_logic;
        uart_tx_cnt1_2      : out std_logic;
        uart_dir_cnt1_2     : out std_logic;

        counter_load_enc    : in std_logic_vector(2 downto 0);
        counter_load_data   : in std_logic_vector(31 downto 0);

        counter_config      : in ar_16bit_3ea;

        counter_status      : out ar_16bit_3ea;
        counter_data        : out ar_32bit_3ea;
        counter_enc_en      : out std_logic_vector(2 downto 0);
        counter_enc_dir     : out std_logic_vector(2 downto 0);

        dbg_phase_a_tmp     : out std_logic_vector(3 downto 0);
        dbg_phase_b_tmp     : out std_logic_vector(3 downto 0);
        dbg_phase_a_filter  : out std_logic_vector(7 downto 0);
        dbg_phase_b_filter  : out std_logic_vector(7 downto 0);
        dbg_phase_a_exe     : out std_logic;
        dbg_phase_b_exe     : out std_logic;
        dbg_count_enc_enable: out std_logic;
        dbg_cnt_enc_local   : out std_logic_vector(31 downto 0)
    );
end servo_encoder_con;

architecture beh of servo_encoder_con is

-- signals for encoders -----------------------------------------------------------
    signal phase_a_tmp        : std_logic_vector(3 downto 0);
    signal phase_b_tmp        : std_logic_vector(3 downto 0);
    signal phase_z_tmp        : std_logic_vector(3 downto 0);
    signal hall_w_tmp         : std_logic_vector(3 downto 0);

    signal phase_a_exe        : std_logic;
    signal phase_b_exe        : std_logic;

    signal phase_z_exe        : std_logic;
    signal hall_w_exe         : std_logic;

    signal phase_a_exe_d1     : std_logic;
    signal phase_b_exe_d1     : std_logic;
    signal phase_z_exe_d1     : std_logic;
    signal hall_w_exe_d1      : std_logic;

    signal phase_a_r          : std_logic;
    signal phase_b_r          : std_logic;
    signal phase_z_r          : std_logic;
    signal hall_w_r           : std_logic;
    signal phase_a_f          : std_logic;
    signal phase_b_f          : std_logic;
    signal phase_z_f          : std_logic;
    signal hall_w_f           : std_logic;

    signal count_enc_enable         : std_logic;
    signal count_enc_dir            : std_logic;
    signal count_enc_enable_active  : std_logic;
    signal count_enc_dir_active     : std_logic;

    signal filter_enc_config        : std_logic_vector(7 downto 0);
    signal phase_a_filter           : std_logic_vector(7 downto 0);
    signal phase_b_filter           : std_logic_vector(7 downto 0);
    signal phase_z_filter           : std_logic_vector(7 downto 0);
    signal hall_w_filter            : std_logic_vector(7 downto 0);

    signal cnt_enc_local            : std_logic_vector(31 downto 0);

    signal multi_turn_1_lo          : std_logic_vector(23 downto 0);
    signal single_turn_1_lo         : std_logic_vector(23 downto 0);
    signal multi_turn_2_lo          : std_logic_vector(23 downto 0);
    signal single_turn_2_lo         : std_logic_vector(23 downto 0);

    signal counter_status_lo        : ar_16bit_3ea;

    component tamakawa_interface is
    PORT (
        ireset         : in std_logic;
        iclk           : in std_logic;  -- 64MHz
        soft_reset     : in std_logic;
        config         : in std_logic_vector(15 downto 0);

    ---- Yaskawa interface ---------------------------------------------------------
        tk_rx          : in std_logic;
        tk_tx          : out std_logic;
        tk_txen        : out std_logic;
        tk_rxen        : out std_logic;
    --------------------------------------------------------------------------------

        multi_turn     : out std_logic_vector(23 downto 0);
        single_turn    : out std_logic_vector(23 downto 0);

        status         : out std_logic_vector(7 downto 0)
    );
    end component;

------------------------------------------------------------------------------------

begin

    enc_a_filtered <= phase_a_exe;
    enc_b_filtered <= phase_b_exe;
    enc_c_filtered <= phase_z_exe;
    hall_w_filtered <= hall_w_exe;

    dbg_phase_a_tmp      <= phase_a_tmp;
    dbg_phase_b_tmp      <= phase_b_tmp;
    dbg_phase_a_filter   <= phase_a_filter;
    dbg_phase_b_filter   <= phase_b_filter;
    dbg_phase_a_exe      <= phase_a_exe;
    dbg_phase_b_exe      <= phase_b_exe;
    dbg_count_enc_enable <= count_enc_enable;
    dbg_cnt_enc_local    <= cnt_enc_local;

    counter_status <= counter_status_lo;

    counter_data(1) <= cnt_enc_local;

    counter_enc_en(0) <= count_enc_enable;
    counter_enc_en(1) <= '0';
    counter_enc_en(2) <= '0';

    counter_enc_dir(0) <= count_enc_dir xor counter_config(1)(0);
    counter_enc_dir(1) <= '0';
    counter_enc_dir(2) <= '0';

    counter_status_lo(1) <= (
                            0 => phase_a_exe,
                            1 => phase_b_exe,
                            2 => phase_z_exe,
                            3 => hall_w_exe,
                            others => '0');

    counter_data(2) <= multi_turn_1_lo(14 downto 0) & single_turn_1_lo(16 downto 0);
    U_tamakawa_interface1 : tamakawa_interface
    PORT map(
        ireset         => reset,
        iclk           => clk,
        soft_reset     => soft_reset,
        config         => counter_config(2),

    ---- Yaskawa interface ---------------------------------------------------------
        tk_rx          => uart_rx_cnt1_1,
        tk_tx          => uart_tx_cnt1_1,
        tk_txen        => uart_dir_cnt1_1,
        tk_rxen        => open,
    --------------------------------------------------------------------------------

        multi_turn     => multi_turn_1_lo,
        single_turn    => single_turn_1_lo,

        status         => counter_status_lo(2)(7 downto 0)
    );

    counter_data(3) <= multi_turn_2_lo(14 downto 0) & single_turn_2_lo(16 downto 0);
    U_tamakawa_interface2 : tamakawa_interface
    PORT map(
        ireset         => reset,
        iclk           => clk,
        soft_reset     => soft_reset,
        config         => counter_config(3),

    ---- Yaskawa interface ---------------------------------------------------------
        tk_rx          => uart_rx_cnt1_2,
        tk_tx          => uart_tx_cnt1_2,
        tk_txen        => uart_dir_cnt1_2,
        tk_rxen        => open,
    --------------------------------------------------------------------------------

        multi_turn     => multi_turn_2_lo,
        single_turn    => single_turn_2_lo,

        status         => counter_status_lo(3)(7 downto 0)
    );

    phase_a_r <= not phase_a_exe_d1 and phase_a_exe;
    phase_b_r <= not phase_b_exe_d1 and phase_b_exe;
    phase_a_f <= phase_a_exe_d1 and not phase_a_exe;
    phase_b_f <= phase_b_exe_d1 and not phase_b_exe;
    phase_z_r <= not phase_z_exe_d1 and phase_z_exe;
    phase_z_f <= phase_z_exe_d1 and not phase_z_exe;

    hall_w_r <= not hall_w_exe_d1 and hall_w_exe;

    filter_enc_config       <= counter_config(1)(15 downto 8);
    count_enc_enable_active <= count_enc_enable;
    count_enc_dir_active    <= count_enc_dir xor counter_config(1)(0);

    count_enc_block : process(reset, clk) begin
        if reset = '0' then
            phase_a_tmp      <= (others => '0');
            phase_b_tmp      <= (others => '0');
            phase_z_tmp      <= (others => '0');
            hall_w_tmp       <= (others => '0');

            phase_a_filter   <= (others => '0');
            phase_b_filter   <= (others => '0');
            phase_z_filter   <= (others => '0');
            hall_w_filter    <= (others => '0');

--          phase_a_exe      <= '0';
--          phase_b_exe      <= '0';
--          phase_z_exe      <= '0';
--          hall_w_exe       <= '0';

            cnt_enc_local    <= (others => '0');

        elsif rising_edge(clk) then
            phase_a_exe_d1 <= phase_a_exe;
            phase_b_exe_d1 <= phase_b_exe;
            phase_z_exe_d1 <= phase_z_exe;
            hall_w_exe_d1  <= hall_w_exe;

            phase_a_tmp <= phase_a_tmp(2 downto 0) & enc_a;
            phase_b_tmp <= phase_b_tmp(2 downto 0) & enc_b;
            phase_z_tmp <= phase_z_tmp(2 downto 0) & enc_c;
            hall_w_tmp  <= hall_w_tmp(2 downto 0) & hall_w;

            if phase_a_tmp = "0000" then
                if phase_a_filter < filter_enc_config then
                    phase_a_filter <= phase_a_filter + 1;
                else
                    phase_a_exe <= '0';
                end if;
            elsif phase_a_tmp = "1111" then
                if phase_a_filter < filter_enc_config then
                    phase_a_filter <= phase_a_filter + 1;
                else
                    phase_a_exe <= '1';
                end if;
            else
                phase_a_filter <= (others => '0');
            end if;

            if phase_b_tmp = "0000" then
                if phase_b_filter < filter_enc_config then
                    phase_b_filter <= phase_b_filter + 1;
                else
                    phase_b_exe <= '0';
                end if;
            elsif phase_b_tmp = "1111" then
                if phase_b_filter < filter_enc_config then
                    phase_b_filter <= phase_b_filter + 1;
                else
                    phase_b_exe <= '1';
                end if;
            else
                phase_b_filter <= (others => '0');
            end if;

            if phase_z_tmp = "0000" then
                if phase_z_filter < filter_enc_config then
                    phase_z_filter <= phase_z_filter + 1;
                else
                    phase_z_exe <= '0';
                end if;
            elsif phase_z_tmp = "1111" then
                if phase_z_filter < filter_enc_config then
                    phase_z_filter <= phase_z_filter + 1;
                else
                    phase_z_exe <= '1';
                end if;
            else
                phase_z_filter <= (others => '0');
            end if;

            if hall_w_tmp = "0000" then
                if hall_w_filter < filter_enc_config then
                    hall_w_filter <= hall_w_filter + 1;
                else
                    hall_w_exe <= '0';
                end if;
            elsif hall_w_tmp = "1111" then
                if hall_w_filter < filter_enc_config then
                    hall_w_filter <= hall_w_filter + 1;
                else
                    hall_w_exe <= '1';
                end if;
            else
                hall_w_filter <= (others => '0');
            end if;

            if counter_load_enc(0) = '1' then
                cnt_enc_local <= counter_load_data;
            else
                if count_enc_enable = '1' then
                    if (count_enc_dir xor counter_config(1)(0)) = '0' then
                        cnt_enc_local <= cnt_enc_local + 1;
                    else
                        cnt_enc_local <= cnt_enc_local - 1;
                    end if;
                end if;
            end if;

            if counter_config(1)(2 downto 1) = "00" then
                case counter_config(1)(5 downto 4) is
                    when "00" =>
                        if phase_a_r = '1' then
                            count_enc_enable <= '1';
                            count_enc_dir    <= '0';
                        elsif phase_b_r = '1' then
                            count_enc_enable <= '1';
                            count_enc_dir    <= '1';
                        else
                            count_enc_enable <= '0';
                            count_enc_dir    <= '0';
                        end if;

                    when "01" =>
                        if phase_a_r = '1' and phase_b_exe = '0' then
                            count_enc_enable <= '1';
                            count_enc_dir    <= '0';
                        elsif phase_a_f = '1' and phase_b_exe = '0' then
                            count_enc_enable <= '1';
                            count_enc_dir    <= '1';
                        else
                            count_enc_enable <= '0';
                            count_enc_dir    <= '0';
                        end if;

                    when "10" =>
                        if phase_a_r = '1' then
                            if phase_b_exe = '0' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            end if;
                        elsif phase_a_f = '1' then
                            if phase_b_exe = '1' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            end if;
                        else
                            count_enc_enable <= '0';
                            count_enc_dir    <= '0';
                        end if;

                    when "11" =>
                        if phase_a_r = '1' then
                            if phase_b_exe = '0' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            end if;
                        elsif phase_a_f = '1' then
                            if phase_b_exe = '0' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            end if;
                        elsif phase_b_r = '1' then
                            if phase_a_exe = '0' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            end if;
                        elsif phase_b_f = '1' then
                            if phase_a_exe = '0' then
                                count_enc_enable <= '1';
                                count_enc_dir    <= '0';
                            else
                                count_enc_enable <= '1';
                                count_enc_dir    <= '1';
                            end if;
                        else
                            count_enc_enable <= '0';
                            count_enc_dir    <= '0';
                        end if;

                    when others =>
                        count_enc_enable <= '0';
                        count_enc_dir    <= '0';
                end case;

            elsif counter_config(1)(2 downto 1) = "01" then
                if phase_z_r = '1' then
                    count_enc_enable <= '1';
                    count_enc_dir    <= '0';
                else
                    count_enc_enable <= '0';
                    count_enc_dir    <= '0';
                end if;

            elsif counter_config(1)(2 downto 1) = "10" then
                if hall_w_r = '1' then
                    count_enc_enable <= '1';
                    count_enc_dir    <= '0';
                else
                    count_enc_enable <= '0';
                    count_enc_dir    <= '0';
                end if;

            else
                count_enc_enable <= '0';
                count_enc_dir    <= '0';
            end if;
        end if;
    end process count_enc_block;

end beh;
