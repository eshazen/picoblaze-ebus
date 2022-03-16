--
-- simple testbench for Dan's counter
--
-- E.Hazen
--

library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity counter_tb is
end entity counter_tb;

architecture sim of counter_tb is

-- "normal" settings in BX
  constant HIT_WIDTH       : integer := 41;  -- HIT data width
  constant BX_BIT_OFFSET   : integer := 0;   -- offset of BX in input hits
  constant TRIG_WIN_OFFSET : integer := 10;  -- offset to start of trigger match (BX)
  constant TRIG_WIN_WIDTH  : integer := 40;  -- width of trigger window in BX
  constant TRIG_MATCH_TIME : integer := 80;  -- min time (BX) to wait for matching hits
  constant TRIG_TIMEOUT    : integer := 200;  -- max time to wait for FIFO to empty

  component counter is
    generic (
      roll_over   : std_logic;
      end_value   : std_logic_vector(31 downto 0);
      start_value : std_logic_vector(31 downto 0);
      A_RST_CNT   : std_logic_vector(31 downto 0);
      DATA_WIDTH  : integer);
    port (
      clk         : in  std_logic;
      reset_async : in  std_logic;
      reset_sync  : in  std_logic;
      enable      : in  std_logic;
      event       : in  std_logic;
      count       : out std_logic_vector(DATA_WIDTH-1 downto 0);
      at_max      : out std_logic);
  end component counter;

  constant clock_period : time := 10.0 ns;
  constant D_WIDTH : integer := 10;

  signal stop_the_clock : boolean;

  signal s_clk      : std_logic;

  signal s_rst_a, s_rst_s : std_logic;
  signal s_ena : std_logic;
  signal s_event : std_logic;
  signal s_count : std_logic_vector( D_WIDTH-1 downto 0);
  signal s_at_max : std_logic;

begin  -- architecture sim

  counter_1: counter
    generic map (
      roll_over => '1',
      end_value => X"000000ff",
      start_value => x"00000000",
      A_RST_CNT => X"00000000",
      DATA_WIDTH => D_WIDTH)
    port map (
      clk         => s_clk,
      reset_async => s_rst_a,
      reset_sync  => s_rst_s,
      enable      => s_ena,
      event       => s_event,
      count       => s_count,
      at_max      => s_at_max);

  stimulus : process

  begin

    -- Put initialisation code here
    s_rst_a <= '0';
    s_ena <= '0';
    s_rst_s <= '0';
    s_event <= '0';

    wait for clock_period*4;

    s_rst_s <= '1';
    wait for clock_period*4;
    s_rst_s <= '0';
    wait for clock_period*4;

    s_ena <= '1';
    wait for clock_period*4;

    s_event <= '1';
    wait for clock_period*4;
    s_event <= '0';
    wait for clock_period*4;

    s_event <= '1';
    wait for clock_period*4;
    s_event <= '0';
    wait for clock_period*4;

    s_event <= '1';
    wait for clock_period*4;
    s_event <= '0';
    wait for clock_period*4;

    s_event <= '1';
    wait for clock_period*4;
    s_event <= '0';
    wait for clock_period*4;

    wait;

  end process;

  g_bx : process
  begin
    while not stop_the_clock loop
      s_clk <= '0';
      wait for clock_period/2;
      s_clk <= '1';
      wait for clock_period/2;
    end loop;
  end process;

end architecture sim;
