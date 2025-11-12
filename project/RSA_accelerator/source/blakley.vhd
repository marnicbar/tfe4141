----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/29/2025 03:22:17 AM
-- Design Name: 
-- Module Name: blakely - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

-- ===============================================================
--  PACKAGE: shared type definitions (e.g. FSM state)
-- ===============================================================
package blakely_pkg is
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
end package blakely_pkg;

package body blakely_pkg is
end package body blakely_pkg;

-- ===============================================================
--  ENTITY: blakely
-- ===============================================================
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.blakely_pkg.all; -- bring in the enum type

entity blakely is
    generic (
        bit_width : positive := 256 -- we are working with 256 bits per word
    );
    port (
        -- debug
        -- pragma translate_off
        dbg_state : out state_type;
        -- pragma translate_on

        -- inputs
        A : in std_logic_vector(bit_width - 1 downto 0);
        B : in std_logic_vector(bit_width - 1 downto 0);
        N : in std_logic_vector(bit_width - 1 downto 0);

        -- misc
        clk     : in std_logic;
        reset_n : in std_logic;

        -- external control signals
        bn_enable : in std_logic;

        -- outputs
        Output        : out std_logic_vector(bit_width - 1 downto 0);
        finished_calc : out std_logic
    );
end blakely;

-- ===============================================================
--  ARCHITECTURE
-- ===============================================================
architecture Behavioral of blakely is

    ------------------------------------------------------------------------
    -- Internal registers 
    ------------------------------------------------------------------------
    signal reg_a, reg_b, reg_n, reg_temp, reg_out : unsigned(bit_width - 1 downto 0);

    ------------------------------------------------------------------------
    -- FSM state declarations
    ------------------------------------------------------------------------
    signal state, state_next : state_type;

    -- Save the most significant bit from A
    signal a_msb : std_logic;

    -- Signal to help verify if the product of the addition state is bigger than N
    signal temp_sub : unsigned(bit_width downto 0); -- one extra bit for carry

    -- Iteration counter
    signal cnt_int : unsigned(8 downto 0) := (others => '0'); -- 9 bits can count up to 511

    -- Finished computation
    signal done_calc_int : std_logic := '0';

begin

    main_statem_proc : process (clk, reset_n)
    begin
        -- asynchronous reset
        if reset_n = '0' then
            reg_a    <= (others => '0');
            reg_b    <= (others => '0');
            reg_n    <= (others => '0');
            reg_temp <= (others => '0');
            -- reg_out  <= (others => '0');
            done_calc_int <= '0';
            state         <= read_inputs;
            cnt_int       <= (others => '0');

        elsif rising_edge(clk) then
            state <= state_next;

            case state is

                    ------------------------------------------------------------
                    -- READ INPUTS
                    ------------------------------------------------------------
                when read_inputs =>
                    if bn_enable = '1' then
                        reg_a      <= unsigned(A);
                        reg_b      <= unsigned(B);
                        reg_n      <= unsigned(N);
                        reg_temp   <= (others => '0');
                        cnt_int    <= (others => '0');
                        state_next <= initial_shifting;
                    else
                        state_next <= read_inputs;
                    end if;

                    ------------------------------------------------------------
                    -- INITIAL SHIFTING
                    ------------------------------------------------------------
                when initial_shifting =>
                    a_msb      <= reg_a(bit_width - 1);
                    reg_a      <= reg_a(bit_width - 2 downto 0) & '0';
                    state_next <= addition;

                    ------------------------------------------------------------
                    -- ADDITION
                    ------------------------------------------------------------
                when addition =>
                    if a_msb = '1' then
                        reg_temp <= reg_temp + reg_b;
                    else
                        reg_temp <= reg_temp;
                    end if;
                    state_next <= comp1;

                    ------------------------------------------------------------
                    -- COMP1
                    ------------------------------------------------------------
                when comp1 =>
                    temp_sub <= ('0' & reg_temp) - ('0' & reg_n);
                    if temp_sub(bit_width) = '0' then
                        state_next <= sub1;
                    else
                        state_next <= store_shift;
                    end if;

                    ------------------------------------------------------------
                    -- SUB1
                    ------------------------------------------------------------
                when sub1 =>
                    reg_temp   <= temp_sub(bit_width - 1 downto 0);
                    state_next <= comp2;

                    ------------------------------------------------------------
                    -- COMP2
                    ------------------------------------------------------------
                when comp2 =>
                    temp_sub <= ('0' & reg_temp) - ('0' & reg_n);
                    if temp_sub(bit_width) = '0' then
                        state_next <= sub2;
                    else
                        state_next <= store_shift;
                    end if;

                    ------------------------------------------------------------
                    -- SUB2
                    ------------------------------------------------------------
                when sub2 =>
                    reg_temp   <= temp_sub(bit_width - 1 downto 0);
                    state_next <= store_shift;

                    ------------------------------------------------------------
                    -- STORE_SHIFT
                    ------------------------------------------------------------
                when store_shift =>
                    reg_out  <= reg_temp;
                    reg_temp <= reg_temp(bit_width - 2 downto 0) & '0';
                    if cnt_int = to_unsigned(bit_width - 1, cnt_int'length) then
                        state_next <= saida;
                    else
                        cnt_int    <= cnt_int + 1;
                        state_next <= initial_shifting;
                    end if;

                    ------------------------------------------------------------
                    -- SAIDA (OUTPUT)
                    ------------------------------------------------------------
                when saida =>
                    reg_out       <= reg_temp;
                    done_calc_int <= '1';
                    state_next    <= saida;
            end case;
        end if;
    end process main_statem_proc;

    -- Outputs
    Output        <= std_logic_vector(reg_out);
    finished_calc <= done_calc_int;

    -- pragma translate_off
    dbg_state <= state;
    -- pragma translate_on

end Behavioral;
