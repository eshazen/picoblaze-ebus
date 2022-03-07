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
    clk25            : in  std_logic;   -- 25MHz oscillator

    UART_rx          : in  std_logic;   --  Serial Input
    UART_tx          : out std_logic;   --  Serial output
    LED              : out std_logic_vector(2 downto 0)    -- LEDs
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

  component clk25_250_100 is
    port (
      clk0      : out std_logic;
      clk1      : out std_logic;
      clk2      : out std_logic;
      clk3      : out std_logic;
      clkout100 : out std_logic;
      reset     : in  std_logic;
      locked    : out std_logic;
      clk_in1   : in  std_logic);
  end component clk25_250_100;

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

  signal s_select : std_logic;          -- '1' selects serializer core, 
  -- '0' selects bit-bang

  signal s_sdata, s_sclk : std_logic;
  signal s_start, s_busy : std_logic;
  signal s_test_strobe   : std_logic;

-- auto-generated signal list for each pin
  signal s_A_T              : std_logic_vector(31 downto 0);
  signal s_B_T              : std_logic_vector(31 downto 0);
  signal s_A_NOR32T_oc      : std_logic;
  signal s_A_NOR32_oc       : std_logic;
  signal s_A_OR32           : std_logic;
  signal s_A_PS_global_trig : std_logic;
  signal s_A_PS_modeb_ext   : std_logic;
  signal s_A_Raz_Chn        : std_logic;
  signal s_A_Val_Evt        : std_logic;
  signal s_A_clk_read       : std_logic;
  signal s_A_clk_sr         : std_logic;
  signal s_A_digital_output : std_logic;
  signal s_A_hold_hg        : std_logic;
  signal s_A_hold_lg        : std_logic;
  signal s_A_load_sc        : std_logic;
  signal s_A_pwr_on         : std_logic;
  signal s_A_resetb_pa      : std_logic;
  signal s_A_resetb_read    : std_logic;
  signal s_A_rstb_PSC       : std_logic;
  signal s_A_rstb_sr        : std_logic;
  signal s_A_select         : std_logic;
  signal s_A_srin_read      : std_logic;
  signal s_A_srin_sr        : std_logic;
  signal s_A_srout_read     : std_logic;
  signal s_A_srout_sr       : std_logic;
  signal s_B_NOR32T_oc      : std_logic;
  signal s_B_NOR32_oc       : std_logic;
  signal s_B_OR32           : std_logic;
  signal s_B_PS_global_trig : std_logic;
  signal s_B_PS_modeb_ext   : std_logic;
  signal s_B_Raz_Chn        : std_logic;
  signal s_B_Val_Evt        : std_logic;
  signal s_B_clk_read       : std_logic;
  signal s_B_clk_sr         : std_logic;
  signal s_B_digital_output : std_logic;
  signal s_B_hold_hg        : std_logic;
  signal s_B_hold_lg        : std_logic;
  signal s_B_load_sc        : std_logic;
  signal s_B_pwr_on         : std_logic;
  signal s_B_resetb_pa      : std_logic;
  signal s_B_resetb_read    : std_logic;
  signal s_B_rstb_PSC       : std_logic;
  signal s_B_rstb_sr        : std_logic;
  signal s_B_select         : std_logic;
  signal s_B_srin_read      : std_logic;
  signal s_B_srin_sr        : std_logic;
  signal s_B_srout_read     : std_logic;
  signal s_B_srout_sr       : std_logic;
  signal s_UART_rx          : std_logic;
  signal s_UART_tx          : std_logic;

  -- for now these must be powers of two
  constant N_STATUS  : integer := 4;  -- number of 32-bit status registers in ebus_slave_gpio
  constant n_CONTROL : integer := 2;  -- number of 32-bit control registers in ebus_slave_gpio

  signal ctrl_regs   : bus_array(N_CONTROL-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);
  signal status_regs : bus_array(N_STATUS-1 downto 0)(EBUS_DATA_WIDTH-1 downto 0);

begin

  reset <= '0';                         -- hopefully not needed

-- 
-- (auto-generated)
-- assign pins to internal signals
--
  s_A_T              <= A_T;
  s_B_T              <= B_T;
  s_A_NOR32T_oc      <= A_NOR32T_oc;
  s_A_NOR32_oc       <= A_NOR32_oc;
  s_A_OR32           <= A_OR32;
  A_PS_global_trig   <= s_A_PS_global_trig;
  A_PS_modeb_ext     <= s_A_PS_modeb_ext;
  A_Raz_Chn          <= s_A_Raz_Chn;
  A_Val_Evt          <= s_A_Val_Evt;
  A_clk_read         <= s_A_clk_read;
  A_clk_sr           <= s_A_clk_sr;
  s_A_digital_output <= A_digital_output;
  A_hold_hg          <= s_A_hold_hg;
  A_hold_lg          <= s_A_hold_lg;
  A_load_sc          <= s_A_load_sc;
  A_pwr_on           <= s_A_pwr_on;
  A_resetb_pa        <= s_A_resetb_pa;
  A_resetb_read      <= s_A_resetb_read;
  A_rstb_PSC         <= s_A_rstb_PSC;
  A_rstb_sr          <= s_A_rstb_sr;
  A_select           <= s_A_select;
  A_srin_read        <= s_A_srin_read;
  A_srin_sr          <= s_A_srin_sr;
  s_A_srout_read     <= A_srout_read;
  s_A_srout_sr       <= A_srout_sr;
  s_B_NOR32T_oc      <= B_NOR32T_oc;
  s_B_NOR32_oc       <= B_NOR32_oc;
  s_B_OR32           <= B_OR32;
  B_PS_global_trig   <= s_B_PS_global_trig;
  B_PS_modeb_ext     <= s_B_PS_modeb_ext;
  B_Raz_Chn          <= s_B_Raz_Chn;
  B_Val_Evt          <= s_B_Val_Evt;
  B_clk_read         <= s_B_clk_read;
  B_clk_sr           <= s_B_clk_sr;
  s_B_digital_output <= B_digital_output;
  B_hold_hg          <= s_B_hold_hg;
  B_hold_lg          <= s_B_hold_lg;
  B_load_sc          <= s_B_load_sc;
  B_pwr_on           <= s_B_pwr_on;
  B_resetb_pa        <= s_B_resetb_pa;
  B_resetb_read      <= s_B_resetb_read;
  B_rstb_PSC         <= s_B_rstb_PSC;
  B_rstb_sr          <= s_B_rstb_sr;
  B_select           <= s_B_select;
  B_srin_read        <= s_B_srin_read;
  B_srin_sr          <= s_B_srin_sr;
  s_B_srout_read     <= B_srout_read;
  s_B_srout_sr       <= B_srout_sr;
  s_UART_rx          <= UART_rx;
  UART_tx            <= s_UART_tx;

-- 
-- pass inputs to status(0..3)
-- note that these are at address 2..5 on the ebus
--
  status_regs(0) <= s_A_T;
  status_regs(1) <= s_B_T;

  status_regs(2)(0) <= s_A_NOR32T_oc;
  status_regs(2)(1) <= s_A_NOR32_oc;
  status_regs(2)(2) <= s_A_OR32;
  status_regs(2)(3) <= s_A_digital_output;
  status_regs(2)(4) <= s_A_srout_read;
  status_regs(2)(5) <= s_A_srout_sr;

  -- board ID
  status_regs(2)(31 downto 24) <= x"f0";

  status_regs(3)(0) <= s_B_NOR32T_oc;
  status_regs(3)(1) <= s_B_NOR32_oc;
  status_regs(3)(2) <= s_B_OR32;
  status_regs(3)(3) <= s_B_digital_output;
  status_regs(3)(4) <= s_B_srout_read;
  status_regs(3)(5) <= s_B_srout_sr;

--
-- set outputs from ctrl(0)
--
  s_A_PS_global_trig <= ctrl_regs(0)(0);
  s_A_PS_modeb_ext   <= ctrl_regs(0)(1);
  s_A_Raz_Chn        <= ctrl_regs(0)(2);
  s_A_Val_Evt        <= ctrl_regs(0)(3);
  s_A_clk_read       <= ctrl_regs(0)(4);

  with s_select select
    s_A_clk_sr <=
    ctrl_regs(0)(5) when '0',
    s_sclk          when others;

  with s_select select
    s_A_srin_sr <=
    ctrl_regs(0)(16) when '0',
    s_sdata          when others;

  with s_select select
    s_B_clk_sr <=
    ctrl_regs(1)(5) when '0',
    s_sclk          when others;

  with s_select select
    s_B_srin_sr <=
    ctrl_regs(1)(16) when '0',
    s_sdata          when others;

  s_A_hold_hg     <= ctrl_regs(0)(6);
  s_A_hold_lg     <= ctrl_regs(0)(7);
  s_A_load_sc     <= ctrl_regs(0)(8);
  s_A_pwr_on      <= ctrl_regs(0)(9);
  s_A_resetb_pa   <= ctrl_regs(0)(10);
  s_A_resetb_read <= ctrl_regs(0)(11);
  s_A_rstb_PSC    <= ctrl_regs(0)(12);
  s_A_rstb_sr     <= ctrl_regs(0)(13);
  s_A_select      <= ctrl_regs(0)(14);
  s_A_srin_read   <= ctrl_regs(0)(15);

  s_B_PS_global_trig <= ctrl_regs(1)(0);
  s_B_PS_modeb_ext   <= ctrl_regs(1)(1);
  s_B_Raz_Chn        <= ctrl_regs(1)(2);
  s_B_Val_Evt        <= ctrl_regs(1)(3);
  s_B_clk_read       <= ctrl_regs(1)(4);

  s_B_hold_hg     <= ctrl_regs(1)(6);
  s_B_hold_lg     <= ctrl_regs(1)(7);
  s_B_load_sc     <= ctrl_regs(1)(8);
  s_B_pwr_on      <= ctrl_regs(1)(9);
  s_B_resetb_pa   <= ctrl_regs(1)(10);
  s_B_resetb_read <= ctrl_regs(1)(11);
  s_B_rstb_PSC    <= ctrl_regs(1)(12);
  s_B_rstb_sr     <= ctrl_regs(1)(13);
  s_B_select      <= ctrl_regs(1)(14);
  s_B_srin_read   <= ctrl_regs(1)(15);

  s_select <= ctrl_regs(0)(28);
  LED      <= ctrl_regs(0)(31 downto 29);

--
-- synthesize a 4-phase 100MHz clock from 25MHz oscillator
--
  clk25_250_100_1 : clk25_250_100
    port map (
      clk0      => clk0,
      clk1      => clk1,
      clk2      => clk2,
      clk3      => clk3,
      clkout100 => clk,
      reset     => reset,
      locked    => open,
      clk_in1   => clk25);

--
-- the Picoblaze bus master (A32/D32)
--  
  pico_ebus_1 : pico_ebus
    port map (
      clk        => clk,
      reset      => reset,
      RX         => s_UART_Rx,
      TX         => s_UART_Tx,
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

  -- device 3:  serial interface
  ebus_slave_serialize_1 : entity work.ebus_slave_serialize
    generic map (
      EBUS_BASE_ADDR => "3-------")
    port map (
      ebus_out        => ebus_out,
      ebus_in         => ebus_in_group(3),
      clk             => clk,
      reset           => warm_reset,
      sclk            => s_sclk,
      test_strobe_out => s_test_strobe,
      sdata           => s_sdata,
      busy            => s_busy,
      start           => s_start);

end arch;

