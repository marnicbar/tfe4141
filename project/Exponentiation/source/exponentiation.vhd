--course: DDS1 Autumn 2025
--Student: Daniel Vangen Horne

--FSM for general module of the RSA core
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
-- Removed use of ieee.std_logic_unsigned (conflicts with numeric_std).
use ieee.numeric_std.all;

entity controller is
    generic (
        bit_width : positive := 16
    );
    port (
        -- misc
        clk         : in  std_logic;
        reset_n     : in  std_logic;

        -- FSM takes no data-signals as input, only 1-bit control signals

        -- external control signals ------------------------------------
        -- input control
        valid_in    : in  std_logic;  -- aka: msgin_valid
        ready_in    : out std_logic;  -- aka: msgin_ready (output from controller)
        -- output control
        ready_out   : in  std_logic;  -- aka: msgout_ready (input to controller)
        valid_out   : out std_logic;  -- aka: msgout_valid

        -- internal control signals
        e_bit           : in  std_logic;   -- the LSB of register LSR_e
        LS_e            : out std_logic;   -- signal which left shift key_e
        e_counter_end   : in  std_logic;   -- tells the FSM when counter >= 255
        initialize_regs : out std_logic;   -- loads initial values into C, P, LSR_e and e_counter
        Blak_enable     : out std_logic;   -- signal that tells Blakley module to start computation
        Blak_finished   : in  std_logic;   -- signal that Blakley module is finished
        pc_select       : out std_logic    -- signal for which of P or C that are using the blakley module
    );
end controller;

architecture Behavioral of controller is

    type state_type is (
        -- states associated with handshake data in
        is_in_valid,
        set_ready,
        initialize,
        read_e_bit,
        -- states associated with computation M*e mod n
        calc_C,
        calc_P,
        -- states associated with handshake data out
        is_out_ready,
        out_ready
    );
    signal state, state_next : state_type;

begin

    -- Combinational process: determine outputs and next state
    main_statem_proc : process (state, valid_in, ready_out, e_bit, Blak_finished, e_counter_end)
    begin
        -- default values (prevent latches)
        initialize_regs <= '0';
        ready_in        <= '0';
        valid_out       <= '0';
        pc_select       <= '0';
        LS_e            <= '0';
        Blak_enable     <= '0';

        state_next <= is_in_valid; -- default next state

        -- main implementation of state machine (combinational)
        case state is

            -- State 1/8:
            when is_in_valid =>
                if valid_in = '1' then
                    state_next <= set_ready;
                else
                    state_next <= is_in_valid;
                end if;

            -- State 2/8:
            when set_ready =>
                ready_in <= '1';    -- msgin_ready = 1
                state_next <= initialize;

            -- State 3/8:
            when initialize =>
                ready_in <= '0';
                initialize_regs <= '1'; -- load registers
                state_next <= read_e_bit;

            -- State 4/8:
            when read_e_bit =>
                LS_e <= '0';            -- stop left shifting key_e (until needed)
                initialize_regs <= '0';
                Blak_enable <= '1';     -- start Blakley computation
                if e_bit = '1' then
                    pc_select <= '1';
                    state_next <= calc_C;
                else
                    pc_select <= '0';
                    state_next <= calc_P;
                end if;

            -- State 5/8:
            when calc_C =>
                -- wait for Blakley module to finish
                if Blak_finished = '1' then
                    state_next <= calc_P;
                else
                    state_next <= calc_C;
                end if;

            -- State 6/8:
            when calc_P =>
                if Blak_finished = '1' then
                    if e_counter_end = '1' then
                        valid_out <= '1';
                        state_next <= is_out_ready;
                    else
                        LS_e <= '1';  -- left shift key_e
                        state_next <= read_e_bit;
                    end if;
                else
                    state_next <= calc_P;
                end if;

            -- State 7/8:
            when is_out_ready =>
                -- Wait for external ready_out to accept the result
                if ready_out = '1' then
                    -- handshake complete, return to initial input-wait state
                    valid_out <= '0';
                    state_next <= is_in_valid;
                else
                    -- remain in this state until the receiver is ready
                    valid_out <= '1';
                    state_next <= is_out_ready;
                end if;

            -- State 8/8 (out_ready) -- optional explicit final
            when out_ready =>
                -- treat same as is_out_ready for safety
                if ready_out = '1' then
                    valid_out <= '0';
                    state_next <= is_in_valid;
                else
                    valid_out <= '1';
                    state_next <= out_ready;
                end if;

            when others =>
                -- safe default fallback
                initialize_regs <= '0';
                ready_in        <= '0';
                valid_out       <= '0';
                pc_select       <= '0';
                LS_e            <= '0';
                Blak_enable     <= '0';
                state_next      <= is_in_valid;
        end case;
    end process main_statem_proc;


    -- Sequential process: update state on clock with asynchronous reset
    update_state : process (reset_n, clk)
    begin
        if reset_n = '0' then
            state <= is_in_valid;
        elsif rising_edge(clk) then
            state <= state_next;
        end if;
    end process update_state;

end Behavioral;
