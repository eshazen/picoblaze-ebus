--
-- ebus_slave_gen.vhd -- ebus slave for Dan's rate meter
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;

entity ebus_slave_gen is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------");

  port (
    ebus_out : in  ebus_out_t;
    ebus_in  : out ebus_in_t;
    clk      : in  std_logic;
    reset    : in  std_logic;
    event    : out std_logic            -- event to measure rate
    );

end entity ebus_slave_gen;


architecture arch of ebus_slave_gen is

  subtype LONG is std_logic_vector(31 downto 0);
  subtype ULONG is unsigned(31 downto 0);

  signal count, rate : ULONG;

begin  -- architecture arch

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)
      count <= (others => '0');
      rate  <= (others => '0');
    elsif rising_edge(clk) then         -- rising clock edge

      event <= '0';

      if count = rate then
        count <= (others => '0');
        event <= '1';
      else
        count <= count + 1;
      end if;

      -- decode address according to DECODE_MASK and BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.wr = '1' then
          rate <= unsigned(ebus_out.data);
          count <= (others => '0');     --reset counter on rate change
        end if;

        if ebus_out.rd = '1' then
          ebus_in.data <= std_logic_vector(rate);
        end if;

      end if;


    end if;
  end process;



end architecture arch;
