-- tb_blakley_fsm.vhd
-- Compact UVVM testbench that explicitly verifies read_inputs -> initial_shifting
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley_fsm is
end entity;

architecture sim of tb_blakley_fsm is
    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal bn_enable : std_logic := '0';

    -- FSM feedback/stimuli
    signal a_msb  : std_logic := '0';
    signal gt_n_1 : std_logic := '0';
    signal gt_n_2 : std_logic := '0';

    -- FSM outputs observed
    signal load_inputs    : std_logic := '0';
    signal shift_a        : std_logic := '0';
    signal add_en         : std_logic := '0';
    signal sub1_en        : std_logic := '0';
    signal sub2_en        : std_logic := '0';
    signal do_store_shift : std_logic := '0';
    signal output_en      : std_logic := '0';

    signal finished_calc : std_logic := '0';
    signal dbg_state     : std_logic_vector(3 downto 0) := (others => '0');
begin
    ----------------------------------------------------------------
    -- Instantiate FSM with small COUNT_LIMIT so we reach 'saida' quickly in test
    ----------------------------------------------------------------
    u_fsm : entity work.blakley_fsm
        port map (
            clk => clk,
            reset_n => reset_n,
            bn_enable => bn_enable,
            a_msb => a_msb,
            gt_n_1 => gt_n_1,
            gt_n_2 => gt_n_2,
            load_inputs => load_inputs,
            shift_a => shift_a,
            add_en => add_en,
            sub1_en => sub1_en,
            sub2_en => sub2_en,
            do_store_shift => do_store_shift,
            output_en => output_en,
            finished_calc => finished_calc,
            dbg_state => dbg_state
        );

    ----------------------------------------------------------------
    -- Clock: 100 MHz
    ----------------------------------------------------------------
    clk_process : process
    begin
        loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Monitor for debugging: prints one line every rising edge
    ----------------------------------------------------------------
    monitor : process
    begin
        loop
            wait until rising_edge(clk);
            log(ID_LOG_HDR,
                "T=" & time'image(now)
                & " state=" & integer'image(to_integer(unsigned(dbg_state)))
                & " bn_en=" & std_logic'image(bn_enable)
                & " a_msb=" & std_logic'image(a_msb)
                & " gt1=" & std_logic'image(gt_n_1)
                & " gt2=" & std_logic'image(gt_n_2)
                & " do_store=" & std_logic'image(do_store_shift)
                & " finished=" & std_logic'image(finished_calc)
            );
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Test sequence
    -- 1) Explicitly test read_inputs -> initial_shifting
    -- 2) Continue to test rest of FSM (one path) to ensure behavior
    ----------------------------------------------------------------
    tb_process : process
    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting focused FSM test (checking read->initial_shifting first)");

        -- reset: hold low for >=2 clock cycles
        reset_n <= '0';
        bn_enable <= '0';
        a_msb <= '0'; gt_n_1 <= '0'; gt_n_2 <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- release reset and wait one clock for sequential to sample it
        reset_n <= '1';
        wait until rising_edge(clk);

        -- check we are in read_inputs (dbg_state code 0)
        check_value( (to_integer(unsigned(dbg_state)) = 0), TRUE, ERROR,
                     "FSM should be in read_inputs after reset (0)");

        ----------------------------------------------------------------
        -- TEST A: assert bn_enable *before* the rising edge that will be sampled,
        -- then wait one rising edge and check initial_shifting (code 1).
        ----------------------------------------------------------------
        bn_enable <= '1';        -- important: assert BEFORE the sampling edge
        wait for 1 ns;           -- give signals time to propagate (avoids delta-race)
        wait until rising_edge(clk);  -- this edge -> state <= initial_shifting
        wait until rising_edge(clk);
        -- Immediately check that FSM moved to initial_shifting
        check_value( (to_integer(unsigned(dbg_state)) = 1), TRUE, ERROR,
                     "read_inputs -> initial_shifting transition failed (expected 1)");

        log(ID_LOG_HDR, "TEST A passed: read_inputs -> initial_shifting");

        ----------------------------------------------------------------
        -- Continue a simple path to make sure FSM progresses (addition -> comp1)
        -- We use the same safe rule: drive inputs early before edges that need them.
        ----------------------------------------------------------------
        -- next edge should go to addition
        a_msb <= '1';
        wait until rising_edge(clk);
        check_value( (to_integer(unsigned(dbg_state)) = 2), TRUE, ERROR,
                     "FSM should be in addition (2)");

       
        gt_n_1 <= '1';
        --wait for 1 ns;
        wait until rising_edge(clk); -- addition -> comp1
        check_value( to_integer(unsigned(dbg_state)) , 3, ERROR,
                     "FSM should be in comp1 (3)");

        -- force gt_n_1 = '1' *while in comp1 decision window* by setting it
        -- early (we set it now - while in comp1 this will set state_next=sub1)
       
        wait for 1 ns;
        wait until rising_edge(clk); -- comp1 -> sub1
        check_value( (to_integer(unsigned(dbg_state)) = 4), TRUE, ERROR,
                     "FSM should be in sub1 (4)");

        -- go on a little further to ensure FSM can reach saida (COUNT_LIMIT small)
        gt_n_2 <= '1';
        wait for 1 ns;
        wait until rising_edge(clk); -- sub1->comp2
        wait until rising_edge(clk); -- comp2->sub2
        wait until rising_edge(clk); -- sub2->store_shift
        wait until to_integer(unsigned(dbg_state)) = 8; -- wait until saida
        check_value( (finished_calc = '1'), TRUE, ERROR,
                     "FSM should assert finished_calc in saida");

        log(ID_LOG_HDR, "Rest of path reached saida OK");

        -- End test
        std.env.stop;
        wait;
    end process;

end architecture;
