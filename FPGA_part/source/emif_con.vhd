-------------------------------------------------------------------------------------------------
-- interface(External memory controller)--------------------
-- DATA       :    2024. 03. 14.
-- Author     :    Andy Kim.
-- Desc.      :    bus controller(reg files, address decoder and etc)
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
-- Address Map(aspect to MCU address bus[15:0]))
--  0x6EE0  : PRODUCT_VENDOR(0x5053) 	
--  0x6EE2  : PRODUCT_ID(0xAA01) 	    
--  0x6EE4  : PRODUCT_VER_MSB(0x2024) 
--  0x6EE8  : PRODUCT_VER_LSB(0x0314) 
--  0x7FF2  : read result data register LSB(16 bit)
--  0x7FF4  : read result data register MSB(16 bit)
--  0x7FF6  : write data register LSB(16 bit)
--  0x7FF8  : write data register MSB(16 bit)
--  0x7F0A  : Read  cmd port.
--  0x7F8C  : Write cmd port.
-- Command list
--     X"0500" => counter_load_exe
--     X"0502" => counter_load_exe
--     X"0504" => counter_load_exe
--     X"0506" => counter_load_exe
--     X"0508" => counter_load_exe
--     X"050A" => counter_load_exe
--  0xFFFF  : with :1A5A" ==> soft reset

-- Register direct access region.(address (15 downto 12) == 0x0)
--  0x0100 : counter_config_lo(1)
--  0x0102 : counter_config_lo(2)
--  0x0104 : counter_config_lo(3)
--  0x0106 : counter_config_lo(4)
--  0x0108 : counter_config_lo(5)
--  0x010A : counter_config_lo(6)
--  0x010C : reserved.
--  0x010E : reserved.
--  0x0110 : counter_status(1)
--  0x0112 : counter_status(2)
--  0x0114 : counter_status(3)
--  0x0116 : counter_status(4)
--  0x0118 : counter_status(5)
--  0x011A : counter_status(6)
--  0x011C : reserved.
--  0x011E : reserved.
--  0x0200 : delta_sigma_config_lo(1)
--  0x0202 : delta_sigma_config_lo(2)
--  0x0204 : delta_sigma_config_lo(3)
--  0x0206 : delta_sigma_config_lo(4)
--  0x0208 : delta_sigma_config_lo(5)
--  0x020A : delta_sigma_config_lo(6)
--  0x020C : reserved.
--  0x020E : reserved.
--  0x0210 : delta_sigma_status_lo(1)
--  0x0212 : delta_sigma_status_lo(2)
--  0x0214 : delta_sigma_status_lo(3)
--  0x0216 : delta_sigma_status_lo(4)
--  0x0218 : delta_sigma_status_lo(5)
--  0x021A : delta_sigma_status_lo(6)
--  0x021C : reserved.
--  0x021E : reserved.
--  0x0300 : spi_config_lo
--  0x0302 : reserved.
--  0x0304 : reserved.
--  0x0306 : reserved.
--  0x0308 : reserved.
--  0x030A : reserved.
--  0x030C : reserved.
--  0x030E : reserved.
--  0x0310 : spi_status_lo
--  0x0312 : reserved.
--  0x0314 : reserved.
--  0x0316 : reserved.
--  0x0318 : reserved.
--  0x031A : reserved.
--  0x031C : reserved.
--  0x031E : reserved.
--  0x0400 : gpio_out_lo
--  0x0402 : gpio_out_lo(same with 0x400)
--  0x0404 : gpio_out_lo(same with 0x400)
--  0x0406 : gpio_out_lo(same with 0x400)
--  0x0408 : gpio_in,
--  0x0408 : reserved.
--  0x040A : reserved.
--  0x040C : reserved.
--  0x040E : reserved.
--  0x0410 : mechanical_status(1)
--  0x0412 : mechanical_status(2)
--  0x0414 : mechanical_status(3)
--  0x0418 : mechanical_status(4)
--  0x0600 : universal_config_lo(1).
--  0x0602 : universal_config_lo(2).
--  0x0604 : universal_config_lo(3).
--  0x0606 : universal_config_lo(4).
--  0x0608 : universal_config_lo(5).
--  0x060A : universal_config_lo(6).
--  0x060C : universal_config_lo(7).
--  0x060E : universal_config_lo(8).
--  0x0700 : universal_status_lo(1).
--  0x0702 : universal_status_lo(2).
--  0x0704 : universal_status_lo(3).
--  0x0706 : universal_status_lo(4).
--  0x0708 : universal_status_lo(5).
--  0x070A : universal_status_lo(6).
--  0x070C : universal_status_lo(7).
--  0x070E : universal_status_lo(8).
-------------------------------------------------------------------------------------------------

library IEEE;

use ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;
use work.typedef_servo_enc.all;

entity emif_con is
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
end emif_con;

architecture behavior of emif_con is

    constant 	PRODUCT_VENDOR 	            : std_logic_vector(15 downto 0) := X"5053"; -- is "0x5053"
	constant 	PRODUCT_ID 	                : std_logic_vector(15 downto 0) := X"0106"; -- 0x0104
	constant 	PRODUCT_VER_MSB 	        : std_logic_vector(15 downto 0) := X"2024"; -- version  : 22024
	constant 	PRODUCT_VER_LSB 	        : std_logic_vector(15 downto 0) := X"0608"; -- version  : 0314

    signal      data_port_lo                : std_logic_vector(31 downto 0);
    signal      write_port_lo               : std_logic_vector(15 downto 0);
    signal      write_addr_lo               : std_logic_vector(15 downto 0);
    signal      write_done_lo               : std_logic;
    signal      write_exe_lo                : std_logic;
    signal      write_addr_1st              : std_logic_vector(15 downto 0);
    signal      write_data_1st              : std_logic_vector(15 downto 0);
    signal      write_addr_2nd              : std_logic_vector(15 downto 0);
    signal      write_data_2nd              : std_logic_vector(15 downto 0);
    signal      write_data_lo               : std_logic_vector(15 downto 0);
    signal      write_state_lo              : std_logic_vector(3 downto 0);
    signal      cs_or_wr_lo                 : std_logic;

    signal      read_cmd_exe_lo             : std_logic;
    signal      read_cmd_index_lo           : std_logic_vector(15 downto 0);
    signal      write_reg_exe_lo            : std_logic;
    signal      write_cmd_exe_lo            : std_logic;
    signal      write_cmd_index_lo          : std_logic_vector(15 downto 0);
    signal      read_result_lo              : std_logic_vector(31 downto 0);

    signal      soft_reset_lo               : std_logic;

-- general purpose status and configure data --------------------------
    signal        counter_config_lo           : ar_16bit_6ea;
    signal        counter_load_exe_lo         : std_logic_vector(5 downto 0);        -- counter load exexcution
    -----------------------------------------------------------------------

    -- general purpose status and configure data --------------------------
    signal        delta_sigma_config_lo       : ar_16bit_6ea;
    -----------------------------------------------------------------------

    -- general purpose status and configure data --------------------------
    signal        spi_config_lo               : std_logic_vector(15 downto 0);
    signal        spi_statue_lo               : std_logic_vector(15 downto 0);
    -----------------------------------------------------------------------

    signal        gpio_out_lo                 : std_logic_vector(15 downto 0);
    signal        servo_io_out_lo             : std_logic_vector(15 downto 0);
----------------------------------------------------------------------------------------------

    signal        universal_config_lo         : ar_16bit_8ea;
    signal        command_load_data_lo        : std_logic_vector(31 downto 0);

begin

cs_or_wr_lo <= ics or iwr;
soft_reset  <= soft_reset_lo;
universal_config    <= universal_config_lo;

-- First stage : latch the address and data port to sync with iclk
write_exe_gen : process(ireset,  write_done_lo, cs_or_wr_lo) begin 
    if ireset = '0' then
        write_exe_lo    <=    '0';
        write_addr_1st    <=    (others => '0');
        write_data_1st    <=    (others => '0');
    else
        if write_done_lo = '1' then
            write_exe_lo    <=    '0';
            write_addr_1st    <=    (others => '0');
            write_data_1st    <=    (others => '0');
        else
            if rising_edge(cs_or_wr_lo) then
                write_exe_lo      <= '1';
                write_addr_1st    <= i_sa;
                write_data_1st    <= i_sd_in;
            end if;    -- rising_edge(cs_or_wr)
        end if;    -- cmd_done = '1'
    end if;    -- reset = '0'
end process write_exe_gen;

-- Second stage : Sync the address and data bus with iclk.
write_state_gen : process(ireset, iclk) begin 
    if ireset = '0' then
        write_state_lo    <=    "0000";
        write_done_lo    <=    '0';
        write_addr_2nd     <=    (others => '0');
        write_data_2nd     <=    (others => '0');
        soft_reset_lo   <= '0';
    elsif rising_edge(iclk) then
        if write_exe_lo = '1' then
            if write_state_lo = "0000" then
                soft_reset_lo   <= '0';
                write_done_lo    <=    '0';
                write_state_lo    <=    "0001";
            elsif write_state_lo = "0001" then
                write_done_lo    <=    '0';
                write_state_lo    <=    "0010";
                write_addr_2nd     <=    write_addr_1st;
                write_data_2nd     <=    write_data_1st;
                if write_addr_1st = X"7FFE" and write_data_1st = X"1A5A" then
                    soft_reset_lo   <= '1';
                end if;
            elsif write_state_lo = "0010" then
                write_done_lo    <=    '1';
                write_state_lo    <=    "0011";
            elsif write_state_lo = "0011" then
                write_done_lo    <=    '1';
                write_state_lo    <=    "0000";
                soft_reset_lo   <= '0';
            else
                write_done_lo    <=    '1';
                write_state_lo    <=    "0000";
            end if;
        else
            write_state_lo    <=    "0000";
            write_done_lo    <=    '0';
            soft_reset_lo   <= '0';
        end if;    -- write_exe_lo = '1'
    end if;    -- rising_edge(iclk)
end process write_state_gen;


port_con : process(ireset, iclk) begin
    if ireset = '0' then
        data_port_lo     <=  (others => '0');
        write_port_lo    <=  (others => '0');
        write_addr_lo    <=  (others => '0');
        read_cmd_exe_lo  <=  '0';
        read_cmd_index_lo<=  (others => '0');
        write_reg_exe_lo <=  '0';
        write_cmd_exe_lo <=  '0';
        write_cmd_index_lo <= (others => '0');
    elsif rising_edge(iclk) then
        if soft_reset_lo = '1' then
            data_port_lo     <=  (others => '0');
            write_port_lo    <=  (others => '0');
            write_addr_lo    <=  (others => '0');
            read_cmd_exe_lo  <=  '0';
            write_reg_exe_lo <=  '0';
            write_cmd_exe_lo <=  '0';
        else
            if write_state_lo = "0010" then
                write_port_lo    <=    write_data_2nd;
                write_addr_lo    <=    write_addr_2nd;
                if write_addr_2nd = X"7FF6" then
                    data_port_lo(15 downto 0)    <= write_data_2nd;
                elsif write_addr_2nd = X"7FF8" then 
                    data_port_lo(31 downto 16)    <= write_data_2nd;
                elsif write_addr_2nd = X"7F0A" then 
                    read_cmd_exe_lo  <=  '1';
                    read_cmd_index_lo<=    write_data_2nd;
                elsif write_addr_2nd = X"7F8C" then 
                    write_cmd_exe_lo <=  '1';
                    write_cmd_index_lo<=    write_data_2nd;
                else
                    if write_addr_2nd(15 downto 12) = X"0" then 
                        write_reg_exe_lo <=  '1';
                    else
                        write_reg_exe_lo <=  '0';
                    end if;
                end if;
            else
                read_cmd_exe_lo  <=  '0';
                write_reg_exe_lo <=  '0';
                write_cmd_exe_lo <=  '0';
            end if;
        end if;
    end if; -- rising_edge(clk)
end process port_con;


-- external register write data ----------------------------------------------------------------
command_load_data   <= command_load_data_lo;
command_write_data_proc : process (ireset, iclk) begin
    if ireset = '0' then
        command_load_data_lo   <= X"00000000";
    elsif rising_edge(iclk) then
       if write_cmd_exe_lo =  '1' then
            command_load_data_lo   <= data_port_lo;
       end if;
    end if;
end process command_write_data_proc; 


-- register files ----------------------------------------------------------------------------

-- Direct mapped register ------------------------------------------------------------------
 counter_config         <= counter_config_lo;
 delta_sigma_config     <= delta_sigma_config_lo;
 spi_config             <= spi_config_lo;
 gpio_out               <= gpio_out_lo;
 servo_io_out           <= servo_io_out_lo;
 direct_memory_write : process (ireset, iclk) begin
    if ireset = '0' then
        counter_config_lo       <= (others => x"0000");
        delta_sigma_config_lo   <= (others => x"0000");
        spi_config_lo           <= (others => '0');
        gpio_out_lo             <= (others => '0');
        servo_io_out_lo         <= (others => '0');
        counter_load_exe        <= (others => '0');
    elsif rising_edge(iclk) then
        -- Direct write
        if write_reg_exe_lo =  '1' then
            case write_addr_lo is
                when X"0100" => counter_config_lo(1) <= write_port_lo;
                when X"0102" => counter_config_lo(2) <= write_port_lo;
                when X"0104" => counter_config_lo(3) <= write_port_lo;
                when X"0106" => counter_config_lo(4) <= write_port_lo;
                when X"0108" => counter_config_lo(5) <= write_port_lo;
                when X"010A" => counter_config_lo(6) <= write_port_lo;
--              when X"010C" => 
--              when X"010E" => 
                when X"0200" => delta_sigma_config_lo(1) <= write_port_lo;
                when X"0202" => delta_sigma_config_lo(2) <= write_port_lo;
                when X"0204" => delta_sigma_config_lo(3) <= write_port_lo;
                when X"0206" => delta_sigma_config_lo(4) <= write_port_lo;
                when X"0208" => delta_sigma_config_lo(5) <= write_port_lo;
                when X"020A" => delta_sigma_config_lo(6) <= write_port_lo;
--              when X"020C" => 
--              when X"020E" => 
                when X"0300" => spi_config_lo            <= write_port_lo;
--              when X"0302" => 
--              when X"0304" => 
--              when X"0306" => 
--              when X"0308" => 
--              when X"030A" => 
--              when X"030C" => 
--              when X"030E" => 
                when X"0400" => gpio_out_lo            <= write_port_lo;
                when X"0402" => gpio_out_lo            <= gpio_out_lo and write_port_lo;
                when X"0404" => gpio_out_lo            <= gpio_out_lo or  write_port_lo; 
                when X"0406" => gpio_out_lo            <= gpio_out_lo xor write_port_lo;  
--              when X"0408" => 
--              when X"040A" => 
--              when X"040C" => 
--              when X"040E" => 
                when X"0410" => servo_io_out_lo        <= write_port_lo;
                when X"0412" => servo_io_out_lo        <= servo_io_out_lo and write_port_lo;
                when X"0414" => servo_io_out_lo        <= servo_io_out_lo or  write_port_lo; 
                when X"0416" => servo_io_out_lo        <= servo_io_out_lo xor write_port_lo;  
--              when X"0418" => 
--              when X"041A" => 
--              when X"041C" => 
--              when X"041E" => 
                when X"0600" => universal_config_lo(1)  <= write_port_lo;
                when X"0602" => universal_config_lo(2)  <= write_port_lo;
                when X"0604" => universal_config_lo(3)  <= write_port_lo;
                when X"0606" => universal_config_lo(4)  <= write_port_lo;
                when X"0608" => universal_config_lo(5)  <= write_port_lo;
                when X"060A" => universal_config_lo(6)  <= write_port_lo;
                when X"060C" => universal_config_lo(7)  <= write_port_lo;
                when X"060E" => universal_config_lo(8)  <= write_port_lo;
                when others => null;
            end case;
        end if;
        -- In-direct write
        if write_cmd_exe_lo =  '1' then
            case write_cmd_index_lo is
                when X"0500" => counter_load_exe(0) <= '1';
                when X"0502" => counter_load_exe(1) <= '1';
                when X"0504" => counter_load_exe(2) <= '1';
                when X"0506" => counter_load_exe(3) <= '1';
                when X"0508" => counter_load_exe(4) <= '1';
                when X"050A" => counter_load_exe(5) <= '1';
--              when X"050C" => 
--              when X"050E" => 
                when others => null;
            end case;
        else
            counter_load_exe        <= (others => '0');
        end if;
    end if;
end process direct_memory_write;
----------------------------------------------------------------------------------------------


-- Start of read cmd(cmd on 0xFFFA, write port on 0xFFF2, 0xFFF4) ----------------------------
process(ireset, iclk) begin
    if ireset = '0' then
        read_result_lo              <= X"00000000";
    elsif rising_edge(iclk) then
        if read_cmd_exe_lo =  '1' then
          case read_cmd_index_lo is
              when X"0220" => read_result_lo   <= delta_sigma_data(1);
              when X"0222" => read_result_lo   <= delta_sigma_data(2);
              when X"0224" => read_result_lo   <= delta_sigma_data(3);
              when X"0226" => read_result_lo   <= delta_sigma_data(4);
              when X"0228" => read_result_lo   <= delta_sigma_data(5);
              when X"022A" => read_result_lo   <= delta_sigma_data(6);
              when X"0320" => read_result_lo   <= spi_data;
--            when X"022C" => 
--            when X"022E" => 
              when X"0500" => read_result_lo   <= encoder_data(1);
              when X"0502" => read_result_lo   <= encoder_data(2);
              when X"0504" => read_result_lo   <= encoder_data(3);
              when X"0506" => read_result_lo   <= encoder_data(4);
              when X"0508" => read_result_lo   <= encoder_data(5);
              when X"050A" => read_result_lo   <= encoder_data(6);
--            when X"050C" => 
--            when X"050E" => 
              when others => read_result_lo   <= X"BAD0BAD0";
          end case;
        end if;
    end if;
end process;
-- End of read cmd ------------------------------------------------------------------------------------


-- Start of Read bus mux ------------------------------------------------------------------------------
o_bus_oe <= '1' when ird = '0' and ics = '0' else '0';
Read_operation : process(ird, ics, i_sa, 
        gpio_out_lo,
        gpio_in,
        spi_config_lo,
        spi_status,
        counter_config_lo,
        counter_status,
        delta_sigma_config_lo,
        delta_sigma_status,
        read_result_lo,   
        mechanical_status,
        data_port_lo,
        write_port_lo,
        read_cmd_index_lo,
        write_cmd_index_lo,
        command_load_data_lo,
        universal_config_lo,
        universal_status,
        servo_io_out_lo,
        servo_io_in
) begin
    if ird = '0' and ics = '0' then
        case i_sa is
            when X"0100" => o_sd_out    <= counter_config_lo(1);
            when X"0102" => o_sd_out    <= counter_config_lo(2);
            when X"0104" => o_sd_out    <= counter_config_lo(3);
            when X"0106" => o_sd_out    <= counter_config_lo(4);
            when X"0108" => o_sd_out    <= counter_config_lo(5);
            when X"010A" => o_sd_out    <= counter_config_lo(6);
            when X"0110" => o_sd_out    <= counter_status(1);
            when X"0112" => o_sd_out    <= counter_status(2);
            when X"0114" => o_sd_out    <= counter_status(3);
            when X"0116" => o_sd_out    <= counter_status(4);
            when X"0118" => o_sd_out    <= counter_status(5);
            when X"011A" => o_sd_out    <= counter_status(6);
            when X"0200" => o_sd_out    <= delta_sigma_config_lo(1);
            when X"0202" => o_sd_out    <= delta_sigma_config_lo(2);
            when X"0204" => o_sd_out    <= delta_sigma_config_lo(3);
            when X"0206" => o_sd_out    <= delta_sigma_config_lo(4);
            when X"0208" => o_sd_out    <= delta_sigma_config_lo(5);
            when X"020A" => o_sd_out    <= delta_sigma_config_lo(6);
            when X"0210" => o_sd_out    <= delta_sigma_status(1);
            when X"0212" => o_sd_out    <= delta_sigma_status(2);
            when X"0214" => o_sd_out    <= delta_sigma_status(3);
            when X"0216" => o_sd_out    <= delta_sigma_status(4);
            when X"0218" => o_sd_out    <= delta_sigma_status(5);
            when X"021A" => o_sd_out    <= delta_sigma_status(6);
            when X"0300" => o_sd_out    <= spi_config_lo;
            when X"0310" => o_sd_out    <= spi_status;
            when X"0400" => o_sd_out    <= gpio_out_lo;
            when X"0402" => o_sd_out    <= gpio_out_lo;
            when X"0404" => o_sd_out    <= gpio_out_lo;
            when X"0406" => o_sd_out    <= gpio_out_lo;
            when X"0408" => o_sd_out    <= gpio_in;
            when X"0410" => o_sd_out    <= servo_io_out_lo;
            when X"0412" => o_sd_out    <= servo_io_out_lo;
            when X"0414" => o_sd_out    <= servo_io_out_lo;
            when X"0416" => o_sd_out    <= servo_io_out_lo;
            when X"0418" => o_sd_out    <= servo_io_in;
            when X"0430" => o_sd_out    <= mechanical_status(1);
            when X"0432" => o_sd_out    <= mechanical_status(2);
            when X"0433" => o_sd_out    <= mechanical_status(3);
            when X"0436" => o_sd_out    <= mechanical_status(4);
            when X"0600" => o_sd_out    <= universal_config_lo(1);
            when X"0602" => o_sd_out    <= universal_config_lo(2);
            when X"0604" => o_sd_out    <= universal_config_lo(3);
            when X"0606" => o_sd_out    <= universal_config_lo(4);
            when X"0608" => o_sd_out    <= universal_config_lo(5);
            when X"060A" => o_sd_out    <= universal_config_lo(6);
            when X"060C" => o_sd_out    <= universal_config_lo(7);
            when X"060E" => o_sd_out    <= universal_config_lo(8);
            when X"0700" => o_sd_out    <= universal_status(1);
            when X"0702" => o_sd_out    <= universal_status(2);
            when X"0704" => o_sd_out    <= universal_status(3);
            when X"0706" => o_sd_out    <= universal_status(4);
            when X"0708" => o_sd_out    <= universal_status(5);
            when X"070A" => o_sd_out    <= universal_status(6);
            when X"070C" => o_sd_out    <= universal_status(7);
            when X"070E" => o_sd_out    <= universal_status(8);

            when X"6EE0"   => o_sd_out    <= PRODUCT_VENDOR;
            when X"6EE2"   => o_sd_out    <= PRODUCT_ID;
            when X"6EE4"   => o_sd_out    <= PRODUCT_VER_MSB;
            when X"6EE8"   => o_sd_out    <= PRODUCT_VER_LSB;
            when X"6EEA"   => o_sd_out    <= X"C8C8";
            when X"6EEC"   => o_sd_out    <= X"C8C8";
            when X"6EEE"   => o_sd_out    <= X"C8C8";

            when X"7FF0"   => o_sd_out    <= write_port_lo;
            when X"7FF2"   => o_sd_out    <= read_result_lo(15 downto 0);
            when X"7FF4"   => o_sd_out    <= read_result_lo(31 downto 16);
            when X"7FF6"   => o_sd_out    <= data_port_lo(15 downto 0);
            when X"7FF8"   => o_sd_out    <= data_port_lo(31 downto 16);
            when X"7F0A"   => o_sd_out    <= read_cmd_index_lo;
            when X"7F8C"   => o_sd_out    <= write_cmd_index_lo;
            when X"7F04"   => o_sd_out    <= command_load_data_lo(15 downto 0);
            when X"7F06"   => o_sd_out    <= command_load_data_lo(31 downto 16);

            when X"7FFE"   => o_sd_out    <= write_port_lo;
            when others   => 
                o_sd_out    <=    X"A5A5";
        end case;
    else
        o_sd_out    <=    X"BBBB";
    end if;
end process Read_operation;
-- End of Read bus mux

end behavior;                      
