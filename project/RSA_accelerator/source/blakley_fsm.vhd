library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakley_controller is
    port(
        clk     : in std_logic;
        rst_n   : in std_logic;  -- active low

        b_enable : in std_logic; -- starts the Blakley computation

        bit_done       : in std_logic; -- true when all bits of A processed
        temp_in_bounds : in std_logic; -- podemos apagar

        ----------------------------Control signals----------------------
        read_inputs  : out std_logic;
        process_bit  : out std_logic;
        comp_sub_1   : out std_logic;
        comp_sub_2   : out std_logic;
        output_en    : out std_logic;
        -----------------------------------------------------------------
        done         : out std_logic
    );
end blakley_controller;

architecture fsm of blakley_controller is

    type state_type is (INPUT, PROCESS_S, OUTPUT_S);

    signal state    : state_type := INPUT;
    signal done_reg : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- FSM
    --------------------------------------------------------------------
    BLAK_FSM : process(clk, rst_n)
    begin
        if rst_n = '0' then
            state    <= INPUT;
            done_reg <= '0';

        elsif rising_edge(clk) then
            case state is

                when INPUT =>
                    done_reg <= '0';
                    if b_enable = '1' then
                        -- next cycle we start shifting bits
                        state <= PROCESS_S;
                    end if;

                when PROCESS_S =>
                    if bit_done = '1' then
                        state <= OUTPUT_S;
                    else
                        state <= PROCESS_S;
                    end if;

                when OUTPUT_S =>
                    done_reg <= '1';
                    -- stay here until reset (one-shot op)
                    state <= OUTPUT_S;

                when others =>
                    state <= INPUT;

            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- CONTROL SIGNALS
    --------------------------------------------------------------------
    read_inputs <= '1' when state = INPUT   else '0';
    process_bit <= '1' when state = PROCESS_S else '0';

    -- No external subtract control anymore – handled inside datapath
    comp_sub_1  <= '0';
    comp_sub_2  <= '0';

    output_en   <= '1' when state = OUTPUT_S else '0';
    done        <= done_reg;

end architecture;
