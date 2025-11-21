library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakley_datapath is
    generic (
        W        : integer := 256; -- operand width
        TMP_BITS : integer := 256 + 2; -- temp width (W + 2)
        CNT_W    : integer := 9 -- enough to count 0..256
    );
    port (
        ---------------- Clock & Reset ----------------
        clk     : in std_logic;
        reset_n : in std_logic;

        ---------------- Flags ------------------------
        temp_in_bounds : out std_logic;
        bit_done       : out std_logic;

        ---------------- Controls ---------------------
        read_inputs : in std_logic;
        process_bit : in std_logic;
        comp_sub_1  : in std_logic; -- legacy, podemos apagar 
        comp_sub_2  : in std_logic; -- podemos apagar é do algoritmo antigo
        output      : in std_logic;

        ---------------- Inputs -----------------------
        A : in unsigned(W - 1 downto 0);
        B : in unsigned(W - 1 downto 0);
        N : in unsigned(W - 1 downto 0);

        ---------------- Output -----------------------
        result : out unsigned(W - 1 downto 0);

        ---------------- Debug Outputs ----------------
        dbg_reg_temp : out unsigned(TMP_BITS - 1 downto 0);
        dbg_reg_a    : out unsigned(W - 1 downto 0);
        dbg_reg_b    : out unsigned(W - 1 downto 0);
        dbg_reg_n    : out unsigned(W - 1 downto 0);
        dbg_counter  : out unsigned(CNT_W - 1 downto 0);
        dbg_A_bit    : out std_logic
    );
end blakley_datapath;

architecture rtl of blakley_datapath is

    signal reg_a          : unsigned(W - 1 downto 0);
    signal reg_b          : unsigned(W - 1 downto 0);
    signal reg_n          : unsigned(W - 1 downto 0);
    signal reg_temp       : unsigned(TMP_BITS - 1 downto 0);
    signal out_reg        : unsigned(W - 1 downto 0);
    signal bits_A_counter : unsigned(CNT_W - 1 downto 0);
    signal A_bit          : std_logic;

begin

    --------------------------------------------------------------------
    -- Sequential logic
    --------------------------------------------------------------------
    process (clk, reset_n)
        variable tmp_var : unsigned(TMP_BITS - 1 downto 0);
        variable A_bit_v : std_logic;
        variable N_ext   : unsigned(TMP_BITS - 1 downto 0);
    begin
        if reset_n = '0' then
            reg_a          <= (others => '0');
            reg_b          <= (others => '0');
            reg_n          <= (others => '0');
            reg_temp       <= (others => '0');
            out_reg        <= (others => '0');
            bits_A_counter <= (others => '0');
            A_bit          <= '0';

        elsif rising_edge(clk) then

            -- LOAD INPUTS
            if read_inputs = '1' then
                reg_a          <= A;
                reg_b          <= B;
                reg_n          <= N;
                reg_temp       <= (others => '0');
                bits_A_counter <= (others => '0');
                A_bit          <= '0';

                -- MAIN BLAKLEY STEP FOR ONE BIT
            elsif process_bit = '1' then
                -- Extend N once in this cycle
                N_ext := resize(reg_n, TMP_BITS);

                -- R' := 2R
                tmp_var := shift_left(reg_temp, 1);

                -- capture current MSB of A
                A_bit_v := reg_a(W - 1);

                -- shift A left for next cycle (MSB first processing)
                reg_a <= reg_a(W - 2 downto 0) & '0';

                -- if this bit of A is '1', add B
                if A_bit_v = '1' then
                    tmp_var := tmp_var + resize(reg_b, TMP_BITS);
                end if;

                -- t up to two conditional subtractions
                if tmp_var >= N_ext then
                    tmp_var := tmp_var - N_ext;
                    if tmp_var >= N_ext then
                        tmp_var := tmp_var - N_ext;
                    end if;
                end if;

                reg_temp       <= tmp_var;
                bits_A_counter <= bits_A_counter + 1;
                A_bit          <= A_bit_v; -- debug only

                -- LATCH FINAL RESULT
            elsif output = '1' then
                out_reg <= reg_temp(W - 1 downto 0);

            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Combinatorial logic
    --------------------------------------------------------------------
    temp_in_bounds <= '1' when reg_temp >= resize(reg_n, TMP_BITS) else
                      '0';
    bit_done <= '1' when bits_A_counter = to_unsigned(W - 1, CNT_W) else
                '0';
    result <= out_reg;

    -- Debug exports
    dbg_reg_temp <= reg_temp;
    dbg_reg_a    <= reg_a;
    dbg_reg_b    <= reg_b;
    dbg_reg_n    <= reg_n;
    dbg_counter  <= bits_A_counter;
    dbg_A_bit    <= A_bit;

end architecture;
