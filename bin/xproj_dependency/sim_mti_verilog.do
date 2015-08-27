set LIB_NAME <xproj_srai_design_name>_lib
set MAKEFILE false
set TOP_MODULE <xproj_srai_design_name>
set TOP_TB_MODULE tb_<xproj_srai_design_name>

if {$MAKEFILE} {
    make
} else {
    exec rm -rf $LIB_NAME
    vlib $LIB_NAME
    vlog -work $LIB_NAME glbl.v
    vlog -work $LIB_NAME ../src/$TOP_MODULE.v
    vlog -work $LIB_NAME ../src/$TOP_TB_MODULE.v

    exec vmake $LIB_NAME > Makefile 
}

vsim -t ps $LIB_NAME.$TOP_TB_MODULE -L unisims_ver -L unimacro_ver -L secureip -L xilinxcorelib_ver $LIB_NAME.glbl -l <xproj_srai_design_name>_sim_transcript.txt
log -r /*
add wave -dec /*
vcd file $TOP_TB_MODULE.vcd
vcd add /*
run 20 us
