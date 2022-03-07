--
-- ebus_slave_serialize.vhd -- ebus slave to control serializer
--
-- Address Map:
--
--     Address  R/W  bits  function
--   ---------  ---  ----  --------------
--   ---- --00  R/W  32    data
--   ---- --01  R/W  8     clock divider
--   ---- --02  R/W  4     count (bits 0-7) direction (bit 31)
--   ---- --1-  W    -     start (data ignored)
--   ---- --1-  R    1     busy
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;


entity ebus_slave_serialize is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "1-------";
    RAM_DEPTH      : integer        := 4);

  port (
    ebus_out        : in  ebus_out_t;
    ebus_in         : out ebus_in_t;
    clk             : in  std_logic;
    reset           : in  std_logic;
    sclk            : out std_logic;    -- Output clock to CITIROC.
    sdata           : out std_logic;
    test_strobe_out : out std_logic;    --for debug
    start           : out std_logic;
    busy            : out std_logic
    );                                  -- Serial data out.

end entity ebus_slave_serialize;


architecture arch of ebus_slave_serialize is

  component serialize is
    port (
      clock   : in  std_logic;
      reset   : in  std_logic;
      divider : in  std_logic_vector(7 downto 0);
      data    : in  std_logic_vector(31 downto 0);
      count   : in  std_logic_vector(4 downto 0);
      dir     : in  std_logic;
      start   : in  std_logic;
      busy    : out std_logic;
      sclk    : out std_logic;
      sdata   : out std_logic);
  end component serialize;

  subtype LONG is std_logic_vector(31 downto 0);
  subtype ULONG is unsigned(31 downto 0);
  type REGS is array (RAM_DEPTH-1 downto 0) of LONG;

  signal s_regs : REGS;

  signal s_divider : std_logic_vector(7 downto 0);
  signal s_data    : std_logic_vector(31 downto 0);
  signal s_count   : std_logic_vector(4 downto 0);
  signal s_dir     : std_logic;
  signal s_start   : std_logic;
  signal s_busy    : std_logic;

begin  -- architecture arch

  serialize_1 : entity work.serialize
    port map (
      clock   => clk,
      reset   => reset,
      divider => s_divider,
      data    => s_data,
      count   => s_count,
      dir     => s_dir,
      start   => s_start,
      busy    => s_busy,
      sclk    => sclk,
      sdata   => sdata);

  s_data    <= s_regs(0);
  s_divider <= s_regs(1)(7 downto 0);
  s_count   <= s_regs(2)(4 downto 0);
  s_dir     <= s_regs(2)(31);

  busy  <= s_busy;
  start <= s_start;

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      s_start         <= '0';
      test_strobe_out <= '0';

      -- decode address according to DECODE_MASK and BASE_ADDR
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        -- writes to address offset 1x cause start
        if ebus_out.wr = '1' then

          test_strobe_out <= '1';

          if ebus_out.addr(4) = '1' then
            s_start <= '1';
          else
            s_regs(to_integer(unsigned(ebus_out.addr(clog2(RAM_DEPTH)-1 downto 0)))) <= ebus_out.data;
          end if;
        end if;

        -- reads from address offset 1x return busy
        if ebus_out.rd = '1' then
          if ebus_out.addr(4) = '1' then
            ebus_in.data <= "0000000000000000000000000000000" & s_busy;
          else
            ebus_in.data <= s_regs(to_integer(unsigned(ebus_out.addr(clog2(RAM_DEPTH)-1 downto 0))));
          end if;
        end if;

      end if;

    end if;
  end process;



end architecture arch;
