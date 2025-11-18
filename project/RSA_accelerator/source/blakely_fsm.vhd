-- blakely_fsm.vhd (modified: added COUNT_LIMIT generic)
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakely_fsm is
    generic (
        COUNT_LIMIT : natural := 255  -- test-time override allowed
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
        initial_shifting,
        addition,
        comp1,
        sub1,
        comp2,
        sub2,
        store_shift,
        saida
    );

    -- make counter wide enough (16 bits)
    signal state, state_next : state_type := read_inputs;
    signal cnt_int : unsigned(15 downto 0) := (others => '0');

    constant COUNT_LIMIT_U : unsigned(cnt_int'length - 1 downto 0) := to_unsigned(COUNT_LIMIT, cnt_int'length);

begin

    ------------------------------------------------------------------------
    -- Sequential process: State register & counter update (clocked)
    ------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state   <= read_inputs;
            cnt_int <= (others => '0');
        elsif rising_edge(clk) then
            state <= state_next;

            -- Counter increments only while in store_shift
            if state = store_shift then
                if cnt_int < COUNT_LIMIT_U then
                    cnt_int <= cnt_int + 1;
                end if;
            else
                -- optional: keep counter (or reset it) when leaving store_shift
                -- keep it as-is to preserve behavior; not required to reset here
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Combinational process: Next state & control signals (reset-aware)
    ------------------------------------------------------------------------
    process(state, bn_enable, a_msb, gt_n_1, gt_n_2, cnt_int, reset_n)
    begin
        if reset_n = '0' then
            -- Force reset outputs and next state immediately
            state_next      <= read_inputs;
            load_inputs     <= '0';
            shift_a         <= '0';
            add_en          <= '0';
            sub1_en         <= '0';
            sub2_en         <= '0';
            do_store_shift  <= '0';
            output_en       <= '0';
            finished_calc   <= '0';
        else
            -- Default outputs
            load_inputs     <= '0';
            shift_a         <= '0';
            add_en          <= '0';
            sub1_en         <= '0';
            sub2_en         <= '0';
            do_store_shift  <= '0';
            output_en       <= '0';
            finished_calc   <= '0';
            state_next      <= state;

            -- FSM next-state logic
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
                    if cnt_int = COUNT_LIMIT_U then
                        state_next <= saida;
                    else
                        state_next <= store_shift;  -- stay until counter done
                    end if;

                when saida =>
                    output_en     <= '1';
                    finished_calc <= '1';
            end case;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- dbg_state mapping (internal state -> 4-bit code visible to TB)
    ------------------------------------------------------------------------
    process(state)
    begin
        case state is
            when read_inputs         => dbg_state <= "0000"; -- 0
            when initial_shifting    => dbg_state <= "0001"; -- 1
            when addition            => dbg_state <= "0010"; -- 2
            when comp1               => dbg_state <= "0011"; -- 3
            when sub1                => dbg_state <= "0100"; -- 4
            when comp2               => dbg_state <= "0101"; -- 5
            when sub2                => dbg_state <= "0110"; -- 6
            when store_shift         => dbg_state <= "0111"; -- 7
            when saida               => dbg_state <= "1000"; -- 8
        end case;
    end process;

end behavioral;
