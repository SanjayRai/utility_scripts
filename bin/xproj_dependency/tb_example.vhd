-- Created : 13:45:23, Mon May 17, 2010 : Sanjay Rai

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

entity tb_<xproj_srai_design_name> is
end entity tb_<xproj_srai_design_name>;

architecture tb_<xproj_srai_design_name>_arch of tb_<xproj_srai_design_name> is


component <xproj_srai_design_name> is port (
    reset : in std_logic;
    clk   : in std_logic;
    count : out std_logic_vector(7 downto 0)
);
end component <xproj_srai_design_name>;


constant PRD : time := 10 ns;


signal clk : std_logic := '0';
signal reset : std_logic := '1';
signal count : std_logic_vector(7 downto 0) := (others => '0');

begin

clk <= transport not(clk) after PRD/2 ;

UUT:  <xproj_srai_design_name> port map (
            reset => reset,
            clk => clk,
            count => count
        );
proc_tb_vector: process
begin
       reset <= '1';
       wait for 200*PRD;
       reset <= '0';
       wait for 2000*PRD;


       wait;
end process;

end architecture tb_<xproj_srai_design_name>_arch;
