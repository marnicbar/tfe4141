library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity blakley is
  generic (
    W        : integer := 256;
    TMP_BITS : integer := 256 + 2;
    CNT_W    : integer := 9
  );
  port (
    clk       : in  std_logic;
    reset_n   : in  std_logic;
    b_enable  : in  std_logic;

    -- *** INTERFACE NOW STD_LOGIC_VECTOR ***
    A : in std_logic_vector(W-1 downto 0);
    B : in std_logic_vector(W-1 downto 0);
    N : in std_logic_vector(W-1 downto 0);

    result_out : out std_logic_vector(W-1 downto 0);
    done_out   : out std_logic;

    ----------------------------------------------------------------------
    -- DEBUG OUTPUTS - HIDDEN FROM SYNTHESIS
    ----------------------------------------------------------------------
    -- pragma translate_off
    debug_state     : out std_logic_vector(2 downto 0);
    debug_reg_temp  : out unsigned(TMP_BITS-1 downto 0);
    debug_reg_a     : out unsigned(W-1 downto 0);
    debug_reg_b     : out unsigned(W-1 downto 0);
    debug_reg_n     : out unsigned(W-1 downto 0);
    debug_counter   : out unsigned(CNT_W-1 downto 0);
    debug_A_bit     : out std_logic
    -- pragma translate_on
  );
end entity blakley;


architecture rtl of blakley is

  --------------------------------------------------------------------
  -- Internal signals (unsigned for arithmetic)
  --------------------------------------------------------------------
  signal A_u, B_u, N_u     : unsigned(W-1 downto 0);
  signal result_u          : unsigned(W-1 downto 0);

  signal read_inputs_s     : std_logic := '0';
  signal process_bit_s     : std_logic := '0';
  signal comp_sub_1_s      : std_logic := '0';
  signal comp_sub_2_s      : std_logic := '0';
  signal output_en_s       : std_logic := '0';

  signal temp_in_bounds_s  : std_logic := '0';
  signal bit_done_s        : std_logic := '0';

  type state_type is (INPUT, PROCESS_BIT, COMP_SUB1, COMP_SUB2, OUTPUT_S);
  signal fsm_state : state_type := INPUT;

begin

  --------------------------------------------------------------------
  -- Convert Input SLV -> Unsigned
  --------------------------------------------------------------------
  A_u <= unsigned(A);
  B_u <= unsigned(B);
  N_u <= unsigned(N);

  --------------------------------------------------------------------
  -- DATAPATH
  --------------------------------------------------------------------
  u_datapath : entity work.blakley_datapath
    generic map (
      W        => W,
      TMP_BITS => TMP_BITS,
      CNT_W    => CNT_W
    )
    port map (
      clk            => clk,
      reset_n        => reset_n,

      temp_in_bounds => temp_in_bounds_s,
      bit_done       => bit_done_s,

      read_inputs => read_inputs_s,
      process_bit => process_bit_s,
      comp_sub_1  => comp_sub_1_s,
      comp_sub_2  => comp_sub_2_s,
      output      => output_en_s,

      A => A_u,
      B => B_u,
      N => N_u,

      result => result_u,

      dbg_reg_temp => debug_reg_temp,
      dbg_reg_a    => debug_reg_a,
      dbg_reg_b    => debug_reg_b,
      dbg_reg_n    => debug_reg_n,
      dbg_counter  => debug_counter,
      dbg_A_bit    => debug_A_bit
    );

  --------------------------------------------------------------------
  -- CONTROLLER
  --------------------------------------------------------------------
  u_ctrl : entity work.blakley_controller
    port map (
      clk             => clk,
      rst_n           => reset_n,
      b_enable        => b_enable,

      bit_done        => bit_done_s,
      temp_in_bounds  => temp_in_bounds_s,

      read_inputs     => read_inputs_s,
      process_bit     => process_bit_s,
      comp_sub_1      => comp_sub_1_s,
      comp_sub_2      => comp_sub_2_s,
      output_en       => output_en_s,

      done            => done_out
    );

  --------------------------------------------------------------------
  -- Convert output Unsigned -> SLV
  --------------------------------------------------------------------
  result_out <= std_logic_vector(result_u);

  --------------------------------------------------------------------
  -- DEBUG FSM STATE
  --------------------------------------------------------------------
  process(read_inputs_s, process_bit_s, comp_sub_1_s, comp_sub_2_s, output_en_s)
  begin
      if read_inputs_s = '1' then
          fsm_state <= INPUT;
      elsif process_bit_s = '1' then
          fsm_state <= PROCESS_BIT;
      elsif comp_sub_1_s = '1' then
          fsm_state <= COMP_SUB1;
      elsif comp_sub_2_s = '1' then
          fsm_state <= COMP_SUB2;
      elsif output_en_s = '1' then
          fsm_state <= OUTPUT_S;
      end if;
  end process;

  debug_state <= std_logic_vector(to_unsigned(state_type'pos(fsm_state), 3));

end architecture;
