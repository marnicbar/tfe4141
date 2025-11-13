library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakely is
    generic (
        bit_width : positive := 256
    );
    port (
        -- Inputs
        A : in std_logic_vector(bit_width-1 downto 0);
        B : in std_logic_vector(bit_width-1 downto 0);
        N : in std_logic_vector(bit_width-1 downto 0);

        clk       : in std_logic;
        reset_n   : in std_logic;
        bn_enable : in std_logic;

        -- Outputs
        Output        : out std_logic_vector(bit_width-1 downto 0);
        finished_calc : out std_logic
    );
end blakely;

architecture Behavioral of blakely is

    -------------------------------------------------------------------------
    -- Internal signals connecting FSM and datapath
    -------------------------------------------------------------------------
    signal load_inputs, shift_a, add_en, sub1_en, sub2_en,
           do_store_shift, output_en : std_logic;

    signal a_msb, gt_n_1, gt_n_2 : std_logic;

begin

    -------------------------------------------------------------------------
    -- DATAPATH INSTANCE
    -------------------------------------------------------------------------
    u_datapath : entity work.blakely_datapath
        generic map (
            bit_width => bit_width
        )
        port map (
            clk    => clk,
            reset_n => reset_n,

            -- Inputs
            A => A,
            B => B,
            N => N,

            -- Control signals from FSM
            load_inputs    => load_inputs,
            shift_a        => shift_a,
            add_en         => add_en,
            sub1_en        => sub1_en,
            sub2_en        => sub2_en,
            do_store_shift => do_store_shift,
            output_en      => output_en,

            -- Feedback to FSM
            a_msb  => a_msb,
            gt_n_1 => gt_n_1,
            gt_n_2 => gt_n_2,

            -- Output
            Output => Output
        );

    -------------------------------------------------------------------------
    -- FSM INSTANCE
    -------------------------------------------------------------------------
    u_fsm : entity work.blakely_fsm
        port map (
            clk   => clk,
            reset_n => reset_n,
            bn_enable => bn_enable,

            -- Feedback from datapath
            a_msb  => a_msb,
            gt_n_1 => gt_n_1,
            gt_n_2 => gt_n_2,
           

            -- Control outputs
            load_inputs    => load_inputs,
            shift_a        => shift_a,
            add_en         => add_en,
            sub1_en        => sub1_en,
            sub2_en        => sub2_en,
            do_store_shift => do_store_shift,
            output_en      => output_en,

            -- Status
            finished_calc => finished_calc,
            dbg_state     => open   -- optional debug
        );

end Behavioral;
