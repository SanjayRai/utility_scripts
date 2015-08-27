Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

entity <xproj_srai_design_name> is port (
    reset : in std_logic;
    clk   : in std_logic;
    count : out std_logic_vector(7 downto 0)
);
end entity <xproj_srai_design_name>;

architecture <xproj_srai_design_name>_arch of <xproj_srai_design_name> is

signal i_count : integer range 0 to 255 := 0;
begin

proc_count: process(clk)
begin
     if (clk'event and clk = '1') then
            if (reset = '1') then
                i_count <= 0;
            elsif (i_count < 255) then
                i_count <= i_count + 1;
            else
                i_count <= 0;
            end if;
            count <= conv_std_logic_vector(i_count, 8);
    end if;
end process;
end architecture <xproj_srai_design_name>_arch;
