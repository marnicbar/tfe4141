-- Minimal DUT: parameterizable adder
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
  generic (
    G_WIDTH : positive := 8
  );
  port (
    a    : in std_logic_vector(G_WIDTH - 1 downto 0);
    b    : in std_logic_vector(G_WIDTH - 1 downto 0);
    cin  : in std_logic := '0';
    sum  : out std_logic_vector(G_WIDTH - 1 downto 0);
    cout : out std_logic
  );
end entity;

architecture rtl of adder is
begin
  process (a, b, cin)
    variable tmp : unsigned(G_WIDTH downto 0);
  begin
    -- Extend operands with leading zero to capture carry
    tmp := ('0' & unsigned(a)) + ('0' & unsigned(b));
    if cin = '1' then
      tmp := tmp + 1;
    end if;
    sum  <= std_logic_vector(tmp(G_WIDTH - 1 downto 0));
    cout <= std_logic(tmp(G_WIDTH));
  end process;
end architecture;
