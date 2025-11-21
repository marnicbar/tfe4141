--course: DDS1 Autumn 2025
--Student: Daniel Vangen Horne

--There are 3 regions to consider: 
--The Blakley module
--The general module, which the Blakley module is inside of (and interfaces with)
--the outside of the general module. The general module interfaces with this region also.

--The Blakley module + the general module, make up "the RSA core".

--The following code defines behaviour the General module only;

--inport libraries:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mod_exp_pkg.all; -- bring in the enum type

--"entity" defines input and output interfaces, and generics/parameters.
--In this case, this means interface towards the outside of the RSA core, 
--and interface to the blakley module.
entity exponentiation is
    generic (--these are some constant integers we define.
        C_block_size     : integer := 256;
        counter_bit_size : integer := 8 --the counter needs 8 bits, to count to 256, for the bits of e.
    );
    port (
        ---------------------------------------------
        -- Only for use in testbenches and debugging:
        ---------------------------------------------
        -- pragma translate_off
        dbg_RSR_e               : out std_logic_vector(C_block_size - 1 downto 0); --Right shift register for key_e
        dbg_P_reg               : out std_logic_vector(C_block_size - 1 downto 0); --register for value P
        dbg_C_reg               : out std_logic_vector(C_block_size - 1 downto 0); --register for value C
        dbg_pc_select           : out std_logic; -- Signal to select which of P or C that are "using" the blakley module.
        dbg_e_bit_counter       : out std_logic_vector(counter_bit_size - 1 downto 0); --8 bit signal for a counter which the state machine uses to iterate over 256 bits of key_e.
        dbg_e_counter_increment : out std_logic; --tells e_counter to += 1.
        dbg_e_counter_end       : out std_logic; --tells FSM that we have processed all 256 bits of e.
        dbg_RS_enable           : out std_logic; --signal which right shifts register RSR_e
        dbg_e_bit               : out std_logic; --the LSB of register RSR_e
        dbg_initialize_regs     : out std_logic; --loads initial values into C, P, RSR_e and e_counter
        dbg_is_last_msg_enable  : out std_logic; --signal which tells "is_last_msg" to record the "msgin_last" signal.
        dbg_is_last_msg         : out std_logic; --register which = 1, if msgin_last has been high.
        dbg_state               : out state_type;
        -- pragma translate_on

        --------------------------------------------------------
        -- Interface from general module to outside of RSA-core:
        --------------------------------------------------------
        --input data
        message : in std_logic_vector(C_block_size - 1 downto 0); --aka: M
        key     : in std_logic_vector(C_block_size - 1 downto 0); --aka: key_e
        modulus : in std_logic_vector(C_block_size - 1 downto 0); --aka: key_n

        --output data
        result : out std_logic_vector(C_block_size - 1 downto 0); --aka: msgout_data

        --input control signals
        valid_in   : in std_logic; --aka: msgin_valid
        msgin_last : in std_logic;
        ready_out  : in std_logic; --aka: msgout_ready

        --output control signals
        ready_in    : out std_logic; --aka: msgin_ready
        valid_out   : out std_logic; --aka: msgout_valid
        msgout_last : out std_logic;

        ---------------------------------------------------
        -- Interface from general module to Blakley module:
        ---------------------------------------------------
        --controll signals
        Blak_enable   : out std_logic; --signal that tells Blakley module to start computation.
        Blak_finished : in  std_logic; --signal that Blakley module is finished.
        Blak_clk      : out std_logic; --clock for blakley module
        Blak_reset_n  : out std_logic; --reset for blakley module. Normally high.

        --data signals
        Blak_A : out std_logic_vector(C_block_size - 1 downto 0); --Input A of blak module
        Blak_B : out std_logic_vector(C_block_size - 1 downto 0); --Input B of blak module
        Blak_C : in  std_logic_vector(C_block_size - 1 downto 0); --Output C of blak module
        Blak_n : out std_logic_vector(C_block_size - 1 downto 0); --Input key_n (modulus) for blak module.

        --utility
        clk     : in std_logic;
        reset_n : in std_logic
    );
end exponentiation;

architecture expBehave of exponentiation is

    -- Defining internal signals:
    signal RSR_e               : std_logic_vector(C_block_size - 1 downto 0); --Right shift register for key_e
    signal P_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value P
    signal C_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value C
    signal pc_select           : std_logic; -- Signal to select which of P or C that are "using" the blakley module.
    signal e_bit_counter       : std_logic_vector(counter_bit_size - 1 downto 0); --8 bit signal for a counter which the state machine uses to iterate over 256 bits of key_e.
    signal e_counter_increment : std_logic; --tells e_counter to += 1.
    signal e_counter_end       : std_logic; --tells FSM that we have processed all 256 bits of e.
    signal RS_enable           : std_logic; --signal which right shifts register RSR_e
    signal e_bit               : std_logic; --the LSB of register RSR_e
    signal initialize_regs     : std_logic; --loads initial values into C, P, RSR_e and e_counter
    signal is_last_msg_enable  : std_logic; --signal which tells "is_last_msg" to record the "msgin_last" signal.
    signal is_last_msg         : std_logic; --register which = 1, if msgin_last has been high.

begin

    --instantiate the FSM_general_module and connect it to the required components
    FSM_general_module_1 : entity work.controller(Behavioral)
        port map(
            -- debug
            -- pragma translate_off
            dbg_state => dbg_state,
            -- pragma translate_on

            clk     => clk,
            reset_n => reset_n,

            --handshake signals:
            valid_in    => valid_in,
            ready_in    => ready_in,
            msgin_last  => msgin_last,
            ready_out   => ready_out,
            valid_out   => valid_out,
            msgout_last => msgout_last,

            --datapath signals:
            RS_enable           => RS_enable,
            e_counter_end       => e_counter_end,
            e_counter_increment => e_counter_increment,
            initialize_regs     => initialize_regs,
            Blak_reset_n        => Blak_reset_n,
            Blak_enable         => Blak_enable,
            Blak_finished       => Blak_finished,
            pc_select           => pc_select,
            is_last_msg_enable  => is_last_msg_enable,
            is_last_msg         => is_last_msg,
            e_bit               => e_bit
        );

    -- ***************************************************************************
    -- Get output from Blakley-module, and put the result in reg P or reg C:
    -- ***************************************************************************
    process(clk, reset_n) begin
        if reset_n = '0' then                -- Asynchronous reset 
            P_reg <= (others => '0');
            C_reg <= (others => '0');
            C_reg(0) <= '1';                 --C = [000...001]
        elsif rising_edge(clk) then          --combinatorial is synchronous to avoid latches
            if initialize_regs = '1' then
                P_reg <= message;            --P = message M.
                C_reg <= (others => '0');
                C_reg(0) <= '1';
            elsif Blak_finished = '1' then
                if pc_select = '0' then
                    P_reg <= Blak_C;
                else
                    C_reg <= Blak_C;
                end if;
            end if;
        end if;
    end process;

    result <= C_reg; --result = msg_out.


    -- ***************************************************************************
    -- Send inputs to Blakley module
    -- ***************************************************************************
     
    process (P_reg, C_reg, modulus, pc_select) begin
        if (pc_select = '0') then
            Blak_B <= P_reg;
        else
            Blak_B <= C_reg;
        end if;
        Blak_A <= P_reg;
        Blak_n <= modulus;
    end process;

    -- ***************************************************************************
    -- clk for blakley module:
    -- ***************************************************************************
        Blak_clk <= clk;

    -- ***************************************************************************
    -- RSR_e and sending the e_bit to the FSM.
    -- ***************************************************************************
    process (reset_n, clk) begin
        if (reset_n = '0') then
            RSR_e <= (others => '0');
        elsif(rising_edge(clk)) then 
            if(initialize_regs = '1') then
                RSR_e <= key;      -------------WARNING: this assumes key`s LSB is also in index 0 on the righthand side of the register.     
            elsif (RS_enable = '1') then
                RSR_e <= std_logic_vector(shift_right(unsigned(RSR_e), 1)); -- shift right by 1 bits, since LSB is on the righthand side.
            end if;
        end if;
    end process;

 
    e_bit <= RSR_e(0); --sends the LSB of RSR_e, to the FSM. LSB is on the righthand side of RSR_e.


    -- ***************************************************************************
    -- e_bit_counter, tells the FSM when we have processed all 256 bits of e.
    -- ***************************************************************************
    process (reset_n, clk) begin
        if (reset_n = '0') then
            e_bit_counter <= (others => '0'); --fills vector with zero`s.
            e_counter_end <= '0';
        elsif(rising_edge(clk)) then
            if(initialize_regs = '1') then
                e_bit_counter <= (others => '0'); --fills vector with zero`s.
                e_counter_end <= '0'; 
            elsif (e_counter_increment = '1') then
                e_bit_counter <= std_logic_vector(unsigned(e_bit_counter) + 1);
            end if;
            if (e_counter_increment = '1' and unsigned(e_bit_counter) = 254 ) then --this condition means we have processed all bits of e.
                e_counter_end <= '1';
            else
                e_counter_end <= '0';
            end if;
        end if;
    end process;




    -- ***************************************************************************
    -- is_last_msg. Being told to record the msgin_last-signal.
    -- ***************************************************************************
    process (reset_n, clk) begin
        if (reset_n = '0') then
            is_last_msg <= '0';
        elsif (rising_edge(clk)) then
            if(is_last_msg_enable = '1') then
                is_last_msg <= msgin_last;
            end if;
        end if;
    end process;
    

    -- Only for use in testbenches and debugging:
    -- pragma translate_off
    dbg_RSR_e               <= RSR_e;
    dbg_P_reg               <= P_reg;
    dbg_C_reg               <= C_reg;
    dbg_pc_select           <= pc_select;
    dbg_e_bit_counter       <= e_bit_counter;
    dbg_e_counter_increment <= e_counter_increment;
    dbg_e_counter_end       <= e_counter_end;
    dbg_RS_enable           <= RS_enable;
    dbg_e_bit               <= e_bit;
    dbg_initialize_regs     <= initialize_regs;
    dbg_is_last_msg_enable  <= is_last_msg_enable;
    dbg_is_last_msg         <= is_last_msg;
    -- pragma translate_on
end expBehave;
