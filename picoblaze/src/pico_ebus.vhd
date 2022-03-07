-- pico_ebus.vhd
--  
-- PicoBlaze control interface to ebus
--
-- All I/O synchronized to clk
--
-- Address table (incomplete decoding, other addresses
-- may produce unexpected results)

-- Adr  WRITE                            READ
--      -----                            ----
-- 00                                    UART status
-- 01   baud rate low byte               UART input data
-- 02   baud rate high byte              Read clock frequency constant
-- 03   program address low byte         Program data low
-- 04   program address high byte        Program data mid
-- 05   program data bits 5:0            Program data high
-- 06   program data bits 11:6           Test counter
-- 07   program data bits 17:12 [1]      perform ebus read [3]

-- 08   ebus address byte 0              ebus address
-- 09   ebus address byte 1              ebus address
-- 0A   ebus address byte 2              ebus address
-- 0B   ebus address byte 3              ebus address

-- 0C   ebus data byte 0                 ebus data
-- 0D   ebus data byte 0                 ebus data
-- 0E   ebus data byte 0                 ebus data
-- 0F   ebus data byte 0 [2]             ebus data
--
-- 10   trigger warm reset [3]           program memory size 7:0
-- 11                                    program memory size 11:8
--
-- 80   UART output data

-- [1] Address 07 triggers write to program memory when written
-- ebus RD strobe generated
-- [2] Address 0F triggers write to ebus when written
-- [3] Data is n/a.  

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ebus_types.all;

entity pico_ebus is

  port (
    clk        : in  std_logic;         -- logic clock for all
    reset      : in  std_logic;         -- active high asynchronous reset
    RX         : in  std_logic;         -- asynch serial input
    TX         : out std_logic;         -- asynch serial output
    warm_reset : out std_logic;         -- programmable reset
    ebus_out   : out ebus_out_t;        -- control bus output
    ebus_in    : in  ebus_in_t          -- control bus input
    );

end entity pico_ebus;

architecture arch of pico_ebus is

  component kcpsm6
    generic(hwbuild                 : std_logic_vector(7 downto 0)  := X"00";
            interrupt_vector        : std_logic_vector(11 downto 0) := X"3FF";
            scratch_pad_memory_size : integer                       := 64);
    port (address        : out std_logic_vector(11 downto 0);
          instruction    : in  std_logic_vector(17 downto 0);
          bram_enable    : out std_logic;
          in_port        : in  std_logic_vector(7 downto 0);
          out_port       : out std_logic_vector(7 downto 0);
          port_id        : out std_logic_vector(7 downto 0);
          write_strobe   : out std_logic;
          k_write_strobe : out std_logic;
          read_strobe    : out std_logic;
          interrupt      : in  std_logic;
          interrupt_ack  : out std_logic;
          sleep          : in  std_logic;
          reset          : in  std_logic;
          clk            : in  std_logic);
  end component;

--
-- Program memory (read/write, inferred)
--

  component monitor is
    port (
      address     : in  std_logic_vector(11 downto 0);
      instruction : out std_logic_vector(17 downto 0);
      addr_2      : in  std_logic_vector(11 downto 0);
      wen         : in  std_logic;
      di          : in  std_logic_vector(17 downto 0);
      do          : out std_logic_vector(17 downto 0);
      msize       : out std_logic_vector(11 downto 0);
      clk         : in  std_logic);
  end component monitor;

--
-- UART Transmitter with integral 16 byte FIFO buffer
--

  component uart_tx6
    port (data_in             : in  std_logic_vector(7 downto 0);
          en_16_x_baud        : in  std_logic;
          serial_out          : out std_logic;
          buffer_write        : in  std_logic;
          buffer_data_present : out std_logic;
          buffer_half_full    : out std_logic;
          buffer_full         : out std_logic;
          buffer_reset        : in  std_logic;
          clk                 : in  std_logic);
  end component;

--
-- UART Receiver with integral 16 byte FIFO buffer
--

  component uart_rx6
    port (serial_in           : in  std_logic;
          en_16_x_baud        : in  std_logic;
          data_out            : out std_logic_vector(7 downto 0);
          buffer_read         : in  std_logic;
          buffer_data_present : out std_logic;
          buffer_half_full    : out std_logic;
          buffer_full         : out std_logic;
          buffer_reset        : in  std_logic;
          clk                 : in  std_logic);
  end component;

--
--
-------------------------------------------------------------------------------------------
--
-- Signals
--
-------------------------------------------------------------------------------------------
--
--

-- Constant to specify the clock frequency in megahertz.
-- (not currently used but can be read by software)
  constant clock_frequency_in_MHz : integer range 0 to 255        := 100;
--
--
-- Signals used to connect KCPSM6
--
  signal address                  : std_logic_vector(11 downto 0);
  signal instruction              : std_logic_vector(17 downto 0);
  signal bram_enable              : std_logic;
  signal in_port                  : std_logic_vector(7 downto 0);
  signal out_port                 : std_logic_vector(7 downto 0);
  signal port_id                  : std_logic_vector(7 downto 0);
  signal write_strobe             : std_logic;
  signal k_write_strobe           : std_logic;
  signal read_strobe              : std_logic;
  signal interrupt                : std_logic;
  signal interrupt_ack            : std_logic;
-- signal                  rdl : std_logic;
--
-- Signals used to connect UART_TX6
--
  signal uart_tx_data_in          : std_logic_vector(7 downto 0);
  signal write_to_uart_tx         : std_logic;
  signal pipe_port_id7            : std_logic                     := '0';
  signal uart_tx_data_present     : std_logic;
  signal uart_tx_half_full        : std_logic;
  signal uart_tx_full             : std_logic;
  signal uart_tx_reset            : std_logic;
--
-- Signals used to connect UART_RX6
--
  signal uart_rx_data_out         : std_logic_vector(7 downto 0);
  signal read_from_uart_rx        : std_logic                     := '0';
  signal uart_rx_data_present     : std_logic;
  signal uart_rx_half_full        : std_logic;
  signal uart_rx_full             : std_logic;
  signal uart_rx_reset            : std_logic;
--
-- Signals used to define baud rate
--
  signal set_baud_rate            : std_logic_vector(15 downto 0) := X"0000";
  signal baud_rate_counter        : std_logic_vector(15 downto 0) := X"0000";
  signal en_16_x_baud             : std_logic                     := '0';

--
-- signals for access to program ROM
--
  signal peek_addr : std_logic_vector(11 downto 0);
  signal peek_data : std_logic_vector(17 downto 0);
  signal poke_data : std_logic_vector(17 downto 0);

  signal pmem_size : std_logic_vector(11 downto 0);

  signal poke_ena : std_logic;

  signal test_counter : std_logic_vector(31 downto 0);

--
-- ebus signals
--  
  signal s_addr : std_logic_vector(31 downto 0);  -- bus address latch
  signal s_din  : std_logic_vector(31 downto 0);  -- bus data in
  signal s_dout : std_logic_vector(31 downto 0);  -- bus data out
  signal s_wr   : std_logic;
  signal s_rd   : std_logic;
--
--
-------------------------------------------------------------------------------------------
--
-- Start of circuit description
--
-------------------------------------------------------------------------------------------
--
begin

  ebus_out.addr <= unsigned(s_addr);    -- always drive the address
  ebus_out.data <= s_dout;              -- and data to the bus
  ebus_out.wr   <= s_wr;
  ebus_out.rd   <= s_rd;

  -- test counter for port action
  -- can also be used for delays.
  process(clk)
  begin
    if(rising_edge(clk)) then
      test_counter <= std_logic_vector(unsigned(test_counter) + 1);
    end if;
  end process;

  --
  -----------------------------------------------------------------------------------------
  -- Instantiate KCPSM6 and connect to program ROM
  -----------------------------------------------------------------------------------------
  --
  -- The generics can be defined as required. In this case the 'hwbuild' value is used to 
  -- define a version using the ASCII code for the desired letter. 
  --

  processor : kcpsm6
    generic map (hwbuild                 => X"42",  -- 41 hex is ASCII Character "A"
                 interrupt_vector        => X"7FF",
                 scratch_pad_memory_size => 256)
    port map(address        => address,
             instruction    => instruction,
             bram_enable    => open,
             port_id        => port_id,
             write_strobe   => write_strobe,
             k_write_strobe => k_write_strobe,
             out_port       => out_port,
             read_strobe    => read_strobe,
             in_port        => in_port,
             interrupt      => interrupt,
             interrupt_ack  => interrupt_ack,
             sleep          => '0',
             reset          => '0',
             clk            => clk);

  --
  -- Development Program Memory 
  -- read/write, inferred (not the Xilinx standard!)
  --
  program_rom : monitor
    port map(address     => address,
             instruction => instruction,
             addr_2      => peek_addr,
             di          => poke_data,
             do          => peek_data,
             wen         => poke_ena,
             msize       => pmem_size,
             clk         => clk);


  --
  -----------------------------------------------------------------------------------------
  -- UART Transmitter with integral 16 byte FIFO buffer
  -----------------------------------------------------------------------------------------
  --
  -- Write to buffer in UART Transmitter at port address 01 hex
  -- 

  txi : uart_tx6
    port map (data_in             => uart_tx_data_in,
              en_16_x_baud        => en_16_x_baud,
              serial_out          => TX,
              buffer_write        => write_to_uart_tx,
              buffer_data_present => uart_tx_data_present,
              buffer_half_full    => uart_tx_half_full,
              buffer_full         => uart_tx_full,
              buffer_reset        => uart_tx_reset,
              clk                 => clk);


  --
  -----------------------------------------------------------------------------------------
  -- UART Receiver with integral 16 byte FIFO buffer
  -----------------------------------------------------------------------------------------
  --
  -- Read from buffer in UART Receiver at port address 01 hex.
  --
  -- When KCPMS6 reads data from the receiver a pulse must be generated so that the 
  -- FIFO buffer presents the next character to be read and updates the buffer flags.
  -- 

  rxi : uart_rx6
    port map (serial_in           => RX,
              en_16_x_baud        => en_16_x_baud,
              data_out            => uart_rx_data_out,
              buffer_read         => read_from_uart_rx,
              buffer_data_present => uart_rx_data_present,
              buffer_half_full    => uart_rx_half_full,
              buffer_full         => uart_rx_full,
              buffer_reset        => uart_rx_reset,
              clk                 => clk);

  --
  -----------------------------------------------------------------------------------------
  -- UART baud rate 
  -----------------------------------------------------------------------------------------
  --
  -- The baud rate is defined by the frequency of 'en_16_x_baud' pulses. These should occur  
  -- at 16 times the desired baud rate. KCPSM6 computes and sets an 8-bit value into 
  -- 'set_baud_rate' which is used to divide the clock frequency appropriately.
  -- 
  -- For example, if the clock frequency is 200MHz and the desired serial communication 
  -- baud rate is 115200 then PicoBlaze will set 'set_baud_rate' to 6C hex (108 decimal). 
  -- This circuit will then generate an 'en_16_x_baud' pulse once every 109 clock cycles 
  -- (note that 'baud_rate_counter' will include state zero). This would actually result 
  -- in a baud rate of 114,679 baud but that is only 0.45% low and well within limits.
  --

  baud_rate : process(clk)
  begin
    if clk'event and clk = '1' then
      if baud_rate_counter = set_baud_rate then
        baud_rate_counter <= (others => '0');
        en_16_x_baud      <= '1';       -- single cycle enable pulse
      else
        baud_rate_counter <= std_logic_vector(unsigned(baud_rate_counter) + 1);
        en_16_x_baud      <= '0';
      end if;
    end if;
  end process baud_rate;


  --
  -----------------------------------------------------------------------------------------
  -- General Purpose Input Ports. 
  -----------------------------------------------------------------------------------------
  --
  -- Three input ports are used with the UART macros. 
  -- 
  --   The first is used to monitor the flags on both the transmitter and receiver.
  --   The second is used to read the data from the receiver and generate a 'buffer_read' 
  --     pulse. 
  --   The third is used to read a user defined constant that enabled KCPSM6 to know the 
  --     clock frequency so that it can compute values which will define the BAUD rate 
  --     for UART communications (as well as values used to define software delays).
  --

  input_ports : process(clk)
  begin
    if clk'event and clk = '1' then

      s_rd <= '0';

      if s_rd = '1' then
        s_din <= ebus_in.data;
      end if;

      case "000" & port_id(4 downto 0) is

        -- Read UART status at port address 00 hex
        when X"00" => in_port(0) <= uart_tx_data_present;
                      in_port(1) <= uart_tx_half_full;
                      in_port(2) <= uart_tx_full;
                      in_port(3) <= uart_rx_data_present;
                      in_port(4) <= uart_rx_half_full;
                      in_port(5) <= uart_rx_full;

        -- Read UART_RX6 data at port address 01 hex
        -- (see 'buffer_read' pulse generation below) 
        when X"01" => in_port <= uart_rx_data_out;

        -- Read clock frequency contant at port address 02 hex
        when X"02" => in_port <= std_logic_vector(to_unsigned(clock_frequency_in_MHz, 8));

        -- read peek data at addresses 03, 04, 05
        when X"03" => in_port <= peek_data(7 downto 0);
        when X"04" => in_port <= peek_data(15 downto 8);
        when X"05" => in_port <= "000000" & peek_data(17 downto 16);

        -- test counter at 06
        when X"06" => in_port <= test_counter(31 downto 24);

        -- capture ebus data at 07 (side-effect only)                     
        when X"07" => s_rd <= '1';

        -- read/write the ebus address latch
        when X"08" => in_port <= s_addr(7 downto 0);
        when X"09" => in_port <= s_addr(15 downto 8);
        when X"0A" => in_port <= s_addr(23 downto 16);
        when X"0B" => in_port <= s_addr(31 downto 24);

        -- read the ebus data
        when X"0C" => in_port <= s_din(7 downto 0);
        when X"0D" => in_port <= s_din(15 downto 8);
        when X"0E" => in_port <= s_din(23 downto 16);
        when X"0F" => in_port <= s_din(31 downto 24);

        -- read memory size
        when X"10" => in_port <= pmem_size(7 downto 0);
        when X"11" => in_port <= "0000" & pmem_size(11 downto 8);

        -- Specify don't care for all other inputs to obtain optimum implementation
        when others => in_port <= "XXXXXXXX";

      end case;

      -- Generate 'buffer_read' pulse following read from port address 01

      if (read_strobe = '1') and (port_id(4 downto 0) = "00001") then
        read_from_uart_rx <= '1';
      else
        read_from_uart_rx <= '0';
      end if;

    end if;

  end process input_ports;


  --
  -----------------------------------------------------------------------------------------
  -- General Purpose Output Ports 
  -----------------------------------------------------------------------------------------
  --
  -- In this design there are two general purpose output ports. 
  --
  --   A port used to write data directly to the FIFO buffer within 'uart_tx6' macro.
  -- 
  --   A port used to define the communication BAUD rate of the UART.
  --
  -- Note that the assignment and decoding of 'port_id' is a one-hot resulting 
  -- in the minimum number of signals actually being decoded for a fast and 
  -- optimum implementation.  
  --

  output_ports : process(clk)
  begin
    if clk'event and clk = '1' then

      s_wr     <= '0';
      poke_ena <= '0';
      warm_reset <= '0';

      -- 'write_strobe' is used to qualify all writes to general output ports
      -- along with bit 7 of the address which selects (only) the UART output
      if write_strobe = '1' and port_id(7) = '0' then

        -- Write to UART at port addresses 01 hex
        -- See below this clocked process for the combinatorial decode required.

        -- Write to 'set_baud_rate' at port addresses 02 hex     
        -- This value is set by KCPSM6 to define the BAUD rate of the UART. 
        -- See the 'UART baud rate' section for details.

        case "000" & port_id(4 downto 0) is

          when x"01" => set_baud_rate(7 downto 0)  <= out_port;
          when x"02" => set_baud_rate(15 downto 8) <= out_port;
          when x"03" => peek_addr(7 downto 0)      <= out_port;
          when x"04" => peek_addr(11 downto 8)     <= out_port(3 downto 0);
          when x"05" => poke_data(7 downto 0)      <= out_port(7 downto 0);
          when x"06" => poke_data(15 downto 8)     <= out_port(7 downto 0);
          when x"07" => poke_data(17 downto 16)    <= out_port(1 downto 0);
                        poke_ena <= '1';

          when x"08" => s_addr(7 downto 0)   <= out_port;
          when x"09" => s_addr(15 downto 8)  <= out_port;
          when x"0A" => s_addr(23 downto 16) <= out_port;
          when x"0B" => s_addr(31 downto 24) <= out_port;

          when x"0C" => s_dout(7 downto 0)   <= out_port;
          when x"0D" => s_dout(15 downto 8)  <= out_port;
          when x"0E" => s_dout(23 downto 16) <= out_port;
          when x"0F" => s_dout(31 downto 24) <= out_port;
                        s_wr <= '1';

          when x"10" => warm_reset <= '1';

          when others => null;
        end case;

      end if;

      --
      -- *** To reliably achieve 200MHz performance when writing to the FIFO buffer
      --     within the UART transmitter, 'port_id' is pipelined to exploit both of  
      --     the clock cycles that it is valid.
      --

      pipe_port_id7 <= port_id(7);

    end if;
  end process output_ports;

  --
  -- Write directly to the FIFO buffer within 'uart_tx6' macro at port address 01 hex.
  -- Note the direct connection of 'out_port' to the UART transmitter macro and the 
  -- way that a single clock cycle write pulse is generated to capture the data.
  -- 

  uart_tx_data_in <= out_port;

  -- See *** above for definition of 'pipe_port_id7'. 

  write_to_uart_tx <= '1' when (write_strobe = '1') and (pipe_port_id7 = '1')
                      else '0';

  --
  -----------------------------------------------------------------------------------------
  -- Constant-Optimised Output Ports 
  -----------------------------------------------------------------------------------------
  --
  -- One constant-optimised output port is used to facilitate resetting of the UART macros.
  --

  constant_output_ports : process(clk)
  begin
    if clk'event and clk = '1' then
      if k_write_strobe = '1' then

        if port_id(0) = '1' then
          uart_tx_reset <= out_port(0);
          uart_rx_reset <= out_port(1);
        end if;

      end if;
    end if;
  end process constant_output_ports;

  --
  -----------------------------------------------------------------------------------------
  --

end arch;

