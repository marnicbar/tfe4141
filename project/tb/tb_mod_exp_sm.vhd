library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.mod_exp_pkg.all; -- bring in the enum type
use work.helpers_pkg.all; -- bring in the pulse_1ns procedure

entity tb_mod_exp_sm is
end entity;

architecture sim of tb_mod_exp_sm is
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
        log(ID_LOG_HDR, "Starting test bench for state machine of modular exponentiation...");

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
        check_value(LS_enable, '0', ERROR, "LS_enable after reset must be '0'");
        check_value(msgout_last, '0', ERROR, "msgout_last after reset must be '0'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment after reset must be '0'");
        check_value(pc_select, '0', ERROR, "pc_select after reset must be '0'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable after reset must be '0'");
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
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'initialize'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'initialize'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'initialize'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'initialize'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'initialize'");
        check_value(Blak_reset_n, '0', ERROR, "Blak_reset_n must be '1' in state 'initialize'");

        -- Test transition to read_e_bit state
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(read_e_bit), ERROR, "State must be 'read_e_bit'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'read_e_bit'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'read_e_bit'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'read_e_bit'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'read_e_bit'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'read_e_bit'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'read_e_bit'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'read_e_bit'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'read_e_bit'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'read_e_bit'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'read_e_bit'");

        -- Test transition to calc_C state
        e_bit <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(calc_C), ERROR, "State must be 'calc_C'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'calc_C'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'calc_C'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'calc_C'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'calc_C'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'calc_C'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'calc_C'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'calc_C'");
        check_value(pc_select, '1', ERROR, "pc_select must be '1' in state 'calc_C'");
        check_value(Blak_enable, '1', ERROR, "Blak_enable must be '1' in state 'calc_C'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'calc_C'");

        -- Test no transition if Blak_finished = '0'
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(calc_C), ERROR, "State must be 'calc_C'");

        -- Test transition to reset_blak_module state
        Blak_finished <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(reset_blak_module), ERROR, "State must be 'reset_blak_module'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'reset_blak_module'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'reset_blak_module'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'reset_blak_module'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'reset_blak_module'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'reset_blak_module'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'reset_blak_module'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'reset_blak_module'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'reset_blak_module'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'reset_blak_module'");
        check_value(Blak_reset_n, '0', ERROR, "Blak_reset_n must be '0' in state 'reset_blak_module'");

        -- Test transition to calc_P state
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(calc_P), ERROR, "State must be 'calc_P'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'calc_P'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'calc_P'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'calc_P'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'calc_P'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'calc_P'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'calc_P'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'calc_P'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'calc_P'");
        check_value(Blak_enable, '1', ERROR, "Blak_enable must be '1' in state 'calc_P'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'calc_P'");

        -- Test no transition if Blak_finished = '0'
        Blak_finished <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(calc_P), ERROR, "State must be 'calc_P'");

        -- Test transition to increment_e state
        Blak_finished <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(increment_e), ERROR, "State must be 'increment_e'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'increment_e'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'increment_e'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'increment_e'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'increment_e'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'increment_e'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'increment_e'");
        check_value(e_counter_increment, '1', ERROR, "e_counter_increment must be '1' in state 'increment_e'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'increment_e'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'increment_e'");
        check_value(Blak_reset_n, '0', ERROR, "Blak_reset_n must be '0' in state 'increment_e'");

        -- Test transition to is_e_processed state
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_e_processed), ERROR, "State must be 'is_e_processed'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'is_e_processed'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'is_e_processed'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'is_e_processed'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'is_e_processed'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'is_e_processed'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'is_e_processed'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'is_e_processed'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'is_e_processed'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'is_e_processed'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'is_e_processed'");

        -- Test transition to Leftshift_e state
        e_counter_end <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(Leftshift_e), ERROR, "State must be 'Leftshift_e'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'Leftshift_e'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'Leftshift_e'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'Leftshift_e'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'Leftshift_e'");
        check_value(LS_enable, '1', ERROR, "LS_enable must be '1' in state 'Leftshift_e'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'Leftshift_e'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'Leftshift_e'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'Leftshift_e'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'Leftshift_e'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'Leftshift_e'");

        -- Test transition to read_e_bit state
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(read_e_bit), ERROR, "State must be 'read_e_bit'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'read_e_bit'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'read_e_bit'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'read_e_bit'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'read_e_bit'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'read_e_bit'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'read_e_bit'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'read_e_bit'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'read_e_bit'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'read_e_bit'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'read_e_bit'");

        -- Test transition to calc_P state
        e_bit <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(calc_P), ERROR, "State must be 'calc_P'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'calc_P'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'calc_P'");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' in state 'calc_P'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'calc_P'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'calc_P'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'calc_P'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' in state 'calc_P'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'calc_P'");
        check_value(Blak_enable, '1', ERROR, "Blak_enable must be '1' in state 'calc_P'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'calc_P'");

        -- Prepare state for transition to is_out_ready state
        Blak_finished <= '1';
        pulse_1ns(clk);
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_e_processed), ERROR, "State must be 'is_e_processed'");

        -- Transition to is_out_ready state
        e_counter_end <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_out_ready), ERROR, "State must be 'is_out_ready'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'is_out_ready'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'is_out_ready'");
        check_value(valid_out, '1', ERROR, "valid_out must be '1' in state 'is_out_ready'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'is_out_ready'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'is_out_ready'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'is_out_ready'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'is_out_ready'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'is_out_ready'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'is_out_ready'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'is_out_ready'");

        -- Test no transition if ready_out = '0'
        ready_out <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_out_ready), ERROR, "State must be 'is_out_ready'");

        -- Test transition to is_in_valid state
        ready_out   <= '1';
        is_last_msg <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_in_valid), ERROR, "State must be 'is_in_valid'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'is_in_valid'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'is_in_valid'");
        check_value(valid_out, '0', ERROR, "valid_out must be '1' in state 'is_in_valid'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'is_in_valid'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'is_in_valid'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'is_in_valid'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'is_in_valid'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'is_in_valid'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'is_in_valid'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'is_in_valid'");

        -- Prepare state for transition to set_msgout_last state
        valid_in <= '1';
        pulse_1ns(clk);
        pulse_1ns(clk);
        e_bit <= '0';
        pulse_1ns(clk);
        Blak_finished <= '1';
        pulse_1ns(clk);
        pulse_1ns(clk);
        e_counter_end <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_out_ready), ERROR, "State must be 'is_out_ready'");

        -- Test transition to set_msgout_last state
        ready_out   <= '1';
        is_last_msg <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(set_msgout_last), ERROR, "State must be 'set_msgout_last'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'set_msgout_last'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'set_msgout_last'");
        check_value(valid_out, '0', ERROR, "valid_out must be '1' in state 'set_msgout_last'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'set_msgout_last'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'set_msgout_last'");
        check_value(msgout_last, '1', ERROR, "msgout_last must be '0' in state 'set_msgout_last'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'set_msgout_last'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'set_msgout_last'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'set_msgout_last'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'set_msgout_last'");

        -- Prepare state for reset test
        pulse_1ns(clk);
        valid_in <= '1';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(initialize), ERROR, "State must be 'initialize'");

        -- Test reset from other state than is_in_valid
        pulse_1ns(clk);
        reset_n <= '0';
        pulse_1ns(clk);
        check_value(state_type'pos(dbg_state), state_type'pos(is_in_valid), ERROR, "State must be 'is_in_valid'");
        check_value(initialize_regs, '0', ERROR, "initialize_regs must be '0' in state 'is_in_valid'");
        check_value(ready_in, '0', ERROR, "ready_in must be '0' in state 'is_in_valid'");
        check_value(valid_out, '0', ERROR, "valid_out must be '1' in state 'is_in_valid'");
        check_value(is_last_msg_enable, '0', ERROR, "is_last_msg_enable must be '0' in state 'is_in_valid'");
        check_value(LS_enable, '0', ERROR, "LS_enable must be '0' in state 'is_in_valid'");
        check_value(msgout_last, '0', ERROR, "msgout_last must be '0' in state 'is_in_valid'");
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '1' in state 'is_in_valid'");
        check_value(pc_select, '0', ERROR, "pc_select must be '0' in state 'is_in_valid'");
        check_value(Blak_enable, '0', ERROR, "Blak_enable must be '0' in state 'is_in_valid'");
        check_value(Blak_reset_n, '1', ERROR, "Blak_reset_n must be '1' in state 'is_in_valid'");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
