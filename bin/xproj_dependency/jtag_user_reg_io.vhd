-- Created : 17:45:3, Mon Dec 12, 2011 : Sanjay Rai

Library IEEE;
use IEEE.std_logic_1164.all;

entity jtag_user_reg_io is
    generic (
                WIDTH_IN : integer := 100;
                WIDTH_OUT : integer := 100);
    port (
	TCK : in std_logic;
	shift_i : in std_logic;
	shift_o : in std_logic;
        iTDI    : in std_logic;
        oTDO    : out std_logic;
	jtag_in_reg : out std_logic_vector((WIDTH_IN-1) downto 0);
        jtag_out_reg : in std_logic_vector((WIDTH_OUT-1) downto 0));
end entity jtag_user_reg_io;

architecture jtag_user_reg_io_arch of jtag_user_reg_io is

signal user_i_reg : std_logic_vector((WIDTH_IN-1) downto 0) := (others => '0');
signal user_o_reg : std_logic_vector((WIDTH_OUT-1) downto 0) := (others => '0');

begin
    proc_user_i_reg_out: process(TCK)

    begin
            if (TCK'event and TCK = '1') then
                    jtag_in_reg <= user_i_reg;
                    if (shift_i = '1') then
                            user_i_reg <= user_i_reg((WIDTH_IN-2) downto 0) & iTDI;
                    end if;
            end if;
    end process;
    proc_user_o_reg_out: process(TCK)
    begin
        if (TCK'event and TCK = '1') then
            case shift_o is
                when '1' => 
                   user_o_reg <= user_o_reg((WIDTH_OUT-2) downto 0) & user_o_reg((WIDTH_OUT-1));
                when others  => 
                   user_o_reg <= jtag_out_reg;
            end case;
        end if;
    end process;
    oTDO <= user_o_reg((WIDTH_OUT-1));

end architecture jtag_user_reg_io_arch;
