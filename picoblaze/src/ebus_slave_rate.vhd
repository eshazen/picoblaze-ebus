--
-- ebus_slave_rate.vhd -- ebus slave for Dan's rate meter
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;
use work.ebus_function_pkg.all;
use work.util_pkg.all;

entity ebus_slave_rate is

  generic (
    EBUS_BASE_ADDR : string(1 to 8) := "2-------");

  port (
    ebus_out : in  ebus_out_t;
    ebus_in  : out ebus_in_t;
    clk      : in  std_logic;
    reset    : in  std_logic;
    clk_b    : in  std_logic;           -- event count clock domain
    event    : in  std_logic            -- event to measure rate
    );

end entity ebus_slave_rate;


architecture arch of ebus_slave_rate is

  subtype LONG is std_logic_vector(31 downto 0);
  subtype ULONG is unsigned(31 downto 0);

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

  signal rate : std_logic_vector(31 downto 0);

begin  -- architecture arch

  rate_counter_1: entity work.rate_counter
    port map (
      clk_A         => clk,
      clk_B         => clk_b,
      reset_A_async => reset,
      event_b       => event,
      rate          => rate);

  process (clk, reset) is
  begin  -- process
    if reset = '1' then                 -- asynchronous reset (active high)

    elsif rising_edge(clk) then         -- rising clock edge

      -- decode address
      if std_match(std_logic_vector(ebus_out.addr), EBUS_BASE_ADDR) then

        if ebus_out.rd = '1' then
          ebus_in.data <= std_logic_vector(rate);
        end if;

      end if;


    end if;
  end process;



end architecture arch;
