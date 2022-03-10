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
    RAM_DEPTH      : integer        := 1024);

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

  type ram_type is array ( 0 to RAM_DEPTH-1) of std_logic_vector(RAM_WIDTH-1 downto 0);
  signal RAM : ram_type;

  -- addresss offset for wide words
  constant RAM_MUX_ADDR_BIT : integer := clog2( RAM_WIDTH/32);
  -- number of words per RAM location
  constant RAM_MUX_FACTOR : integer := integer( 2 ** RAM_MUX_ADDR_BIT);
  -- width of RAM rounded up to 32 bits
  constant RAM_MUX_WIDTH : integer := 32 * RAM_MUX_FACTOR;

  -- address width
  constant ADDR_WIDTH : integer := clog2( RAM_DEPTH);

  signal write_addr : unsigned( ADDR_WIDTH-1 downto 0);
  signal read_addr : unsigned( ADDR_WIDTH-1 downto 0);

  signal mux_in : std_logic_vector( RAM_MUX_WIDTH-1 downto 0);
  signal mux_out : std_logic_vector(31 downto 0);

begin  -- architecture arch

  -- asynchronously multiplex output
  fg: for i in 31 downto 0 generate
    mux_out(i) <= mux_in( 32 * to_integer(unsigned(ebus_out.addr(RAM_MUX_ADDR_BIT-1 downto 0))));
  end generate fg;

  mux_in( RAM_WIDTH-1 downto 0) <= ram_in;

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

      write_addr <= (others => '0');
      read_addr <= (others => '0');

    elsif rising_edge(clk) then         -- rising clock edge

      -- write incoming data with wrap around
      if ram_wr = '1' then
        RAM( to_integer( write_addr)) <= ram_in;
        if write_addr /= RAM_DEPTH-1 then
          write_addr <= write_addr + 1;
        end if;
      end if;
      

      -- decode address according to BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.rd = '1' then

          if ebus_out.addr(RAM_MUX_ADDR_BIT) = '0' then
            ebus_in.data <= mux_out;
          else
            if ebus_out.addr(0) = '0' then
              ebus_in.data(ADDR_WIDTH-1 downto 0) <= std_logic_vector(write_addr);
              ebus_in.data(31 downto ADDR_WIDTH) <= (others => '0');
            else
              ebus_in.data(ADDR_WIDTH-1 downto 0) <= std_logic_vector(read_addr);
              ebus_in.data(31 downto ADDR_WIDTH) <= (others => '0');
          end if;
        end if;

        if ebus_out.wr = '1' then
          read_addr <= ebus_in.data(ADDR_WIDTH-1 downto 0);
        end if;

      end if;

    end if;
  end process;

end architecture arch;
