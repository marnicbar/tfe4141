--course: DDS1 Autumn 2025
--Student: Daniel Vangen Horne


--FSM for general module of the RSA core
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity controller is
	generic (
		bit_width 			: positive := 16
	);
	port (
		--misc
		clk 				: in  std_logic;
		reset_n 			: in  std_logic;

		--FSM takes no data-signals as input, only 1-bit control signals
		

		--external controll signals------------------------------------
		--input controll
		valid_in	: in STD_LOGIC;  --aka: msgin_valid
		ready_in	: out STD_LOGIC; --aka: msgin_ready
		--ouput controll
		ready_out	: in STD_LOGIC;  --aka: msgout_ready
		valid_out	: out STD_LOGIC; --aka: msgout_valid

		--internal controll signals
		e_bit 		        : in std_logic;    --the LSB of register LSR_e
		LS_e                : out STD_LOGIC;   --signal which left shift key_e
		e_counter_end       : in std_logic;    --tells the FSM when counter >= 255
		initialize_regs     : out STD_LOGIC;   --loads initial values into C, P, LSR_e and e_counter
		Blak_enable	        : out STD_LOGIC;   --signal that tells Blakley module to start computation.
		Blak_finished       : in STD_LOGIC;    --signal that Blakley module is finished.
        pc_select           : out std_logic    -- Signal for which of P or C that are using the blakley module:
	);
end controller;

architecture Behavioral of controller is

	type state_type is (
		--states associated with handshake data inn
		is_in_valid, set_ready, initialize, read_e_bit,
		--states associated with computation M*e mod n
		calc_C, calc_P,
		--states associated with handshake data out
		is_out_ready, out_ready
		--IDLE,ERR  this was here by default. comment it out.
	);
	signal state,state_next : state_type;
begin

	main_statem_proc : process (state,valid_in,ready_out,input_equal,input_greater)
	begin
		--default values
		--included at the as to make it unessesarry to specify in every state
		--this may hide errors, but prevents unintended latches
		initialize_regs <= '0';
		ready_in 		<= '0';
		valid_out 		<= '0';
		pc_select       <= '0';
		state_next 		<= is_in_valid;

		
		--main implementation of statemachine
		case(state) is
		
		    --State 1/8:
			when is_in_valid =>                    --"when in state "1_in_valid":
				if valid_in = '1' then             --if msgin_valid = 1
					state_next <= set_ready;         --we go to the next handshake state
				else
					state_next <= is_in_valid;
				end if;
				
			--State 2/8:
			when set_ready =>
			    ready_in <= '1';                   --msgin_ready = 1                  
				state_next <= initialize;
				
			--State 3/8:
			when initialize =>
			    ready_in <= '0';                   --msgin_ready = 0, so that a new message is not sent to the RSA CORE.
			    initialize_regs <= '1';            -- loads M into P, and '1', into C. Loads key_e into LSR_e.            
				state_next <= read_e_bit;        
				
				
			--State 4/8:
			when read_e_bit => 
			    LS_e <= '0';                   --if prev state was calc_P, then we now stop left shifting key_e.
			    initialize_regs <= '0';        --Values are initialized already.
			    Blak_enable <= '1';              
				if e_bit = '1' then             --if msgin_valid = 1
				    pc_select <= '1';
					state_next <= calc_C;         --we go to the next handshake state
				else
				    pc_select <= '0';
					state_next <= calc_P;
				end if;
				
			--State 5/8:
			when calc_C =>                 
				if Blak_finished = '1' then           
					state_next <= calc_P;         
				else
					state_next <= calc_C;
				end if;
				
			--must make sure that blak_finished goes low at some point, 
			--so that we dont skip a calculation.
				
			--State 6/8:
			when calc_P =>                 
				if Blak_finished = '1' then
				    if e_counter_end = '1' then
				       valid_out <= '1';          
					   state_next <= is_out_ready;
					else
					   LS_e <= '1'; --we leftshift key_e
					   state_next <= read_e_bit;
					end if;        
				else
					state_next <= calc_P;
				end if;
				
			--State 7/8:
			when is_out_ready =>                 
				if Blak_finished = '1' then        
				else
					state_next <= calc_P;
				end if;
				
				
				
			
			
			
			when others =>
				read_a_select 	<= read_reg0;
				read_b_select 	<= read_reg0;
				write_select 	<= write_none;
				valid_out 		<= '0';
				ready_in 		<= '0';
				opcode 			<= alu_load;
				state_next 		<= read_2N;  --i inserted this instead of: IDLE;
		end case;
	end process main_statem_proc;


	update_state : process (reset_n, clk)
	begin
		if (reset_n = '0') then
			state <= read_2N;           --I put in read_2N, instead of IDLE;
		elsif (rising_edge(clk)) then
			state <= state_next;
		end if;
	end process update_state;


end Behavioral;




end Behavioral;

