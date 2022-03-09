--
-- ebus_slave_felix.vhd -- 
--
-- memory buffer for FELIX data readout
-- accept words FIFO-like from FELIX
-- read as 32-bit words over eBus
-- 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;
use work.bus_multiplexer_pkg.all;

entity ebus_slave_felix is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------";
    RAM_WIDTH      : integer        := 230;
    RAM_DEPTH      : integer        := 256);

  port (
    ebus_out : in  ebus_out_t;
    ebus_in  : out ebus_in_t;
    clk      : in  std_logic;
    reset    : in  std_logic;
    ram_in   : in  std_logic_vector(RAM_WIDTH-1 downto 0);
    ram_wr   : in  std_logic;
    ram_full : out std_logic
    );

end entity ebus_slave_felix;


architecture arch of ebus_slave_felix is

  type ram_type is array ( 0 to RAM_DEPTH-1) of std_logic_vector(RWM_WIDTH-1 downto 0);
  signal RAM : ram_type;

  -- addresss offset for wide words
  constant RAM_MUX_ADDR_BIT : integer := clog2( RAM_WIDTH/32);
  -- number of words per RAM location
  constant RAM_MUX_FACTOR : integer := integer( 2 ** RAM_MUX_ADDR_BIT);

  -- address widths
  constant WRITE_ADDR_WIDTH : integer := clog2( RAM_DEPTH);
  constant READ_ADDR_WIDTH : integer := WRITE_ADDR_WIDTH + RAM_MUX_ADDR_BIT;

begin  -- architecture arch

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      -- decode address according to BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.wr = '1' then
--          if ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '0' then
--            ctrl_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0)))) <= ebus_out.data;
--          elsif ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '1' then
--            action_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0)))) <= ebus_out.data;
--          end if;
        end if;

        if ebus_out.rd = '1' then

          -- FIXME:  finish this

--          if ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '0' then
--            ebus_in.data <= ctrl_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0))));
--          elsif ebus_out.addr(REG_SEL_BIT) = '1' and ebus_out.addr(ACT_SEL_BIT) = '0' then
--            ebus_in.data <= status_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_STATUS)-1 downto 0))));
--          end if;
        end if;

      end if;

    end if;
  end process;

end architecture arch;
