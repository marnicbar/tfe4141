library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mod_exp_pkg.all;

entity rsa_core is
    generic (
        C_BLOCK_SIZE : integer := 256
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;

        msgin_valid : in  std_logic;
        msgin_ready : out std_logic;
        msgin_data  : in  std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        msgin_last  : in  std_logic;

        msgout_valid : out std_logic;
        msgout_ready : in  std_logic;
        msgout_data  : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        msgout_last  : out std_logic;

        key_e_d     : in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        key_n       : in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
        rsa_status  : out std_logic_vector(31 downto 0);

        -------------------------------------------------------------------------
        -- FULL DEBUG VISIBILITY yupi :)
        -------------------------------------------------------------------------
        -- pragma translate_off
        dbg_state_exp : out state_type;  -- exponentiation FSM
        dbg_state_bla : out std_logic_vector(2 downto 0); -- blakley FSM
        dbg_temp      : out unsigned(C_BLOCK_SIZE+1 downto 0);
        dbg_a         : out unsigned(C_BLOCK_SIZE-1 downto 0);
        dbg_b         : out unsigned(C_BLOCK_SIZE-1 downto 0);
        dbg_n         : out unsigned(C_BLOCK_SIZE-1 downto 0);
        dbg_cnt       : out unsigned(8 downto 0);
        dbg_bit       : out std_logic
        -- pragma translate_on
    );
end rsa_core;


architecture rtl of rsa_core is

    -- internal connections exponentiation ↔ blakley
    signal Blak_enable_s   : std_logic;
    signal Blak_finished_s : std_logic;
    signal Blak_clk_s      : std_logic;
    signal Blak_reset_n_s  : std_logic;

    signal Blak_A_s : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal Blak_B_s : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal Blak_C_s : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal Blak_n_s : std_logic_vector(C_BLOCK_SIZE-1 downto 0);

    -- pragma translate_off
    signal dbg_state_exp_s : state_type;              -- exponentiation FSM
    signal dbg_state_bla_s : std_logic_vector(2 downto 0); -- blakley FSM

    signal dbg_temp_s  : unsigned(C_BLOCK_SIZE+1 downto 0);
    signal dbg_a_s     : unsigned(C_BLOCK_SIZE-1 downto 0);
    signal dbg_b_s     : unsigned(C_BLOCK_SIZE-1 downto 0);
    signal dbg_n_s     : unsigned(C_BLOCK_SIZE-1 downto 0);
    signal dbg_cnt_s   : unsigned(8 downto 0);
    signal dbg_bit_s   : std_logic;
    -- pragma translate_on

begin

    -------------------------------------------------------------------------
    -- exponentiation module
    -------------------------------------------------------------------------
    exp_inst : entity work.exponentiation
        generic map (
            C_block_size     => C_BLOCK_SIZE,
            counter_bit_size => 8
        )
        port map (
            message     => msgin_data,
            key         => key_e_d,
            modulus     => key_n,
            result      => msgout_data,

            valid_in    => msgin_valid,
            msgin_last  => msgin_last,
            ready_out   => msgout_ready,

            ready_in    => msgin_ready,
            valid_out   => msgout_valid,
            msgout_last => msgout_last,

            Blak_enable   => Blak_enable_s,
            Blak_finished => Blak_finished_s,
            Blak_clk      => Blak_clk_s,
            Blak_reset_n  => Blak_reset_n_s,

            Blak_A        => Blak_A_s,
            Blak_B        => Blak_B_s,
            Blak_C        => Blak_C_s,
            Blak_n        => Blak_n_s,

            clk     => clk,
            reset_n => reset_n,

            -- exponentiation FSM debug
            -- pragma translate_off
            dbg_state => dbg_state_exp_s
            -- pragma translate_on
        );

    -------------------------------------------------------------------------
    -- Blakley Multiplier
    -------------------------------------------------------------------------
    blak_inst : entity work.blakley
        generic map (
            W        => C_BLOCK_SIZE,
            TMP_BITS => C_BLOCK_SIZE + 2,
            CNT_W    => 9
        )
        port map (
            clk       => Blak_clk_s,
            reset_n   => Blak_reset_n_s,
            b_enable  => Blak_enable_s,

            A => Blak_A_s,
            B => Blak_B_s,
            N => Blak_n_s,

            result_out => Blak_C_s,
            done_out   => Blak_finished_s,

            -- pragma translate_off
            debug_state    => dbg_state_bla_s,
            debug_reg_temp => dbg_temp_s,
            debug_reg_a    => dbg_a_s,
            debug_reg_b    => dbg_b_s,
            debug_reg_n    => dbg_n_s,
            debug_counter  => dbg_cnt_s,
            debug_A_bit    => dbg_bit_s
            -- pragma translate_on
        );

    -------------------------------------------------------------------------
    -- Export debug signals
    -------------------------------------------------------------------------
    -- pragma translate_off
    dbg_state_exp <= dbg_state_exp_s;
    dbg_state_bla <= dbg_state_bla_s;
    dbg_temp      <= dbg_temp_s;
    dbg_a         <= dbg_a_s;
    dbg_b         <= dbg_b_s;
    dbg_n         <= dbg_n_s;
    dbg_cnt       <= dbg_cnt_s;
    dbg_bit       <= dbg_bit_s;
    -- pragma translate_on

    rsa_status <= (others => '0');

end architecture;
