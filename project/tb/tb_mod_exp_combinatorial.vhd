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
            reset_n => reset_n
        );
    p_seq : process

    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting test bench for modular exponentiation combinatorial logic...");

        -- Final reporting
        -- report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
        report_global_ctrl(VOID);
        report_check_counters(FINAL);
        report_alert_counters(FINAL);

        std.env.stop; -- End simulation cleanly
        wait;
    end process;
end architecture;
