library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley is
end entity;

architecture sim of tb_blakley is
    constant bit_width : positive := 256;
    -- DUT inputs
    signal A         : std_logic_vector(bit_width - 1 downto 0);
    signal B         : std_logic_vector(bit_width - 1 downto 0);
    signal N         : std_logic_vector(bit_width - 1 downto 0);
    signal clk       : std_logic;
    signal reset_n   : std_logic;
    signal bn_enable : std_logic;

    -- DUT outputs
    signal output        : std_logic_vector(bit_width - 1 downto 0);
    signal finished_calc : std_logic;
begin
    dut: entity work.blakely
        generic map(
            bit_width => bit_width
        )
        port map(
            A             => A,
            B             => B,
            N             => N,
            clk           => clk,
            reset_n       => reset_n,
            bn_enable     => bn_enable,
            Output        => output,
            finished_calc => finished_calc
        );
end architecture;
