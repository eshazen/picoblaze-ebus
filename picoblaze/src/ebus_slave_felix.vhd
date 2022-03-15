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

  type ram_type is array (0 to RAM_DEPTH-1) of std_logic_vector(RAM_WIDTH-1 downto 0);
  signal RAM : ram_type;

  -- addresss offset for wide words
  constant RAM_MUX_ADDR_BIT : integer := clog2(RAM_WIDTH/32);
  -- number of words per RAM location
  constant RAM_MUX_FACTOR   : integer := integer(2 ** RAM_MUX_ADDR_BIT);
  -- width of RAM rounded up to 32 bits
  constant RAM_MUX_WIDTH    : integer := 32 * RAM_MUX_FACTOR;

  -- address width
  constant ADDR_WIDTH : integer := clog2(RAM_DEPTH);

  signal write_addr      : unsigned(ADDR_WIDTH-1 downto 0);
  signal prog_write_addr : unsigned(ADDR_WIDTH-1 downto 0);
  signal read_addr       : unsigned(ADDR_WIDTH-1 downto 0);

  signal set_write_addr : std_logic;
  signal write_enable   : std_logic;

  -- multiplexer for reading FELIX data
  signal mux_in  : std_logic_vector(RAM_MUX_WIDTH-1 downto 0);
  signal mux_out : std_logic_vector(31 downto 0);

  -- demultiplexer for writing FELIX data
  signal dmux_in  : std_logic_vector(31 downto 0);
  signal dmux_out : std_logic_vector(RAM_MUX_WIDTH-1 downto 0);

  -- input word for RAM
  signal ram_write_word : std_logic_vector(RAM_MUX_WIDTH-1 downto 0);

  signal tick : unsigned(31 downto 0);

begin  -- architecture arch

  -- asynchronously multiplex/demultiplex RAM for 32-bit access
  fg : for i in 31 downto 0 generate
    mux_out(i) <= mux_in(i + (32 * to_integer(unsigned(ebus_out.addr(RAM_MUX_ADDR_BIT-1 downto 0)))));
  end generate fg;

  mux_in(RAM_WIDTH-1 downto 0) <= RAM(to_integer(read_addr));

  -- for now replace low 32 bits with timestamp
  ram_write_word <= ram_in( RAM_WIDTH-1 downto RAM_WIDTH-32) & std_logic_vector(tick);

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

      write_addr      <= (others => '0');
      read_addr       <= (others => '0');
      prog_write_addr <= (others => '0');
      write_enable    <= '0';
      set_write_addr  <= '0';
      tick           <= (others => '0');

    elsif rising_edge(clk) then         -- rising clock edge

      tick <= tick + 1;

      set_write_addr <= '0';            -- flag: programmed write address set

      -- write incoming data with wrap around
      if write_enable = '1' and ram_wr = '1' then
        RAM(to_integer(write_addr)) <= ram_write_word;
        if write_addr /= RAM_DEPTH-1 then
          write_addr <= write_addr + 1;
        end if;
      end if;

      if set_write_addr = '1' then
        write_addr <= prog_write_addr;
      end if;

      -- decode address according to BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.rd = '1' then
          -- read from addresses 0..7 for data
          if ebus_out.addr(RAM_MUX_ADDR_BIT) = '0' then
            ebus_in.data <= mux_out;
          else
            -- read from address 8 is write address plus write enable
            if ebus_out.addr(0) = '0' then
              ebus_in.data(ADDR_WIDTH-1 downto 0) <= std_logic_vector(write_addr);
              ebus_in.data(14 downto ADDR_WIDTH)  <= (others => '0');
              ebus_in.data(15)                    <= write_enable;
              ebus_in.data(31 downto 16)          <= X"beef";
            else
              -- read from address 9 is read address plus write enable in bit 15
              ebus_in.data(ADDR_WIDTH-1 downto 0) <= std_logic_vector(read_addr);
              ebus_in.data(15 downto ADDR_WIDTH)  <= (others => '0');
              ebus_in.data(31 downto 16)          <= X"cafe";
            end if;
          end if;
        end if;

        if ebus_out.wr = '1' then

          if ebus_out.addr(RAM_MUX_ADDR_BIT) = '0' then
          -- write to addresses 0..7 for data
          else
            if ebus_out.addr(1 downto 0) = "00" then
              -- write to address 8 sets write address
              prog_write_addr <= unsigned(ebus_out.data(ADDR_WIDTH-1 downto 0));
              set_write_addr  <= '1';
            elsif ebus_out.addr(1 downto 0) = "01" then
              -- write to address 9 sets read address
              read_addr <= unsigned(ebus_out.data(ADDR_WIDTH-1 downto 0));
            elsif ebus_out.addr(1 downto 0) = "10" then
              -- write to address A sets write enable
              write_enable <= ebus_out.data(0);
            end if;
          end if;

        end if;

      end if;

    end if;

  end process;

end architecture arch;
