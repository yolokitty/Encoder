-------------------------------------------------------------------------------------------------
-- delta sigma interface --------------------
-- Author     :    Andy Kim.
-- Desc.      :    delta sigma(target ADC : AMC1306Mxx)
-- Last Fix:  :    2024. 03. 18 .
-- Tartget    :    
-- Contens    :    
-- History :
-- 1) 2024. 03. 18  -. Start
-- 2) 
-------------------------------------------------------------------------------------------------
                

Library ieee;
Use ieee.std_logic_1164.all;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;
use work.typedef_servo_enc.all;

ENTITY  delta_sigma is
    PORT (
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
END delta_sigma;

architecture behavior of delta_sigma is
    signal DN0, DN1, DN3, DN5 : std_logic_vector(24 downto 0);
    signal CN1, CN2, CN3, CN4, CN5 : std_logic_vector(24 downto 0);
    signal DELTA1 : std_logic_vector(24 downto 0);

    signal clock_cnt    : std_logic_vector(7 downto 0);
    signal mclk_lo      : std_logic;
    signal mclk_rising  : std_logic;

    signal cnr_clock_cnt : std_logic_vector(7 downto 0);
    signal cnr_event     : std_logic;
begin
    ds_clk_out  <= mclk_lo;

output_shaper : process(reset, clk) begin
    if reset = '0' then
        delta_sigma_data    <= (others => '0');
        delta_sigma_status  <= (others => '0');
    elsif rising_edge(clk) then
        if soft_reset = '1' then
            delta_sigma_data    <= (others => '0');
            delta_sigma_status  <= (others => '0');
        else
            delta_sigma_data    <= "0000000" & CN5;
            delta_sigma_status  <= cnr_clock_cnt & clock_cnt;
        end if;
    end if;
end process output_shaper;

    CN3 <= DN0 - DN1;
    CN4 <= CN3 - DN3;
    CN5 <= CN4 - DN5;


clock_gen : process(reset, clk) begin
        if reset = '0' then
            clock_cnt   <= (others => '0');
            mclk_lo     <= '0';
            mclk_rising <= '0';
            cnr_clock_cnt <= (others => '0');
            cnr_event     <= '0';
        elsif rising_edge(clk) then
            if clock_cnt(3 downto 0) >= delta_sigma_config(3 downto 0) then 
                mclk_lo   <= not mclk_lo;
                clock_cnt <= (others => '0');
                if mclk_lo = '0' then
                    mclk_rising   <= '1';
                    if cnr_clock_cnt < delta_sigma_config(15 downto 8) then 
                        cnr_clock_cnt <= cnr_clock_cnt  + 1;
                        cnr_event     <= '0';
                    else
                        cnr_event     <= '1';
                        cnr_clock_cnt <= (others => '0');
                    end if;
                end if;
            else
                clock_cnt   <= clock_cnt + 1;
                mclk_rising <= '0';
            end if;
       end if;
end process clock_gen;

 first_stage : process(reset, clk) begin
     if reset = '0' then
        DELTA1 <= (others => '0');
    elsif rising_edge(clk) then
        if mclk_rising = '1' then
             DELTA1 <= DELTA1 + 1;
         end if;
    end if;
 end process first_stage;

 second_state : process(reset, clk) begin
    if reset = '0' then
         CN1 <= (others => '0');
         CN2 <= (others => '0');
     elsif rising_edge(clk) then
        if mclk_rising = '0' then
            CN1 <= CN1 + DELTA1;
            CN2 <= CN2 + CN1;
        end if;
    end if;
 end process second_state;

 decimator :  process(reset, clk) begin
    if reset = '0' then
        DN0 <= (others => '0');
        DN1 <= (others => '0');
        DN3 <= (others => '0');
        DN5 <= (others => '0');
    elsif rising_edge(clk) then
        if cnr_event = '1' then
            DN0 <= CN2;
            DN1 <= DN0;
            DN3 <= CN3;
            DN5 <= CN4;
        end if;
    end if;
 end process decimator;

end behavior;
