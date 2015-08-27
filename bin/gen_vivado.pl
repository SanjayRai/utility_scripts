#!perl

my @verilog_rtl_files;
my @vhdl_rtl_files;
$USAGE = "\n Usage :\n\t gen_vivado xst_cmd_file XST\n\t gen_vivado synplify_prj_file SYNPLIFY\n\t gen_vivado Quartus_QSF_file QUARTUS\n";

$PROJECT_FILE_TYPE = $ARGV[1];
$VIVADO_BATCH_FILE = "vivado_batch.tcl";
$XST_PRJ_FILE = "NULL";
$TOP_MODULE = "NULL";


if (($#ARGV != 1)) {
    print "\n !ERROR Wrong Number of Arguments\n";
    print $USAGE; 
    die;
}


if (($PROJECT_FILE_TYPE eq "XST")) {
    open (FP_XST, "<$ARGV[0]") or die $!; 
    while (<FP_XST>) {
        chomp;
        if (/-ifn/) {
            s/\s*-ifn\s*//;
            $XST_PRJ_FILE = $_;
        }
        if (/-top/i) {
            s/\s*-top\s*//i;
            $TOP_MODULE = $_;
        }

        if (/-vlgincdir/i) {
            s/\s*-vlgincdir\s*//i;
            s/"//g;
            s/{//;
            s/}//;
            @INCLUDE_DIRECTORIES = split;
        }

        if (/-define/i) {
            s/\s*-define\s*//i;
            s/"//g;
            s/{//;
            s/}//;
            @DEFINES = split;
        }
    }
    close FP_XST;

    if ($XST_PRJ_FILE eq "NULL") { 
        print "XST Project file not found\n";
        die;
    }

    open (FP_PRJ, "<$XST_PRJ_FILE") or die $!; 
    while (<FP_PRJ>) {
        chomp;
        s/"//g;
        s/^#.*//;
        if (/vhdl\s*work\s*/) {
            s/\s*vhdl\s*work\s*//;
            push (@vhdl_rtl_files, $_);
        } elsif (/verilog\s*work\s*/) {
            s/\s*verilog\s*work\s*//;
            push (@verilog_rtl_files, $_);
        } elsif (/`include\s*/) {
            s/`include\s*//;
            push (@verilog_rtl_files, $_);
        }
    }
    close FP_PRJ;
} elsif (($PROJECT_FILE_TYPE eq "SYNPLIFY")) {
    open (FP_SYNP, "<$ARGV[0]") or die $!; 
    while (<FP_SYNP>) {
        chomp;
        s/^#.*//;
        s/"//g;
        if (/-top_module/i) {
            s/\s*set_option\s*-top_module\s*//i;
            $TOP_MODULE = $_;
        }

        if (/-include_path/i) {
            s/\s*set_option\s*-include_path\s*//i;
            push (@INCLUDE_DIRECTORIES, $_);
        }

        if (/-hdl_define\s*-set/i) {
            s/\s*set_option\s*-hdl_define\s*-set\s*//i;
            push (@DEFINES, $_);
        }

        if (/add_file.*-verilog/i) {
            s/.*add_file.*-verilog//i;
            push (@verilog_rtl_files, $_);
        }
        if (/add_file.*-vhdl/i) {
            s/.*add_file.*-vhdl//i;
            push (@vhdl_rtl_files, $_);
        }
    }
    close FP_SYNP;
} elsif (($PROJECT_FILE_TYPE eq "QUARTUS")) {
    open (FP_QSF, "<$ARGV[0]") or die $!; 
    while (<FP_QSF>) {
        chomp;
        s/^#.*//;
        s/"//g;
        if (/set_global_assignment\s*-name\s*TOP_LEVEL_ENTITY/i) {
            s/\s*set_global_assignment\s*-name\s*TOP_LEVEL_ENTITY\s*//i;
            $TOP_MODULE = $_;
        } elsif (/set_global_assignment\s*-name\s*SEARCH_PATH/i) {
            s/\s*set_global_assignment\s*-name\s*SEARCH_PATH\s*//i;
            s/{//;
            s/}//;
            push (@INCLUDE_DIRECTORIES, $_);
        } elsif (/set_global_assignment\s*-name\s*VERILOG_MACRO/i) {
            s/\s*set_global_assignment\s*-name\s*VERILOG_MACRO\s*//i;
            s/{//;
            s/}//;
            push (@DEFINES, $_);
        } elsif (/set_global_assignment\s*-name\s*VERILOG_FILE/i) {
            s/.*set_global_assignment\s*-name\s*VERILOG_FILE//i;
            push (@verilog_rtl_files, $_);
        } elsif (/set_global_assignment\s*-name\s*VHDL_FILE/i) {
            s/.*set_global_assignment\s*-name\s*VHDL_FILE//i;
            push (@vhdl_rtl_files, $_);
        }
    }
    close FP_QSF;
}else {
    print " Project file type is unrecogniged \n";
    print $USAGE; 
    exit(0);
}



if ($TOP_MODULE eq "NULL") { 
    print "Top module not found\n";
    die;
}


open FP_VIVADO_BATCH_FILE, ">$VIVADO_BATCH_FILE" or die "Cannot Open $VIVADO_BATCH_FILE for writing : $!"; 

print FP_VIVADO_BATCH_FILE "set DEVICE XC7K325t-2-FFG900\n";

print FP_VIVADO_BATCH_FILE "set VIVADO_IMPLEMENTATION 0\n\n";

if ($#verilog_rtl_files >= 0) {
    print FP_VIVADO_BATCH_FILE "read_verilog -sv -verbose {\n";
    foreach $verilog_file_name (@verilog_rtl_files) {
        print FP_VIVADO_BATCH_FILE "    $verilog_file_name\n";
    }
    print FP_VIVADO_BATCH_FILE "}\n\n";
}

if ($#vhdl_rtl_files >= 0) {
    print FP_VIVADO_BATCH_FILE "read_vhdl -verbose {\n";
    foreach $vhdl_file_name (@vhdl_rtl_files) {
        print FP_VIVADO_BATCH_FILE "    $vhdl_file_name\n";
    }
    print FP_VIVADO_BATCH_FILE "}\n\n";
}



print FP_VIVADO_BATCH_FILE "#### coregen & third-party netlist files ###\n";
print FP_VIVADO_BATCH_FILE "# read_edif -verbose {\n";
print FP_VIVADO_BATCH_FILE "#     ../coregen/mram_1024x8.ngc\n";
print FP_VIVADO_BATCH_FILE "# }\n\n";

print FP_VIVADO_BATCH_FILE "#### Read XDC Constraint files ###\n";
print FP_VIVADO_BATCH_FILE "# read_xdc -verbose ../src/dummy.xdc\n";
print FP_VIVADO_BATCH_FILE "# read_xdc -verbose ../src/$TOP_MODULE.xdc\n\n";

print FP_VIVADO_BATCH_FILE "synth_design -name synth_design_1 -top $TOP_MODULE -flatten_hierarchy rebuilt -fanout_limit 100000 -part \$DEVICE";
foreach $define_item (@DEFINES) {
    print FP_VIVADO_BATCH_FILE " -verilog_define $define_item ";
}
foreach $include_dirs_item (@INCLUDE_DIRECTORIES) {
    print FP_VIVADO_BATCH_FILE " -include_dirs $include_dirs_item";
}
print FP_VIVADO_BATCH_FILE "\n";
print FP_VIVADO_BATCH_FILE "opt_design -verbose -remap -effort high\n";
print FP_VIVADO_BATCH_FILE "if \(\$VIVADO_IMPLEMENTATION\) {\n";

print FP_VIVADO_BATCH_FILE "    place_design -verbose -effort_level high\n";
print FP_VIVADO_BATCH_FILE "    phys_opt_design -verbose\n";
print FP_VIVADO_BATCH_FILE "    route_design -verbose -effort_level high\n";
print FP_VIVADO_BATCH_FILE "    report_timing -delay_type min_max -path_type full_clock_expanded -max_paths 100 -nworst 10 -sort_by group -significant_digits 3 -input_pins -nets -name {results_par_1} -file $TOP_MODULE.timing_rpt\n";
print FP_VIVADO_BATCH_FILE "    report_timing_summary -delay_type min_max -path_type full_clock_expanded -max_paths 100 -nworst 10 -significant_digits 3 -input_pins -nets -file $TOP_MODULE.timing_summary_rpt\n";
print FP_VIVADO_BATCH_FILE "}\n";



close FP_VIVADO_BATCH_FILE;
