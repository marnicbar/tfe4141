library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakely_fsm is
    port (
        clk, reset_n : in std_logic;
        bn_enable    : in std_logic;

        a_msb, gt_n_1, gt_n_2 : in std_logic;

        load_inputs, shift_a, add_en, sub1_en, sub2_en,
        do_store_shift, output_en : out std_logic;

        finished_calc : out std_logic;
        dbg_state     : out std_logic_vector(3 downto 0)
    );
end blakely_fsm;

architecture behavioral of blakely_fsm is

    type state_type is (
        read_inputs,
        initial_shifting,
        addition,
        comp1,
        sub1,
        comp2,
        sub2,
        store_shift,
        saida
    );

    signal state, state_next : state_type;
    signal cnt_int : unsigned(8 downto 0) := (others => '0');

begin

    ------------------------------------------------------------
    -- Sequential process: state register & counter update
    ------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state   <= read_inputs;
            cnt_int <= (others => '0');
        elsif rising_edge(clk) then
            state <= state_next;
            if state = store_shift then
                if cnt_int < to_unsigned(255, cnt_int'length) then
                    cnt_int <= cnt_int + 1;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------
    -- Combinational control logic
    ------------------------------------------------------------
    process(state, bn_enable, a_msb, gt_n_1, gt_n_2, cnt_int)
    begin
        -- default outputs
        load_inputs     <= '0';
        shift_a         <= '0';
        add_en          <= '0';
        sub1_en         <= '0';
        sub2_en         <= '0';
        do_store_shift  <= '0';
        output_en       <= '0';
        finished_calc   <= '0';
        state_next      <= state;

        case state is
            when read_inputs =>
                if bn_enable = '1' then
                    load_inputs <= '1';
                    state_next  <= initial_shifting;
                end if;

            when initial_shifting =>
                shift_a    <= '1';
                state_next <= addition;

            when addition =>
                if a_msb = '1' then
                    add_en <= '1';
                end if;
                state_next <= comp1;

            when comp1 =>
                if gt_n_1 = '1' then
                    state_next <= sub1;
                else
                    state_next <= store_shift;
                end if;

            when sub1 =>
                sub1_en    <= '1';
                state_next <= comp2;

            when comp2 =>
                if gt_n_2 = '1' then
                    state_next <= sub2;
                else
                    state_next <= store_shift;
                end if;

            when sub2 =>
                sub2_en    <= '1';
                state_next <= store_shift;

            when store_shift =>
                do_store_shift <= '1';
                if cnt_int = to_unsigned(255, cnt_int'length) then
                    state_next <= saida;
                else
                    state_next <= initial_shifting;
                end if;

            when saida =>
                output_en     <= '1';
                finished_calc <= '1';
        end case;
    end process;

 

end behavioral;
