--
-- ebus_slave_mux.vhd - multiplexer for multiple ebus devices
-- note that the number of ports is set in ebus_types.yml as EBUS_PORT_COUNT
--
-- the upper n bits of the 32-bit address are used to switch the mux
-- where n is clog2(EBUS_PORT_COUNT)

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;

entity ebus_slave_mux is

  port (
    ebus_in  : out ebus_in_t;
    ebus_in_group : in ebus_in_group_t;
    in_select : in unsigned( clog2(EBUS_PORT_COUNT)-1 downto 0)
    );

end entity ebus_slave_mux;



architecture arch of ebus_slave_mux is

begin  -- architecture arch

  process(in_select)
  begin  -- process

    ebus_in <= ebus_in_group( to_integer(unsigned(in_select)));

  end process;

end architecture arch;
