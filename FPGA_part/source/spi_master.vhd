-------------------------------------------------------------------------------------------------
-- spi master for miso only --------------------
-- Author     :    Andy Kim.
-- Desc.      :    spi master for ADS7042 
-- Last Fix:  :    2024. 03. 18 .
-- Tartget    :    
-- Contens    :    
-- History :
-- 1) 2024. 03. 18  -. Start
-- 2) 
-------------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

ENTITY spi_master IS
  PORT(
    reset   : in     std_logic;                             --asynchronous reset
    clk     : in     std_logic;                             --system clock  (64MHz)
    enable  : in     std_logic;                             -- enable for SPI(active high)

    mosi    : out    std_logic;
    miso    : in     std_logic;                             --master out, slave in
    sclk    : out    std_logic;                             --spi clock
    ss_n    : out    std_logic;                             --slave select

    busy    : out    std_logic;                             --busy / data ready signal
    rx_data : out    std_logic_vector(15 downto 0)          --data received
);
END spi_master;

ARCHITECTURE logic OF spi_master IS
  TYPE machine IS(ready, execute);                           --state machine data type
  SIGNAL state       : machine;                              --current state
  SIGNAL clk_ratio   : INTEGER;                              --current clk_div
  SIGNAL count       : INTEGER;                              --counter to trigger sclk from system clock
  SIGNAL clk_toggles : INTEGER RANGE 0 TO 31;                --count spi clock toggles
  SIGNAL assert_data : STD_LOGIC;                            --'1' is tx sclk toggle, '0' is rx sclk toggle
  SIGNAL continue    : STD_LOGIC;                            --flag to continue transaction
  SIGNAL rx_buffer   : STD_LOGIC_VECTOR(13 DOWNTO 0);        --receive data buffer
  SIGNAL last_bit_rx : INTEGER RANGE 0 TO 31;

  constant cpol      : std_logic := '0';
  constant clk_div   : integer := 2;
  constant d_width   : integer := 14;
  constant cont      : std_logic := '0';

  signal ss_n_lo     : std_logic;
  signal sclk_lo     : std_logic;

  signal ph_cs_cnt   : integer range 0 to 31;   -- minimum 60nSec

BEGIN
  PROCESS(clk, reset)
  BEGIN
    IF(reset = '0') THEN            --reset system
      ss_n_lo   <= '1';             --deassert all slave select lines
      rx_data   <= (OTHERS => '0'); --clear receive data port
      rx_buffer <= (OTHERS => '0'); --clear receive data port
      state     <= ready;           --go to ready state when reset is exited
      ph_cs_cnt <= 0;

      ss_n      <= '1';
      sclk      <= cpol;
      mosi      <= 'Z';

    elsif rising_edge(clk) then
      ss_n      <= ss_n_lo;
      sclk      <= sclk_lo; 

      CASE state IS               --state machine
        WHEN ready =>
          ss_n_lo  <= '1';             --deassert all slave select lines
          sclk_lo  <= cpol;            --set spi clock polarity
          --user input to initiate transaction
          IF(enable = '1') THEN       
            clk_ratio <= clk_div;    --set to input selection if valid
            count <= clk_div;        --initiate system-to-spi clock counter
            clk_toggles <= 0;        --initiate clock toggle counter
            if ph_cs_cnt < 5 then
                ph_cs_cnt <= ph_cs_cnt + 1;
            else
                ph_cs_cnt <= 0;
                state     <= execute;        --proceed to execute state
            end if;
          ELSE
            state <= ready;          --remain in ready state
          END IF;

        WHEN execute =>
          ss_n_lo <= '0'; --set proper slave select output
          
          --system clock to sclk ratio is met
          IF(count = clk_ratio) THEN        
            count <= 1;                     --reset system-to-spi clock counter
            IF(clk_toggles = d_width*2 + 1) THEN
              clk_toggles <= 0;               --reset spi clock toggles counter
            ELSE
              clk_toggles <= clk_toggles + 1; --increment spi clock toggles counter
            END IF;
            
            --spi clock toggle needed
            IF(clk_toggles <= d_width*2 AND ss_n_lo = '0') THEN 
              sclk_lo <= NOT sclk_lo; --toggle spi clock
            END IF;
            
            --receive spi clock toggle
            IF( sclk_lo = (not cpol) AND clk_toggles < (d_width*2) AND ss_n_lo = '0') THEN 
              rx_buffer <= rx_buffer(d_width-2 DOWNTO 0) & miso; --shift in received bit
            END IF;
            
            --end of transaction
            IF((clk_toggles = d_width*2 + 1) AND cont = '0') THEN   
              busy    <= '0';          --clock out not busy signal
              ss_n_lo <= '1';           --set all slave selects high
              rx_data <= "00" & rx_buffer;    --clock out received data to output port
              state   <= ready;        --return to ready state
            ELSE                       --not end of transaction
              state <= execute;        --remain in execute state
            END IF;
          
          ELSE        --system clock to sclk ratio not met
            count <= count + 1; --increment counter
            state <= execute;   --remain in execute state
          END IF;

      END CASE;
    END IF;
  END PROCESS; 
END logic;
