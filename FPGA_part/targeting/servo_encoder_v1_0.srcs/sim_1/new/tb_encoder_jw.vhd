-------------------------------------------------------------------------------------------------
-- Testbench for servo_encoder_con
-- Target : A/B 증분형 인코더 시뮬레이션
-------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.typedef_servo_enc.all;

entity tb_servo_encoder_con is
end tb_servo_encoder_con;

architecture sim of tb_servo_encoder_con is

    component servo_encoder_con
    port(
        reset              : in std_logic;
        clk                : in std_logic;
        soft_reset         : in std_logic;
        enc_a              : in std_logic;
        enc_b              : in std_logic;
        enc_c              : in std_logic;
        hall_w             : in std_logic;
        enc_a_filtered     : out std_logic;
        enc_b_filtered     : out std_logic;
        enc_c_filtered     : out std_logic;
        hall_w_filtered    : out std_logic;
        uart_rx_cnt1_1     : in std_logic;
        uart_tx_cnt1_1     : out std_logic;
        uart_dir_cnt1_1    : out std_logic;
        uart_rx_cnt1_2     : in std_logic;
        uart_tx_cnt1_2     : out std_logic;
        uart_dir_cnt1_2    : out std_logic;
        counter_load_enc   : in std_logic_vector(2 downto 0);
        counter_load_data  : in std_logic_vector(31 downto 0);
        counter_config     : in ar_16bit_3ea;
        counter_status     : out ar_16bit_3ea;
        counter_data       : out ar_32bit_3ea;
        counter_enc_en     : out std_logic_vector(2 downto 0);
        counter_enc_dir    : out std_logic_vector(2 downto 0)
        -- synthesis translate_off
        ;
        dbg_phase_a_exe    : out std_logic;
        dbg_phase_b_exe    : out std_logic;
        dbg_phase_z_exe    : out std_logic;
        dbg_hall_w_exe     : out std_logic;
        dbg_phase_a_r      : out std_logic;
        dbg_phase_b_r      : out std_logic;
        dbg_phase_a_f      : out std_logic;
        dbg_phase_b_f      : out std_logic;
        dbg_phase_a_tmp    : out std_logic_vector(3 downto 0);
        dbg_phase_b_tmp    : out std_logic_vector(3 downto 0);
        dbg_phase_a_filter : out std_logic_vector(7 downto 0);
        dbg_phase_b_filter : out std_logic_vector(7 downto 0)
        -- synthesis translate_on
    );
    end component;

    -- 클럭/리셋
    signal clk             : std_logic := '0';
    signal reset           : std_logic := '0';
    signal soft_reset      : std_logic := '0';

    -- 인코더 입력
    signal enc_a           : std_logic := '0';
    signal enc_b           : std_logic := '0';
    signal enc_c           : std_logic := '0';
    signal hall_w          : std_logic := '0';

    -- 필터 출력 (미사용)
    signal enc_a_filtered  : std_logic;
    signal enc_b_filtered  : std_logic;
    signal enc_c_filtered  : std_logic;
    signal hall_w_filtered : std_logic;

    -- UART (미사용)
    signal uart_rx_cnt1_1  : std_logic := '1';
    signal uart_tx_cnt1_1  : std_logic;
    signal uart_dir_cnt1_1 : std_logic;
    signal uart_rx_cnt1_2  : std_logic := '1';
    signal uart_tx_cnt1_2  : std_logic;
    signal uart_dir_cnt1_2 : std_logic;

    -- 카운터 제어
    signal counter_load_enc  : std_logic_vector(2 downto 0)  := "000";
    signal counter_load_data : std_logic_vector(31 downto 0) := (others => '0');
    signal counter_config    : ar_16bit_3ea;

    -- 카운터 출력
    signal counter_status   : ar_16bit_3ea;
    signal counter_data     : ar_32bit_3ea;
    signal counter_enc_en   : std_logic_vector(2 downto 0);
    signal counter_enc_dir  : std_logic_vector(2 downto 0);

    -- ★ 관찰용 신호 (0번 채널만)
    signal watch_counter_data   : std_logic_vector(31 downto 0);
    signal watch_enc_en         : std_logic;
    signal watch_enc_dir        : std_logic;

    -- 시뮬레이션 파라미터
    constant CLK_PERIOD : time := 15.625 ns;   -- 64MHz
    constant ENC_PERIOD : time := 500 ns;

    -- ★ 내부 신호 관찰용
    signal dbg_phase_a_exe  : std_logic;
    signal dbg_phase_b_exe  : std_logic;
    signal dbg_phase_z_exe  : std_logic;
    signal dbg_hall_w_exe   : std_logic;
    signal dbg_phase_a_r    : std_logic;
    signal dbg_phase_b_r    : std_logic;
    signal dbg_phase_a_f    : std_logic;
    signal dbg_phase_b_f    : std_logic;
    signal dbg_phase_a_tmp  : std_logic_vector(3 downto 0);
    signal dbg_phase_b_tmp  : std_logic_vector(3 downto 0);
    signal dbg_phase_a_filter : std_logic_vector(7 downto 0);
    signal dbg_phase_b_filter : std_logic_vector(7 downto 0);

begin

    -- ★ 관찰용 신호 연결
    watch_counter_data  <= counter_data(1);
    watch_enc_en        <= counter_enc_en(0);
    watch_enc_dir       <= counter_enc_dir(0);

    -- DUT 인스턴스
    DUT : servo_encoder_con
    port map(
        reset              => reset,
        clk                => clk,
        soft_reset         => soft_reset,

        enc_a              => enc_a,
        enc_b              => enc_b,
        enc_c              => enc_c,
        hall_w             => hall_w,

        enc_a_filtered     => enc_a_filtered,
        enc_b_filtered     => enc_b_filtered,
        enc_c_filtered     => enc_c_filtered,
        hall_w_filtered    => hall_w_filtered,

        uart_rx_cnt1_1     => uart_rx_cnt1_1,
        uart_tx_cnt1_1     => uart_tx_cnt1_1,
        uart_dir_cnt1_1    => uart_dir_cnt1_1,

        uart_rx_cnt1_2     => uart_rx_cnt1_2,
        uart_tx_cnt1_2     => uart_tx_cnt1_2,
        uart_dir_cnt1_2    => uart_dir_cnt1_2,

        counter_load_enc   => counter_load_enc,
        counter_load_data  => counter_load_data,
        counter_config     => counter_config,

        counter_status     => counter_status,
        counter_data       => counter_data,
        counter_enc_en     => counter_enc_en,
        counter_enc_dir    => counter_enc_dir
        -- synthesis translate_off
        ,
        dbg_phase_a_exe    => dbg_phase_a_exe,
        dbg_phase_b_exe    => dbg_phase_b_exe,
        dbg_phase_z_exe    => dbg_phase_z_exe,
        dbg_hall_w_exe     => dbg_hall_w_exe,
        dbg_phase_a_r      => dbg_phase_a_r,
        dbg_phase_b_r      => dbg_phase_b_r,
        dbg_phase_a_f      => dbg_phase_a_f,
        dbg_phase_b_f      => dbg_phase_b_f,
        dbg_phase_a_tmp    => dbg_phase_a_tmp,
        dbg_phase_b_tmp    => dbg_phase_b_tmp,
        dbg_phase_a_filter => dbg_phase_a_filter,
        dbg_phase_b_filter => dbg_phase_b_filter
        -- synthesis translate_on
    );

    -- 64MHz 클럭
    clk_gen : process begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_gen;

    -- 메인 시뮬레이션
    stim_proc : process begin

        -- -----------------------------------------------
        -- 1. 초기화 및 리셋
        -- -----------------------------------------------
        reset      <= '0';
        soft_reset <= '0';
        enc_a      <= '0';
        enc_b      <= '0';
        enc_c      <= '0';
        hall_w     <= '0';

        counter_config(1) <= X"0330";  -- 필터3, 4배모드
        counter_config(2) <= X"0000";
        counter_config(3) <= X"0000";

        wait for CLK_PERIOD * 10;
        reset <= '1';
        wait for CLK_PERIOD * 10;

        -- -----------------------------------------------
        -- 2. 정방향 20펄스 (4배 = +80 카운트 예상)
        -- -----------------------------------------------
        for i in 1 to 20 loop
            enc_a <= '1';
            wait for ENC_PERIOD / 4;
            enc_b <= '1';
            wait for ENC_PERIOD / 4;
            enc_a <= '0';
            wait for ENC_PERIOD / 4;
            enc_b <= '0';
            wait for ENC_PERIOD / 4;
        end loop;

        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 3. 역방향 10펄스 (4배 = -40 카운트 예상)
        -- 최종 = +80 - 40 = +40
        -- -----------------------------------------------
        for i in 1 to 10 loop
            enc_b <= '1';
            wait for ENC_PERIOD / 4;
            enc_a <= '1';
            wait for ENC_PERIOD / 4;
            enc_b <= '0';
            wait for ENC_PERIOD / 4;
            enc_a <= '0';
            wait for ENC_PERIOD / 4;
        end loop;

        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 4. Z 펄스
        -- -----------------------------------------------
        enc_c <= '1';
        wait for ENC_PERIOD;
        enc_c <= '0';
        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 5. HALL_W 펄스
        -- -----------------------------------------------
        hall_w <= '1';
        wait for ENC_PERIOD;
        hall_w <= '0';
        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 6. 노이즈 주입 (2클럭 = 필터보다 짧음 → 무시)
        -- -----------------------------------------------
        enc_a <= '1';
        wait for CLK_PERIOD * 2;
        enc_a <= '0';
        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 7. 카운터 강제 로드 (1000으로 설정)
        -- -----------------------------------------------
        counter_load_data <= X"000003E8";
        counter_load_enc  <= "001";
        wait for CLK_PERIOD * 4;
        counter_load_enc  <= "000";
        wait for ENC_PERIOD * 2;

        -- -----------------------------------------------
        -- 8. 강제 로드 후 정방향 10펄스 (4배 = +40)
        -- 최종 = 1000 + 40 = 1040 예상
        -- -----------------------------------------------
        for i in 1 to 10 loop
            enc_a <= '1';
            wait for ENC_PERIOD / 4;
            enc_b <= '1';
            wait for ENC_PERIOD / 4;
            enc_a <= '0';
            wait for ENC_PERIOD / 4;
            enc_b <= '0';
            wait for ENC_PERIOD / 4;
        end loop;

        wait for ENC_PERIOD * 5;

        -- -----------------------------------------------
        -- 9. 소프트 리셋
        -- -----------------------------------------------
        soft_reset <= '1';
        wait for CLK_PERIOD * 4;
        soft_reset <= '0';
        wait for ENC_PERIOD * 5;

        report "Simulation Done" severity note;
        wait;

    end process stim_proc;

end sim;