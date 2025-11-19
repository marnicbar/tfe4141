library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakley is
    generic (
        bit_width   : positive := 256;
        COUNT_LIMIT : positive := 255
    );
    port (
        -- External inputs
        A : in std_logic_vector(bit_width-1 downto 0);
        B : in std_logic_vector(bit_width-1 downto 0);
        N : in std_logic_vector(bit_width-1 downto 0);

        clk       : in std_logic;
        reset_n   : in std_logic;
        bn_enable : in std_logic;

        -- External outputs
        Output        : out std_logic_vector(bit_width-1 downto 0);
        finished_calc : out std_logic;

        -- Debug output (FSM state)
        dbg_state_sig : out std_logic_vector(3 downto 0);

        -- OPTIONAL: expose datapath internal feedback for debugging
        a_msb_sig  : out std_logic;
        gt1_sig    : out std_logic;
        gt2_sig    : out std_logic;

        -- OPTIONAL: expose FSM control outputs for debugging
        load_i_sig     : out std_logic;
        shift_a_sig    : out std_logic;
        add_en_sig     : out std_logic;
        sub1_en_sig    : out std_logic;
        sub2_en_sig    : out std_logic;
        store_shift_sig: out std_logic;
        output_en_sig  : out std_logic
    );
end blakley;

architecture Behavioral of blakley is

    -------------------------------------------------------------------------
    -- Internal signals connecting FSM ↔ datapath
    -------------------------------------------------------------------------
    signal load_inputs    : std_logic := '0';
    signal shift_a        : std_logic := '0';
    signal add_en         : std_logic := '0';
    signal sub1_en        : std_logic := '0';
    signal sub2_en        : std_logic := '0';
    signal do_store_shift : std_logic := '0';
    signal output_en      : std_logic := '0';

    signal a_msb  : std_logic := '0';
    signal gt_n_1 : std_logic := '0';
    signal gt_n_2 : std_logic := '0';

begin

    -------------------------------------------------------------------------
    -- DATAPATH INSTANCE
    -------------------------------------------------------------------------
    u_datapath : entity work.blakley_datapath
        generic map (
            bit_width => bit_width
        )
        port map (
            clk            => clk,
            reset_n        => reset_n,

            A              => A,
            B              => B,
            N              => N,

            load_inputs    => load_inputs,
            shift_a        => shift_a,
            add_en         => add_en,
            sub1_en        => sub1_en,
            sub2_en        => sub2_en,
            do_store_shift => do_store_shift,
            output_en      => output_en,

            a_msb          => a_msb,
            gt_n_1         => gt_n_1,
            gt_n_2         => gt_n_2,

            Output         => Output
        );

    -------------------------------------------------------------------------
    -- FSM INSTANCE
    -------------------------------------------------------------------------
    u_fsm : entity work.blakley_fsm
        port map (
            clk            => clk,
            reset_n        => reset_n,
            bn_enable      => bn_enable,

            a_msb          => a_msb,
            gt_n_1         => gt_n_1,
            gt_n_2         => gt_n_2,

            load_inputs    => load_inputs,
            shift_a        => shift_a,
            add_en         => add_en,
            sub1_en        => sub1_en,
            sub2_en        => sub2_en,
            do_store_shift => do_store_shift,
            output_en      => output_en,

            finished_calc  => finished_calc,
            dbg_state      => dbg_state_sig
        );

    -------------------------------------------------------------------------
    -- EXPOSE INTERNAL SIGNALS FOR TESTBENCH / DEBUGGING
    -------------------------------------------------------------------------
    a_msb_sig      <= a_msb;
    gt1_sig        <= gt_n_1;
    gt2_sig        <= gt_n_2;

    load_i_sig      <= load_inputs;
    shift_a_sig     <= shift_a;
    add_en_sig      <= add_en;
    sub1_en_sig     <= sub1_en;
    sub2_en_sig     <= sub2_en;
    store_shift_sig <= do_store_shift;
    output_en_sig   <= output_en;

end Behavioral;
