library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.blakely_pkg.all;

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
    signal dbg_state     : state_type;
begin
    dut : entity work.blakely
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
            finished_calc => finished_calc,
            dbg_state     => dbg_state
        );
    p_seq : process

    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting UVVM blakley demo");

        -- Test reset state
        reset_n <= '0';
        wait for 1 ns;
        check_value(state_type'pos(dbg_state), state_type'pos(read_inputs), ERROR, "State after reset must be 'read_inputs'");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
