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

--"entity" defines input and output interfaces, and generics/parameters.
--In this case, this means interface towards the outside of the RSA core, 
--and interface to the blakley module.
entity exponentiation is
    generic (
        C_block_size     : integer := 256;
        counter_bit_size : integer := 8 --the counter needs 8 bits, to count to 256, for the bits of e.
    );
    port (
        --------------------------------------------------------
        --interface from general module to outside of RSA-core:
        ---------------------------------------------------------

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

        ----------------------------------------------------
        --interface from general module to Blakley module:---
        -----------------------------------------------------

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
    signal LSR_e               : std_logic_vector(C_block_size - 1 downto 0); --Left shift register for key_e
    signal P_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value P
    signal C_reg               : std_logic_vector(C_block_size - 1 downto 0); --register for value C
    signal pc_select           : std_logic; -- Signal to select which of P or C that are "using" the blakley module.
    signal e_bit_counter       : std_logic_vector(counter_bit_size downto 0); --8 bit signal for a counter which the state machine uses to iterate over 256 bits of key_e.
    signal e_counter_increment : std_logic; --tells e_counter to += 1.
    signal e_counter_end       : std_logic; --tells FSM that we have processed all 256 bits of e.
    signal LS_enable           : std_logic; --signal which left shifts register LSR_e
    signal e_bit               : std_logic; --the LSB of register LSR_e
    signal initialize_regs     : std_logic; --loads initial values into C, P, LSR_e and e_counter
    signal is_last_msg_enable  : std_logic; --signal which tells "is_last_msg" to record the "msgin_last" signal.
    signal is_last_msg         : std_logic; --register which = 1, if msgin_last has been high.

begin

    --instantiate the FSM_general_module and connect it to the required components
    FSM_general_module_1 : entity work.controller(Behavioral)
        port map(
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
            LS_enable          => LS_enable,
            e_counter_end      => e_counter_end,
            initialize_regs    => initialize_regs,
            Blak_reset_n       => Blak_reset_n,
            Blak_enable        => Blak_enable,
            Blak_finished      => Blak_finished,
            pc_select          => pc_select,
            is_last_msg_enable => is_last_msg_enable,
            is_last_msg        => is_last_msg,
            e_bit              => e_bit

        );

    -- ***************************************************************************
    -- Get output from Blakley-module, and put the result in reg P or reg C:
    -- ***************************************************************************
    process (clk, reset_n) begin
        if (reset_n = '0') then --reset/initialize register P and C
            P_reg    <= message; --Message M gets put in register P.
            C_reg    <= (others => '0');
            C_reg(0) <= '1'; -- value [000...001] gets put into register C.
        elsif (clk'event and clk = '1') then
            if (pc_select = '0' and Blak_finished = '1') then
                P_reg <= Blak_C;
            elsif (pc_select = '1' and Blak_finished = '1') then
                C_reg <= Blak_C;
            end if;
            if (initialize_regs = '1') then
                P_reg    <= message; --Message M gets put in register P.
                C_reg    <= (others => '0');
                C_reg(0) <= '1'; -- value [000...001] gets put into register C.
            end if;
        end if;
    end process;

    process (C_reg) begin
        result <= C_reg; --msg_out.
    end process;

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
    -- Tell blakley module to reset, if general module resets, or we initialize the system:
    -- ***************************************************************************
    process (clk, reset_n) begin
        if (reset_n = '0') then --reset/initialize register P and C
            Blak_reset_n <= '0'; --tell Blakley module to reset.
        elsif (clk'event and clk = '1') then
            if (initialize_regs = '1') then
                Blak_reset_n <= '0';
            else
                Blak_reset_n <= '1';
            end if;
        end if;
    end process;

    process (clk) begin
        Blak_clk <= clk;
    end process;

    -- ***************************************************************************
    -- LSR_e and sending the e_bit to the FSM.
    -- ***************************************************************************
    process (clk, reset_n) begin
        if (reset_n = '0') then
            LSR_e <= key; -------------WARNING: this assumes key`s LSB is also in index 0 on the righthand side of the register.      
        elsif (clk'event and clk = '1') then
            if (initialize_regs = '1') then
                LSR_e <= key; -----------WARNING: this assumes key`s LSB is also in index 0 on the righthand side of the register.
            elsif (LS_enable = '1') then
                LSR_e <= std_logic_vector(shift_right(unsigned(LSR_e), 1)); -- shift right by 1 bits, since LSB is on the righthand side.
            end if;
        end if;
    end process;

    process (LSR_e) begin
        e_bit <= LSR_e(0); --sends the LSB of LSR_e, to the FSM. LSB is on the righthand side of LSR_e.
    end process;

    -- ***************************************************************************
    -- e_bit_counter, tells the FSM when we have processed all 256 bits of e.
    -- ***************************************************************************
    process (clk, reset_n) begin
        if (reset_n = '0') then
            e_bit_counter <= (others => '0'); --fills vector with zero`s.
            e_counter_end <= '0';
        elsif (clk'event and clk = '1') then
            if (initialize_regs = '1') then
                e_bit_counter <= (others => '0'); --fills vector with zero`s.
                e_counter_end <= '0';
            elsif (e_counter_increment = '1') then
                e_bit_counter <= std_logic_vector(unsigned(e_bit_counter) + 1);
            end if;
        end if;
    end process;

    process (e_bit_counter) begin
        if (unsigned(e_bit_counter) >= 255) then
            e_counter_end <= '1';
        else
            e_counter_end <= '0';
        end if;
    end process;

    -- ***************************************************************************
    -- is_last_msg. Being told to record the msgin_last-signal.
    -- ***************************************************************************
    process (clk, reset_n) begin
        if (reset_n = '0') then
            is_last_msg <= '0';
        elsif (clk'event and clk = '1') then
            if (is_last_msg_enable = '1') then
                is_last_msg <= msgin_last;
            end if;
        end if;
    end process;

end expBehave;
