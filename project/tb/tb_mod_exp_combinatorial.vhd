library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.mod_exp_pkg.all; -- bring in the enum type

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
    signal LSR_e               : std_logic_vector(C_block_size - 1 downto 0); --Left shift register for key_e
    signal P_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value P
    signal C_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value C
    signal pc_select           : std_logic; -- Signal to select which of P or C that are "using" the blakley module.
    signal e_bit_counter       : std_logic_vector(counter_bit_size downto 0); --8 bit signal for a counter which the state machine uses to iterate over 256 bits of key_e.
    signal e_counter_increment : std_logic; --tells e_counter to += 1.
    signal e_counter_end       : std_logic; --tells FSM that we have processed all 256 bits of e.
    signal LS_enable           : std_logic; --signal which left shifts register LSR_e
    signal e_bit               : std_logic; --the LSB of register LSR_e
    signal initialize_regs     : std_logic; --loads initial values into C, P, LSR_e and e_counter
    signal is_last_msg_enable  : std_logic; --signal which tells "is_last_msg" to record the "msgin_last" signal.
    signal is_last_msg         : std_logic; --register which = 1, if msgin_last has been high.

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
            dbg_LSR_e               => LSR_e,
            dbg_P_reg               => P_reg,
            dbg_C_reg               => C_reg,
            dbg_pc_select           => pc_select,
            dbg_e_bit_counter       => e_bit_counter,
            dbg_e_counter_increment => e_counter_increment,
            dbg_e_counter_end       => e_counter_end,
            dbg_LS_enable           => LS_enable,
            dbg_e_bit               => e_bit,
            dbg_initialize_regs     => initialize_regs,
            dbg_is_last_msg_enable  => is_last_msg_enable,
            dbg_is_last_msg         => is_last_msg
        );
    p_seq : process

    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting test bench for modular exponentiation combinatorial logic...");

        -- Test reset behavior
        message <= x"9F3C7A12D84B55E0A6C1F90347BC2D8894EF01A76D52C3BB18E6F4D2A7C9E510";
        reset_n <= '0';
        wait for 1 ns;
        check_value(P_reg, message, ERROR, "P_reg shall hold the value of message during reset.");
        check_value(C_reg, std_logic_vector(to_unsigned(1, C_reg'length)), ERROR, "C_reg shall be initialized to 1 during reset.");
        -- TODO: Test it again when Blak_reset_n is implemented correctly.
        -- check_value(Blak_reset_n, '0', ERROR, "Blak_reset_n shall be low during reset.");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
