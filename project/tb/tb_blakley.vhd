library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley is
end tb_blakley;

architecture sim of tb_blakley is

    constant W        : integer := 256;
    constant TMP_BITS : integer := W + 2;
    constant CNT_W    : integer := 9;

    ------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------
    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal b_enable : std_logic := '0';

    signal A, B, N     : unsigned(W-1 downto 0);
    signal result_out  : unsigned(W-1 downto 0);
    signal done_out    : std_logic;

    ------------------------------------------------------------
    -- DEBUG FROM TOP-LEVEL
    ------------------------------------------------------------
    signal dbg_state     : std_logic_vector(2 downto 0);
    signal dbg_reg_temp  : unsigned(TMP_BITS-1 downto 0);
    signal dbg_reg_a     : unsigned(W-1 downto 0);
    signal dbg_reg_b     : unsigned(W-1 downto 0);
    signal dbg_reg_n     : unsigned(W-1 downto 0);
    signal dbg_counter   : unsigned(CNT_W-1 downto 0);
    signal dbg_A_bit     : std_logic;

    ------------------------------------------------------------
    -- Expected result for A*B mod N
    ------------------------------------------------------------
    constant EXPECTED_RES : unsigned(W-1 downto 0) :=
        x"48FF651515CC31E26435A962E514F83284B30565D44494AF9778FAEA134346E9";

begin

    ------------------------------------------------------------
    -- CLOCK GEN
    ------------------------------------------------------------
    clk <= not clk after 5 ns;

    ------------------------------------------------------------
    -- DUT INSTANCE
    ------------------------------------------------------------
    UUT : entity work.blakely
        generic map (
            W        => W,
            TMP_BITS => TMP_BITS,
            CNT_W    => CNT_W
        )
        port map(
            clk         => clk,
            reset_n     => reset_n,
            b_enable    => b_enable,
            A           => A,
            B           => B,
            N           => N,
            result_out  => result_out,
            done_out    => done_out,

            debug_state     => dbg_state,
            debug_reg_temp  => dbg_reg_temp,
            debug_reg_a     => dbg_reg_a,
            debug_reg_b     => dbg_reg_b,
            debug_reg_n     => dbg_reg_n,
            debug_counter   => dbg_counter,
            debug_A_bit     => dbg_A_bit
        );

    ------------------------------------------------------------
    -- LOGGING PROCESS
    ------------------------------------------------------------
    log_proc : process(clk)
    begin
        if rising_edge(clk) then
            log(ID_SEQUENCER,
                "STATE=" & to_hstring(dbg_state) &
                "  count=" & integer'image(to_integer(dbg_counter)) &
                "  A_bit=" & std_logic'image(dbg_A_bit));

            log(ID_SEQUENCER,
                "TEMP= x" & to_hstring(dbg_reg_temp));
        end if;
    end process;

    ------------------------------------------------------------
    -- STIMULUS
    ------------------------------------------------------------
    stim : process
    begin
        log(ID_LOG_HDR, "Starting FULL Blakley top-level testbench");

        --------------------------------------------------------
        -- RESET
        --------------------------------------------------------
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait until rising_edge(clk);

        --------------------------------------------------------
        -- TEST VECTORS
        --------------------------------------------------------
        A <= x"0123456789ABCDEFFEDCBA987654321000112233445566778899AABBCCDDEEFF";
        B <= x"AAAA5555AAAA55550123456789ABCDEFFFFFFFFFFFFFFFFF0000000000000001";
        N <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";

        wait until rising_edge(clk);

        --------------------------------------------------------
        -- START
        --------------------------------------------------------
        b_enable <= '1';
        wait until rising_edge(clk);
        b_enable <= '0';

        log(ID_SEQUENCER, "b_enable pulsed computation started.");

        --------------------------------------------------------
        -- WAIT FOR COMPLETION
        --------------------------------------------------------
        wait until done_out = '1';
        wait until rising_edge(clk);

        log(ID_SEQUENCER, "Computation finished. Checking result...");

        --------------------------------------------------------
        -- VERIFICATION
        --------------------------------------------------------
        check_value(
            result_out, EXPECTED_RES, ERROR,
            "Blakley top-level result mismatch!"
        );

        log(ID_LOG_HDR,
            "TEST PASSED: Hardware matches Blakley golden model");

        std.env.stop;
        wait;
    end process;

end architecture;
