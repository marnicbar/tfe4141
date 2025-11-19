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
        shift_a        : in std_logic;
        add_en         : in std_logic;
        sub1_en        : in std_logic;
        sub2_en        : in std_logic;
        do_store_shift : in std_logic;  -- <<<<< add this
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
    signal reg_a, reg_b, reg_n, reg_temp, reg_out : unsigned(bit_width - 1 downto 0);
    signal temp_sub : unsigned(bit_width downto 0);
begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_a    <= (others => '0');
            reg_b    <= (others => '0');
            reg_n    <= (others => '0');
            reg_temp <= (others => '0');
            reg_out  <= (others => '0');
        elsif rising_edge(clk) then
            if load_inputs = '1' then
                reg_a <= unsigned(A);
                reg_b <= unsigned(B);
                reg_n <= unsigned(N);
                reg_temp <= (others => '0');
            end if;

            if shift_a = '1' then
                reg_a <= reg_a(bit_width - 2 downto 0) & '0';
            end if;

            if add_en = '1' then
                reg_temp <= reg_temp + reg_b;
            end if;

            if sub1_en = '1' then
                reg_temp <= temp_sub(bit_width - 1 downto 0);
            end if;

            if sub2_en = '1' then
                reg_temp <= temp_sub(bit_width - 1 downto 0);
            end if;

            if do_store_shift = '1' then
                reg_out  <= reg_temp;
                reg_temp <= reg_temp(bit_width - 2 downto 0) & '0';
            end if;

            if output_en = '1' then
                reg_out <= reg_temp;
            end if;
        end if;
    end process;

    -- combinational
    a_msb  <= reg_a(bit_width - 1);
    temp_sub <= ('0' & reg_temp) - ('0' & reg_n);
    gt_n_1 <= not temp_sub(bit_width);  -- '1' if reg_temp >= N
    gt_n_2 <= not temp_sub(bit_width);

    Output <= std_logic_vector(reg_out);

end behavioral;
