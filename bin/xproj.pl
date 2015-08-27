#!perl

# Periodically referesh the $PARTGENFILE (xproj_dependency/partgen.txt) file by 
# executing the following Xilinx command. Ideally this is done every new Xilinx ISE Software update
#
#       % partgen -i > partgen.txt
#
#
$ISE_RESULTS = "ise_results";
$EDK_RESULTS = "edk_results";
$SYN_RESULTS = "synth_results";

$XPROJ_DEPENDENCY_DIR = "/home/sanjayr/bin/xproj_dependency/";

$PARTGENFILE = $XPROJ_DEPENDENCY_DIR."partgen.txt";
$PLD_BUILD_MAKEFILE = $XPROJ_DEPENDENCY_DIR."Makefile_build_pld";
$FPGA_BUILD_MAKEFILE = $XPROJ_DEPENDENCY_DIR."Makefile_build_fpga";
$PLD_BUILD_XST_FILE = $XPROJ_DEPENDENCY_DIR."pld.xst";
$FPGA_BUILD_XST_FILE = $XPROJ_DEPENDENCY_DIR."fpga.xst";
$CONSTRAINT_FILE = $XPROJ_DEPENDENCY_DIR."generic_constraint_file.ucf";
$MTI_VHDL_SIM_DO_FILE = $XPROJ_DEPENDENCY_DIR."sim_mti_vhdl.do";
$MTI_VERILOG_SIM_DO_FILE = $XPROJ_DEPENDENCY_DIR."sim_mti_verilog.do";
$GLBL_VERILOG_FILE = $XPROJ_DEPENDENCY_DIR."glbl.v";
$VERILOG_FILE = $XPROJ_DEPENDENCY_DIR."example.v";
$VHDL_FILE = $XPROJ_DEPENDENCY_DIR."example.vhd";
$VERILOG_TESTBENCH_FILE = $XPROJ_DEPENDENCY_DIR."tb_example.v";
$VHDL_TESTBENCH_FILE = $XPROJ_DEPENDENCY_DIR."tb_example.vhd";
$FPGA_COREGEN_Make_FILE = $XPROJ_DEPENDENCY_DIR."Makefile_coregen";
$FPGA_PLANAHEAD_TCL_FILE = $XPROJ_DEPENDENCY_DIR."pa.tcl";
$Makefile_PlanAhead = $XPROJ_DEPENDENCY_DIR."Makefile_pa";
$FPGA_SMARTXPLORER_STRATAGIES = $XPROJ_DEPENDENCY_DIR."strategies.sf";
$FPGA_SMARTXPLORER_HOSTLIST = $XPROJ_DEPENDENCY_DIR."smartxplorer.hostlist";
$FPGA_SMART_RUN_MAKE_FILE = $XPROJ_DEPENDENCY_DIR."Makefile_smart_run";
$FPGA_COREGEN_cpg_FILE = $XPROJ_DEPENDENCY_DIR."coregen.cgp";
$Makefile_isim = $XPROJ_DEPENDENCY_DIR."Makefile_isim";
$TCLfile_isim = $XPROJ_DEPENDENCY_DIR."isim_startup.tcl";
$XPARTITION_PXML = $XPROJ_DEPENDENCY_DIR."xpartition.pxml_sample";
$VIVADO_TCL_FILE = $XPROJ_DEPENDENCY_DIR."vivado_batch.tcl";
$VIVADO_XDC_FILE = $XPROJ_DEPENDENCY_DIR."generic_constraint_file.xdc";


# Prints Human Readable Time and Date
@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$Date_and_Time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
$ERROR_MSG = "\n !ERROR\n \n Usage :\n \t xproj project_name device_name [-verilog] [-CPLD]\n\n Example:\n \t xproj test_design xc5vlx50t-1-ff1136\n\n";

if (($#ARGV < 1) || ($#ARGV > 3)) {
    print $ERROR_MSG;
    exit(0);
} else {
    $DESIGN_NAME = $ARGV[0];
    $XILINX_DEVICE = $ARGV[1];
    $DEVICE_LANGUAGE = $ARGV[2];
    $DEVICE_TYPE = $ARGV[3];

    # Parse the partgen.txt file to ensure Valid part
    open (FP, "<$PARTGENFILE") or die $!; 

    $i = 0;
    while (<FP>) {
    chomp;
    s/Release .*//i;
    s/Copyright .*//i;
    s/\s+/ /g;
    s/\s*\(Minimum speed data available\).*//;
        if (/^x/) {
            $idx = 0;
            ($part_name, $dummy, $speed[0], $speed[1], $speed[2], $speed[3], $speed[4], $speed[5]) = split;
            foreach $spd_grade (@speed) {
                if ($spd_grade ne "") {
                    $device[$idx] = $part_name.$spd_grade;
                    $idx++;
                }
            }
        } else {
            s/\s+//g;
            foreach $device_name_partgen (@device) {
                $XILINX_DEVICE_partgen[$i] = $device_name_partgen."-".$_;
                $i++;
            }
        }
    }
    close(FP);

    $match = 0;
    foreach $XILINX_DEVICE_NAME_partgen (@XILINX_DEVICE_partgen) {
        if (uc($XILINX_DEVICE_NAME_partgen) eq uc($XILINX_DEVICE)) {
            $match = 1;
        } 
    }

    if ($match) {
        print "Found device $XILINX_DEVICE\n";
    } else {
        print "Part mismatch $XILINX_DEVICE doesn't exist in the current part database\n";
        print $ERROR_MSG;
        exit(0);
    }

    ($DEVICE_NAME, $DEVICE_SPEED_GRADE, $DEVICE_PACKAGE) = split("-", $XILINX_DEVICE);

    
    if ($DEVICE_LANGUAGE eq "-verilog") {
        $RTL_LANG_IS_VERILOG = 1;
    } else {
        $RTL_LANG_IS_VERILOG = 0;
    }


    if ($DEVICE_TYPE eq "-CPLD")
    {
        $dir_structure[0] = "$DESIGN_NAME";
        $dir_structure[1] = "$DESIGN_NAME/build";
        $dir_structure[2] = "$DESIGN_NAME/build/$ISE_RESULTS";
        $dir_structure[3] = "$DESIGN_NAME/sim_mti";
        $dir_structure[4] = "$DESIGN_NAME/src";
        $dir_structure[5] = "$DESIGN_NAME/isim";
        $dir_structure[6] = "$DESIGN_NAME/build/$SYN_RESULTS";

        for ($i = 0; $i < @dir_structure; $i++)
        {
            if (-d$dir_structure[$i])
            {
                print "Directory $dir_structure[$i] already exists\n";
            }
            else
            {
                print "Creating Directory $dir_structure[$i]\n";
                `mkdir $dir_structure[$i]`;
            }
        }
        $files[0] ="$dir_structure[1]/Makefile";
        $files[1] ="$dir_structure[1]/$DESIGN_NAME.xst";
        $files[2] ="$dir_structure[1]/$DESIGN_NAME.prj";
        $files[3] ="$dir_structure[4]/$DESIGN_NAME.ucf";
        $files[4] ="$dir_structure[3]/sim.do";
        $glbl_file_mti ="$dir_structure[3]/glbl.v";
        $glbl_file_isim ="$dir_structure[5]/glbl.v";
        if ( $RTL_LANG_IS_VERILOG) {
            $files[5] ="$dir_structure[4]/$DESIGN_NAME.v";
            $files[6] ="$dir_structure[4]/tb_$DESIGN_NAME.v";
        } else {
            $files[5] ="$dir_structure[4]/$DESIGN_NAME.vhd";
            $files[6] ="$dir_structure[4]/tb_$DESIGN_NAME.vhd";
        }
        $files[7] ="$dir_structure[5]/Makefile";
        $files[8] ="$dir_structure[5]/tb_$DESIGN_NAME.prj";
        $files[9] ="$dir_structure[5]/isim_startup.tcl";

        for ($i = 0; $i < @files; $i++)
        {
            $files_status[$i] = 0;
            if (-e$files[$i])
            {
                print "$files[$i] already exists\n";
                $files_status[$i] = 1;
            }
            else
            {
                print "Creating $files[$i]\n";
                `touch $files[$i]`;
            }
        }

        # Create Generic Makefile
        if ($files_status[0] == 0)
        {
            open(FP_PLD, $PLD_BUILD_MAKEFILE) or die $!;
            open(fp, ">$files[0]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }

            close(FP_PLD);
            close(fp);
        }

        # Create Generic .xst file
        if ($files_status[1] == 0)
        {
            open(FP_PLD, $PLD_BUILD_XST_FILE) or die $!;
            open(fp, ">$files[1]");
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }

            close(FP_PLD);
            close(fp);
        }
        # Create Generic .prj file isim prj file
        if ($files_status[2] == 0)
        {
            open(fp, ">$files[2]") or die $!;
            open (fp_isim, ">$files[8]") or die $!;
            if ($RTL_LANG_IS_VERILOG) {
                print fp "verilog work \"..\/src\/$DESIGN_NAME.v\"\n";
                print fp_isim "verilog work \"glbl.v\"\n";
                print fp_isim "verilog work \"..\/src\/$DESIGN_NAME.v\"\n";
                print fp_isim "verilog work \"..\/src\/tb_$DESIGN_NAME.v\"\n";
            } else {
                print fp "vhdl work \"..\/src\/$DESIGN_NAME.vhd\"\n";
                print fp_isim "verilog work \"glbl.v\"\n";
                print fp_isim "vhdl work \"..\/src\/$DESIGN_NAME.vhd\"\n";
                print fp_isim "vhdl work \"..\/src\/tb_$DESIGN_NAME.vhd\"\n";
            }
            close(fp);
        }
        # Create Generic .ucf file
        if ($files_status[3] == 0)
        {
            open(FP_PLD, $CONSTRAINT_FILE) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            open(fp, ">$files[3]");
            print fp "#Basic Constraint file Example\n";
            print fp "#--------------------------------------------------------------\n";
            while (<FP_PLD>) {
                print fp;
            }
            print fp "#--------------------------------------------------------------\n";
            close(FP_PLD);
            close(fp);
        }

        # Write glbl.v file into the sim directory for Verilog sim
        open(fp, ">$glbl_file_mti") or die $!;
        open(fp_isim, ">$glbl_file_isim") or die $!;
        open (FP_PLD, $GLBL_VERILOG_FILE) or die $!;
        while (<FP_PLD>) {
            print fp;
            print fp_isim;
        }
        close(FP_PLD);
        close(fp);
        close(fp_isim);

        # Create MTI do file
        if ($files_status[4] == 0)
        {
            open(fp, ">$files[4]") or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $MTI_VERILOG_SIM_DO_FILE) or die $!;
                while (<FP_PLD>) {
                    s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                    print fp;
                }
            } else {
                open(FP_PLD, $MTI_VHDL_SIM_DO_FILE) or die $!;
                while (<FP_PLD>) {
                    s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                    print fp;
                }
            }
            close(FP_PLD);
            close(fp);
        }
        # Create template toplevel RTL file
        if ($files_status[5] == 0)
        {

            open(fp, ">$files[5]");
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $VERILOG_FILE) or die $!;
                print fp "// Created : $Date_and_Time : Sanjay Rai\n\n";
            } else {
                open(FP_PLD, $VHDL_FILE) or die $!;
                print fp "-- Created : $Date_and_Time : Sanjay Rai\n\n";
            }
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }

        # Create template toplevel RTL test bench file
        if ($files_status[6] == 0)
        {
            open(fp, ">$files[6]");
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $VERILOG_TESTBENCH_FILE) or die $!;
                print fp "// Created : $Date_and_Time : Sanjay Rai\n\n";
            } else {
                open(FP_PLD, $VHDL_TESTBENCH_FILE) or die $!;
                print fp "-- Created : $Date_and_Time : Sanjay Rai\n\n";
            }
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }

        # Create iSIM Makefile  
        if ($files_status[7] == 0)
        {
            open(fp, ">$files[7]");
            open(FP_PLD, $Makefile_isim) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/tb_$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create iSIM_startup TCL file
        if ($files_status[9] == 0)
        {
            open(fp, ">$files[9]") or die $!;
            open(FP_PLD, $TCLfile_isim) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/tb_$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
    }
    else
    {
        $dir_structure[0] = "$DESIGN_NAME";
        $dir_structure[1] = "$DESIGN_NAME/build";
        $dir_structure[2] = "$DESIGN_NAME/build/$ISE_RESULTS";
        $dir_structure[3] = "$DESIGN_NAME/sim_mti";
        $dir_structure[4] = "$DESIGN_NAME/src";
        $dir_structure[5] = "$DESIGN_NAME/coregen";
        $dir_structure[6] = "$DESIGN_NAME/planAhead";
        $dir_structure[7] = "$DESIGN_NAME/smartxplorer";
        $dir_structure[8] = "$DESIGN_NAME/sim_isim";
        $dir_structure[9] = "$DESIGN_NAME/build/$EDK_RESULTS";
        $dir_structure[10] = "$DESIGN_NAME/build/$SYN_RESULTS";
        $dir_structure[11] = "$DESIGN_NAME/vivado";

        for ($i = 0; $i < @dir_structure; $i++)
        {
            if (-d$dir_structure[$i])
            {
                print "Directory $dir_structure[$i] already exists\n";
            }
            else
            {
                print "Creating Directory $dir_structure[$i]\n";
                `mkdir $dir_structure[$i]`;
            }
        }
        $files[0] ="$dir_structure[1]/Makefile";
        $files[1] ="$dir_structure[1]/$DESIGN_NAME.xst";
        $files[2] ="$dir_structure[1]/$DESIGN_NAME.prj";
        $files[3] ="$dir_structure[4]/$DESIGN_NAME.ucf";
        $files[4] ="$dir_structure[3]/sim.do";
        $glbl_file_mti ="$dir_structure[3]/glbl.v";
        $glbl_file_isim ="$dir_structure[8]/glbl.v";
        if ( $RTL_LANG_IS_VERILOG) {
            $files[5] ="$dir_structure[4]/$DESIGN_NAME.v";
            $files[6] ="$dir_structure[4]/tb_$DESIGN_NAME.v";
        } else {
            $files[5] ="$dir_structure[4]/$DESIGN_NAME.vhd";
            $files[6] ="$dir_structure[4]/tb_$DESIGN_NAME.vhd";
        }
        $files[7] ="$dir_structure[5]/Makefile";
        $files[8] ="$dir_structure[6]/pa.tcl";
        $files[9] ="$dir_structure[7]/Makefile";
        $files[10] ="$dir_structure[5]/coregen.cgp";
        $files[11] ="$dir_structure[7]/smartxplorer.hostlist";
        $files[12] ="$dir_structure[7]/strategies.sf";
        $files[13] ="$dir_structure[8]/Makefile";
        $files[14] ="$dir_structure[8]/tb_$DESIGN_NAME.prj";
        $files[15] ="$dir_structure[8]/isim_startup.tcl";
        $files[16] ="$dir_structure[6]/Makefile";
        $files[17] ="$dir_structure[1]/xpartition.pxml_sample";
        $files[18] ="$dir_structure[11]/vivado_batch.tcl";
        $files[19] ="$dir_structure[4]/$DESIGN_NAME.xdc";

        for ($i = 0; $i < @files; $i++)
        {
            $files_status[$i] = 0;
            if (-e$files[$i])
            {
                print "$files[$i] already exists\n";
                $files_status[$i] = 1;
            }
            else
            {
                print "Creating $files[$i]\n";
                `touch $files[$i]`;
            }
        }

        # Create Generic Makefile
        if ($files_status[0] == 0)
        {
            open(FP_PLD, $FPGA_BUILD_MAKEFILE) or die $!;
            open(fp, ">$files[0]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }

        # Create Generic .xst file
        if ($files_status[1] == 0)
        {
            open(FP_PLD, $FPGA_BUILD_XST_FILE) or die $!;
            open(fp, ">$files[1]");
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }

            close(FP_PLD);
            close(fp);
        }
        # Create Generic .prj file
        if ($files_status[2] == 0)
        {
            open(fp, ">$files[2]") or die $!;
            open(fp_isim, ">$files[14]") or die $!;
            if ($RTL_LANG_IS_VERILOG) {
                print fp "verilog work \"..\/src\/$DESIGN_NAME.v\"\n";
                print fp_isim "verilog work \"glbl.v\"\n";
                print fp_isim "verilog work \"..\/src\/$DESIGN_NAME.v\"\n";
                print fp_isim "verilog work \"..\/src\/tb_$DESIGN_NAME.v\"\n";
            } else {
                print fp "vhdl work \"..\/src\/$DESIGN_NAME.vhd\"\n";
                print fp_isim "verilog work \"glbl.v\"\n";
                print fp_isim "vhdl work \"..\/src\/$DESIGN_NAME.vhd\"\n";
                print fp_isim "vhdl work \"..\/src\/tb_$DESIGN_NAME.vhd\"\n";
            }
            close(fp);
        }

        # Create sample xpartition.pxml file 
        if ($files_status[17] == 0)
        {
            open(FP_PLD, $XPARTITION_PXML) or die $!;
            open(fp, ">$files[17]");
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create Generic .ucf file
        if ($files_status[3] == 0)
        {
            open(FP_PLD, $CONSTRAINT_FILE) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            open(fp, ">$files[3]");
            print fp "#Basic Constraint file Example\n";
            print fp "#--------------------------------------------------------------\n";
            while (<FP_PLD>) {
                print fp;
            }
            print fp "#--------------------------------------------------------------\n";
            close(FP_PLD);
            close(fp);
        }

        # Write glbl.v file into the sim directory for Verilog sim
        open(fp, ">$glbl_file_mti") or die $!;
        open(fp_isim, ">$glbl_file_isim") or die $!;
        open (FP_PLD, $GLBL_VERILOG_FILE) or die $!;
        while (<FP_PLD>) {
            print fp;
            print fp_isim;
        }
        close(FP_PLD);
        close(fp);
        close(fp_isim);

        # Create MTI do file
        if ($files_status[4] == 0)
        {
            open(fp, ">$files[4]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $MTI_VERILOG_SIM_DO_FILE) or die $!;
            } else {
                open(FP_PLD, $MTI_VHDL_SIM_DO_FILE) or die $!;
            }
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create template toplevel RTL file
        if ($files_status[5] == 0)
        {

            open(fp, ">$files[5]");
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $VERILOG_FILE) or die $!;
                print fp "// Created : $Date_and_Time : Sanjay Rai\n\n";
            } else {
                open(FP_PLD, $VHDL_FILE) or die $!;
                print fp "-- Created : $Date_and_Time : Sanjay Rai\n\n";
            }
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }

        # Create template toplevel RTL test bench file
        if ($files_status[6] == 0)
        {
            open(fp, ">$files[6]");
            if ($RTL_LANG_IS_VERILOG) {
                open(FP_PLD, $VERILOG_TESTBENCH_FILE) or die $!;
                print fp "// Created : $Date_and_Time : Sanjay Rai\n\n";
            } else {
                open(FP_PLD, $VHDL_TESTBENCH_FILE) or die $!;
                print fp "-- Created : $Date_and_Time : Sanjay Rai\n\n";
            }
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create Coregen Makefile 
        if ($files_status[7] == 0)
        {

            open(FP_PLD, $FPGA_COREGEN_Make_FILE) or die $!;
            open(fp, ">$files[7]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                print fp;
            }

            close(FP_PLD);
            close(fp);
        }
        # Create Coregen coregen.cpg 
        if ($files_status[10] == 0)
        {

            open(FP_PLD, $FPGA_COREGEN_cpg_FILE) or die $!;
            open(fp, ">$files[10]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                print fp;
            }

            close(FP_PLD);
            close(fp);
        }

        # Create PlanAhead Tcl file 
        if ($files_status[8] == 0)
        {
            open(FP_PLD, $FPGA_PLANAHEAD_TCL_FILE) or die $!;
            open(fp, ">$files[8]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create PlanAhead Make file 
        if ($files_status[16] == 0)
        {
            open(FP_PLD, $Makefile_PlanAhead) or die $!;
            open(fp, ">$files[16]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        if ($files_status[9] == 0)
        {
            open(fp, ">$files[9]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            open(FP_PLD, $FPGA_SMART_RUN_MAKE_FILE) or die $!;
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        if ($files_status[11] == 0)
        {
            open(FP_PLD, $FPGA_SMARTXPLORER_HOSTLIST) or die $!;
            open(fp, ">$files[11]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        if ($files_status[12] == 0)
        {
            open(FP_PLD, $FPGA_SMARTXPLORER_STRATAGIES) or die $!;
            open(fp, ">$files[12]");
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create iSIM Makefile  
        if ($files_status[13] == 0)
        {
            open(fp, ">$files[13]");
            open(FP_PLD, $Makefile_isim) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/tb_$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create iSIM_startup TCL file
        if ($files_status[15] == 0)
        {
            open(fp, ">$files[15]") or die $!;
            open(FP_PLD, $TCLfile_isim) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/tb_$DESIGN_NAME/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create Vivado Batch  TCL file
        if ($files_status[18] == 0)
        {
            open(fp, ">$files[18]") or die $!;
            open(FP_PLD, $VIVADO_TCL_FILE) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                s/<xproj_srai_design_name>/$DESIGN_NAME/g;
                s/<xproj_srai_device_name>/$XILINX_DEVICE/g;
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
        # Create XDC Constraint file
        if ($files_status[19] == 0)
        {
            open(fp, ">$files[19]") or die $!;
            open(FP_PLD, $VIVADO_XDC_FILE) or die $!;
            print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
            while (<FP_PLD>) {
                print fp;
            }
            close(FP_PLD);
            close(fp);
        }
    }
}
