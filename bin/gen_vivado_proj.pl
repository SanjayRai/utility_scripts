#!perl


$PROJ_DEPENDENCY_DIR = "/home/sanjayr/bin/vivado_proj_dependency/";


$device_type_FILE = $PROJ_DEPENDENCY_DIR."device_type.tcl";
$IP_mk_clean_FILE = $PROJ_DEPENDENCY_DIR."/IP/mk_clean.bat";
$IP_vivado_project_FILE = $PROJ_DEPENDENCY_DIR."/IP/vivado_project.tcl";
$BATCH_mk_clean_FILE = $PROJ_DEPENDENCY_DIR."/vivado_batch/mk_clean.bat";
$BATCH_vivado_project_FILE = $PROJ_DEPENDENCY_DIR."/vivado_batch/vivado_batch.tcl";
$PROJECT_mk_clean_FILE = $PROJ_DEPENDENCY_DIR."/vivado_project/mk_clean.bat";
$PROJECT_vivado_project_FILE = $PROJ_DEPENDENCY_DIR."/vivado_project/vivado_project.tcl";


# Prints Human Readable Time and Date
@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$Date_and_Time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
$ERROR_MSG = "\n !ERROR\n \n Usage :\n \t xproj project_name device_name [-verilog] \n\n Example:\n \t xproj test_design xc5vlx50t-1-ff1136\n\n";

if (($#ARGV < 0) || ($#ARGV > 0)) {
    print "Error $#ARGV received for args \n";
    print $ERROR_MSG;
    exit(0);
} else {
    $DESIGN_NAME = $ARGV[0];
    
    $dir_structure[0] = "$DESIGN_NAME";
    $dir_structure[1] = "$DESIGN_NAME/IP";
    $dir_structure[2] = "$DESIGN_NAME/IP_examples";
    $dir_structure[3] = "$DESIGN_NAME/src";
    $dir_structure[4] = "$DESIGN_NAME/src/xdc";
    $dir_structure[5] = "$DESIGN_NAME/vivado_project";
    $dir_structure[6] = "$DESIGN_NAME/vivado_batch";

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
    $files[0] ="$dir_structure[0]/device_type.tcl";
    $files[1] ="$dir_structure[1]/mk_clean.bat";
    $files[2] ="$dir_structure[1]/vivado_project.tcl";
    $files[3] ="$dir_structure[5]/mk_clean.bat";
    $files[4] ="$dir_structure[5]/vivado_project.tcl";
    $files[5] ="$dir_structure[6]/mk_clean.bat";
    $files[6] ="$dir_structure[6]/vivado_batch.tcl";

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

    if ($files_status[0] == 0)
    {
        open(FP_PLD, $device_type_FILE) or die $!;
        open(fp, ">$files[0]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            print fp;
        }
        close(FP_PLD);
        close(fp);
    }

    if ($files_status[1] == 0)
    {
        open(FP_PLD, $IP_mk_clean_FILE) or die $!;
        open(fp, ">$files[1]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            print fp;
        }

        close(FP_PLD);
        close(fp);
    }

    if ($files_status[2] == 0)
    {
        open(FP_PLD, $IP_vivado_project_FILE) or die $!;
        open(fp, ">$files[2]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            s/<top_module_name>/$DESIGN_NAME/g;
            print fp;
        }
        close(FP_PLD);
        close(fp);
    }
    if ($files_status[3] == 0)
    {
        open(FP_PLD, $PROJECT_mk_clean_FILE) or die $!;
        open(fp, ">$files[3]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            print fp;
        }

        close(FP_PLD);
        close(fp);
    }

    if ($files_status[4] == 0)
    {
        open(FP_PLD, $PROJECT_vivado_project_FILE) or die $!;
        open(fp, ">$files[4]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            s/<top_module_name>/$DESIGN_NAME/g;
            print fp;
        }
        close(FP_PLD);
        close(fp);
    }

    if ($files_status[5] == 0)
    {
        open(FP_PLD, $BATCH_mk_clean_FILE) or die $!;
        open(fp, ">$files[5]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            print fp;
        }

        close(FP_PLD);
        close(fp);
    }

    if ($files_status[6] == 0)
    {
        open(FP_PLD, $BATCH_vivado_project_FILE) or die $!;
        open(fp, ">$files[6]");
        print fp "# Created : $Date_and_Time : Sanjay Rai\n\n";
        while (<FP_PLD>) {
            s/<top_module_name>/$DESIGN_NAME/g;
            print fp;
        }
        close(FP_PLD);
        close(fp);
    }
}
