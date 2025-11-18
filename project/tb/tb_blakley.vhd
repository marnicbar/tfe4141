-- tb_blakley.vhd
-- Robust UVVM testbench for Blakley module with safe finished_calc wait and fast simulation

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

       -- DEBUG SIGNALS matching blakely.vhd
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

begin
    --------------------------------------------------------------------
    -- Instantiate DUT
    --------------------------------------------------------------------
    dut : entity work.blakely
        generic map(
            bit_width   => bit_width,
            COUNT_LIMIT => 3
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
    -- Test sequence (unchanged)
    --------------------------------------------------------------------
    tb_process : process
        variable A_int, B_int, N_int : integer := 0;
        variable result : unsigned(bit_width-1 downto 0);
        variable timeout : integer := 0;
    begin
        reset_n   <= '0';
        bn_enable <= '0';
        A <= (others => '0');
        B <= (others => '0');
        N <= (others => '0');
        wait for 10 ns;

        set_log_destination(CONSOLE_AND_LOG);
        log(ID_LOG_HDR, "Starting robust Blakley testbench");

        reset_n <= '1';
        wait until rising_edge(clk);

        bn_enable <= '1';

        A <= (others => '0');  A(0) <= '1';            -- A=1
        B <= (others => '0');  B(1) <= '1';            -- B=2
        N <= (others => '0');  N(7 downto 0) <= x"FF"; -- N=255

        A_int := 1; B_int := 2; N_int := 255;
        result := to_unsigned((A_int * B_int) mod N_int, bit_width);
        reference_result <= std_logic_vector(result);

        timeout := 0;
        while finished_calc /= '1' loop
            wait until rising_edge(clk);
            timeout := timeout + 1;
            if timeout > 500 then
                report "ERROR: finished_calc timeout!" severity error;
                exit;
            end if;
        end loop;

        wait for 10 ns;

        log(ID_LOG_HDR, "DUT result: " & to_hstring(output));
        log(ID_LOG_HDR, "REF result: " & to_hstring(reference_result));

        check_value(output, reference_result, ERROR, "Result mismatch");
        log(ID_LOG_HDR, "Simulation complete.");

        std.env.stop;
        wait;
    end process;

end architecture;
