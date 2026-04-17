-------------------------------------------------------------------------------------------------
-- tamakawa interface --------------------
-- Author     :    Andy Kim.
-- Desc.      :    tamakawa encoder
-- Last Fix:  :    2024. 03. 17 .
-- Tartget    :    
-- Contens    :    
-- Status
-- 0 bit : rx CRC check error
-- 1 bit : rx completeted
-- 2 bit : spi CS toggled
-- 3 bit : reserved.
-- History :
-- 1) 2024. 03. 17  -. Start
-- 2) 
-- tk_rx_data(19 byte) : 
--  >> address(1 byte, 1), 
--  >> Data(16 byte, 2 ~17)[command, wrtie index, read index, data(13)], 
--  >> CRC(2 byte, 18~19)
-- tk_tx_data(25 byte) : 
--  >> Pre-framge(4 byte, 1~4) : 0xAAAAAAAA
--  >> flag(1byte,5 ) : 0x7E
--  >> address(1 byte, 6) : 0x01
--  >> data (16 byte, 7 ~ 22)
--     =>> command(1byte)
--     =>> write_index(1byte)
--     =>> read(1byte)
--     =>> data(13 byte)
--  >> CRC(2, 23~24)
--  >> flag(1byte, 25) : 0x7E
-- Status
-- 0 : FLAG data is equal to 0x7E.
-- 1 : data recieved successfully.
-- 2 : pre-frame detected.
-- 3 : FLAG data is not detected(time out) 
-------------------------------------------------------------------------------------------------
                

Library ieee;
Use ieee.std_logic_1164.all;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;
use work.typedef_servo_enc.all;

ENTITY  tamakawa_interface is
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
END tamakawa_interface;

ARCHITECTURE behavior OF tamakawa_interface is

    signal  tk_rx_meta         : std_logic;
    signal  tk_rx_meta_1       : std_logic;
    signal  tk_rx_meta_2       : std_logic;
    signal  tk_rx_meta_3       : std_logic;
    signal  tk_rx_reg          : std_logic;
    signal  tk_rx_reg_dly      : std_logic;
    signal  tk_rx_r_edge       : std_logic;
    signal  tk_rx_f_edge       : std_logic;

    signal tk_state            : integer range 0 to 255;

    signal status_lo           : std_logic_vector(7 downto 0);
    signal rx_data_cnt         : std_logic_vector(31 downto 0);
    signal tx_data_cnt         : std_logic_vector(31 downto 0);
    signal rx_frame_error_cnt  : std_logic_vector(31 downto 0);
--    signal rx_crc_error_cnt    : std_logic_vector(31 downto 0);

    signal preframe_detect_enable : std_logic;
    signal preframe_detected      : std_logic;
    signal preframe_detect_started: std_logic;
    signal pf_edge_cnt            : std_logic_vector(7 downto 0);
    signal pf_edge_width          : std_logic_vector(7 downto 0);
    signal tk_rx_ref_clk          : std_logic_vector(3 downto 0);

    signal data_valid           : std_logic;
    signal tk_data_in           : std_logic_vector(7 downto 0);
    signal tk_data_latch        : std_logic_vector(7 downto 0);
    signal tk_bit_cnt           : integer range 0 to 8;
    signal tk_skip_cnt          : integer range 0 to 8;
    signal tk_rx_data           : ar_8bit_23ea; 
    signal tk_tx_data           : ar_8bit_30ea;

    signal skip_func_en         : std_logic;
    signal tk_rx_byte           : integer range 1 to 31;
    signal tk_tx_byte           : integer range 1 to 31;
    signal tk_tx_bit            : integer range 0 to 7;

    signal tk_tx_ref_clk        : std_logic_vector(3 downto 0);
    signal tk_tx_reg            : std_logic;

    signal tk_tx_done           : std_logic;
    signal tk_tx_started        : std_logic;
    signal tk_tx_enable         : std_logic;
    signal tk_tx_skip_act       : std_logic;
    signal tk_tx_skip_cnt       : integer range 0 to 7;

    signal rx_time_interval     : integer range 0 to 65535;
    signal tx_time_interval     : integer range 0 to 65535;

    signal crc_tx_index         : integer range 1 to 31;
    signal crc_rx_en            : std_logic;
    signal crc_rx_din           : std_logic_vector(7 downto 0);
    signal crc_tx_en            : std_logic;
    signal crc_tx_din           : std_logic_vector(7 downto 0);
    signal crc_rx               : std_logic_vector(15 downto 0);
    signal crc_tx               : std_logic_vector(15 downto 0);  

    signal multi_turn_lo     :  std_logic_vector(23 downto 0);
    signal single_turn_lo     : std_logic_vector(23 downto 0);

    constant FLAG_data          : std_logic_vector(7 downto 0)  := x"7E";
    constant PREFRAME_data      : std_logic_vector(15 downto 0) := x"AAAA";
    constant PREFRAME4_data     : std_logic_vector(31 downto 0) := x"AAAAAAAA";
    constant ADDRESS_data       : std_logic_vector(7 downto 0)  := x"01";
      
begin
    multi_turn  <= multi_turn_lo;    
    single_turn <= single_turn_lo;   
    tk_tx   <= tk_tx_reg;
--    tk_txen <= tk_tx_enable; -- high active;
--    tk_rxen <= tk_tx_enable; -- low active;
    status  <= status_lo;
    signal_shaper : process(iclk) 
    begin
        if rising_edge(iclk) then
            tk_rx_meta         <= tk_rx;
            tk_rx_meta_1       <= tk_rx_meta;
            tk_rx_meta_2       <= tk_rx_meta_1;
            tk_rx_meta_3       <= tk_rx_meta_2;
            tk_rx_reg_dly      <= tk_rx_reg;
            tk_txen            <= tk_tx_enable; -- high active;
            tk_rxen            <= '0'; -- low active;
            if tk_rx_meta = '0' and tk_rx_meta_1 = '0' and tk_rx_meta_2 = '0' and tk_rx_meta_3 = '0'   then
                tk_rx_reg <= '0';
            elsif tk_rx_meta = '1' and tk_rx_meta_1 = '1' and tk_rx_meta_2 = '1' and tk_rx_meta_3 = '1'  then
                tk_rx_reg <= '1';
            end if;
        end if;
    end process;

    tk_rx_r_edge    <= '1' when tk_rx_reg_dly = '0' and tk_rx_reg = '1' else '0';
    tk_rx_f_edge    <= '1' when tk_rx_reg_dly = '1' and tk_rx_reg = '0' else '0';

preframe_detector : process(iclk) begin
    if rising_edge(iclk) then
        if ireset = '0' or soft_reset = '1' then
            preframe_detected       <= '0';
            preframe_detect_started <= '0';
            pf_edge_cnt             <= (others => '0');
            pf_edge_width           <= (others => '0');
            tk_rx_ref_clk           <= (others => '0');
        else
            if preframe_detect_enable = '1' then
                if tk_rx_r_edge = '1' or tk_rx_f_edge = '1'then
                    preframe_detect_started <= '1';
                end if;
                if pf_edge_cnt = "00001111" then        -- Edge count is 16 : 0xAAAA is inputed.(LSB first)
                    preframe_detected   <= '1';
                end if;
            else
                preframe_detected       <= '0';
                preframe_detect_started <= '0';
            end if;

            if preframe_detect_started = '1' then
                if (tk_rx_r_edge = '1' or tk_rx_f_edge = '1') and pf_edge_width > "00001010" and pf_edge_width < "00010010" then        
                    pf_edge_cnt    <= pf_edge_cnt + 1;    
                end if;
                
                if tk_rx_r_edge = '1' or tk_rx_f_edge = '1' then
                    pf_edge_width           <= (others => '0');
                else
                    pf_edge_width  <= pf_edge_width + 1;
                end if;
            else
                pf_edge_width           <= (others => '0');
                pf_edge_cnt             <= (others => '0');
            end if;

            -- reference clock generation 
            if preframe_detected = '1' then
                tk_rx_ref_clk <= tk_rx_ref_clk + 1;         -- ref_clk(3) is the 4MHz ref clk
            else
                tk_rx_ref_clk  <= (others => '0');
            end if;
        end if;
    end if;
end process preframe_detector;

menchaster_decoder  : process(iclk) begin
    if rising_edge(iclk) then
        if ireset = '0' then
            data_valid  <= '0';
            tk_data_in  <= (others => '0');
            tk_bit_cnt  <= 0;
            tk_skip_cnt <= 0;  
            tk_data_latch   <= (others => '0');
        else
            if preframe_detected = '1' then
                if tk_rx_ref_clk = "1100" then    -- 3/4 time on ref clk
                    if skip_func_en  = '1' then 
                        if tk_skip_cnt < 5 then
                            if tk_bit_cnt = 7 then
                                tk_bit_cnt      <= 0;
                                data_valid      <= '1';
                                tk_data_latch  <= (tk_rx_reg) & tk_data_in(7 downto 1);
                            else
                                tk_bit_cnt <= tk_bit_cnt  + 1;
                            end if;
                            tk_data_in  <= (tk_rx_reg) & tk_data_in(7 downto 1);
                        end if;
                        if tk_rx_reg = '1' then     -- input is '1' 
                            tk_skip_cnt <= tk_skip_cnt + 1; 
                        else
                            tk_skip_cnt <= 0; 
                        end if;
                    else
                        if tk_bit_cnt = 7 then
                            tk_bit_cnt     <= 0;
                            data_valid     <= '1';
                            tk_data_latch  <= (tk_rx_reg) & tk_data_in(7 downto 1);
                        else
                            tk_bit_cnt <= tk_bit_cnt  + 1;
                        end if;
                        tk_data_in  <= (tk_rx_reg) & tk_data_in(7 downto 1);
                    end if;
                else
                    data_valid     <= '0';
                end if;
            end if;
        end if;
    end if;
end process menchaster_decoder;


menchaster_encoder  : process(iclk) begin
    if rising_edge(iclk) then
        if ireset = '0' then
            tk_tx_ref_clk   <= (others => '0');
            tk_tx_reg       <= '1';
            tk_tx_byte      <= 1;
            tk_tx_bit       <= 0;
            tk_tx_done      <= '0';
            tk_tx_started   <= '0';
            tk_tx_skip_act  <= '0';
            tk_tx_skip_cnt  <= 0;
        else
            if tk_tx_started    = '1' and tk_tx_enable = '1' and tk_tx_done = '0' then 
                if tk_tx_skip_act = '1' then
                    tk_tx_reg   <= tk_tx_ref_clk(3);    -- '0' pattern output
                else
                    tk_tx_reg   <= tk_tx_data(tk_tx_byte)(tk_tx_bit) xor tk_tx_ref_clk(3);    -- data pattern output
                end if;
            else
                 tk_tx_reg   <= '1';
            end if;

            if tk_tx_enable = '1' then
                tk_tx_ref_clk   <= tk_tx_ref_clk + 1;
                if tk_tx_ref_clk = "1111" then
                    tk_tx_started   <= '1';
                end if;
            else
                tk_tx_ref_clk   <= (others => '0');
                tk_tx_byte      <= 1;
                tk_tx_bit       <= 0;
                tk_tx_done      <= '0';
                tk_tx_started   <= '0';
            end if;

            if tk_tx_ref_clk = "1111" and tk_tx_started = '1' then
                if tk_tx_byte > 5 and tk_tx_byte < 25 then  -- Address, Data, CRC
                    if tk_tx_skip_cnt >= 4 then
                        if tk_tx_data(tk_tx_byte)(tk_tx_bit) = '1' then     -- current output value is '1'
                            tk_tx_skip_act <= '1';
                        else
                             if tk_tx_bit = 7 then
                                 tk_tx_bit <= 0;
--                                 if tk_tx_byte < 23 then
                                     tk_tx_byte  <= tk_tx_byte + 1;
--                                 else
--                                     tk_tx_done      <= '1';
--                                 end if;
                             else
                                 tk_tx_bit <= tk_tx_bit + 1;
                             end if;
                        end if;
                        tk_tx_skip_cnt  <= 0;
                    else
                        tk_tx_skip_act <= '0';
                        if tk_tx_data(tk_tx_byte)(tk_tx_bit) = '1' and tk_tx_skip_act = '0' then    
                            tk_tx_skip_cnt  <= tk_tx_skip_cnt + 1;
                        else
                            tk_tx_skip_cnt  <= 0;
                        end if;
                        if tk_tx_bit = 7 then
                            tk_tx_bit <= 0;
--                           if tk_tx_byte < 25 then
                                tk_tx_byte  <= tk_tx_byte + 1;
--                            else
--                                tk_tx_done      <= '1';
--                            end if;
                        else
                            tk_tx_bit <= tk_tx_bit + 1;
                        end if;
                    end if;
                else
                    tk_tx_skip_act     <= '0';
                    tk_tx_skip_cnt  <= 0;
                    if tk_tx_bit = 7 then
                        tk_tx_bit <= 0;
                        if tk_tx_byte < 25 then
                            tk_tx_byte  <= tk_tx_byte + 1;
                        else
                            tk_tx_done      <= '1';
                        end if;
                    else
                        tk_tx_bit <= tk_tx_bit + 1;
                    end if;
                end if;
            end if;
        end if;
    end if;
end process menchaster_encoder;

    --------------------------------------------------------------------------------
    state_machine_proc : process(iclk) begin
        if rising_edge(iclk) then
           if ireset = '0' then
               tk_state         <= 0;

               multi_turn_lo       <= (others => '0');
               single_turn_lo      <= (others => '0');

               tk_rx_data       <= (others => (others => '0'));
               tk_tx_data       <= (others => (others => '0'));
               tk_tx_enable     <= '0';
               tk_rx_byte       <= 1;

--               crc_rx_en        <= '0';
--               crc_tx_en        <= '0';
--               crc_tx_index     <= 6;
--               crc_rx_din       <= (others => '0');
--               crc_tx_din       <= (others => '0');
--               rx_crc_error_cnt <= (others => '0');

               rx_data_cnt      <= (others => '0');
               tx_data_cnt      <= (others => '0');
               rx_frame_error_cnt <= (others => '0');
               status_lo        <= (others => '0');
               skip_func_en     <= '0';
               rx_time_interval <= 0;
               tx_time_interval <= 0;
               preframe_detect_enable   <= '0';
           else
               status_lo(2)     <= preframe_detected; 
               case tk_state is
                   -- Initaial state
                   when 0 =>
                       
                       tk_rx_data       <= (others => (others => '0'));
                       tk_tx_data       <= (others => (others => '0'));
                       tk_tx_enable     <= '0';
                       tk_rx_byte       <= 1;
                       
--                       crc_rx_en        <= '0';
--                       crc_tx_en        <= '0';
--                       crc_tx_index     <= 6;
--                       crc_rx_din       <= (others => '0');
--                       crc_tx_din       <= (others => '0');
                       
                       skip_func_en     <= '0';

                       if tk_rx_reg = '0' then
                            rx_time_interval <= 0;
                       else
                            rx_time_interval <= rx_time_interval + 1;
                       end if;

                       if rx_time_interval > 260 then
                            tk_state                <= tk_state + 1;
                            preframe_detect_enable  <= '1';
                            rx_time_interval        <= 0;
                       else
                            preframe_detect_enable  <= '0';
                       end if;
                   -- wait until Pre-Frame is received.
                   when 1 =>
                        if preframe_detected = '1' then
                            tk_state                <= tk_state + 1;
                        end if;
                   -- wait until Flag "01111110"
                   when 2 =>
                       if data_valid = '1' then
                           rx_time_interval <= 0;
                           if tk_data_latch = FLAG_data then        -- Flag is detected.
                                tk_state         <= tk_state + 1;
                                skip_func_en     <= '1';
                                rx_time_interval <= 0;
                           else
                                tk_state         <= 250;
                           end if;
                       else
                           rx_time_interval <= rx_time_interval + 1;
                           if rx_time_interval > 130 then 
                              tk_state      <= 251;     -- error on Flag waiting
                           end if;
                       end if;
                   when 3 =>
                       if data_valid = '1' then
                           rx_time_interval <= 0;
                           if tk_rx_byte < 20 then
                               tk_rx_data(tk_rx_byte) <= tk_data_latch;
                               tk_rx_byte             <= tk_rx_byte + 1;
                           -- when tk_rx_byte = 20
                           else
                               -- END of recieve processing successfully.
                               if tk_data_latch = FLAG_data then
                                  tk_state                <= tk_state + 1;
                                  preframe_detect_enable  <= '0';
                               else
                                  tk_state      <= 252;     -- error on Flag waiting
                               end if;
                           end if;
--                           if tk_rx_byte < 18 then
--                               crc_rx_en    <= '1';
--                               crc_rx_din   <= tk_data_latch;
--                           end if;
                       else
                           if tk_rx_byte = 20 and tk_bit_cnt > 1 then
                                skip_func_en     <= '0';
                           end if;

                           rx_time_interval <= rx_time_interval + 1;
                           if rx_time_interval > 162 then 
                              tk_state      <= 253;     -- error on Flag waiting 
                           end if;
--                           crc_rx_en    <= '0';
                       end if;
                   -- write to CMD register(CRC check is performed on MCU
                   when 4 =>
                        multi_turn_lo    <= tk_rx_data(2) & tk_rx_data(3) & tk_rx_data(4);
                        single_turn_lo   <= tk_rx_data(5) & tk_rx_data(6) & tk_rx_data(7);
                        tk_state         <= tk_state + 1;
                        rx_data_cnt      <= rx_data_cnt + 1;
                   when 5 =>
                        tk_state         <= 100;
                   -- ready for Transmission
                    -- tk_tx_data(24 byte) : 
                    --  >> Pre-framge(4 byte, 1~4) : 0x55555555
                    --  >> flag(1byte,5 ) : 0x7E
                    --  >> address(1 byte, 6) : 0x01
                    --  >> data (16 byte, 7 ~ 22)
                    --     =>> command(1byte)
                    --     =>> write_index(1byte)
                    --     =>> read(1byte)
                    --     =>> data(13 byte)
                    --  >> CRC(2, 23~24)
                    --  >> flag(1byte, 25) : 0x7E
                   when 100 =>
                       tk_tx_data(1) <= X"AA";  -- Pre-frame4
                       tk_tx_data(2) <= X"AA";  -- Pre-frame4
                       tk_tx_data(3) <= X"AA";  -- Pre-frame4
                       tk_tx_data(4) <= X"AA";  -- Pre-frame4
                       tk_tx_data(5) <= X"7E";  -- Flag
                       tk_tx_data(6)  <= multi_turn_lo(7 downto 0);  
                       tk_tx_data(7)  <= multi_turn_lo(15 downto 8);  
                       tk_tx_data(8)  <= multi_turn_lo(23 downto 16);  
                       tk_tx_data(9)  <= single_turn_lo(7 downto 0);  
                       tk_tx_data(10) <= single_turn_lo(15 downto 8);  
                       tk_tx_data(11) <= single_turn_lo(23 downto 16);  
                       tk_tx_data(12) <= (others => '0');
                       tk_tx_data(13) <= (others => '0');
                       tk_tx_data(14) <= (others => '0');
                       tk_tx_data(15) <= (others => '0');
                       tk_tx_data(16) <= (others => '0');
                       tk_tx_data(17) <= (others => '0');
                       tk_tx_data(18) <= (others => '0');
                       tk_tx_data(19) <= (others => '0');
                       tk_tx_data(20) <= (others => '0');
                       tk_tx_data(21) <= (others => '0');
                       tk_tx_data(22) <= (others => '0');
                       tk_tx_data(23) <= (others => '0');
                       tk_tx_data(24) <= (others => '0');

                       tk_tx_data(25)   <= x"7E";  -- flag
                       tk_state         <= tk_state + 1;
                       status_lo(1)     <= '1';
                   -- make delay between RX and TX(about 5 usec)
                   when 101 =>
                       if tx_time_interval > 260 then   -- 5 uSec
                            tk_state            <= tk_state + 1;
                            tx_time_interval    <= 0;
                            tk_tx_enable        <= '1';
                       else
                            tx_time_interval    <= tx_time_interval + 1;    
                       end if;
                   -- dummy state
                   when 102 =>
                       tk_state         <= tk_state + 1;
                   -- dummy state
                   when 103 =>
                       tk_state         <= tk_state + 1;
                   -- Send tx data with manchester encoder
                   when 104 =>
                       if tk_tx_done = '1' then
                           tk_state     <= 255;
                           tk_tx_enable <= '0';
                           tx_data_cnt  <= tx_data_cnt + 1;
                       end if;
                   when 250 =>
                       status_lo(0)     <= not status_lo(0);
                       rx_frame_error_cnt <= rx_frame_error_cnt + 1;
                       tk_state         <= 255;
                   when 251 =>
                       status_lo(3)     <= not status_lo(3);
                       rx_frame_error_cnt <= rx_frame_error_cnt + 1;
                       tk_state         <= 255;
                   when 252 =>
--                       status_lo(3)     <= not status_lo(3);
                       rx_frame_error_cnt <= rx_frame_error_cnt + 1;
                       tk_state         <= 255;
                   when 253 =>
                       rx_frame_error_cnt <= rx_frame_error_cnt + 1;
                       tk_state         <= 255;
                   when 254 =>
                       tk_state   <= 255;
                   when others => null;
                       preframe_detect_enable  <= '0';
                       rx_time_interval        <= 0;
                       tk_state   <= 0;
                       status_lo(1)            <= '0';
                    end case;
               end if;
           end if;
    end process state_machine_proc;

    --------------------------------------------------------------------------------
    crc_gen : process(ireset, iclk) begin
       if rising_edge(iclk) then
           if ireset = '0' then
               crc_tx   <= (others => '1');
               crc_rx   <= (others => '1');
           else
               if tk_state = 255  then -- initailize
                   crc_rx   <= (others => '1');
               else
                   if crc_rx_en = '1' then
                        crc_rx  <= (x"00" & crc_rx_din) xor crc_rx;
                   end if;
               end if;

               if tk_state = 255  then -- initailize
                   crc_tx   <= (others => '1');
               else
                   if crc_tx_en = '1' then
                        crc_tx  <= (x"00" & crc_tx_din) xor crc_tx;
                   end if;
               end if;
           end if;
       end if;
    end process crc_gen;

end behavior;
