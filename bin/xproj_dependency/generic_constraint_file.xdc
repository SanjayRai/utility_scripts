set PRD 4.5
set PRD_2 [expr $PRD/2]
create_clock -period $PRD -name sys_clk -waveform "0 $PRD_2" [get_ports clk]


set_property IOSTANDARD LVCMOS18 [get_ports {*}]

#set_property LOC AF24 [get_ports {a_pc_usr_cntr_reg_msk_db[0]}]
#set_property LOC AA31 [get_ports {count[5]}]
#set_property LOC B16 [get_ports clk]
