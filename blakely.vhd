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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity blakely is
    generic(
            bit_width      : positive := 256 --we are working with 256 bits per word
    );
    Port ( 
            --inputs
           A                : in std_logic_vector(bit_width-1 downto 0);
           B                : in std_logic_vector(bit_width-1 downto 0);
           N                : in std_logic_vector(bit_width-1 downto 0);
           
           --msc
           clk                : in STD_LOGIC;
           reset_n                : in STD_LOGIC;
           
           --external controll signals
           bn_enable               : in STD_LOGIC;
           
           --outputs
           Output : out std_logic_vector(bit_width-1 downto 0);
           finished_calc : out STD_LOGIC
end blakely;

architecture Behavioral of blakely is

    ------------------------------------------------------------------------
    -- Internal registers 
    ------------------------------------------------------------------------
   signal reg_a, reg_b, reg_n, reg_temp, reg_out : unsigned(bit_width-1 downto 0);
    
    ------------------------------------------------------------------------
    -- FSM state declarations
    ------------------------------------------------------------------------

  type state_type is( 
    --reading states
   read_inputs,
   
   --working states
   initial_shifting, 
   addition, 
   comp1, 
   sub1,
   comp2,
   sub2, 
   store_shift,
   
   --output
   saida
 );
 signal state,state_next : state_type;
 
 --Save the most signficant bit from A
 signal a_msb : std_logic;
 
 --Signal to help verify with the product of the addition state is bigger then N
 signal temp_sub : unsigned(bit_width downto 0); -- one extra bit for carry
 
 --Iteration counter
 signal cnt_int : unsigned(8 downto 0) := (others => '0');  -- 9 bits can count up to 511
 
 --Finished computation
 signal done_calc_int : std_logic := '0';

begin
    main_statem_proc : process (clk,reset_n)
    begin
		--default values
		--included at the as to make it unessesarry to specify in every state
		--this may hide errors, but prevents unintended latches
		state_next 		<= read_inputs;
        
        --ascy reset
        if reset_n = '0' then
            -- async reset
            reg_a    <= (others => '0');
            reg_b    <= (others => '0');
            reg_n    <= (others => '0');
            reg_temp <= (others => '0');
            reg_out  <= (others => '0');
            done_calc_int <= '0';
            state    <= read_inputs;
        elsif rising_edge(clk) then
            state <= state_next;

        
        
        --main implementation of statemachine    
        case(state) is
        
         ------------------------------------------------------------
         -- READ INPUTS
         ------------------------------------------------------------
        when read_inputs => --Reading the operands of the module
            if bn_enable = '1' then
                         reg_a <= unsigned(A);
                         reg_b <= unsigned(B);
                         reg_n <= unsigned(N);
                        state_next <= initial_shifting;
        
            else
                state_next <= read_inputs;
            end if;
            
            
          ------------------------------------------------------------
          -- INITIAL SHIFTING (example setup phase)
          ------------------------------------------------------------
          when initial_shifting =>
             -- Capture MSB before shifting
             a_msb <= reg_a(bit_width-1);

             -- Shift reg_a left by one position
             reg_a <= reg_a(bit_width-2 downto 0) & '0';

              -- Move to next state
              state_next <= addition;

         ------------------------------------------------------------
         -- ADDITION
         ------------------------------------------------------------
         when addition =>
         --If the msb equals one add B to the partial result
        if a_msb = '1' then
            reg_temp <= reg_temp + reg_b;
         else
            reg_temp <= reg_temp; -- no addition
         end if;
         
         
         ------------------------------------------------------------
         -- COMP
         ------------------------------------------------------------
         when comp1 =>
         
         --Instead of using a comparator, use a subtraction to see if the sub result is bigger then N
         temp_sub <= ('0' & reg_temp) - ('0' & reg_n);

         if temp_sub(bit_width) = '0' then
         -- No underflow → reg_temp >= reg_n
         state_next <= sub1;
         else
         -- Underflow → reg_temp < reg_n
         state_next <= store_shift;
         end if;
         
         ------------------------------------------------------------
         -- SUB1
         ------------------------------------------------------------
         when sub1 =>
         
         --We already did the subtraction, so just assign the already done subtraction to the temporary result   
         reg_temp <= temp_sub(bit_width-1 downto 0);
         state_next <= comp2;
         
         ------------------------------------------------------------
         -- COMP2
         ------------------------------------------------------------
         when comp2 =>
         
         --Instead of using a comparator, use a subtraction to see if the sub result is bigger then N
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
 
         --We already did the subtraction, so just assign the already done subtraction to the temporary result   
         reg_temp <= temp_sub(bit_width-1 downto 0);
         state_next <= store_shift;
         
         ------------------------------------------------------------
         -- STORE_SHIFT
         ------------------------------------------------------------
        when store_shift =>
            -- Store modular result
            reg_out <= reg_temp;
        
            -- Left shift reg_temp for next iteration
            reg_temp <= reg_temp(bit_width-2 downto 0) & '0';
        
           if cnt_int = bit_width-1 then
                state_next <= saida;
                cnt_int <= cnt_int;  -- stop counting
           else
                state_next <= initial_shifting;
                cnt_int <= cnt_int + 1;
            end if;

            
        ------------------------------------------------------------
        -- SAIDA (OUTPUT)
        ------------------------------------------------------------
        when saida =>
            -- Keep final result
            reg_out <= reg_temp;
        
            -- Indicate computation finished
            done_calc_int <= '1';
            
            state_next <= saida;  -- hold in final state
    
        end case;
    
    
    end process main_statem_proc;
    
 
--Outputs, this outputs are always being driven by the current value of the registers  
Output <= std_logic_vector(reg_out);
finished_calc <= done_calc_int


end Behavioral;
