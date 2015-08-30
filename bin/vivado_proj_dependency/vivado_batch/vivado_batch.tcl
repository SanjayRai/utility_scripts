source ../device_type.tcl


set TOP_module <top_module_name>

create_project -in_memory -part [DEVICE_TYPE] 

read_ip {
../IP/<ip_name>/<ip_name>.xci
}

read_verilog {
../src/<top_module_name>.v
}

read_xdc {
../src/xdc/<top_module_name>.xdc
}

if (1) {
synth_design -top $TOP_module -part [DEVICE_TYPE] 
opt_design -verbose -directive Explore
write_checkpoint -force $TOP_module.post_synth_opt.dcp
place_design -verbose -directive Explore
write_checkpoint -force $TOP_module.post_place.dcp
phys_opt_design  -verbose -directive Explore
write_checkpoint -force $TOP_module.post_place_phys_opt.dcp
route_design  -verbose -directive Explore
write_checkpoint -force $TOP_module.post_route.dcp
phys_opt_design  -verbose -directive Explore
write_checkpoint -force $TOP_module.post_route_phys_opt.dcp
report_timing_summary -file $TOP_module.timing_summary.rpt
report_drc -file $TOP_module.drc.rpt
set_property config_mode SPIx4 [current_design]
set_property config_mode B_SCAN [current_design]
set_property config_mode SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
write_bitstream $TOP_module.bit      
}
