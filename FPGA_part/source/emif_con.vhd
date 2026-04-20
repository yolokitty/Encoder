-------------------------------------------------------------------------------------------------
-- interface(External memory controller)--------------------
-- DATA       :    2024. 03. 14.
-- Author     :    Andy Kim.
-- Desc.      :    bus controller(reg files, address decoder and etc)
-- Last Fix:  :    2024. 03. 14.
-- Tartget    :    XC7S25-1FTGB196
-------------------------------------------------------------------------------------------------

library IEEE;

use ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;
use work.typedef_servo_enc.all;

entity emif_con is
    PORT (    
        ireset                      : in std_logic;
        iclk                        : in std_logic;
        ics                         : in std_logic;
        iwr                         : in std_logic;
        ird                         : in std_logic;
        i_sa                        : in std_logic_vector(15 downto 0);
        i_sd_in                     : in std_logic_vector(15 downto 0);
        o_sd_out                    : out std_logic_vector(15 downto 0);
        o_bus_oe                    : out std_logic;

        soft_reset                  : out std_logic;
        command_load_data           : out std_logic_vector(31 downto 0);

        encoder_data                : in  ar_32bit_6ea;
        counter_config              : out ar_16bit_6ea;
        counter_status              : in  ar_16bit_6ea;
        counter_load_exe            : out std_logic_vector(5 downto 0);

        delta_sigma_config          : out ar_16bit_6ea;
        delta_sigma_status          : in ar_16bit_6ea;
        delta_sigma_data            : in ar_32bit_6ea;

        spi_config                  : out std_logic_vector(15 downto 0);
        spi_status                  : in std_logic_vector(15 downto 0);
        spi_data                    : in std_logic_vector(31 downto 0);

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

    constant    PRODUCT_VENDOR              : std_logic_vector(15 downto 0) := X"5053";
    constant    PRODUCT_ID                  : std_logic_vector(15 downto 0) := X"0106";
    constant    PRODUCT_VER_MSB             : std_logic_vector(15 downto 0) := X"2024";
    constant    PRODUCT_VER_LSB             : std_logic_vector(15 downto 0) := X"0608";

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

    -- ★ 기존 cs_or_wr_lo 제거, 새 신호 추가
    signal      cs_or_wr_raw                : std_logic;
    signal      cs_wr_d1                    : std_logic;
    signal      cs_wr_d2                    : std_logic;
    signal      cs_wr_rise                  : std_logic;
    signal      i_sa_latch                  : std_logic_vector(15 downto 0);
    signal      i_sd_latch                  : std_logic_vector(15 downto 0);
    -- ★ 여기까지

    signal      read_cmd_exe_lo             : std_logic;
    signal      read_cmd_index_lo           : std_logic_vector(15 downto 0);
    signal      write_reg_exe_lo            : std_logic;
    signal      write_cmd_exe_lo            : std_logic;
    signal      write_cmd_index_lo          : std_logic_vector(15 downto 0);
    signal      read_result_lo              : std_logic_vector(31 downto 0);

    signal      soft_reset_lo               : std_logic;

    signal        counter_config_lo           : ar_16bit_6ea;
    signal        counter_load_exe_lo         : std_logic_vector(5 downto 0);

    signal        delta_sigma_config_lo       : ar_16bit_6ea;

    signal        spi_config_lo               : std_logic_vector(15 downto 0);
    signal        spi_statue_lo               : std_logic_vector(15 downto 0);

    signal        gpio_out_lo                 : std_logic_vector(15 downto 0);
    signal        servo_io_out_lo             : std_logic_vector(15 downto 0);

    signal        universal_config_lo         : ar_16bit_8ea;
    signal        command_load_data_lo        : std_logic_vector(31 downto 0);

begin

-- ★ 비동기 cs_or_wr_lo 제거, 동기식 교체 시작 ★

-- write 사이클 활성 중(CS=0, WR=0) i_sa/i_sd_in을 동기 래치
addr_data_latch : process(ireset, iclk) begin
    if ireset = '0' then
        i_sa_latch  <= (others => '0');
        i_sd_latch  <= (others => '0');
    elsif rising_edge(iclk) then
        if ics = '0' and iwr = '0' then
            i_sa_latch  <= i_sa;
            i_sd_latch  <= i_sd_in;
        end if;
    end if;
end process addr_data_latch;

-- cs_or_wr rising edge 동기 검출
cs_or_wr_raw <= ics or iwr;

sync_edge_proc : process(ireset, iclk) begin
    if ireset = '0' then
        cs_wr_d1 <= '1';
        cs_wr_d2 <= '1';
    elsif rising_edge(iclk) then
        cs_wr_d1 <= cs_or_wr_raw;
        cs_wr_d2 <= cs_wr_d1;
    end if;
end process sync_edge_proc;

cs_wr_rise <= cs_wr_d1 and (not cs_wr_d2);

-- ★ write_exe_gen 완전 동기식으로 교체 (비동기 rising_edge 제거)
write_exe_gen : process(ireset, iclk) begin
    if ireset = '0' then
        write_exe_lo   <= '0';
        write_addr_1st <= (others => '0');
        write_data_1st <= (others => '0');
    elsif rising_edge(iclk) then
        if write_done_lo = '1' then
            write_exe_lo   <= '0';
            write_addr_1st <= (others => '0');
            write_data_1st <= (others => '0');
        elsif cs_wr_rise = '1' then
            write_exe_lo   <= '1';
            write_addr_1st <= i_sa_latch;  -- 래치된 안정적인 값 사용
            write_data_1st <= i_sd_latch;
        end if;
    end if;
end process write_exe_gen;
-- ★ 동기식 교체 끝 ★

soft_reset  <= soft_reset_lo;
universal_config    <= universal_config_lo;

-- Second stage : 원본 그대로 유지
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
        end if;
    end if;
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
    end if;
end process port_con;


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
        if write_reg_exe_lo =  '1' then
            case write_addr_lo is
                when X"0100" => counter_config_lo(1) <= write_port_lo;
                when X"0102" => counter_config_lo(2) <= write_port_lo;
                when X"0104" => counter_config_lo(3) <= write_port_lo;
                when X"0106" => counter_config_lo(4) <= write_port_lo;
                when X"0108" => counter_config_lo(5) <= write_port_lo;
                when X"010A" => counter_config_lo(6) <= write_port_lo;
                when X"0200" => delta_sigma_config_lo(1) <= write_port_lo;
                when X"0202" => delta_sigma_config_lo(2) <= write_port_lo;
                when X"0204" => delta_sigma_config_lo(3) <= write_port_lo;
                when X"0206" => delta_sigma_config_lo(4) <= write_port_lo;
                when X"0208" => delta_sigma_config_lo(5) <= write_port_lo;
                when X"020A" => delta_sigma_config_lo(6) <= write_port_lo;
                when X"0300" => spi_config_lo            <= write_port_lo;
                when X"0400" => gpio_out_lo            <= write_port_lo;
                when X"0402" => gpio_out_lo            <= gpio_out_lo and write_port_lo;
                when X"0404" => gpio_out_lo            <= gpio_out_lo or  write_port_lo; 
                when X"0406" => gpio_out_lo            <= gpio_out_lo xor write_port_lo;  
                when X"0410" => servo_io_out_lo        <= write_port_lo;
                when X"0412" => servo_io_out_lo        <= servo_io_out_lo and write_port_lo;
                when X"0414" => servo_io_out_lo        <= servo_io_out_lo or  write_port_lo; 
                when X"0416" => servo_io_out_lo        <= servo_io_out_lo xor write_port_lo;  
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
        if write_cmd_exe_lo =  '1' then
            case write_cmd_index_lo is
                when X"0500" => counter_load_exe(0) <= '1';
                when X"0502" => counter_load_exe(1) <= '1';
                when X"0504" => counter_load_exe(2) <= '1';
                when X"0506" => counter_load_exe(3) <= '1';
                when X"0508" => counter_load_exe(4) <= '1';
                when X"050A" => counter_load_exe(5) <= '1';
                when others => null;
            end case;
        else
            counter_load_exe        <= (others => '0');
        end if;
    end if;
end process direct_memory_write;


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
              when X"0500" => read_result_lo   <= encoder_data(1);
              when X"0502" => read_result_lo   <= encoder_data(2);
              when X"0504" => read_result_lo   <= encoder_data(3);
              when X"0506" => read_result_lo   <= encoder_data(4);
              when X"0508" => read_result_lo   <= encoder_data(5);
              when X"050A" => read_result_lo   <= encoder_data(6);
              when others => read_result_lo   <= X"BAD0BAD0";
          end case;
        end if;
    end if;
end process;


-- Read 경로 완전 원본 그대로 -------------------------------------------------------
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

end behavior;