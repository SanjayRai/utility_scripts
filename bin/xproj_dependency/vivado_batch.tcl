read_verilog -sv -verbose {
../src/<xproj_srai_design_name>.v
}

# __SRAI coregen files
#read_edif -verbose {
#../coregen/mram_1024x8.ngc
#}

read_xdc -verbose ../src/<xproj_srai_design_name>.xdc

synth_design -name synth_design_1 -prop_constrs -top <xproj_srai_design_name> -fanout_limit 100 -include_dirs ../coregn -part <xproj_srai_device_name>
opt_design -propconst -verbose
place_design -verbose
phys_opt_design -verbose
route_design -verbose -effort_level high
report_timing -delay_type min_max -path_type full_clock_expanded -max_paths 100 -nworst 10 -sort_by group -significant_digits 3 -input_pins -nets -name {results_par_1} -file <xproj_srai_design_name>.timing_rpt
report_timing_summary -delay_type min_max -path_type full_clock_expanded -max_paths 100 -nworst 10 -significant_digits 3 -input_pins -nets -file <xproj_srai_design_name>.timing_summary_rpt
