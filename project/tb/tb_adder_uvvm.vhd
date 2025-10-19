-- Minimal UVVM testbench for adder
-- Demonstrates: uvvm_util context, logging, checks, final report

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_adder_uvvm is
end entity;

architecture sim of tb_adder_uvvm is
  constant C_WIDTH : positive := 8;

  signal a    : std_logic_vector(C_WIDTH - 1 downto 0);
  signal b    : std_logic_vector(C_WIDTH - 1 downto 0);
  signal cin  : std_logic := '0';
  signal sum  : std_logic_vector(C_WIDTH - 1 downto 0);
  signal cout : std_logic;

begin
  -- DUT
  i_dut : entity work.adder
    generic map(G_WIDTH => C_WIDTH)
    port map(
      a    => a,
      b    => b,
      cin  => cin,
      sum  => sum,
      cout => cout
    );

  -- Simple test sequencer
  p_seq : process
    variable v_a, v_b : unsigned(C_WIDTH - 1 downto 0);
    variable v_sum    : unsigned(C_WIDTH - 1 downto 0);
    variable v_cout   : std_logic;
  begin
    -- Optional: choose log destination
    -- set_log_file_name("UVVM_Log.txt");
    --set_alert_file_name("UVVM_Alerts.txt");
    set_log_destination(CONSOLE_AND_LOG);

    log(ID_LOG_HDR, "Starting UVVM adder demo");

    -- Test 1: 1 + 2
    v_a := to_unsigned(1, C_WIDTH);
    v_b := to_unsigned(2, C_WIDTH);
    a   <= std_logic_vector(v_a);
    b   <= std_logic_vector(v_b);
    cin <= '0';
    wait for 1 ns;

    v_sum  := resize(v_a, C_WIDTH) + resize(v_b, C_WIDTH);
    v_cout := '0';
    check_value(sum, std_logic_vector(v_sum), ERROR, "1+2 sum");
    check_value(cout, v_cout, ERROR, "1+2 carry");

    -- Test 2: Max + 1 -> expect sum=0 carry=1
    v_a := (others => '1');
    v_b := to_unsigned(1, C_WIDTH);
    a   <= std_logic_vector(v_a);
    b   <= std_logic_vector(v_b);
    cin <= '0';
    wait for 1 ns;

    v_sum  := (others => '0');
    v_cout := '1';
    check_value(sum, std_logic_vector(v_sum), ERROR, "max+1 wrap sum");
    check_value(cout, v_cout, ERROR, "max+1 carry");

    -- Test 3: 10 + 5 + cin=1 -> expect 16, carry 0
    v_a := to_unsigned(10, C_WIDTH);
    v_b := to_unsigned(5, C_WIDTH);
    a   <= std_logic_vector(v_a);
    b   <= std_logic_vector(v_b);
    cin <= '1';
    wait for 1 ns;

    v_sum  := resize(v_a, C_WIDTH) + resize(v_b, C_WIDTH) + 1;
    v_cout := '0';
    check_value(sum, std_logic_vector(v_sum), ERROR, "10+5+1 sum");
    check_value(cout, v_cout, ERROR, "10+5+1 carry");

    -- Final reporting
    report_msg_id_panel(VOID); -- Prints enabled/disabled log IDs (optional)
    report_global_ctrl(VOID);
    report_check_counters(FINAL);
    report_alert_counters(FINAL);

    std.env.stop; -- End simulation cleanly
    wait;         -- forever
  end process;

end architecture;
