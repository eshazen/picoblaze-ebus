--
-- ebus_slave_gpio.vhd -- 
--
-- provide NUM_CONTROL 32-bit output registers (reg itself is R/W)
--   addresses 0..NUM_CONTROL-1
-- provide NUM_STATUS 32-bit input only
--   addresses NUM_CONTROL..NUM_CONTROL+NUM_STATUS-1
-- provide NUM_ACTION 32-bit pulsed output
--   

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;
use work.bus_multiplexer_pkg.all;

entity ebus_slave_gpio is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------";
    NUM_CONTROL    : integer        := 1;
    NUM_STATUS     : integer        := 1;
    NUM_ACTION     : integer        := 1);

  port (
    ebus_out   : in  ebus_out_t;
    ebus_in    : out ebus_in_t;
    clk        : in  std_logic;
    reset      : in  std_logic;
    ctrl_reg   : out bus_array(NUM_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
    status_reg : in  bus_array(NUM_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
    action_reg : out bus_array(NUM_ACTION-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0)
    );

end entity ebus_slave_gpio;


architecture arch of ebus_slave_gpio is

  subtype LONG is std_logic_vector(31 downto 0);
  subtype ULONG is unsigned(31 downto 0);

  signal ctrl_regs   : bus_array(NUM_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal status_regs : bus_array(NUM_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal action_regs : bus_array(NUM_ACTION-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);

  -- use maximum of (#control, #status) registers to divide up the address space
  constant REG_SEL_BIT : integer := MAXIMUM(clog2(NUM_CONTROL), clog2(NUM_STATUS));
--  constant ACT_SEL_BIT : integer := clog2( NUM_CONTROL+NUM_STATUS);
  constant ACT_SEL_BIT : integer := 8;  -- hardwired for now
  

begin  -- architecture arch

  ctrl_reg    <= ctrl_regs;
  status_regs <= status_reg;
  action_reg  <= action_regs;

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      -- decode address according to BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        action_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0)))) <= (others => '0');

        if ebus_out.wr = '1' then
          if ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '0' then
            ctrl_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0)))) <= ebus_out.data;
          elsif ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '1' then
            action_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0)))) <= ebus_out.data;
          end if;
        end if;

        if ebus_out.rd = '1' then
          if ebus_out.addr(REG_SEL_BIT) = '0' and ebus_out.addr(ACT_SEL_BIT) = '0' then
            ebus_in.data <= ctrl_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_CONTROL)-1 downto 0))));
          elsif ebus_out.addr(REG_SEL_BIT) = '1' and ebus_out.addr(ACT_SEL_BIT) = '0' then
            ebus_in.data <= status_regs(to_integer(unsigned(ebus_out.addr(clog2(NUM_STATUS)-1 downto 0))));
          end if;
        end if;

      end if;

    end if;
  end process;

end architecture arch;
