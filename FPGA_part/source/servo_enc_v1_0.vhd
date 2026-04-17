-------------------------------------------------------------------------------------------------
-- Encoder interface for ServoDriver(Presto solution)                        --------------------
-- Author     :    Andy Kim.
-- Desc.      :    Top block of servo encoder interface
-- Last Fix:  :    2024. 0x.  .
-- Tartget    :    XC7S25-1FTGB196
-- Contens    :    
-- History :
-- 1) 2024. 03. 13  -. Start
-- 2) 2024. xx. xx  -. First fix
-- 3) 
-- 4) 
-- 5) 
-------------------------------------------------------------------------------------------------
                

Library ieee;
Use ieee.std_logic_1164.all;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;
use work.typedef_servo_enc.all;

ENTITY  servo_enc_v1_0 is
    PORT (

    -- fmc_cs2N    : in std_logic;
        iresetn       : in std_logic;                   -- reset input
        fpga_clk      : in std_logic;                   -- FPGA main clock : up to 64MHz

    ---- Local bus interface -------------------------------------------------------
        fmc_csn     : in std_logic;                         -- bus chip selector
        fmc_rdn     : in std_logic;                         -- bus read enable
        fmc_wrn     : in std_logic;                         -- bus write enable
        fmc_waitn   : out std_logic;                        -- bus wait strobe
        fmc_ab      : in std_logic_vector (13 DOWNTO 0);    -- bus Address bus
        fmc_db      : inout std_logic_vector (15 DOWNTO 0); -- bus DataBus
    --------------------------------------------------------------------------------

    ---- status led output   -------------------------------------------------------
        status_led  : out std_logic_vector(3 downto 0);
    --------------------------------------------------------------------------------

    ---- encoder #1 input interface --------------------------------------------
        enc_a_cnt1          : in std_logic;
        enc_b_cnt1          : in std_logic;
        enc_c_cnt1          : in std_logic;
        hall_w_cnt1         : in std_logic;

        uart_rx_cnt1_1      : in std_logic;
        uart_tx_cnt1_1      : out std_logic;
        uart_dir_cnt1_1     : out std_logic;

        uart_rx_cnt1_2      : in std_logic;
        uart_tx_cnt1_2      : out std_logic;
        uart_dir_cnt1_2     : out std_logic;
    --------------------------------------------------------------------------------

    ---- encoder #2 input interface --------------------------------------------
        enc_a_cnt2          : in std_logic;
        enc_b_cnt2          : in std_logic;
        enc_c_cnt2          : in std_logic;
        hall_w_cnt2         : in std_logic;

        uart_rx_cnt2_1      : in std_logic;
        uart_tx_cnt2_1      : out std_logic;
        uart_dir_cnt2_1     : out std_logic;

        uart_rx_cnt2_2      : in std_logic;
        uart_tx_cnt2_2      : out std_logic;
        uart_dir_cnt2_2     : out std_logic;
    --------------------------------------------------------------------------------

    ---- Delta Sigma  group2 -------------------------------------------------------
        ds_clk_out             : out std_logic_vector(6 downto 1);
        ds_data_in             : in std_logic_vector(6 downto 1);
    --------------------------------------------------------------------------------

    ---- NTC spi interface for ADS7042 ---------------------------------------------
        ntc_csn             : out std_logic;
        ntc_sclk            : out std_logic;
        ntc_sdi             : in std_logic;
        ntc_sdo             : out std_logic;
    --------------------------------------------------------------------------------

    ---- STO status control --------------------------------------------------------
        fdm                 : in std_logic;
        sto1                : in std_logic;
        sto2                : in std_logic;
        pwm_buffer_con      : out std_logic;
    --------------------------------------------------------------------------------

    ---- AMP status/control --------------------------------------------------------
        ipm_fault           : in std_logic;
        power_fault         : in std_logic;
        fan_status          : in std_logic;

        fan_enable          : out std_logic;
        regen_brake         : out std_logic;
        rdy_rly             : out std_logic;
        dbr_rly             : out std_logic;
    --------------------------------------------------------------------------------
    ---- General purppose input/output ---------------------------------------------
        gp_in               : in std_logic_vector(3 downto 0);
        gp_out              : out std_logic_vector(3 downto 0)
    --------------------------------------------------------------------------------
);

END servo_enc_v1_0;

ARCHITECTURE behavior OF servo_enc_v1_0 is

    component emif_con is
    PORT (    
        ireset                      : in std_logic;                            -- Reset signal from pci.
        iclk                        : in std_logic;                            -- MCU local & FPGA clock : 50MHz
        ics                         : in std_logic;                            -- selection strobe from MCU.
        iwr                         : in std_logic;                            -- write strobe from MCU.
        ird                         : in std_logic;                            -- read strobe from MCU.
        i_sa                        : in std_logic_vector(15 downto 0);        -- Address from MCU.
        i_sd_in                     : in std_logic_vector(15 downto 0);        -- local data bus from MCU.
        o_sd_out                    : out std_logic_vector(15 downto 0);       -- local data bus from MCU.
        o_bus_oe                    : out std_logic;                           -- local bus output enable strobe.

        soft_reset                  : out std_logic;                           -- software reset.
        command_load_data           : out std_logic_vector(31 downto 0);

        -- general purpose status and configure data --------------------------
        encoder_data                : in  ar_32bit_6ea;
        counter_config              : out ar_16bit_6ea;
        counter_status              : in  ar_16bit_6ea;
        counter_load_exe            : out std_logic_vector(5 downto 0);        -- counter load exexcution
        -----------------------------------------------------------------------

        -- general purpose status and configure data --------------------------
        delta_sigma_config          : out ar_16bit_6ea;
        delta_sigma_status          : in ar_16bit_6ea;
        delta_sigma_data            : in ar_32bit_6ea;
        -----------------------------------------------------------------------

        -- general purpose status and configure data --------------------------
        spi_config                  : out std_logic_vector(15 downto 0);
        spi_status                  : in std_logic_vector(15 downto 0);
        spi_data                    : in std_logic_vector(31 downto 0);
        -----------------------------------------------------------------------

        universal_config            : out ar_16bit_8ea;
        universal_status            : in ar_16bit_8ea;
        mechanical_status           : in ar_16bit_4ea;
        gpio_in                     : in std_logic_vector(15 downto 0);
        gpio_out                    : out std_logic_vector(15 downto 0);
        servo_io_in                 : in std_logic_vector(15 downto 0);
        servo_io_out                : out std_logic_vector(15 downto 0)
    );
    end component;


    component servo_encoder_con
    port(
        reset              : in std_logic;
        clk                : in std_logic;
        soft_reset         : in std_logic;                        -- Software reset signal.

    ---- encoder #1 input interface --------------------------------------------
        enc_a              : in std_logic;
        enc_b              : in std_logic;
        enc_c              : in std_logic;
        hall_w             : in std_logic;

        enc_a_filtered     : out std_logic;
        enc_b_filtered     : out std_logic;
        enc_c_filtered     : out std_logic;
        hall_w_filtered    : out std_logic;

        uart_rx_cnt1_1      : in std_logic;
        uart_tx_cnt1_1      : out std_logic;
        uart_dir_cnt1_1     : out std_logic;

        uart_rx_cnt1_2      : in std_logic;
        uart_tx_cnt1_2      : out std_logic;
        uart_dir_cnt1_2     : out std_logic;

        counter_load_enc   : in std_logic_vector(2 downto 0);
        counter_load_data  : in std_logic_vector(31 downto 0);

        counter_config     : in ar_16bit_3ea;

        counter_status     : out ar_16bit_3ea;
        counter_data       : out ar_32bit_3ea;
        counter_enc_en     : out std_logic_vector(2 downto 0);
        counter_enc_dir    : out std_logic_vector(2 downto 0)
    );
    end component;

    component delta_sigma
    port(
        reset              : in std_logic;
        clk                : in std_logic;
        soft_reset         : in std_logic;                        -- Software reset signal.

    ---- Delta Sigma  group2 -------------------------------------------------------
        ds_clk_out         : out std_logic;
        ds_data_in         : in std_logic;
    --------------------------------------------------------------------------------

     -- general purpose status and configure data --------------------------
        delta_sigma_config : in std_logic_vector(15 downto 0);
        delta_sigma_status : out std_logic_vector(15 downto 0);
        delta_sigma_data   : out std_logic_vector(31 downto 0)
     -----------------------------------------------------------------------
    );
    end component;

    component spi_master
      port(
        reset   : in     std_logic;                             --asynchronous reset
        clk     : in     std_logic;                             --system clock  (64MHz)
        enable  : in     std_logic;                             -- enable for SPI(active high)
    
        mosi    : out     std_logic;                            --master out, slave in
        miso    : in     std_logic;                             --master in, slave out
        sclk    : out    std_logic;                             --spi clock
        ss_n    : out    std_logic;                             --slave select

        busy    : out    std_logic;                             --busy / data ready signal
        rx_data : out    std_logic_vector(15 downto 0)          --data received
    );
    end component;

    signal o_sd_out_lo              : std_logic_vector(15 downto 0);
    signal o_bus_oe_lo              : std_logic;
    signal soft_reset_lo            : std_logic;
    signal command_load_data_lo     : std_logic_vector(31 downto 0);
    signal counter_data_lo          : ar_32bit_6ea;
    signal counter_config_lo        : ar_16bit_6ea;
    signal counter_status_lo        : ar_16bit_6ea;
    signal counter_load_exe_lo      : std_logic_vector(5 downto 0);        -- counter load exexcution
    signal delta_sigma_config_lo    : ar_16bit_6ea;
    signal delta_sigma_status_lo    : ar_16bit_6ea;
    signal delta_sigma_data_lo      : ar_32bit_6ea;
    signal spi_config_lo            : std_logic_vector(15 downto 0);
    signal spi_status_lo            : std_logic_vector(15 downto 0);
    signal spi_data_lo              : std_logic_vector(31 downto 0);
    signal mechanical_status_lo     : ar_16bit_4ea;
    signal gpio_in_lo               : std_logic_vector(15 downto 0);
    signal gpio_out_lo              : std_logic_vector(15 downto 0);
    signal servo_io_in_lo           : std_logic_vector(15 downto 0);
    signal servo_io_out_lo          : std_logic_vector(15 downto 0);
    signal counter_config1_lo       : ar_16bit_3ea;
    signal counter_config2_lo       : ar_16bit_3ea;
    signal counter_data1_lo : ar_32bit_3ea;
    signal counter_data2_lo : ar_32bit_3ea;   
    
    signal counter_status1_lo : ar_16bit_3ea;    
    signal counter_status2_lo : ar_16bit_3ea;     

    signal counter_enc1_en_lo     : std_logic_vector(2 downto 0);
    signal counter_enc1_dir_lo    : std_logic_vector(2 downto 0);
    signal counter_enc2_en_lo     : std_logic_vector(2 downto 0);
    signal counter_enc2_dir_lo    : std_logic_vector(2 downto 0);

    signal universal_config_lo    : ar_16bit_8ea;
    signal universal_status_lo    : ar_16bit_8ea;
        
    signal clock_count_lo         : std_logic_vector(31 downto 0);
    signal clock_led_lo           : std_logic;
    
    signal u2_enc_filter : std_logic_vector(3 downto 0); -- 임시 신호 추가
    
BEGIN

    gpio_in_lo <= X"0030";
--    gpio_in_lo   <= X"000" & gp_in;
    gp_out       <= gpio_out_lo(3 downto 0);
    status_led   <=  clock_led_lo & o_bus_oe_lo & counter_enc2_en_lo(0) & counter_enc1_en_lo(0);
    fmc_waitn    <= '1';
    fmc_db      <= o_sd_out_lo when o_bus_oe_lo = '1' else (others => 'Z');

    process(fpga_clk, iresetn) begin
        if iresetn = '0' then
            clock_count_lo  <= (others => '0');         
            clock_led_lo    <= '0';           
        elsif rising_edge(fpga_clk) then
            if clock_count_lo = x"01E847FF" then    -- 0.5 sec with FPGA clock(64MHz)
                clock_count_lo  <= (others => '0');
                clock_led_lo    <= not clock_led_lo;
            else
                clock_count_lo  <= clock_count_lo + 1;  
            end if;
        end if;
    end process;



    U_emif_con : emif_con 
    port map(
        ireset                      => iresetn,
        iclk                        => fpga_clk, 
        ics                         => fmc_csn,
        iwr                         => fmc_wrn,
        ird                         => fmc_rdn,
        i_sa                        => '0' & fmc_ab & '0',
        i_sd_in                     => fmc_db,
        o_sd_out                    => o_sd_out_lo,
        o_bus_oe                    => o_bus_oe_lo,


        soft_reset                  => soft_reset_lo,
        command_load_data           => command_load_data_lo,

        -- general purpose status and configure data --------------------------
        encoder_data                => counter_data_lo,
        counter_config              => counter_config_lo,
        counter_status              => counter_status_lo,
        counter_load_exe            => counter_load_exe_lo,
        -----------------------------------------------------------------------

        -- general purpose status and configure data --------------------------
        delta_sigma_config          => delta_sigma_config_lo,
        delta_sigma_status          => delta_sigma_status_lo,
        delta_sigma_data            => delta_sigma_data_lo,
        -----------------------------------------------------------------------

        -- general purpose status and configure data --------------------------
        spi_config                  => spi_config_lo,
        spi_status                  => spi_status_lo,
        spi_data                    => spi_data_lo,
        -----------------------------------------------------------------------

        universal_config            => open,
        universal_status            => universal_status_lo,
        mechanical_status           => mechanical_status_lo,
        gpio_in                     => gpio_in_lo,
        gpio_out                    => gpio_out_lo,
        servo_io_in                 => servo_io_in_lo,
        servo_io_out                => servo_io_out_lo        
    );

    mechanical_status_lo(2) <= "000000" & counter_enc2_en_lo & counter_enc2_dir_lo & u2_enc_filter;

    
    counter_status_lo(1) <= counter_status1_lo(1);
    counter_status_lo(2) <= counter_status1_lo(2);
    counter_status_lo(3) <= counter_status1_lo(3);
    counter_status_lo(4) <= counter_status2_lo(1);
    counter_status_lo(5) <= counter_status2_lo(2);
    counter_status_lo(6) <= counter_status2_lo(3);                

    counter_data_lo(1) <= counter_data1_lo(1);
    counter_data_lo(2) <= counter_data1_lo(2);
    counter_data_lo(3) <= counter_data1_lo(3);
    counter_data_lo(4) <= counter_data2_lo(1);
    counter_data_lo(5) <= counter_data2_lo(2);
    counter_data_lo(6) <= counter_data2_lo(3);
    
    counter_config1_lo(1) <= counter_config_lo(1);
    counter_config1_lo(2) <= counter_config_lo(2);
    counter_config1_lo(3) <= counter_config_lo(3);
    counter_config2_lo(1) <= counter_config_lo(4);
    counter_config2_lo(2) <= counter_config_lo(5);
    counter_config2_lo(3) <= counter_config_lo(6);    
        
    U1_servo_encoder_con : servo_encoder_con 
    port map(
        reset              => iresetn,
        clk                => fpga_clk,
        soft_reset         => soft_reset_lo,

        enc_a              => enc_a_cnt1,  
        enc_b              => enc_b_cnt1,  
        enc_c              => enc_c_cnt1,  
        hall_w             => hall_w_cnt1, 

        enc_a_filtered => u2_enc_filter(0),
        enc_b_filtered => u2_enc_filter(1),
        enc_c_filtered => u2_enc_filter(2),
        hall_w_filtered => u2_enc_filter(3),

        uart_rx_cnt1_1     => uart_rx_cnt1_1,
        uart_tx_cnt1_1     => uart_tx_cnt1_1,
        uart_dir_cnt1_1    => uart_dir_cnt1_1,
                                              
        uart_rx_cnt1_2     => uart_rx_cnt1_2,
        uart_tx_cnt1_2     => uart_tx_cnt1_2,
        uart_dir_cnt1_2    => uart_dir_cnt1_2,

        counter_load_enc   => counter_load_exe_lo(2 downto 0),
        counter_load_data  => command_load_data_lo,

        counter_config     => counter_config1_lo,

        counter_status     => counter_status1_lo,
        counter_data       => counter_data1_lo,          
        counter_enc_en     => counter_enc1_en_lo,
        counter_enc_dir    => counter_enc1_dir_lo
    );

    U2_servo_encoder_con : servo_encoder_con 
    port map(
        reset              => iresetn,
        clk                => fpga_clk,
        soft_reset         => soft_reset_lo,

        enc_a              => enc_a_cnt2,  
        enc_b              => enc_b_cnt2,  
        enc_c              => enc_c_cnt2,  
        hall_w             => hall_w_cnt2, 

        enc_a_filtered     => mechanical_status_lo(2)(0),
        enc_b_filtered     => mechanical_status_lo(2)(1),
        enc_c_filtered     => mechanical_status_lo(2)(2),
        hall_w_filtered    => mechanical_status_lo(2)(3),

        uart_rx_cnt1_1     => uart_rx_cnt2_1,
        uart_tx_cnt1_1     => uart_tx_cnt2_1,
        uart_dir_cnt1_1    => uart_dir_cnt2_1,
                                              
        uart_rx_cnt1_2     => uart_rx_cnt2_2,
        uart_tx_cnt1_2     => uart_tx_cnt2_2,
        uart_dir_cnt1_2    => uart_dir_cnt2_2,

        counter_load_enc   => counter_load_exe_lo(5 downto 3),
        counter_load_data  => command_load_data_lo,

        counter_config     => counter_config2_lo,

        counter_status     => counter_status2_lo,
        counter_data       => counter_data2_lo,          
        counter_enc_en     => counter_enc2_en_lo,
        counter_enc_dir    => counter_enc2_dir_lo
    );
    
        universal_status_lo  <= (others => (others => '0'));

delta_sigma_mapping : for j in 1 to 6 generate

    U_delta_sigma : delta_sigma
    port map(
        reset              => iresetn,
        clk                => fpga_clk,
        soft_reset         => soft_reset_lo,

    ---- Delta Sigma  group2 -------------------------------------------------------
        ds_clk_out         => ds_clk_out(j),             
        ds_data_in         => ds_data_in(j),
    --------------------------------------------------------------------------------

     -- general purpose status and configure data --------------------------
        delta_sigma_config => delta_sigma_config_lo(j),
        delta_sigma_status => delta_sigma_status_lo(j), 
        delta_sigma_data   => delta_sigma_data_lo(j)   
     -----------------------------------------------------------------------
    );
end generate delta_sigma_mapping;

signal_shaper : process(iresetn, fpga_clk) begin
    if iresetn = '0' then
        servo_io_in_lo  <= (others => '0');
        pwm_buffer_con  <= '0';
        fan_enable      <= '0';
        regen_brake     <= '0'; 
        rdy_rly         <= '0';
        dbr_rly         <= '0';
    elsif rising_edge(fpga_clk) then
        servo_io_in_lo  <= ( 0 => fdm, 1 => sto1, 2 => sto2, 3 => ipm_fault, 4 => power_fault, 5 => fan_status, others => '0'); 
        pwm_buffer_con  <= servo_io_out_lo(0);
        fan_enable      <= servo_io_out_lo(1);
        regen_brake     <= servo_io_out_lo(2);
        rdy_rly         <= servo_io_out_lo(3);
        dbr_rly         <= servo_io_out_lo(4);
    end if;
end process signal_shaper;

    spi_data_lo(31 downto 16) <= (others => '0');              
    spi_status_lo(15 downto 1) <= (others => '0');
    U_spi_master : spi_master 
      port map(
        reset   => iresetn,
        clk     => fpga_clk,
        enable  => spi_config_lo(0),
    
        mosi    => ntc_sdo,
        miso    => ntc_sdi,
        sclk    => ntc_sclk,
        ss_n    => ntc_csn,

        busy    => spi_status_lo(0),
        rx_data => spi_data_lo(15 downto 0)              
    );

END behavior;
