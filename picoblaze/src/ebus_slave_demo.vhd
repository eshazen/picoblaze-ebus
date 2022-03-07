--
-- ebus_slave_demo.vhd -- demonstrator ebus slave for testing
--
-- provide RAM_DEPTH read/write registers, 32 bits long
-- at address above map a 32-bit counter

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;

entity ebus_slave_demo is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------";
    RAM_DEPTH      : integer        := 4);

  port (
    ebus_out : in  ebus_out_t;
    ebus_in  : out ebus_in_t;
    clk      : in  std_logic;
    reset    : in  std_logic);

end entity ebus_slave_demo;


architecture arch of ebus_slave_demo is

  subtype LONG is std_logic_vector(31 downto 0);
  subtype ULONG is unsigned(31 downto 0);
  type REGS is array (RAM_DEPTH-1 downto 0) of LONG;

  signal s_regs    : REGS;
  signal s_counter : ULONG;

begin  -- architecture arch

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      s_counter <= s_counter + 1;

      -- decode address according to DECODE_MASK and BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.wr = '1' then
          s_regs(to_integer(unsigned(ebus_out.addr(clog2(RAM_DEPTH)-1 downto 0)))) <= ebus_out.data;
        end if;

        if ebus_out.rd = '1' then
          if ebus_out.addr(clog2(RAM_DEPTH)) = '1' then
            ebus_in.data <= std_logic_vector(s_counter);
          else
            ebus_in.data <= s_regs(to_integer(unsigned(ebus_out.addr(clog2(RAM_DEPTH)-1 downto 0))));
          end if;
        end if;

      end if;


    end if;
  end process;



end architecture arch;
