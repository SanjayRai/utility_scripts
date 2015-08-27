set LIB_NAME <xproj_srai_design_name>_lib
set MAKEFILE false
set TOP_MODULE <xproj_srai_design_name>
set TOP_TB_MODULE tb_<xproj_srai_design_name>

if {$MAKEFILE} {
    make
} else {
    exec rm -rf $LIB_NAME
    vlib $LIB_NAME
    vcom -2002 -work $LIB_NAME ../src/$TOP_MODULE.vhd
    vcom -2002 -work $LIB_NAME ../src/$TOP_TB_MODULE.vhd

    exec vmake $LIB_NAME > Makefile 
}

vsim -t ps $LIB_NAME.$TOP_TB_MODULE -l <xproj_srai_design_name>_sim_transcript.txt
log -r /*
add wave -dec /*
vcd file $TOP_TB_MODULE.vcd
vcd add /*
run 20 us
