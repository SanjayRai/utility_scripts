source ../device_type.tcl

create_project project_X project_X -part [DEVICE_TYPE]


add_files -norecurse {
../IP/<ip_name>/<ip_name>.xci
../src/<top_module_name>.v
}
add_files -fileset constrs_1 {
../src/xdc/<top_module_name>.xdc
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
if (1) {
launch_runs synth_1
wait_on_run synth_1
open_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1
}
