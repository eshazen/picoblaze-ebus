--
-- Inferred program rom test for PicoBlaze
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity monitor is

  port (
    address     : in  std_logic_vector(11 downto 0);
    instruction : out std_logic_vector(17 downto 0);
    addr_2      : in  std_logic_vector(11 downto 0);
    wen         : in  std_logic;                    
    di          : in  std_logic_vector(17 downto 0);
    do          : out std_logic_vector(17 downto 0);
    msize       : out std_logic_vector(11 downto 0);
    clk         : in  std_logic);

end entity monitor;


architecture syn of monitor is
  -- N.B. (0 to nn) order needed otherwise data is backwards!
  type ram_type is array (0 to <SIZE> ) of std_logic_vector(19 downto 0);
  signal RAM : ram_type := (
    <DATA>
    );
begin

  process (clk) is
  begin  -- process
    if clk'event and clk = '1' then     -- rising clock edge
      instruction <= RAM(to_integer(unsigned(address)))(17 downto 0);
      if wen = '1' then
        RAM(to_integer(unsigned(addr_2))) <= B"00" & di;
      end if;
    end if;
  end process;

  do <= RAM(to_integer(unsigned(addr_2)))(17 downto 0);

  msize <= std_logic_vector( to_unsigned( RAM'length, msize'length));

end syn;
