--course: DDS1 Autumn 2025
--Student: Daniel Vangen Horne


--FSM for general module of the RSA core
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity controller is
	port (
		--misc
		clk 				: in  std_logic;
		reset_n 			: in  std_logic;

		--FSM takes no data-signals as input, only 1-bit control signals
		

		--external controll signals in/out the RSA-core----------------------------
		--input controll
		valid_in	: in STD_LOGIC;  --aka: msgin_valid
		ready_in	: out STD_LOGIC; --aka: msgin_ready
		msgin_last  : in STD_LOGIC;
		--ouput controll
		ready_out	: in STD_LOGIC;  --aka: msgout_ready
		valid_out	: out STD_LOGIC; --aka: msgout_valid
		msgout_last	: out STD_LOGIC; 

		--controll signals inside the RSA-core
		e_bit 		        : out std_logic;    --the LSB of register LSR_e
		LS_enable           : out STD_LOGIC;   --signal which left shift key_e
		e_counter_end       : out std_logic;    --tells the FSM when counter >= 255
		initialize_regs     : out STD_LOGIC;   --loads initial values into C, P, LSR_e and e_counter
		Blak_reset_n	        : out STD_LOGIC;   --blakley module reset sign. must be reset after each computation.
		Blak_enable	        : out STD_LOGIC;   --signal that tells Blakley module to start computation.
		Blak_finished       : in STD_LOGIC;    --signal that Blakley module is finished.
        pc_select           : out std_logic    -- Signal for which of P or C that are using the blakley module:
	);
end controller;

architecture Behavioral of controller is

	type state_type is (
		--states associated with handshake data inn
		is_in_valid, initialize, read_e_bit,
		--states associated with P = P*P mod n,  and C = C*P mod n.
		calc_C, calc_P,
		--states associated with handshake data out
		is_out_ready
	);
	signal state,state_next : state_type;
begin

	main_statem_proc : process (state, Blak_finished, e_counter_end, e_bit, ready_out, valid_in )
	begin
		--default values
		--included at the as to make it unessesarry to specify in every state
		--this may hide errors, but prevents unintended latches
		initialize_regs <= '0';
		ready_in 		<= '0';
		valid_out 		<= '0';
		pc_select       <= '0';
		Blak_reset_n      <= '1';            --reset for blakley module is normally high.
		state_next 		<= is_in_valid;    --We start at this state.

		
		--main implementation of statemachine
		case(state) is
		
		    --State 1/6:
			when is_in_valid =>                     --"when in state "1_in_valid":
				if valid_in = '1' then              --if msgin_valid = 1
				    ready_in <= '1';                --msgin_ready = 1
					state_next <= initialize;       --we go to the next handshake state
				else
					state_next <= is_in_valid;
				end if;
				
			--State 2/6:
			when initialize =>
			    ready_in <= '0';                   -- msgin_ready = 0, so that a new message is not sent to the RSA CORE.
			    initialize_regs <= '1';            -- loads M into P, and '1', into C. Loads key_e into LSR_e.                 
				state_next <= read_e_bit;
				
    
			--State 3/6:
			when read_e_bit => 
			    initialize_regs <= '0';          --if prev state was initialize, then we dont want to initialize anymore.
			    LS_enable <= '0';                     --if prev state was calc_P, then we now stop left shifting key_e.
			    Blak_enable <= '1';              
				if e_bit = '1' then               --if msgin_valid = 1
				    pc_select <= '1';             --C gets connected to the Blakley module.
					state_next <= calc_C;         --we calculate C.
				else
				    pc_select <= '0';            --P gets connected to the Blakley module.
					state_next <= calc_P;        --we calculate C.
				end if;
				
			--State 4/6:
			when calc_C =>                 
				if Blak_finished = '1' then  
				    --P or C (depending), will now load the output into itself.
				    Blak_reset      <= '0';   --we reset blakley-module, to prepare it for next computation.
					state_next <= calc_P;         
				else
				    --if code goes here, then blakley module is still calculating, and we wait.
					state_next <= calc_C;
				end if;
				
			--must make sure that blak_finished goes low at some point, 
			--so that we dont skip a calculation.
				
			--State 5/6:
			when calc_P =>
			    Blak_reset      <= '1';    --if prev state was calc_C, then we stop resetting now.               
				if Blak_finished = '1' then
				    Blak_reset      <= '0';
				    if e_counter_end = '1' then  --"if we have gone through all the bits of e"
				       valid_out <= '1';          
					   state_next <= is_out_ready;
					else
					   LS_enable <= '1'; --we leftshift the bits of e
					   state_next <= read_e_bit;
					end if;        
				else
					state_next <= calc_P;   --if Bl-module is not finished, then we wait.
				end if;
				
			--State 6/6:
			when is_out_ready => 
			    --Data is being sent out of the RSA-core, when in this state.
			    valid_out       <= '0';          --we want to stop sending data out, next state.
			    Blak_reset      <= '1';          --we stop resetting the bl-module.              
				state_next      <= is_in_valid;  --we go to the first state agein.
				
			when others =>    --this is a default condition, to reset if we end in an undefined state.
				initialize_regs <= '0';
		        ready_in 		<= '0';
		        valid_out 		<= '0';
		        pc_select       <= '0';
		        Blak_reset      <= '1';          --reset signal is normally high.
				state_next 		<= is_in_valid;  --go to the first state next.
		end case;
	end process main_statem_proc;


	update_state : process (reset_n, clk)
	begin
		if (reset_n = '0') then
			state <= is_in_valid;           --I put in read_2N, instead of IDLE;
		elsif (rising_edge(clk)) then
			state <= state_next;
		end if;
	end process update_state;




end Behavioral;




