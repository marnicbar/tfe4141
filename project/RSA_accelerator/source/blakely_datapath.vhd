library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakely_datapath is
    generic (
        bit_width : positive := 256
    );
    port (
        clk    : in std_logic;
        reset_n : in std_logic;

        -- Inputs
        A : in std_logic_vector(bit_width-1 downto 0);
        B : in std_logic_vector(bit_width-1 downto 0);
        N : in std_logic_vector(bit_width-1 downto 0);

        -- Control signals from FSM
        load_inputs    : in std_logic;
        shift_a        : in std_logic;  -- used as "shift step" (after add)
        add_en         : in std_logic;  -- enable add of reg_b into reg_temp if a_msb=1
        sub1_en        : in std_logic;
        sub2_en        : in std_logic;
        do_store_shift : in std_logic;
        output_en      : in std_logic;

        -- Feedback to FSM
        a_msb  : out std_logic;
        gt_n_1 : out std_logic;
        gt_n_2 : out std_logic;

        -- Output
        Output : out std_logic_vector(bit_width-1 downto 0)
    );
end blakely_datapath;

architecture behavioral of blakely_datapath is
    signal reg_a, reg_b, reg_n, reg_temp, reg_out : unsigned(bit_width-1 downto 0) := (others => '0');
begin

    ----------------------------------------------------------------
    -- Clocked process (variables declared in header for synthesis)
    ----------------------------------------------------------------
    process(clk, reset_n)
        -- variables (must be declared here — synthesizable)
        variable v_a    : unsigned(bit_width-1 downto 0);
        variable v_b    : unsigned(bit_width-1 downto 0);
        variable v_n    : unsigned(bit_width-1 downto 0);
        variable v_temp : unsigned(bit_width-1 downto 0);

        variable v_sub      : unsigned(bit_width downto 0);  -- temp subtraction (temp - n)
        variable v_sub_b    : unsigned(bit_width downto 0);  -- b_shifted - n
        variable b_shifted  : unsigned(bit_width-1 downto 0);
    begin
        if reset_n = '0' then
            reg_a    <= (others => '0');
            reg_b    <= (others => '0');
            reg_n    <= (others => '0');
            reg_temp <= (others => '0');
            reg_out  <= (others => '0');
        elsif rising_edge(clk) then

            -- read current state into variables
            v_a    := reg_a;
            v_b    := reg_b;
            v_n    := reg_n;
            v_temp := reg_temp;

            -- Load inputs: load registers and clear temp
            if load_inputs = '1' then
                v_a    := unsigned(A);
                v_b    := unsigned(B);
                v_n    := unsigned(N);
                v_temp := (others => '0');
            end if;

            -- === Conditional addition (add B into temp if current A bit = '1') ===
            if add_en = '1' and a_msb = '1' then
                v_temp := v_temp + v_b;
            end if;

            -- === Modular subtraction for temp (when FSM requests) ===
            if sub1_en = '1' or sub2_en = '1' then
                v_sub := ('0' & v_temp) - ('0' & v_n);
                -- if v_temp >= v_n then MSB of v_sub (index bit_width) is '0'
                if v_sub(bit_width) = '0' then
                    v_temp := v_sub(bit_width-1 downto 0);
                end if;
            end if;

            -- === Shift step: shift A right (consume one bit) and shift B left (double B) ===
            if shift_a = '1' then
                -- shift A right (LSB-first processing)
                v_a := '0' & v_a(bit_width-1 downto 1);

                -- shift B left by 1
                b_shifted := v_b(bit_width-2 downto 0) & '0';

                -- reduce B modulo N after shift: if b_shifted >= v_n then b_shifted := b_shifted - v_n
                v_sub_b := ('0' & b_shifted) - ('0' & v_n);
                if v_sub_b(bit_width) = '0' then
                    v_b := v_sub_b(bit_width-1 downto 0);
                else
                    v_b := b_shifted;
                end if;
            end if;

            -- === Store / output (observability) ===
            if do_store_shift = '1' then
                reg_out <= v_temp;
            end if;

            if output_en = '1' then
                reg_out <= v_temp;
            end if;

            -- commit variable updates to signals at end of cycle
            reg_a    <= v_a;
            reg_b    <= v_b;
            reg_n    <= v_n;
            reg_temp <= v_temp;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Combinational feedback for FSM (synthesizable)
    ----------------------------------------------------------------
    a_msb  <= reg_a(0);  -- current bit (LSB-first)
    gt_n_1 <= '1' when reg_temp >= reg_n else '0';
    gt_n_2 <= '1' when reg_temp >= reg_n else '0';

    Output <= std_logic_vector(reg_out);

end behavioral;
