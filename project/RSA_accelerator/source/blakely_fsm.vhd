library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakely_fsm is
    generic (
        COUNT_LIMIT : natural := 255  -- number of cycles / bit-width
    );
    port (
        clk, reset_n : in std_logic;
        bn_enable    : in std_logic;

        a_msb, gt_n_1, gt_n_2 : in std_logic;

        -- Control outputs to datapath
        load_inputs, shift_a, add_en, sub1_en, sub2_en,
        do_store_shift, output_en : out std_logic;

        -- Status output
        finished_calc : out std_logic;
        dbg_state     : out std_logic_vector(3 downto 0)
    );
end blakely_fsm;

architecture behavioral of blakely_fsm is

    type state_type is (
        read_inputs,
        add_if_needed,
        shift_a_state,
        check_sub1,
        sub1_state,
        check_sub2,
        sub2_state,
        store_result,
        done
    );

    signal state, state_next : state_type := read_inputs;
    signal cnt_int : unsigned(15 downto 0) := (others => '0');

    constant COUNT_LIMIT_U : unsigned(cnt_int'length-1 downto 0) := to_unsigned(COUNT_LIMIT, cnt_int'length);

begin

    ------------------------------------------------------------------------
    -- Sequential: state & counter
    ------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state   <= read_inputs;
            cnt_int <= (others => '0');
        elsif rising_edge(clk) then
            state <= state_next;

            if state = store_result then
                if cnt_int < COUNT_LIMIT_U then
                    cnt_int <= cnt_int + 1;
                end if;
            else
                cnt_int <= cnt_int;  -- keep counter
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Combinational: next state & outputs
    ------------------------------------------------------------------------
    process(state, bn_enable, a_msb, gt_n_1, gt_n_2, cnt_int)
    begin
        -- Defaults
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
                    state_next  <= add_if_needed;
                end if;

            when add_if_needed =>
                if a_msb = '1' then
                    add_en <= '1';
                end if;
                state_next <= check_sub1;

            when check_sub1 =>
                if gt_n_1 = '1' then
                    state_next <= sub1_state;
                else
                    state_next <= check_sub2;
                end if;

            when sub1_state =>
                sub1_en <= '1';
                state_next <= check_sub2;

            when check_sub2 =>
                if gt_n_2 = '1' then
                    state_next <= sub2_state;
                else
                    state_next <= shift_a_state;
                end if;

            when sub2_state =>
                sub2_en <= '1';
                state_next <= shift_a_state;

            when shift_a_state =>
                shift_a <= '1';
                state_next <= store_result;

            when store_result =>
                do_store_shift <= '1';
                if cnt_int = COUNT_LIMIT_U then
                    state_next <= done;
                else
                    state_next <= add_if_needed;  -- next bit of A
                end if;

            when done =>
                output_en <= '1';
                finished_calc <= '1';

        end case;
    end process;

    ------------------------------------------------------------------------
    -- Debug state mapping
    ------------------------------------------------------------------------
    process(state)
    begin
        case state is
            when read_inputs      => dbg_state <= "0000";
            when add_if_needed    => dbg_state <= "0001";
            when check_sub1       => dbg_state <= "0010";
            when sub1_state       => dbg_state <= "0011";
            when check_sub2       => dbg_state <= "0100";
            when sub2_state       => dbg_state <= "0101";
            when shift_a_state    => dbg_state <= "0110";
            when store_result     => dbg_state <= "0111";
            when done             => dbg_state <= "1000";
        end case;
    end process;

end behavioral;
