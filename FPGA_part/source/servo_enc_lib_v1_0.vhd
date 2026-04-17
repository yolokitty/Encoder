---------------------------------------------------------------------------------------------
-- Description : htc-adf user library v2021.04.29
--------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package typedef_servo_enc is
	type ar_4bit_4ea is array(4 downto 1) of std_logic_vector(3 downto 0);
	type ar_4bit_5ea is array(5 downto 1) of std_logic_vector(3 downto 0);
	type ar_4bit_9ea is array(9 downto 1) of std_logic_vector(3 downto 0);
	type ar_4bit_8ea is array(8 downto 1) of std_logic_vector(3 downto 0);
	type ar_6bit_4ea is array(4 downto 1) of std_logic_vector(5 downto 0);
	type ar_8bit_4ea is array(4 downto 1) of std_logic_vector(7 downto 0);
	type ar_8bit_5ea is array(5 downto 1) of std_logic_vector(7 downto 0);
	type ar_8bit_8ea is array(8 downto 1) of std_logic_vector(7 downto 0);
	type ar_8bit_9ea is array(9 downto 1) of std_logic_vector(7 downto 0);
	type ar_8bit_23ea is array(23 downto 1) of std_logic_vector(7 downto 0);
	type ar_8bit_30ea is array(30 downto 1) of std_logic_vector(7 downto 0);
	type ar_9bit_4ea is array(4 downto 1) of std_logic_vector(8 downto 0);
	type ar_9bit_8ea is array(8 downto 1) of std_logic_vector(8 downto 0);
	type ar_12bit_4ea is array(4 downto 1) of std_logic_vector(11 downto 0);
	type ar_12bit_8ea is array(8 downto 1) of std_logic_vector(11 downto 0);
	type ar_16bit_2ea is array(2 downto 1) of std_logic_vector(15 downto 0);
	type ar_16bit_3ea is array(3 downto 1) of std_logic_vector(15 downto 0);
	type ar_16bit_4ea is array(4 downto 1) of std_logic_vector(15 downto 0);
	type ar_16bit_5ea is array(5 downto 1) of std_logic_vector(15 downto 0);
	type ar_16bit_6ea is array(6 downto 1) of std_logic_vector(15 downto 0);
	type ar_16bit_16ea is array(16 downto 1) of std_logic_vector(15 downto 0);
	type ar_40bit_4ea is array(4 downto 1) of std_logic_vector(39 downto 0);
	type ar_16bit_8ea is array(8 downto 1) of std_logic_vector(15 downto 0);
	type ar_32bit_2ea is array(2 downto 1) of std_logic_vector(31 downto 0);
	type ar_32bit_3ea is array(3 downto 1) of std_logic_vector(31 downto 0);
	type ar_32bit_4ea is array(4 downto 1) of std_logic_vector(31 downto 0);
	type ar_32bit_5ea is array(5 downto 1) of std_logic_vector(31 downto 0);
	type ar_32bit_6ea is array(6 downto 1) of std_logic_vector(31 downto 0);
	type ar_32bit_8ea is array(8 downto 1) of std_logic_vector(31 downto 0);
	type ar_40bit_5ea is array(5 downto 1) of std_logic_vector(39 downto 0);
	type ar_40bit_8ea is array(8 downto 1) of std_logic_vector(39 downto 0);
	type ar_3bit_4ea is array(4 downto 1) of std_logic_vector(2 downto 0);
end typedef_servo_enc;
