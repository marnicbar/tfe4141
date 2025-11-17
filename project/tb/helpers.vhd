library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package helpers_pkg is
    procedure pulse_1ns(signal sig : out std_logic);
    procedure wait_clocks_until(
        signal clk  : out std_logic;
        signal cond : in  std_logic
    );
end package helpers_pkg;

-- Helper procedure: generate a single pulse of 1 ns low then 1 ns high
-- Usage: call pulse_1ns(clk) to simulate one clock cycle of 2 ns period
package body helpers_pkg is
    procedure pulse_1ns(signal sig : out std_logic) is
    begin
        wait for 1 ns;
        sig <= '1';
        wait for 1 ns;
        sig <= '0';
    end procedure pulse_1ns;

    procedure wait_clocks_until(
        signal clk  : out std_logic;
        signal cond : in  std_logic
    ) is
    begin
        while cond /= '1' loop
            pulse_1ns(clk);
        end loop;
    end procedure;
end package body helpers_pkg;
