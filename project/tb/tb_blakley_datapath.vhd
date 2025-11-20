library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_blakley_datapath is
end entity;

architecture sim of tb_blakley_datapath is

    constant W        : integer := 256;
    constant TMP_BITS : integer := W + 2;
    constant CNT_W    : integer := 9;

    -- DUT signals
    signal clk            : std_logic := '0';
    signal reset_n        : std_logic := '0';

    signal read_inputs    : std_logic := '0';
    signal process_bit    : std_logic := '0';
    signal comp_sub_1     : std_logic := '0';
    signal comp_sub_2     : std_logic := '0';
    signal output_en      : std_logic := '0';

    signal temp_in_bounds : std_logic;
    signal bit_done       : std_logic;

    signal A, B, N        : unsigned(W-1 downto 0);
    signal result         : unsigned(W-1 downto 0);

    -- Debug wires from DUT
    signal dbg_reg_temp : unsigned(TMP_BITS-1 downto 0);
    signal dbg_reg_a    : unsigned(W-1 downto 0);
    signal dbg_reg_b    : unsigned(W-1 downto 0);
    signal dbg_reg_n    : unsigned(W-1 downto 0);
    signal dbg_counter  : unsigned(CNT_W-1 downto 0);
    signal dbg_A_bit    : std_logic;

    constant ZERO256 : unsigned(W-1 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Golden Blakley model: (A * B) mod N using the same algorithmic
    -- structure as the datapath, but purely behavioral.
    --------------------------------------------------------------------
    function golden_blakley(Ax, Bx, Nx : unsigned) return unsigned is
        variable R     : unsigned(TMP_BITS-1 downto 0) := (others => '0');
        variable N_ext : unsigned(TMP_BITS-1 downto 0);
        variable B_ext : unsigned(TMP_BITS-1 downto 0);
    begin
        assert Nx /= ZERO256
          report "golden_blakley: modulus N is zero!" severity failure;

        N_ext := resize(Nx, TMP_BITS);
        B_ext := resize(Bx, TMP_BITS);

        -- Process bits of A from MSB (W-1) to LSB (0)
        for i in 0 to W-1 loop
            -- R := 2R
            R := shift_left(R, 1);

            -- If current bit of A is 1, R := R + B
            if Ax(W-1 - i) = '1' then
                R := R + B_ext;
            end if;

            -- At most two reductions by N_ext (Blakley bound 3N-3)
            if R >= N_ext then
                R := R - N_ext;
            end if;
            if R >= N_ext then
                R := R - N_ext;
            end if;
        end loop;

        return R(W-1 downto 0);
    end function;

begin

    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    DUT: entity work.blakley_datapath
        generic map(
            W        => W,
            TMP_BITS => TMP_BITS,
            CNT_W    => CNT_W
        )
        port map(
            clk            => clk,
            reset_n        => reset_n,
            read_inputs    => read_inputs,
            process_bit    => process_bit,
            comp_sub_1     => comp_sub_1,
            comp_sub_2     => comp_sub_2,
            output         => output_en,
            A              => A,
            B              => B,
            N              => N,
            temp_in_bounds => temp_in_bounds,
            bit_done       => bit_done,
            result         => result,

            dbg_reg_temp => dbg_reg_temp,
            dbg_reg_a    => dbg_reg_a,
            dbg_reg_b    => dbg_reg_b,
            dbg_reg_n    => dbg_reg_n,
            dbg_counter  => dbg_counter,
            dbg_A_bit    => dbg_A_bit
        );

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk <= not clk after 5 ns;

    --------------------------------------------------------------------
    -- TEST SEQUENCE – Blakley FSM emulation
    --------------------------------------------------------------------
    stim_proc : process
        variable expected : unsigned(W-1 downto 0);
    begin

        log(ID_LOG_HDR, "Starting Blakley datapath testbench");

        ----------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------
        reset_n <= '0';
        wait for 50 ns;
        reset_n <= '1';
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- Load Test Vectors
        ----------------------------------------------------------------
        A <= x"0123456789ABCDEF_FEDCBA9876543210_0011223344556677_8899AABBCCDDEEFF";
        B <= x"AAAA5555AAAA5555_0123456789ABCDEF_FFFFFFFFFFFFFFFF_0000000000000001";
        N <= x"FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF";

        ----------------------------------------------------------------
        -- LOAD INPUTS INTO DUT
        ----------------------------------------------------------------
        read_inputs <= '1';
        wait until rising_edge(clk);
        read_inputs <= '0';
        wait until rising_edge(clk);

        check_value(dbg_reg_a, A, ERROR, "reg_a mismatch");
        check_value(dbg_reg_b, B, ERROR, "reg_b mismatch");
        check_value(dbg_reg_n, N, ERROR, "reg_n mismatch");

        ----------------------------------------------------------------
        -- PERFORM 256 ITERATIONS OF BLAKLEY ALGORITHM
        ----------------------------------------------------------------
        for i in 0 to W-1 loop

            -- STEP 1: PROCESS BIT
            process_bit <= '1';
            wait until rising_edge(clk);
            process_bit <= '0';
            wait until rising_edge(clk);

            -- STEP 2: FIRST REDUCTION
            if temp_in_bounds = '1' then
                comp_sub_1 <= '1';
                wait until rising_edge(clk);
                comp_sub_1 <= '0';
                wait until rising_edge(clk);
            end if;

            -- STEP 3: SECOND REDUCTION
            if temp_in_bounds = '1' then
                wait until rising_edge(clk);
                comp_sub_2 <= '1';
                wait until rising_edge(clk);
                comp_sub_2 <= '0';
                wait until rising_edge(clk);
            end if;

        end loop;

        ----------------------------------------------------------------
        -- OUTPUT RESULT
        ----------------------------------------------------------------
        output_en <= '1';
        wait until rising_edge(clk);
        output_en <= '0';
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- GOLDEN MODEL (Blakley)
        ----------------------------------------------------------------
        expected := golden_blakley(A, B, N);

        check_value(result, expected, ERROR, "Blakley datapath result mismatch!");
        log(ID_LOG_HDR, "TEST PASSED: Hardware matches Blakley golden model");

        std.env.stop;
        wait;
    end process;

end architecture;
