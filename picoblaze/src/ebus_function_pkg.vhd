library IEEE;
use IEEE.Std_logic_1164.all;
use ieee.numeric_std.all;

package ebus_function_pkg is

  function lowest_set_bit (v : std_logic_vector) return natural;
  function hex_match(s       : string) return std_logic_vector;

  function std_match(v      : std_logic_vector; s : string) return boolean;
  function std_match(s      : string; v : std_logic_vector) return boolean;
  function std_match(s1, s2 : string) return boolean;

  function to_HexChar(Value : natural) return character;

  function to_HexString( Value: natural) return string;

end package ebus_function_pkg;


package body ebus_function_pkg is


  function to_HexString( Value: natural) return string is
    variable str : string(1 to 1);
  begin
    str(1) := to_HexChar( Value);
    return str;
  end function;
  


  function to_HexChar(Value : natural) return character is
    constant HEX : string := "0123456789ABCDEF";
  begin
    if Value < 16 then
      return HEX(Value+1);
    else
      return 'X';
    end if;
  end function;


  -- find the lowest-numbered bit set to '1' in a vector
  function lowest_set_bit (v : std_logic_vector) return natural is
    variable n : natural := 0;
  begin

    for i in v'range loop
      if v(i) = '1' then
        n := i;
      end if;
    end loop;

    return n;
  end function lowest_set_bit;


  --  a hex string with "don't care" digits as 'X' or '-'

  function hex_match(s : string) return std_logic_vector is
    variable v : std_logic_vector((s'length*4)-1 downto 0);
    variable p : integer;
  begin
    p := (s'length*4)-1;
    for i in s'range loop

      if s(i) = 'X' then v(p downto p-3)    := "----";
      elsif s(i) = 'x' then v(p downto p-3) := "----";
      elsif s(i) = '-' then v(p downto p-3) := "----";
      elsif s(i) = '0' then v(p downto p-3) := "0000";
      elsif s(i) = '1' then v(p downto p-3) := "0001";
      elsif s(i) = '2' then v(p downto p-3) := "0010";
      elsif s(i) = '3' then v(p downto p-3) := "0011";
      elsif s(i) = '4' then v(p downto p-3) := "0100";
      elsif s(i) = '5' then v(p downto p-3) := "0101";
      elsif s(i) = '6' then v(p downto p-3) := "0110";
      elsif s(i) = '7' then v(p downto p-3) := "0111";
      elsif s(i) = '8' then v(p downto p-3) := "1000";
      elsif s(i) = '9' then v(p downto p-3) := "1001";
      elsif s(i) = 'A' then v(p downto p-3) := "1010";
      elsif s(i) = 'B' then v(p downto p-3) := "1011";
      elsif s(i) = 'C' then v(p downto p-3) := "1100";
      elsif s(i) = 'D' then v(p downto p-3) := "1101";
      elsif s(i) = 'E' then v(p downto p-3) := "1110";
      elsif s(i) = 'F' then v(p downto p-3) := "1111";
      elsif s(i) = 'a' then v(p downto p-3) := "1010";
      elsif s(i) = 'b' then v(p downto p-3) := "1011";
      elsif s(i) = 'c' then v(p downto p-3) := "1100";
      elsif s(i) = 'd' then v(p downto p-3) := "1101";
      elsif s(i) = 'e' then v(p downto p-3) := "1110";
      elsif s(i) = 'f' then v(p downto p-3) := "1111";
      else
        v(p downto p-3) := "----";
      end if;

      p := p - 4;

    end loop;

    return v;
  end function hex_match;

  function std_match(v : std_logic_vector; s : string) return boolean is
  begin
    return std_match(v, hex_match(s));
  end function std_match;


  function std_match(s : string; v : std_logic_vector) return boolean is
  begin
    return std_match(v, hex_match(s));
  end function std_match;


  function std_match(s1, s2 : string) return boolean is
  begin
    return std_match(hex_match(s1), hex_match(s2));
  end function std_match;




end package body ebus_function_pkg;
