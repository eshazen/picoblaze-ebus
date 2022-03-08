--
-- top_pb_example.vhd
--
-- Interface via picoblaze serial interface currently at 9600 baud
-- (see .../psm/monitor.psm to change, search for "start:")
--
-- current top-level memory map (ebus devices)
-- 0000000x - CITIROC bit-bang interface
-- 10000000 - Dan's rate meter for debugging
-- 20000000 - Event generator for debugging
-- 300000xx - CITIROC serial interface
--
-- Useful commands:
--   "O 10 0" warm reset the logic (recommended once at start)
-- Write/read registers above
--   "W a d"  where a and d are hex values up to 8 digits
--   "R a"
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;
use work.bus_multiplexer_pkg.all;

--
-------------------------------------------------------------------------------------------
--
--

entity top_pb_example is

  port (
    clk100 : in std_logic;              -- 100MHz oscillator

    UART_rx : in  std_logic;                    --  Serial Input
    UART_tx : out std_logic;                    --  Serial output
    LED     : out std_logic_vector(2 downto 0)  -- LEDs
    );
end entity top_pb_example;


--
-------------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture arch of top_pb_example is
--
-------------------------------------------------------------------------------------------
--
-- Components
--
-------------------------------------------------------------------------------------------
--

--  component clk25_250_100 is
--    port (
--      clk0      : out std_logic;
--      clk1      : out std_logic;
--      clk2      : out std_logic;
--      clk3      : out std_logic;
--      clkout100 : out std_logic;
--      reset     : in  std_logic;
--      locked    : out std_logic;
--      clk_in1   : in  std_logic);
--  end component clk25_250_100;

  component pico_ebus is
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      RX         : in  std_logic;
      TX         : out std_logic;
      warm_reset : out std_logic;
      ebus_out   : out ebus_out_t;
      ebus_in    : in  ebus_in_t);
  end component pico_ebus;

  component ebus_slave_mux is
    port (
      ebus_in       : out ebus_in_t;
      ebus_in_group : in  ebus_in_group_t;
      in_select     : in  unsigned(clog2(EBUS_PORT_COUNT)-1 downto 0));
  end component ebus_slave_mux;

  component ebus_slave_gpio is
    generic (
      EBUS_BASE_ADDR : string(1 to 8);
      NUM_CONTROL    : integer;
      NUM_STATUS     : integer);
    port (
      ebus_out   : in  ebus_out_t;
      ebus_in    : out ebus_in_t;
      clk        : in  std_logic;
      reset      : in  std_logic;
      ctrl_reg   : out bus_array(NUM_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
      status_reg : in  bus_array(NUM_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0));
  end component ebus_slave_gpio;

  component ebus_slave_gen is
    generic (
      EBUS_BASE_ADDR : string(1 to 8));
    port (
      ebus_out : in  ebus_out_t;
      ebus_in  : out ebus_in_t;
      clk      : in  std_logic;
      reset    : in  std_logic;
      event    : out std_logic);
  end component ebus_slave_gen;

  component ebus_slave_rate is
    generic (
      EBUS_BASE_ADDR : string(1 to 8));
    port (
      ebus_out : in  ebus_out_t;
      ebus_in  : out ebus_in_t;
      clk      : in  std_logic;
      reset    : in  std_logic;
      clk_b    : in  std_logic;
      event    : in  std_logic);
  end component ebus_slave_rate;

  component ebus_slave_serialize is
    generic (
      EBUS_BASE_ADDR : string(1 to 8);
      RAM_DEPTH      : integer);
    port (
      ebus_out : in  ebus_out_t;
      ebus_in  : out ebus_in_t;
      clk      : in  std_logic;
      reset    : in  std_logic;
      sclk     : out std_logic;
      sdata    : out std_logic;
      start    : out std_logic;
      busy     : out std_logic);
  end component ebus_slave_serialize;

--
  signal clk : std_logic;
--

  signal reset, clk0, clk1, clk2, clk3 : std_logic;

  signal warm_reset : std_logic;        -- reset logic only

  signal ebus_out      : ebus_out_t;
  signal ebus_in       : ebus_in_t;
  signal ebus_in_group : ebus_in_group_t;

  signal event : std_logic;


  -- for now these must be powers of two
  constant N_STATUS  : integer := 4;  -- number of 32-bit status registers in ebus_slave_gpio
  constant n_CONTROL : integer := 2;  -- number of 32-bit control registers in ebus_slave_gpio

  signal ctrl_regs   : bus_array(N_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal status_regs : bus_array(N_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);

begin

  reset <= '0';                         -- hopefully not needed

  LED <= ctrl_regs(0)(31 downto 29);

  clk <= clk100;

----
---- synthesize a 4-phase 100MHz clock from 25MHz oscillator
----
--  clk25_250_100_1 : clk25_250_100
--    port map (
--      clk0      => clk0,
--      clk1      => clk1,
--      clk2      => clk2,
--      clk3      => clk3,
--      clkout100 => clk,
--      reset     => reset,
--      locked    => open,
--      clk_in1   => clk25);

--
-- the Picoblaze bus master (A32/D32)
--  
  pico_ebus_1 : pico_ebus
    port map (
      clk        => clk,
      reset      => reset,
      RX         => UART_Rx,
      TX         => UART_Tx,
      warm_reset => warm_reset,
      ebus_out   => ebus_out,
      ebus_in    => ebus_in);

--
-- bus input multiplexer
-- note that for now EBUS_PORT_COUNT in ebus_types.yml must match the select bits
--  
  ebus_slave_mux_1 : ebus_slave_mux
    port map (
      in_select     => ebus_out.addr(29 downto 28),
      ebus_in       => ebus_in,
      ebus_in_group => ebus_in_group);

  -- device 0:  GPIO slave
  ebus_slave_gpio_1 : ebus_slave_gpio
    generic map (
      EBUS_BASE_ADDR => "0-------",
      NUM_CONTROL    => N_CONTROL,
      NUM_STATUS     => N_STATUS)
    port map (
      ebus_out   => ebus_out,
      ebus_in    => ebus_in_group(0),
      clk        => clk,
      reset      => warm_reset,
      ctrl_reg   => ctrl_regs,
      status_reg => status_regs);

  -- device 1:  rate meter test
  ebus_slave_rate_1 : ebus_slave_rate
    generic map (
      EBUS_BASE_ADDR => "1-------")
    port map (
      ebus_out => ebus_out,
      ebus_in  => ebus_in_group(1),
      clk      => clk,
      reset    => warm_reset,
      clk_b    => clk,
      event    => event);

  -- device 2:  rate generator test
  ebus_slave_gen_1 : ebus_slave_gen
    generic map (
      EBUS_BASE_ADDR => "2-------")
    port map (
      ebus_out => ebus_out,
      ebus_in  => ebus_in_group(2),
      clk      => clk,
      reset    => warm_reset,
      event    => event);

--  -- device 3:  serial interface
--  ebus_slave_serialize_1 : entity work.ebus_slave_serialize
--    generic map (
--      EBUS_BASE_ADDR => "3-------")
--    port map (
--      ebus_out        => ebus_out,
--      ebus_in         => ebus_in_group(3),
--      clk             => clk,
--      reset           => warm_reset,
--      sclk            => s_sclk,
--      test_strobe_out => s_test_strobe,
--      sdata           => s_sdata,
--      busy            => s_busy,
--      start           => s_start);

end arch;

