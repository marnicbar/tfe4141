library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.mod_exp_pkg.all; -- bring in the enum type
use work.helpers_pkg.all; -- bring in the pulse_1ns procedure

entity tb_mod_exp_combinatorial is
end entity;

architecture sim of tb_mod_exp_combinatorial is
    constant C_block_size     : integer := 256;
    constant counter_bit_size : integer := 8;

    --------------------------------------------------------
    -- Interface from general module to outside of RSA-core:
    --------------------------------------------------------
    -- Input data
    signal message : std_logic_vector(C_block_size - 1 downto 0); --aka: M
    signal key     : std_logic_vector(C_block_size - 1 downto 0); --aka: key_e
    signal modulus : std_logic_vector(C_block_size - 1 downto 0); --aka: key_n

    -- Output data
    signal result : std_logic_vector(C_block_size - 1 downto 0); --aka: msgout_data

    -- Input control signals
    signal valid_in   : std_logic; --aka: msgin_valid
    signal msgin_last : std_logic;
    signal ready_out  : std_logic; --aka: msgout_ready
    signal clk        : std_logic;
    signal reset_n    : std_logic;

    -- Output control signals
    signal ready_in    : std_logic; --aka: msgin_ready
    signal valid_out   : std_logic; --aka: msgout_valid
    signal msgout_last : std_logic;

    ---------------------------------------------------
    -- Interface from general module to Blakley module:
    ---------------------------------------------------
    -- Input data
    signal Blak_C : std_logic_vector(C_block_size - 1 downto 0);

    -- Output data
    signal Blak_A : std_logic_vector(C_block_size - 1 downto 0); -- Input A of blak module
    signal Blak_B : std_logic_vector(C_block_size - 1 downto 0); -- Input B of blak module
    signal Blak_n : std_logic_vector(C_block_size - 1 downto 0); -- Input key_n (modulus) for blak module.

    -- Input control signals
    signal Blak_finished : std_logic; --signal that Blakley module is finished.

    -- Output control signals
    signal Blak_enable  : std_logic; --signal that tells Blakley module to start computation.
    signal Blak_clk     : std_logic; --clock for blakley module
    signal Blak_reset_n : std_logic; --reset for blakley module. Normally high.

    ---------------------------------------------------
    -- Internal signals for debugging/testing purposes:
    ---------------------------------------------------
    signal RSR_e               : std_logic_vector(C_block_size - 1 downto 0); --Right shift register for key_e
    signal P_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value P
    signal C_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value C
    signal pc_select           : std_logic; -- Signal to select which of P or C that are "using" the blakley module.
    signal e_bit_counter       : std_logic_vector(counter_bit_size - 1 downto 0); --8 bit signal for a counter which the state machine uses to iterate over 256 bits of key_e.
    signal e_counter_increment : std_logic; --tells e_counter to += 1.
    signal e_counter_end       : std_logic; --tells FSM that we have processed all 256 bits of e.
    signal RS_enable           : std_logic; --signal which right shifts register RSR_e
    signal e_bit               : std_logic; --the LSB of register RSR_e
    signal initialize_regs     : std_logic; --loads initial values into C, P, RSR_e and e_counter
    signal is_last_msg_enable  : std_logic; --signal which tells "is_last_msg" to record the "msgin_last" signal.
    signal is_last_msg         : std_logic; --register which = 1, if msgin_last has been high.
    signal dbg_state           : state_type;
begin
    dut : entity work.exponentiation
        port map(
            -- Interface from general module to outside of RSA-core:
            message     => message,
            key         => key,
            modulus     => modulus,
            result      => result,
            valid_in    => valid_in,
            msgin_last  => msgin_last,
            ready_out   => ready_out,
            ready_in    => ready_in,
            valid_out   => valid_out,
            msgout_last => msgout_last,

            -- Interface from general module to Blakley module:
            Blak_enable   => Blak_enable,
            Blak_finished => Blak_finished,
            Blak_clk      => Blak_clk,
            Blak_reset_n  => Blak_reset_n,
            Blak_A        => Blak_A,
            Blak_B        => Blak_B,
            Blak_C        => Blak_C,
            Blak_n        => Blak_n,

            clk     => clk,
            reset_n => reset_n,

            -- Debug signals
            dbg_RSR_e               => RSR_e,
            dbg_P_reg               => P_reg,
            dbg_C_reg               => C_reg,
            dbg_pc_select           => pc_select,
            dbg_e_bit_counter       => e_bit_counter,
            dbg_e_counter_increment => e_counter_increment,
            dbg_e_counter_end       => e_counter_end,
            dbg_RS_enable           => RS_enable,
            dbg_e_bit               => e_bit,
            dbg_initialize_regs     => initialize_regs,
            dbg_is_last_msg_enable  => is_last_msg_enable,
            dbg_is_last_msg         => is_last_msg,
            dbg_state               => dbg_state
        );
    p_seq : process

    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting test bench for modular exponentiation combinatorial logic...");

        -- Test reset behavior
        clk     <= '0';
        message <= x"a5140ad17ed8ac766e0d9ab72dab049ef85efb70b71e05a947005324353db950";
        key     <= x"33711769db52093a2521995f33d34d3602c0e038bb2b467edce7471a7be75818";
        reset_n <= '0';
        wait for 1 ns;
        check_value(P_reg, (P_reg'range => '0'), ERROR, "P_reg shall hold value zero after/during reset.");
        check_value(C_reg, std_logic_vector(to_unsigned(1, C_reg'length)), ERROR, "C_reg shall be initialized to 1 during reset.");
        check_value(RSR_e, (RSR_e'range => '0'), ERROR, "RSR_e shall hold value zero after/during reset");
        check_value(e_bit_counter, (e_bit_counter'range => '0'), ERROR, "e_bit_counter shall be zero during reset.");
        check_value(e_counter_end, '0', ERROR, "e_counter_end shall be '0' during reset.");
        check_value(is_last_msg, '0', ERROR, "is_last_msg shall be '0' during reset.");
        check_value(result, std_logic_vector(to_unsigned(1, C_reg'length)), ERROR, "result shall be zero during reset.");
        -- TODO: Are there more signals that need to be checked?

        -- Load test values
        reset_n  <= '1';
        valid_in <= '1';
        msgin_last <= '1'; -- Indicate that this is the last message
        message  <= std_logic_vector(to_unsigned(7, message'length));
        key      <= std_logic_vector(to_unsigned(3, key'length)); -- Exponent 
        modulus  <= std_logic_vector(to_unsigned(55, modulus'length));

        -- First clock to set initialize_regs
        pulse_1ns(clk);
        check_value(initialize_regs, '1', ERROR, "initialize_regs must be '1' after valid_in pulse.");

        --check values in registers, after they have been initialized:
        pulse_1ns(clk);
        check_value(RSR_e, key, ERROR, "RSR_e shall be loaded with key after valid_in pulse.");
        check_value(P_reg, message, ERROR, "P_reg shall be loaded with message after valid_in pulse.");
        check_value(C_reg, std_logic_vector(to_unsigned(1, C_reg'length)), ERROR, "C_reg shall be initialized to 1 after valid_in pulse.");
        check_value(e_bit_counter, (e_bit_counter'range => '0'), ERROR, "e_bit_counter shall be zero after valid_in pulse.");
        check_value(e_bit, '1', ERROR, "e_bit shall be LSB of RSR_e after first shift.");

        -- Calc C
        pulse_1ns(clk);
        pulse_1ns(clk); -- Two clocks to get to state calc_C
        check_value(Blak_enable, '1', ERROR, "Blak_enable must be '1' to start calculation of C.");
        check_value(pc_select, '1', ERROR, "pc_select must be '1' when calculating C.");
        check_value(Blak_A, std_logic_vector(to_unsigned(7, Blak_A'length)), ERROR, "Blak_A must be P_reg value when calculating C.");
        check_value(Blak_B, std_logic_vector(to_unsigned(1, Blak_B'length)), ERROR, "Blak_B must be C_reg value when calculating C.");

        -- Simulate Blakley module finishing calculation
        Blak_C        <= std_logic_vector(to_unsigned(7, Blak_C'length)); -- 7 * 1 mod 55 = 7
        Blak_finished <= '1';
        pulse_1ns(clk);
        check_value(P_reg, std_logic_vector(to_unsigned(7, P_reg'length)), ERROR, "P_reg must hold previous value when calculating C.");
        check_value(C_reg, std_logic_vector(to_unsigned(7, C_reg'length)), ERROR, "C_reg must hold correct value after calculating C.");

        -- Calc P
        Blak_finished <= '0';
        pulse_1ns(clk);
        check_value(P_reg, std_logic_vector(to_unsigned(7, P_reg'length)), ERROR, "P_reg must hold previous value when calculating P.");
        check_value(C_reg, std_logic_vector(to_unsigned(7, C_reg'length)), ERROR, "C_reg must be previous C_reg when calculating P.");
        check_value(Blak_A, std_logic_vector(to_unsigned(7, Blak_A'length)), ERROR, "Blak_A must be P_reg value when calculating P.");
        check_value(Blak_B, std_logic_vector(to_unsigned(7, Blak_B'length)), ERROR, "Blak_B must be P_reg value when calculating P.");

        -- Simulate Blakley module finishing calculation
        Blak_C        <= std_logic_vector(to_unsigned(49, Blak_C'length)); -- 7 * 7 mod 55 = 49
        Blak_finished <= '1';
        pulse_1ns(clk);
        check_value(P_reg, std_logic_vector(to_unsigned(49, C_reg'length)), ERROR, "P_reg must hold correct value after calculating C.");
        check_value(C_reg, std_logic_vector(to_unsigned(7, C_reg'length)), ERROR, "C_reg must hold previous value after calculating P.");
        

        -- Increment e counter
        Blak_finished <= '0';
        check_value(e_counter_increment, '1', ERROR, "e_counter_increment must be '1' after C and then P have been updated.");
        pulse_1ns(clk);   --this clock makes e_bit_counter increment from 0 to 1.
        check_value(e_bit_counter, std_logic_vector(to_unsigned(1, e_bit_counter'length)), ERROR, "e_bit_counter must be incremented after processing one bit.");
        check_value(e_counter_end, '0', ERROR, "e_counter_end must be '0' having updated e_bit_counter.");
        

        -- Rightshift e
        pulse_1ns(clk); --this clock switches from "is_e_processed state", to "rightshift_e state".
        check_value(e_counter_increment, '0', ERROR, "e_counter_increment must be '0' after it has incremented once.");

        --i am here now.
        pulse_1ns(clk); --this clock switches from "rightshift_e"-state to "read_e_bit"-state
        --the e_bit should still be = 1 here. We are reading the second 1-bit in the key here.
        check_value(e_bit, '1', ERROR, "e_bit must be updated to new LSB of RSR_e after shift.");

        -- Calc C
        pulse_1ns(clk); -- Two clocks to get from "read_e_bit"-state, to state "calc_C"
        -- check_value(Blak_enable, '1', ERROR, "Blak_enable must be '1' to start calculation of C.");
        -- check_value(pc_select, '1', ERROR, "pc_select must be '1' when calculating C.");
        check_value(Blak_A, std_logic_vector(to_unsigned(49, Blak_A'length)), ERROR, "Blak_A must be P_reg value when calculating C.");
        check_value(Blak_B, std_logic_vector(to_unsigned(7, Blak_B'length)), ERROR, "Blak_B must be C_reg value when calculating C.");

        -- Simulate Blakley module finishing calculation
        Blak_C        <= std_logic_vector(to_unsigned(13, Blak_C'length)); -- 49 * 7 mod 55 = 13
        Blak_finished <= '1';
        pulse_1ns(clk);  --this clock switches from "calc_C", to "reset_blak_module".
        check_value(P_reg, std_logic_vector(to_unsigned(49, P_reg'length)), ERROR, "P_reg must hold previous value when calculating C.");
        check_value(C_reg, std_logic_vector(to_unsigned(13, C_reg'length)), ERROR, "C_reg must hold correct value after calculating C.");

        -- Calc P
        Blak_finished <= '0';
        pulse_1ns(clk); --from "reset_blak_module", to "calc_P". 
        check_value(Blak_A, std_logic_vector(to_unsigned(49, Blak_A'length)), ERROR, "Blak_A must be P_reg value when calculating P.");
        check_value(Blak_B, std_logic_vector(to_unsigned(49, Blak_B'length)), ERROR, "Blak_B must be P_reg value when calculating P.");

        -- Simulate Blakley module finishing calculation
        Blak_C        <= std_logic_vector(to_unsigned(36, Blak_C'length)); -- 49 * 49 mod 55 = 36
        Blak_finished <= '1';
        pulse_1ns(clk); --from "calc_p", to "increment_e".
        check_value(P_reg, std_logic_vector(to_unsigned(36, C_reg'length)), ERROR, "P_reg must hold result of multiplication.");
        check_value(C_reg, std_logic_vector(to_unsigned(13, C_reg'length)), ERROR, "C_reg must hold previous value.");
        

        -- Increment e counter
        Blak_finished <= '0';
        pulse_1ns(clk); --from "increment_e", to "is_e_processed".
        check_value(e_bit_counter, std_logic_vector(to_unsigned(2, e_bit_counter'length)), ERROR, "e_bit_counter must be incremented after processing one bit.");
        check_value(e_counter_end, '0', ERROR, "e_counter_end must be '0' after processing second bit.");



        -- Rightshift e
        pulse_1ns(clk); --from "is_e_processed" to "rightshift_e".
        pulse_1ns(clk); --from "rightshift_e" to "read_e_bit".
        check_value(e_bit, '0', ERROR, "e_bit should be the first 0, when reading from LSB (1, 1, 0 <-this one, 0, 0...)");


        -- Calc P (since e_bit = 0, we skip calc C)
        pulse_1ns(clk); -- from "read_e_bit", to "calk_P".
        check_value(Blak_A, std_logic_vector(to_unsigned(36, Blak_A'length)), ERROR, "Blak_A must be P_reg value when calculating P.");
        check_value(Blak_B, std_logic_vector(to_unsigned(36, Blak_B'length)), ERROR, "Blak_B must be P_reg value when calculating P.");

        -- Simulate Blakley module finishing calculation
        Blak_C        <= std_logic_vector(to_unsigned(31, Blak_C'length)); -- 36 * 36 mod 55 = 31
        Blak_finished <= '1';
        pulse_1ns(clk); --from "calc_P" to "increment_e".
        check_value(P_reg, std_logic_vector(to_unsigned(31, C_reg'length)), ERROR, "P_reg must hold result of multiplication.");
        check_value(C_reg, std_logic_vector(to_unsigned(13, C_reg'length)), ERROR, "C_reg must hold previous value.");
        

        -- Increment e counter
        Blak_finished <= '0';
        check_value(e_bit_counter, std_logic_vector(to_unsigned(2, e_bit_counter'length)), ERROR, "e_bit_counter should be 2, before the clock that increments it to 3");
        pulse_1ns(clk); --from "increment_e", to "is_e_processed".
        check_value(e_bit_counter, std_logic_vector(to_unsigned(3, e_bit_counter'length)), ERROR, "e_bit_counter must be incremented after processing one bit.");
        check_value(e_counter_end, '0', ERROR, "e_counter_end must be '0' after processing third bit.");

-------------eg er her nå.------------------------------

        -------------------------------------------------
        -- Now three bits of exponent have been processed.
        -- The current state should be is_e_processed
        -------------------------------------------------

        -- Process remaining bits quickly until e_counter_end = '1'
        Blak_finished <= '1';
        wait_clocks_until(clk, e_counter_end); --runs the clock, until we are in "is_e_processed"-state.
        check_value(state_type'pos(dbg_state), state_type'pos(is_e_processed), ERROR, "State must be 'is_e_processed'");
        check_value(e_counter_end, '1', ERROR, "e_counter_end must be '1' after processing all bits.");
        
        check_value(valid_out, '0', ERROR, "valid_out must be '0' before we handshake out.");

        -- go to handshake out.
        pulse_1ns(clk); --from "is_e_processed", to "is_out_ready_final_msg".
        ready_out <= '1';
        check_value(result, std_logic_vector(to_unsigned(13, result'length)), ERROR, "Result must hold final computed value.");
        check_value(valid_out, '1', ERROR, "valid_out must be '1' when in handshake out.");
        check_value(msgout_last, '1', ERROR, "msgout_last must be '1' as this was the final handshake out");
        check_value(state_type'pos(dbg_state), state_type'pos(is_out_ready_final_msg), ERROR, "State must be 'is_out_ready_final_msg' ");

        --send it back to handshake-inn-state again.
        pulse_1ns(clk); --from "is_out_ready_final_msg", to "is_in_valid".
        check_value(msgout_last, '0', ERROR, "msgout_last should be = 0, when in handshake inn again.");
        check_value(valid_out, '0', ERROR, "valid_out must be '0' when in handshake inn again.");
        check_value(state_type'pos(dbg_state), state_type'pos(is_in_valid), ERROR, "State must be 'is_in_valid' ");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
