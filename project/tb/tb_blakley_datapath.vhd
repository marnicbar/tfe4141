-- tb_blakley_datapath.vhd
-- UVVM testbench for blakley_datapath using check_value() style from tb_blakley_fsm
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley_datapath is
end entity;

architecture sim of tb_blakley_datapath is
    constant bit_width : positive := 256;

    -- DUT signals
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal A, B, N : std_logic_vector(bit_width-1 downto 0) := (others => '0');

    -- Control signals (driven by testbench)
    signal load_inputs    : std_logic := '0';
    signal shift_a        : std_logic := '0';
    signal add_en         : std_logic := '0';
    signal sub1_en        : std_logic := '0';
    signal sub2_en        : std_logic := '0';
    signal do_store_shift : std_logic := '0';
    signal output_en      : std_logic := '0';

    -- Feedback from datapath
    signal a_msb  : std_logic := '0';
    signal gt_n_1 : std_logic := '0';
    signal gt_n_2 : std_logic := '0';

    -- Output
    signal Output : std_logic_vector(bit_width-1 downto 0) := (others => '0');

    -- Helpers
    -- replace the old function with this
    function to_slv(val : natural; width : positive) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(val, width));
        end function to_slv;


begin
    ----------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------
    uut: entity work.blakley_datapath
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
    -- Monitor: print a line every rising edge for debugging
    -- NOTE: Output removed from this concatenation to avoid & type mismatch
    ----------------------------------------------------------------
    monitor : process
    begin
        wait until rising_edge(clk);
        log(ID_LOG_HDR,
            "T=" & time'image(now)
            & " a_msb=" & std_logic'image(a_msb)
            & " gt1=" & std_logic'image(gt_n_1)
            & " gt2=" & std_logic'image(gt_n_2)
            & " load=" & std_logic'image(load_inputs)
            & " add=" & std_logic'image(add_en)
            & " sub1=" & std_logic'image(sub1_en)
            & " store_shift=" & std_logic'image(do_store_shift)
            & " out_en=" & std_logic'image(output_en)
        );
        wait;
    end process;

    ----------------------------------------------------------------
    -- Test sequence (mirrors style of tb_blakley_fsm check_value usage)
    ----------------------------------------------------------------
    tb_process : process
        constant zero  : std_logic_vector(bit_width-1 downto 0) := (others => '0');
        constant one   : std_logic_vector(bit_width-1 downto 0) := to_slv(1, bit_width);
        constant two   : std_logic_vector(bit_width-1 downto 0) := to_slv(2, bit_width);
        constant three : std_logic_vector(bit_width-1 downto 0) := to_slv(3, bit_width);
    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting focused datapath testbench (load/add/sub/shift/store checks)");

        -- Reset: hold low for >=2 clock cycles
        reset_n <= '0';
        load_inputs <= '0';
        shift_a <= '0';
        add_en <= '0';
        sub1_en <= '0';
        sub2_en <= '0';
        do_store_shift <= '0';
        output_en <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Release reset and wait one clock for sequential to sample it
        reset_n <= '1';
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- Phase 1: Load inputs A=1, B=3, N=2
        ----------------------------------------------------------------
        A <= one;
        B <= three;
        N <= two;
        load_inputs <= '1';
        wait for 1 ns;                 -- assert before sampling edge (avoid delta race)
        wait until rising_edge(clk);   -- load sampled here
        load_inputs <= '0';
        wait until rising_edge(clk);

        -- After load, Output should still be zero (reg_out initialized to 0)
        check_value( (Output = zero), TRUE, ERROR,
                     "After load, Output should be 0");

        ----------------------------------------------------------------
        -- Phase 2: Add B (3) into reg_temp and present it on Output
        ----------------------------------------------------------------
        add_en <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);   -- add sampled
        add_en <= '0';
        wait until rising_edge(clk);

        -- Move reg_temp to reg_out via output_en
        output_en <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);
        output_en <= '0';
        wait until rising_edge(clk);

        check_value( (Output = three), TRUE, ERROR,
                     "After add_en and output_en, Output should be 3");

        -- With reg_temp=3 and N=2, gt_n_* should indicate reg_temp >= N -> '1'
        check_value( (gt_n_1 = '1'), TRUE, ERROR,
                     "gt_n_1 should be '1' when reg_temp >= N");
        check_value( (gt_n_2 = '1'), TRUE, ERROR,
                     "gt_n_2 should be '1' when reg_temp >= N");

        ----------------------------------------------------------------
        -- Phase 3: Subtract N (2) from reg_temp (3) -> reg_temp becomes 1
        ----------------------------------------------------------------
        sub1_en <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);   -- subtraction sampled
        sub1_en <= '0';
        wait until rising_edge(clk);

        output_en <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);
        output_en <= '0';
        wait until rising_edge(clk);

        check_value( (Output = one), TRUE, ERROR,
                     "After subtraction and output_en, Output should be 1");

        -- Now reg_temp=1 < N=2 -> gt_n_* should be '0'
        check_value( (gt_n_1 = '0'), TRUE, ERROR,
                     "gt_n_1 should be '0' when reg_temp < N");
        check_value( (gt_n_2 = '0'), TRUE, ERROR,
                     "gt_n_2 should be '0' when reg_temp < N");

        ----------------------------------------------------------------
        -- Phase 4: do_store_shift: reg_out <= reg_temp; reg_temp <= reg_temp << 1
        ----------------------------------------------------------------
        do_store_shift <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);   -- store+shift sampled
        do_store_shift <= '0';
        wait until rising_edge(clk);

        -- Output should hold previous reg_temp (which was 1)
        check_value( (Output = one), TRUE, ERROR,
                     "After do_store_shift, Output should hold previous reg_temp (1)");

        ----------------------------------------------------------------
        -- Phase 5: Shift A and check a_msb feedback
        ----------------------------------------------------------------
        -- A was 1 at LSB; shift once -> reg_a becomes 2, MSB still '0'
        shift_a <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);
        shift_a <= '0';
        wait until rising_edge(clk);

        check_value( (a_msb = '0'), TRUE, ERROR,
                     "a_msb should be '0' after single shift of small A");

        -- Drive A with MSB set, reload inputs and check a_msb
        A <= (others => '0');
        A(bit_width-1) <= '1';  -- set MSB
        load_inputs <= '1';
        wait for 1 ns;
        wait until rising_edge(clk);
        load_inputs <= '0';
        wait until rising_edge(clk);

        check_value( (a_msb = '1'), TRUE, ERROR,
                     "a_msb should be '1' when MSB of A is set");

        log(ID_LOG_HDR, "Datapath checks executed");

        -- End test
        std.env.stop;
        wait;
    end process;

end architecture;
