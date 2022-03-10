--
-- ebus_slave_rate.vhd -- ebus slave for Dan's rate meter
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;
use work.bus_multiplexer_pkg.all;

entity ebus_slave_rate is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------";
    NUM_RATE_METER : integer        := 1);
  port (
    ebus_out : in  ebus_out_t;
    ebus_in  : out ebus_in_t;
    clk      : in  std_logic;
    reset    : in  std_logic;
    clk_b    : in  std_logic;           -- event count clock domain
    event    : in  std_logic_vector(NUM_RATE_METER-1 downto 0)  -- event to measure rate
    );

end entity ebus_slave_rate;


architecture arch of ebus_slave_rate is

  component rate_counter is
    generic (
      CLK_A_1_SECOND : integer);
    port (
      clk_A         : in  std_logic;
      clk_B         : in  std_logic;
      reset_A_async : in  std_logic;
      event_b       : in  std_logic;
      rate          : out std_logic_vector(31 downto 0));
  end component rate_counter;
  signal rate : bus_array(NUM_RATE_METER-1 downto 0)(31 downto 0);
  
begin  -- architecture arch

  fg : for i in 0 to NUM_RATE_METER-1 generate
    rate_counter_2 : entity work.rate_counter
      port map (
        clk_A         => clk,
        clk_B         => clk_b,
        reset_A_async => reset,
        event_b       => event(i),
        rate          => rate(i));
  end generate fg;

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      -- decode address
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.rd = '1' then
          ebus_in.data <= rate(to_integer(unsigned(ebus_out.addr(clog2(NUM_RATE_METER)-1 downto 0))));
        end if;

      end if;


    end if;
  end process;



end architecture arch;
