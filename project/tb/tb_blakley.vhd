-- tb_blakley.vhd
-- Robust UVVM testbench for Blakley module with multi-vector support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley is
end entity;

architecture sim of tb_blakley is
    constant bit_width : positive := 256;

    -- DUT inputs
    signal A         : std_logic_vector(bit_width - 1 downto 0) := (others => '0');
    signal B         : std_logic_vector(bit_width - 1 downto 0) := (others => '0');
    signal N         : std_logic_vector(bit_width - 1 downto 0) := (others => '0');
    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal bn_enable : std_logic := '0';

    -- DUT outputs
    signal output        : std_logic_vector(bit_width - 1 downto 0);
    signal finished_calc : std_logic;
    signal dbg_state_sig : std_logic_vector(3 downto 0);

    -- DEBUG SIGNALS matching blakley.vhd
    signal load_i_sig      : std_logic;
    signal shift_a_sig     : std_logic;
    signal add_en_sig      : std_logic;
    signal sub1_en_sig     : std_logic;
    signal sub2_en_sig     : std_logic;
    signal store_shift_sig : std_logic;
    signal output_en_sig   : std_logic;

    signal a_msb_sig  : std_logic;
    signal gt1_sig    : std_logic;
    signal gt2_sig    : std_logic;

    -- Reference result
    signal reference_result : std_logic_vector(bit_width-1 downto 0);

    -- Test vector type
type test_vector_t is record
    A_val : integer;
    B_val : integer;
    N_val : integer;
end record;

-- Array type for test vectors
type test_vector_array_t is array (natural range <>) of test_vector_t;

-- Test vectors constant
constant test_vectors : test_vector_array_t := (
    (A_val => 1,   B_val => 2,   N_val => 255),
    (A_val => 10,  B_val => 20,  N_val => 97),
    (A_val => 123, B_val => 456, N_val => 789)
);


begin
    --------------------------------------------------------------------
    -- Instantiate DUT
    --------------------------------------------------------------------
    dut : entity work.blakley
        generic map(
            bit_width   => bit_width,
            COUNT_LIMIT => bit_width - 1   -- full computation
        )
        port map(
            A             => A,
            B             => B,
            N             => N,
            clk           => clk,
            reset_n       => reset_n,
            bn_enable     => bn_enable,

            output        => output,
            finished_calc => finished_calc,
            dbg_state_sig => dbg_state_sig,

            load_i_sig      => load_i_sig,
            shift_a_sig     => shift_a_sig,
            add_en_sig      => add_en_sig,
            sub1_en_sig     => sub1_en_sig,
            sub2_en_sig     => sub2_en_sig,
            store_shift_sig => store_shift_sig,
            output_en_sig   => output_en_sig,

            a_msb_sig => a_msb_sig,
            gt1_sig   => gt1_sig,
            gt2_sig   => gt2_sig
        );

    --------------------------------------------------------------------
    -- Clock generation: 100 MHz
    --------------------------------------------------------------------
    clk_process : process
    begin
        loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Monitor with debug signals
    --------------------------------------------------------------------
    monitor : process
    begin
        wait until rising_edge(clk);
        log(ID_LOG_HDR,
            "T=" & time'image(now)
            & " a_msb=" & std_logic'image(a_msb_sig)
            & " gt1="   & std_logic'image(gt1_sig)
            & " gt2="   & std_logic'image(gt2_sig)
            & " add="   & std_logic'image(add_en_sig)
            & " sub1="  & std_logic'image(sub1_en_sig)
            & " sub2="  & std_logic'image(sub2_en_sig)
            & " shift=" & std_logic'image(shift_a_sig)
            & " store=" & std_logic'image(store_shift_sig)
            & " out_en="& std_logic'image(output_en_sig)
        );
    end process;

    --------------------------------------------------------------------
    -- Test sequence (multi-vector)
    --------------------------------------------------------------------
    tb_process : process
        variable result : unsigned(bit_width-1 downto 0);
        variable timeout : integer;
    begin
        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting robust Blakley testbench");

        -- Loop through test vectors
        for i in test_vectors'range loop
            -- Assign inputs
            A <= std_logic_vector(to_unsigned(test_vectors(i).A_val, bit_width));
            B <= std_logic_vector(to_unsigned(test_vectors(i).B_val, bit_width));
            N <= std_logic_vector(to_unsigned(test_vectors(i).N_val, bit_width));

            -- Reset DUT
            reset_n <= '0';
            wait until rising_edge(clk);
            reset_n <= '1';
            wait until rising_edge(clk);

            -- Pulse bn_enable to start computation
            bn_enable <= '1';
            wait until rising_edge(clk);
            bn_enable <= '0';

            -- Compute reference
            result := to_unsigned((test_vectors(i).A_val * test_vectors(i).B_val) mod test_vectors(i).N_val, bit_width);
            reference_result <= std_logic_vector(result);

            -- Wait for finished_calc
            timeout := 0;
            while finished_calc /= '1' loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
                if timeout > 50000 then
                    report "ERROR: finished_calc timeout for vector " & integer'image(i) severity error;
                    exit;
                end if;
            end loop;

            wait for 10 ns;

            -- Log results
            log(ID_LOG_HDR, "Test vector " & integer'image(i));
            log(ID_LOG_HDR, "  DUT result: " & to_hstring(output));
            log(ID_LOG_HDR, "  REF result: " & to_hstring(reference_result));

            check_value(output, reference_result, ERROR, "Result mismatch");
        end loop;

        log(ID_LOG_HDR, "Simulation complete.");
        std.env.stop;
        wait;
    end process;

end architecture;
