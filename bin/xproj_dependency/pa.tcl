set DESIGN_NAME "<xproj_srai_design_name>"
set PROJECT_NAME "planAhead_prj1"
set DEVICE "<xproj_srai_device_name>"
set NETLIST "../build/synth_results/$DESIGN_NAME.ngc"
set CORE_SEARCH_PATH "../coregen"
set UCF_FILE "../src/$DESIGN_NAME.ucf"
set NCD_FILE "../build/ise_results/$DESIGN_NAME.ncd"
set PCF_FILE "../build/ise_results/$DESIGN_NAME.pcf"
set TWX_FILE "../build/ise_results/$DESIGN_NAME.twx"

create_project $PROJECT_NAME $PROJECT_NAME
set_property design_mode GateLvl [get_property srcset [current_run]]
set_property edif_top_file $NETLIST [get_property srcset [current_run]]
add_files $CORE_SEARCH_PATH
set_property name floorplan_1 [get_filesets constrs_1]
set_property target_part $DEVICE [get_filesets floorplan_1]
open_netlist_design -constrset floorplan_1 -part $DEVICE  
import_as_run -pcf $PCF_FILE -twx $TWX_FILE $NCD_FILE 
open_impl_design
