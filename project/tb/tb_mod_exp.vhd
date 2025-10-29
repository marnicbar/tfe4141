library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_mod_exp is
end entity;

architecture sim of tb_mod_exp is
  constant DATA_WIDTH : positive := 256;
  signal msgin_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal msgout_data  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal key_e        : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal key_n        : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal e_bit        : std_logic;
  signal bl_finished  : std_logic;
  signal msgin_valid  : std_logic;
  signal msgin_ready  : std_logic;
  signal msgin_last   : std_logic;
  signal msgout_valid : std_logic;
  signal msgout_ready : std_logic;
  signal msgout_last  : std_logic;
  signal pc_select    : std_logic;

end architecture;
