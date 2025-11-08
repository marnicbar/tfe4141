library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.mod_exp_pkg.all; -- bring in the enum type

entity tb_mod_exp is
end entity;

architecture sim of tb_mod_exp is
    --misc
    signal clk     : std_logic;
    signal reset_n : std_logic;

    --external controll signals in/out of the RSA-core----------------------------
    --input controll
    signal valid_in   : std_logic; --aka: msgin_valid
    signal ready_in   : std_logic; --aka: msgin_ready
    signal msgin_last : std_logic;
    --ouput controll
    signal ready_out    : std_logic; --aka: msgout_ready
    signal valid_out    : std_logic; --aka: msgout_valid
    signal msgout_last  : std_logic;
    signal Blak_reset_n : std_logic; --blakley module reset sign. must be reset after each computation. 

    --controll signals inside the RSA-core
    signal e_bit               : std_logic; --the LSB of register LSR_e
    signal LS_enable           : std_logic; --signal which left shift key_e
    signal e_counter_end       : std_logic; --tells the FSM when counter >= 255
    signal e_counter_increment : std_logic; --tells the FSM when counter >= 255
    signal initialize_regs     : std_logic; --loads initial values into C, P, LSR_e and e_counter
    signal Blak_enable         : std_logic; --signal that tells Blakley module to start computation.
    signal Blak_finished       : std_logic; --signal that Blakley module is finished.
    signal is_last_msg_enable  : std_logic;
    signal is_last_msg         : std_logic;
    signal pc_select           : std_logic; -- Signal for which of P or C that are using the blakley module:

    signal dbg_state : state_type;
    --
    -- Helper procedure: generate a single pulse of 1 ns high then 1 ns low
    -- Usage: call pulse_1ns(clk) to simulate one clock cycle of 2 ns period
    procedure pulse_1ns(signal sig : out std_logic) is
    begin
        wait for 1 ns;
        sig <= '1';
        wait for 1 ns;
        sig <= '0';
    end procedure pulse_1ns;

begin
    dut : entity work.controller
        port map(
            clk                 => clk,
            reset_n             => reset_n,
            valid_in            => valid_in,
            ready_in            => ready_in,
            msgin_last          => msgin_last,
            ready_out           => ready_out,
            valid_out           => valid_out,
            msgout_last         => msgout_last,
            Blak_reset_n        => Blak_reset_n,
            e_bit               => e_bit,
            LS_enable           => LS_enable,
            e_counter_end       => e_counter_end,
            e_counter_increment => e_counter_increment,
            initialize_regs     => initialize_regs,
            Blak_enable         => Blak_enable,
            Blak_finished       => Blak_finished,
            is_last_msg_enable  => is_last_msg_enable,
            is_last_msg         => is_last_msg,
            pc_select           => pc_select,
            -- Testing
            dbg_state => dbg_state
        );
    p_seq : process

    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting modular exponentiation test bench");

        -- Init state
        reset_n       <= '0';
        clk           <= '0';
        valid_in      <= '0';
        msgin_last    <= '0';
        ready_out     <= '0';
        e_bit         <= '0';
        e_counter_end <= '0';
        Blak_finished <= '0';
        is_last_msg   <= '0';
        wait for 1 ns;

        -- Test reset state
        check_value(state_type'pos(dbg_state), state_type'pos(is_in_valid), ERROR, "State after reset must be 'is_in_valid'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs after reset must be '0'");
        check_value(ready_in, '0', ERROR, "ready_in after reset must be '0'");
        check_value(valid_out, '0', ERROR, "valid_out after reset must be '0'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable after reset must be'0'");
        check_value(msgout_last, '0', ERROR, "msgout_last after reset must be '0'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment after reset must be '0'");
        check_value(pc_select, '0', ERROR, "pc_select after reset must be '0'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n after reset must be '1'");

        -- Test transition to is_in_valid state
        reset_n  <= '1';
        valid_in <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(initialize), ERROR, "State after valid_in='1' must be 'initialize'");
        check_value(initialize_regs, '1', ERROR, "initialize_regs must be '1' in state 'initialize'");
        check_value(ready_in, '1', ERROR, "ready_in must be '1' in state 'initialize'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'initialize'");
        check_value(is_last_msg_enable, '1', ERROR, "is_last_msg_enable must be '1' in state 'initialize'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'initialize'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'initialize'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'initialize'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'initialize'");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
