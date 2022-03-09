--
-- top_pb_daq.vhd
--
-- Interface via picoblaze serial interface currently at 9600 baud
-- (see .../psm/monitor.psm to change, search for "start:")
--
-- current top-level memory map (ebus devices)
-- 0000000x - GPIO interface
-- 10000000 - Dan's rate meter for debugging
-- 20000000 - Event generator for debugging
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

entity top_pb_daq is

  port (
    clk100  : in  std_logic;                      -- 100MHz oscillator
    uart_rx : in  std_logic;                      --  Serial Input
    uart_tx : out std_logic;                      --  Serial output
    sw      : in  std_logic_vector(15 downto 0);
    led     : out std_logic_vector(15 downto 0);  -- LEDs
    JA      : out std_logic_vector(7 downto 0)
    );
end entity top_pb_daq;


--
-------------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture arch of top_pb_daq is
--
-------------------------------------------------------------------------------------------
--
-- Components
--
-------------------------------------------------------------------------------------------
--

  component daq_unit is
    generic (
      ORBIT_LENGTH      : integer;
      PIPE_CLK_MULTIPLE : integer;
      HIT_WIDTH         : integer;
      BX_BIT_OFFSET     : integer;
      TRIG_WIN_OFFSET   : integer;
      TRIG_WIN_WIDTH    : integer;
      TRIG_MATCH_TIME   : integer;
      TRIG_TIMEOUT      : integer;
      DAQ_WIDTH         : integer;
      DAQ_MULT          : integer;
      SLOT_WIDTH        : integer;
      NUM_WM            : integer;
      WM_SEL_WID        : integer);
    port (
      sys_clk    : in  std_logic;
      sys_rst    : in  std_logic;
      trig_rate  : in  std_logic_vector(31 downto 0);
      hit_rate   : in  std_logic_vector(31 downto 0);
      ocr_req    : in  std_logic;
      ecr_req    : in  std_logic;
      felix      : out std_logic_vector(229 downto 0);
      felix_dv   : out std_logic;
      felix_full : in  std_logic);
  end component daq_unit;

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
      NUM_STATUS     : integer;
      NUM_ACTION     : integer);
    port (
      ebus_out   : in  ebus_out_t;
      ebus_in    : out ebus_in_t;
      clk        : in  std_logic;
      reset      : in  std_logic;
      ctrl_reg   : out bus_array(NUM_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
      status_reg : in  bus_array(NUM_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
      action_reg : out bus_array(NUM_ACTION-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0));
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
  constant N_STATUS  : integer := 2;  -- number of 32-bit status registers in ebus_slave_gpio
  constant N_CONTROL : integer := 4;  -- number of 32-bit control registers in ebus_slave_gpio
  constant N_ACTION  : integer := 1;  -- number of 32-bit action registers in ebus_slave_gpio

  signal ctrl_regs   : bus_array(N_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal status_regs : bus_array(N_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal action_regs : bus_array(N_ACTION-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);

  signal felix : std_logic_vector( 229 downto 0);
  signal felix_dv : std_logic;
  signal felix_full : std_logic;

begin

  reset <= '0';                         -- hopefully not needed

  led                         <= ctrl_regs(0)(15 downto 0);
  status_regs(0)(15 downto 0) <= sw;
  JA                          <= action_regs(0)(7 downto 0);

  clk <= clk100;

--
-- the Picoblaze bus master (A32/D32)
--  
  pico_ebus_1 : pico_ebus
    port map (
      clk        => clk,
      reset      => reset,
      RX         => uart_rx,
      TX         => uart_tx,
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
      NUM_STATUS     => N_STATUS,
      NUM_ACTION     => N_ACTION)
    port map (
      ebus_out   => ebus_out,
      ebus_in    => ebus_in_group(0),
      clk        => clk,
      reset      => warm_reset,
      ctrl_reg   => ctrl_regs,
      status_reg => status_regs,
      action_reg => action_regs);

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


  daq_unit_1 : entity work.daq_unit
    port map (
      sys_clk    => clk,
      sys_rst    => action_regs(0)(0),
      trig_rate  => ctrl_regs(0),
      hit_rate   => ctrl_regs(1),
      ocr_req    => action_regs(0)(1),
      ecr_req    => action_regs(0)(2),
      felix      => felix,
      felix_dv   => felix_dv,
      felix_full => felix_full);

end arch;

