--course: DDS1 Autumn 2025
--Student: Daniel Vangen Horne


--FSM for general module of the RSA core
----------------------------------------------------------------------------------

-- ===============================================================
--  PACKAGE: shared type definitions (e.g. FSM state)
-- ===============================================================
package mod_exp_pkg is
	type state_type is (
		--states associated with handshake data inn
		is_in_valid, initialize, read_e_bit,
		--states associated with P = P*P mod n,  and C = C*P mod n.
		calc_C, reset_blak_module, calc_P, increment_e, is_e_processed, Leftshift_e,
		--states associated with handshake data out
		is_out_ready, set_msgout_last
	);
end package mod_exp_pkg;

package body mod_exp_pkg is
end package body mod_exp_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.mod_exp_pkg.all; -- bring in the enum type

entity controller is
	port (
		--misc
		clk 				: in  std_logic;
		reset_n 			: in  std_logic;

		--FSM takes no data-signals as input, only 1-bit control signals
		
		--external controll signals in/out of the RSA-core----------------------------
		--input controll
		valid_in	: in STD_LOGIC;  --aka: msgin_valid
		ready_in	: out STD_LOGIC; --aka: msgin_ready
		msgin_last  : in STD_LOGIC;
		--ouput controll
		ready_out	: in   STD_LOGIC;  --aka: msgout_ready
		valid_out	: out  STD_LOGIC; --aka: msgout_valid
		msgout_last	: out  STD_LOGIC;
		Blak_reset_n: out  STD_LOGIC;   --blakley module reset sign. must be reset after each computation. 

		--controll signals inside the RSA-core
		e_bit 		        : in  STD_LOGIC;    --the LSB of register LSR_e
		LS_enable           : out STD_LOGIC;   --signal which left shift key_e
		e_counter_end       : in  STD_LOGIC;    --tells the FSM when counter >= 255
		e_counter_increment : out  STD_LOGIC;    --tells the FSM when counter >= 255
		initialize_regs     : out STD_LOGIC;   --loads initial values into C, P, LSR_e and e_counter
		Blak_enable	        : out STD_LOGIC;   --signal that tells Blakley module to start computation.
		Blak_finished       : in  STD_LOGIC;    --signal that Blakley module is finished.
		is_last_msg_enable  : out STD_LOGIC;
		is_last_msg         : in  STD_LOGIC;
        pc_select           : out STD_LOGIC;    -- Signal for which of P or C that are using the blakley module:

		-- debug
        -- pragma translate_off
        dbg_state : out state_type
        -- pragma translate_on
	);
end controller;

architecture Behavioral of controller is
	signal state, state_next : state_type;
begin

	main_statem_proc : process (state, Blak_finished, e_counter_end, e_bit, e_counter_end, ready_out, msgin_last, valid_in, is_last_msg )
	begin
		--default values
		--included at the as to make it unessesarry to specify in every state
		--this may hide errors, but prevents unintended latches
		initialize_regs <= '0';
		ready_in 		<= '0';
		valid_out 		<= '0';
		is_last_msg_enable <= '0';
		msgout_last     <= '0';
		e_counter_increment <= '0';
		pc_select       <= '0';
		Blak_reset_n    <= '1';            --reset for blakley module is normally high.
		state_next 		<= is_in_valid;    --We start at this state.

		
		--main implementation of statemachine
		case(state) is
		
		    --State 1/11:
			when is_in_valid =>                   --"when in state "1_in_valid":
			    valid_out       <= '0';           --If we got her from handshake out, then stop sending data out.
			    msgout_last     <= '0';
				if valid_in = '1' then            --if msgin_valid = 1
					state_next <= initialize;     --we go to the next handshake state
				else
					state_next <= is_in_valid;
				end if;
				
				
			--State 2/11:
			when initialize =>
			    ready_in <= '1';                   --msgin_ready = 1
			    is_last_msg_enable <= '1';        --tell the register to hold the value "msgin_last".
			    initialize_regs <= '1';            -- loads M into P, and '1', into C. Loads key_e into LSR_e.                 
				state_next <= read_e_bit;
				
				
			--State 3/11:
			when read_e_bit => 
			    is_last_msg_enable <= '0';
			    ready_in <= '0';              -- msgin_ready = 0, so that a new message is not sent to the RSA CORE.
			    initialize_regs <= '0';       --if prev state was initialize, then we dont want to initialize anymore.
			    LS_enable <= '0';             --if prev state was Leftshift_e, then we now stop left shifting key_e.           
				if e_bit = '1' then               --if msgin_valid = 1
					state_next <= calc_C;         --we calculate C.
				else
					state_next <= calc_P;         --we calculate P.
				end if;
				
				
			--State 4/11:
			when calc_C =>
			    Blak_enable <= '1';
			    pc_select <= '1';           --C gets connected to the Blakley module.                 
				if Blak_finished = '1' then  
					state_next <= reset_blak_module;         
				else
					state_next <= calc_C;
				end if;
				

			--State 5/11:
			when reset_blak_module =>
			    Blak_enable     <= '0';
			    Blak_reset_n    <= '0';   --we reset blakley-module, to prepare it for next computation.  
			    state_next <= calc_P;              

				
			--State 6/11:
			when calc_P =>
			    pc_select         <= '0';    --P gets connected to the Blakley module.
			    Blak_enable       <= '1';
			    Blak_reset_n      <= '1';    --if prev state was reset_blak_module, then we stop resetting now.               
				if (Blak_finished = '1') then
				    state_next <= increment_e;        
				else
					state_next <= calc_P;  
				end if;
				
				
			--State 7/11:
			when increment_e =>
			    e_counter_increment <= '1';
			    Blak_enable         <= '0';
			    Blak_reset_n        <= '0';    -- reset blakley after updating P.
			    state_next          <= is_e_processed;
			   
				
			--State 8/11:
			when is_e_processed => 
			    e_counter_increment <= '0';
			    Blak_reset_n        <= '1';
			    if (e_counter_end = '1') then  --"if we have gone through all the bits of e"
			         state_next <= is_out_ready;
			    else
			         state_next <= Leftshift_e;   
				end if;
				
				
				--State 9/11:
			when Leftshift_e => 
			    LS_enable  <= '1'; --we leftshift the bits of e
			    state_next <= read_e_bit;

				
			--State 10/11:
			when is_out_ready =>
			    valid_out       <= '1'; 
			    if(ready_out = '1') then      --this means msgout_ready = 1              
			         if(is_last_msg = '1') then
			             state_next <= set_msgout_last; 
			         else
			             state_next <= is_in_valid;   --go to handshake inn. 
			         end if;
			    else
			         state_next <= is_out_ready; --wait for handshake out.
			    end if;
			    
			    
			--State 11/11:
			when set_msgout_last =>     --is_out_ready_last (former name)
			    valid_out       <= '0';
			    msgout_last     <= '1';             
				state_next      <= is_in_valid;  --we go to the first state again.  
				
				
			--this is a default condition, to reset if we end up in an undefined state.	
			when others =>    
				initialize_regs <= '0';
		        ready_in 		<= '0';
		        valid_out 		<= '0';
		        is_last_msg_enable <= '0';
		        msgout_last     <= '0';
		        e_counter_increment <= '0';
		        pc_select       <= '0';
		        Blak_reset_n      <= '1';          --reset signal is normally high.
				state_next 		<= is_in_valid;  --go to the first state next.
		end case;
	end process main_statem_proc;


	update_state : process (reset_n, clk)
	begin
		if (reset_n = '0') then
			state <= is_in_valid;           --first state.
		elsif (rising_edge(clk)) then
			state <= state_next;
		end if;
	end process update_state;

	-- pragma translate_off
    dbg_state <= state;
    -- pragma translate_on

end Behavioral;




