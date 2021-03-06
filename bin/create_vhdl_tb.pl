bin/extract_locs.pl                                                                                 0000750 0161652 0024461 00000016322 10640276275 015273  0                                                                                                    ustar   sanjayr                         mkgroup-l-d                                                                                                                                                                                                            #!perl
#
#
my $LOC_val;
my @hdl_instance_names;

$USAGE = "\n Usage :\n\t extract_locs file.ngd file.ncd [-Iinstance_path_to_include1#instance_path_to_include2] [-Einstance_path_to_exclude1#instance_path_to_exclude2]\n";

$file_ext_ngd = $ARGV[0];
$file_ext_ncd = $ARGV[1];
$file_ext_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name = $1;
$file_ext_ngd =~ s/(^.*)\.(ngd)/$2/;
$ngd_hdl_name = $1."_ngd.v";
$primitives_v5 = "SLICEM|SLICEL|RAMB36_EXP|RAMB36SDP_EXP|FIFO36_72_EXP|FIFO36_EXP|DSP48|DSP48A|DSP48E";
$exclude_instances = "";
$include_instances = ".*";

if ($#ARGV < 4) {
    if ($#ARGV > 1) {
        for ($i = 2; $i < ($#ARGV+1); $i++) {
            $input_arg = $ARGV[$i];
            if ($input_arg=~/^-I.*/) {
                $include_instances = $input_arg; 
                $include_instances =~ s/^-I//;
                $include_instances =~s/\//\\\//g;
                $include_instances =~s/\./\\\./g;
                $include_instances =~ s/#/.*|/;
                $include_instances = "(".$include_instances."\.*)";
            } elsif ($input_arg=~/^-E/) {
                $exclude_instances = $input_arg; 
                $exclude_instances =~ s/^-E//;
                $exclude_instances =~s/\//\\\//g;
                $exclude_instances =~s/\./\\\./g;
                $exclude_instances =~ s/#/|/;
                $exclude_instances = "(".$exclude_instances."\.*)";
            } else {
                print "\n !ERROR Wrong Arguments\n";
                print $USAGE; 
                die;
            }
        }
    }
} else {
    print "\n !ERROR Wrong Number of Arguments\n";
    print $USAGE; 
    die;
}

print "Excluded Instances : $exclude_instances\n";
print "Included Instances : $include_instances\n";

if ($file_ext_ngd ne "ngd") { 
    print "\n !ERROR Wrong File type\n";
    print $USAGE; 
    die;
}elsif ($file_ext_ncd ne "ncd") { 
    print "\n !ERROR Wrong File type\n";
    print $USAGE; 
    die;
} else {
    print "Working.....\n\tInput NGD File\t= $ARGV[0]\n\tInput NCD File\t= $ARGV[1]\n";
    `xdl -ncd2xdl $ARGV[1] $design_name.xdl`;
    open FP_XDL, "$design_name.xdl" or die $!; # Open Input xdl file for reading file
    `netgen -ofmt verilog -fn -w $ARGV[0] $ngd_hdl_name`;
    open FP_NGD_HDL, "$ngd_hdl_name" or die $!; # Open Input xdl file for reading file
    $out_file = $design_name.".ncf";
    open FP_out, ">$out_file" or die $!;
    print "\tOutput file\t= $out_file\n";
    open FP_LOG, ">extract_locs.log" or die $!;


    # Read the file_ngd.v hdl file and make a list of all Instance names
    $prev_pram = "";
    while (<FP_NGD_HDL>) {
        s/^\s*//; #remove LEading Edge Spaces
        s/\/\/.*//; # Remove Comments
        if (/\bdefparam\s/i) {
            s/\bdefparam\s*//i;
            if (/^\\/) {
                s/\s\.\w.*//; # Remove everything past the dot(.)
            } else {
                s/\.\w.*//;
            }
            s/\\//g;
            s/\s*//g;
            if ($_ ne $prev_pram) {
                push(@hdl_instance_names, $_); 
            }
            $prev_pram = $_; # This is done to handle Multiple defpram lines
        }
    }
    close FP_NGD_HDL;


    print FP_LOG "extract_locs $ARGV[0] $ARGV[1]\n";
    print FP_LOG "Following Tokens in the NCD file did not Match NGD instance names\n";

    $extract_LOCS = 0;
    while (<FP_XDL>) {
        # Check Device Type First
        if (/^design\b/i) {
            @device_type_tokens = split;
            $device_type = $device_type_tokens[2];
            if ($device_type =~ /^xc5v.*/i) {
                print "\tDevice Type\t= $device_type\n";
            } else {
                print "\tDevice Type = $device_type NOT SUPPORTED Exiting!!\n";
                close FP_XDL;
                close FP_out;
                close FP_LOG;
                die;
            }
        }
        s/inst.*XDL_DUMMY.*//;
        s/cfg *"//;
        s/\\\s/_/; # Substitute \  with an _ (ie Space with _) THis helps remove _INST_PROP.*
        s/_INST_PROP::.*//;
        s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
        s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy
        if (/^inst\b.*\b($primitives_v5)\b/i) {
            $extract_LOCS = 1;
            s/placed//; #Eliminate keyword placed
            s/,//g; # Eliminate ,'s
            s/\s*$/\n/;
            @fields = split;
            $LOC_val= $fields[4];
        } elsif ($extract_LOCS == 1) {
            if(/\s;\s/) {
                $extract_LOCS = 0;
            } else {
                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    if ($token=~/A5LUT:.+:/) {
                        $BEL = "A5LUT";
                    } elsif ($token=~/A6LUT:.+:/) {
                        $BEL = "A6LUT";
                    } elsif ($token=~/B5LUT:.+:/) {
                        $BEL = "B5LUT"
                    } elsif ($token=~/B6LUT:.+:/) {
                        $BEL = "B6LUT";
                    } elsif ($token=~/C5LUT:.+:/) {
                        $BEL = "C5LUT";
                    } elsif ($token=~/C6LUT:.+:/) {
                        $BEL = "C6LUT";
                    } elsif ($token=~/D5LUT:.+:/) {
                        $BEL = "D5LUT";
                    } elsif ($token=~/D6LUT:.+:/) {
                        $BEL = "D6LUT";
                    } elsif ($token=~/AFF:.+:/) {
                        $BEL = "AFF";
                    } elsif ($token=~/BFF:.+:/) {
                        $BEL = "BFF";
                    } elsif ($token=~/CFF:.+:/) {
                        $BEL = "CFF";
                    } elsif ($token=~/DFF:.+:/) {
                        $BEL = "DFF";
                    } else {
                        $BEL = "";
                    }
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if ($token=~/$exclude_instances/i) {
                        last;
                    } elsif ($token=~/$include_instances/i) {
                        if($token ne "") {
                            $match = 0;
                            foreach $hdl_instance_name (@hdl_instance_names) {
                                if ($hdl_instance_name eq $token) {
                                    $match = 1;
                                    if($BEL) {
                                        print FP_out "INST \"$token\" LOC = \"$LOC_val\" | BEL = \"$BEL\";\n";
                                    } else {
                                        print FP_out "INST \"$token\" LOC = \"$LOC_val\";\n";
                                    }
                                    last; # Break out of the loop - No reason to Check further
                                }
                            }
                            if ($match == 0) {
                                print FP_LOG "$token :: $LOC_val\n";
                            }
                        }

                    }
                }
            }
        }
    }

     



    close FP_XDL;
    close FP_out;
    close FP_LOG;
}
                                                                                                                                                                                                                                                                                                              bin/extract_locs_ip_inst.pl                                                                         0000750 0161652 0024461 00000020407 10650205135 017003  0                                                                                                    ustar   sanjayr                         mkgroup-l-d                                                                                                                                                                                                            #!perl
#
#
my $LOC_val;
my @hdl_instance_names;
$WRITE_RLOCS = 0;

$USAGE = "\n Usage :\n\t extract_locs_ip_inst file.ngd file.ncd instance_name_to_extract [-Einstance_path_to_exclude1#instance_path_to_exclude2] [-RLOC [SET_identifier]]\n";

if (($#ARGV > 5) | ($#ARGV < 2)) {
    print "\n !ERROR Wrong Number of Arguments\n";
    print $USAGE; 
    die;
}


$file_ext_ngd = $ARGV[0];
$file_ext_ncd = $ARGV[1];
$ip_instance = $ARGV[2];
$file_ext_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name = $1;
$file_ext_ngd =~ s/(^.*)\.(ngd)/$2/;
$ngd_hdl_name = $1."_ngd.v";
$primitives_v5 = "SLICEM|SLICEL|RAMB36_EXP|RAMB36SDP_EXP|FIFO36_72_EXP|FIFO36_EXP|DSP48|DSP48A|DSP48E";
$exclude_instances = "";
$include_instances = ".*";

$set_identifier = $ip_instance;

$include_instances = $ip_instance."/"; 
$include_instances =~ s/^-I//;
$include_instances =~s/\//\\\//g;
$include_instances =~s/\./\\\./g;
$include_instances =~ s/#/.*|/;
$include_instances = "(".$include_instances."\.*)";

if ($#ARGV > 2) {
    for ($i = 3; $i < ($#ARGV+1); $i++) {
        $input_arg = $ARGV[$i];
        if ($input_arg=~/^-E/) {
            $exclude_instances = $input_arg; 
            $exclude_instances =~ s/^-E//;
            $exclude_instances =~s/\//\\\//g;
            $exclude_instances =~s/\./\\\./g;
            $exclude_instances =~ s/#/|/;
            $exclude_instances = "(".$exclude_instances."\.*)";
        } elsif ($input_arg =~ /^-RLOC/) {
            $WRITE_RLOCS = 1;
            if ($#ARGV >= $i+1) {
                $i++;
                $set_identifier = $ARGV[$i];
            }
        } else {
            print "\n !ERROR Wrong Argument $input_arg : \n";
            print $USAGE; 
            die;
        }
    }
}


print "Instance being Extracted to NCF File : $include_instances\n";
print "Excluded Instances : $exclude_instances\n";

if ($file_ext_ngd ne "ngd") { 
    print "\n !ERROR Wrong File type\n";
    print $USAGE; 
    die;
}elsif ($file_ext_ncd ne "ncd") { 
    print "\n !ERROR Wrong File type\n";
    print $USAGE; 
    die;
} else {
    print "Working.....\n\tInput NGD File\t= $ARGV[0]\n\tInput NCD File\t= $ARGV[1]\n";
    `xdl -ncd2xdl $ARGV[1] $design_name.xdl`;
    open FP_XDL, "$design_name.xdl" or die $!; # Open Input xdl file for reading file
    `netgen -ofmt verilog -fn -w $ARGV[0] $ngd_hdl_name`;
    open FP_NGD_HDL, "$ngd_hdl_name" or die $!; # Open Input xdl file for reading file
    $out_file = $ip_instance.".ncf";
    open FP_out, ">$out_file" or die $!;
    print "\tOutput file\t= $out_file\n";
    open FP_LOG, ">extract_locs.log" or die $!;


    # Read the file_ngd.v hdl file and make a list of all Instance names
    $prev_pram = "";
    while (<FP_NGD_HDL>) {
        s/^\s*//; #remove LEading Edge Spaces
        s/\/\/.*//; # Remove Comments
        if (/\bdefparam\s/i) {
            s/\bdefparam\s*//i;
            if (/^\\/) {
                s/\s\.\w.*//; # Remove everything past the dot(.)
            } else {
                s/\.\w.*//;
            }
            s/\\//g;
            s/\s*//g;
            if ($_ ne $prev_pram) {
                push(@hdl_instance_names, $_); 
            }
            $prev_pram = $_; # This is done to handle Multiple defpram lines
        }
    }
    close FP_NGD_HDL;


    print FP_LOG "extract_locs $ARGV[0] $ARGV[1]\n";
    print FP_LOG "Following Tokens in the NCD file did not Match NGD instance names\n";

    $extract_LOCS = 0;
    while (<FP_XDL>) {
        # Check Device Type First
        if (/^design\b/i) {
            @device_type_tokens = split;
            $device_type = $device_type_tokens[2];
            if ($device_type =~ /^xc5v.*/i) {
                print "\tDevice Type\t= $device_type\n";
            } else {
                print "\tDevice Type = $device_type NOT SUPPORTED Exiting!!\n";
                close FP_XDL;
                close FP_out;
                close FP_LOG;
                die;
            }
        }
        s/inst.*XDL_DUMMY.*//;
        s/cfg *"//;
        s/\\\s/_/; # Substitute \  with an _ (ie Space with _) THis helps remove _INST_PROP.*
        s/_INST_PROP::.*//;
        s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
        s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy
        if (/^inst\b.*\b($primitives_v5)\b/i) {
            $extract_LOCS = 1;
            s/placed//; #Eliminate keyword placed
            s/,//g; # Eliminate ,'s
            s/\s*$/\n/;
            @fields = split;
            $LOC_val= $fields[4];
        } elsif ($extract_LOCS == 1) {
            if(/\s;\s/) {
                $extract_LOCS = 0;
            } else {
                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    if ($token=~/A5LUT:.+:/) {
                        $BEL = "A5LUT";
                    } elsif ($token=~/A6LUT:.+:/) {
                        $BEL = "A6LUT";
                    } elsif ($token=~/B5LUT:.+:/) {
                        $BEL = "B5LUT"
                    } elsif ($token=~/B6LUT:.+:/) {
                        $BEL = "B6LUT";
                    } elsif ($token=~/C5LUT:.+:/) {
                        $BEL = "C5LUT";
                    } elsif ($token=~/C6LUT:.+:/) {
                        $BEL = "C6LUT";
                    } elsif ($token=~/D5LUT:.+:/) {
                        $BEL = "D5LUT";
                    } elsif ($token=~/D6LUT:.+:/) {
                        $BEL = "D6LUT";
                    } elsif ($token=~/AFF:.+:/) {
                        $BEL = "AFF";
                    } elsif ($token=~/BFF:.+:/) {
                        $BEL = "BFF";
                    } elsif ($token=~/CFF:.+:/) {
                        $BEL = "CFF";
                    } elsif ($token=~/DFF:.+:/) {
                        $BEL = "DFF";
                    } else {
                        $BEL = "";
                    }
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if ($token=~/$exclude_instances/i) {
                        last;
                    } elsif ($token=~/$include_instances/i) {
                        if($token ne "") {
                            $match = 0;
                            foreach $hdl_instance_name (@hdl_instance_names) {
                                if ($hdl_instance_name eq $token) {
                                    $match = 1;
                                    #Remove $ip_instance name from the TOKEN since we writing an Instance specific NCF file
                                    $token =~ s/^$ip_instance\///;
                                    if($BEL) {
                                        if ($WRITE_RLOCS == 1) {
                                            $LOC_val =~ s/^.*_(X\d+Y\d+)/$1/i;
                                            print FP_out "INST \"$token\" RLOC = \"$LOC_val\" | BEL = \"$BEL\" | HU_SET = \"$set_identifier\";\n";
                                        } else {
                                            print FP_out "INST \"$token\" LOC = \"$LOC_val\" | BEL = \"$BEL\";\n";
                                        }
                                    } else {
                                        if ($WRITE_RLOCS == 1) {
                                            $LOC_val =~ s/^.*_(X\d+Y\d+)/$1/i;
                                            print FP_out "INST \"$token\" RLOC = \"$LOC_val\" | HU_SET = \"$set_identifier\";\n";
                                        } else {
                                            print FP_out "INST \"$token\" LOC = \"$LOC_val\";\n";
                                        }
                                    }
                                    last; # Break out of the loop - No reason to Check further
                                }
                            }
                            if ($match == 0) {
                                print FP_LOG "$token :: $LOC_val\n";
                            }
                        }

                    }
                }
            }
        }
    }

     



    close FP_XDL;
    close FP_out;
    close FP_LOG;
}
                                                                                                                                                                                                                                                         bin/touchvhd.pl                                                                                     0000750 0161652 0024461 00000002356 10631333416 014416  0                                                                                                    ustar   sanjayr                         mkgroup-l-d                                                                                                                                                                                                            #!perl

if ($#ARGV != 0) {
    print "Wrong number of Arguments\n";
    die;
} else {
    $file_ext = $ARGV[0];
    $file_ext =~ s/^.*\.//;
    $entity = $ARGV[0];
    $entity =~ s/\.vhd//;
    $architecture = "arch_"."$entity";

    if (-e $ARGV[0]) {
        print "File $ARGV[0] Already exists !\n";
        die;
    } else {
        open FP_VHDL, ">$ARGV[0]";

        print FP_VHDL "-- Author: Sanjay Rai (Xilinx, Inc.)\n";
        print FP_VHDL "-- CVS Log: \$log:\n\n";

        print FP_VHDL "Library IEEE;\n";
        print FP_VHDL "use IEEE.std_logic_1164.all;\n";
        print FP_VHDL "use IEEE.std_logic_arith.all;\n";
        print FP_VHDL "use IEEE.std_logic_unsigned.all;\n";
        print FP_VHDL "Library unisim;\n";
        print FP_VHDL "use unisim.vcomponents.all;\n\n"; 
        print FP_VHDL "entity $entity is\n";
        print FP_VHDL "\tgeneric (\n";
        print FP_VHDL "\t);\n";
        print FP_VHDL "\tport (\n";
        print FP_VHDL "\t);\n";
        print FP_VHDL "end entity $entity;\n\n";
        print FP_VHDL "architecture $architecture of $entity is\n\n";
        print FP_VHDL "begin\n\n";
        print FP_VHDL "end architecture $architecture;\n";

        close FP_VHDL;
    }
}
                                                                                                                                                                                                                                                                                  bin/xil_ip_gen.pl                                                                                   0000750 0161652 0024461 00000042172 10650166131 014706  0                                                                                                    ustar   sanjayr                         mkgroup-l-d                                                                                                                                                                                                            use File::Copy;

my @comp_fields;
my @component_instance;


$Error_msg = "Wrong Arguments !\n\tusage:\n\t\txil_ip_gen -lib Library_name xst_cmd_file.xst module_name module_name.xcf\n";

# DEfault Device type
$DEVICE_TYPE = "xc5vlx50t-1-ff1136a";
$IP_dirs = "";

if ($#ARGV != 4) {
    print $Error_msg;
    die;
} elsif ($ARGV[0] ne "-lib") {
    print $Error_msg;
    die;
} elsif ( ! (-e $ARGV[1])) {
    mkdir $ARGV[1], 0755 or die "Cannot Create Directory $ARGV[0] : $!";
}

$library_name = $ARGV[1]; 
$module_name = $ARGV[3];
$module_name_ncf = "$library_name\/$module_name".".ncf"; 
$module_name_xcf = $ARGV[4];
$NGC_file = "$library_name\/$module_name".".ngc";
$NGD_file = "$library_name\/$module_name".".ngd";
$NGD_hdl_file = "$library_name\/$module_name"."_ngd.vhd";
$PCF_file = "$library_name\/$module_name".".pcf";
$NCD_map_file = "$library_name\/$module_name"."_map.ncd";
$ip_gen_top_module = "ip_gen_top_"."$module_name";
$IP_GEN_VHDL_file = "$library_name\/$ip_gen_top_module".".vhd";
$IP_GEN_TOP_XST_file = "$library_name\/$ip_gen_top_module".".xst";
$IP_GEN_TOP_PRJ_file = "$library_name\/$ip_gen_top_module".".prj";
$IP_GEN_TOP_UCF_file_name = "$ip_gen_top_module".".ucf";
$IP_GEN_TOP_UCF_file = "$library_name\/$IP_GEN_TOP_UCF_file_name";

print "\t******* Creating $IP_GEN_TOP_XST_file ********\n";
open FP_XST, "<$ARGV[2]" or die "Cannot Open $ARGV[2] file for reading : $!";
open FP_IP_XST, ">xil_ip_gen.xst" or die "Cannot Create intermedeate XST file xil_ip_gen.xst: $!";
open FP_IP_GEN_TOP_XST, ">$IP_GEN_TOP_XST_file" or die "Cannot Open $IP_GEN_TOP_XST_file for writing : $!"; 

while (<FP_XST>) {
    if (/^-ofn\s.*/i) {
        print FP_IP_XST "-ofn $library_name\/$module_name\n";
        print FP_IP_GEN_TOP_XST "-ofn $ip_gen_top_module\n";
    } elsif (/^-ifn\s.*/i) {
        print FP_IP_XST;
        print FP_IP_GEN_TOP_XST "-ifn $ip_gen_top_module".".prj\n";
    } elsif (/^-iuc\s.*/i) {
        print FP_IP_XST "-iuc NO\n";
        print FP_IP_GEN_TOP_XST "-iuc NO\n";
    } elsif (/^-top\s.*/i) {
        print FP_IP_XST "-top $module_name\n";
        print FP_IP_GEN_TOP_XST "-top $ip_gen_top_module\n";
    } elsif (/^-write_timing_constraints\s.*/i) {
        print FP_IP_XST "-write_timing_constraints YES\n";
        print FP_IP_GEN_TOP_XST "-write_timing_constraints YES\n";
    } elsif (/^-read_cores\s.*/i) {
        print FP_IP_XST "-read_cores OPTIMIZE\n";
        print FP_IP_GEN_TOP_XST "-read_cores YES\n"; #This ensures the IP_MODULE is read and the Clock_buffers are inserted (xcf constraint to say this must exist)
    } elsif (/^-keep_hierarchy\s.*/i) {
        print FP_IP_XST "-keep_hierarchy YES\n";
        print FP_IP_GEN_TOP_XST "-keep_hierarchy YES\n";
    } elsif (/^-iobuf\s.*/i) {
        print FP_IP_XST "-iobuf NO\n";
        print FP_IP_GEN_TOP_XST "-iobuf NO\n";
    } elsif (/^-p\s.*/i) {
        $DEVICE_TYPE = $_;
        $DEVICE_TYPE =~ s/^-p\s*(\w.*)/$1/;
        print FP_IP_XST;
        print FP_IP_GEN_TOP_XST;
    } elsif (/^-sd\s.*/i) {
        $IP_dirs = $IP_dirs.$_;
        print FP_IP_XST;
        print FP_IP_GEN_TOP_XST;
    } else {
        print FP_IP_XST;
        print FP_IP_GEN_TOP_XST;
    }
}

print FP_IP_XST "-uc $module_name_xcf";

close FP_XST;
close FP_IP_XST;
close FP_IP_GEN_TOP_XST;



print "\t******* Synthesizing $module_name ********\n";
$xst_report = `xst -ifn xil_ip_gen.xst -intstyle silent`;
if ( $xst_report =~ /ERROR/i ) {
    print "XST Synthesis Failed!\n $xst_report\n";
    die;
}
print "\t******* running NGDBUILD on $module_name ********\n";
@ngdbuild_report = `ngdbuild -verbose -nt timestamp -dd _ngo -p $DEVICE_TYPE $NGC_file $NGD_file`;
foreach $line (@ngdbuild_report) {
    if ($line =~ /Number\s*of\s*Errors\s*:\s*(\d+)/i) {
        if ($1 != 0) {
            print "NGDBUILD Failed with $1 Errors\n";
            die;
        }
    }
}
print "\t******* running NETGEN on $module_name ********\n";
`netgen -ofmt vhdl -fn -w $NGD_file $NGD_hdl_file`;


print "\t******* Creating $IP_GEN_VHDL_file ********\n";
#create ip_gen_{module_name}.vhd
open FP_IP_GEN_VHDL, ">$IP_GEN_VHDL_file" or die "Cannot Open ip_gen_$module_name for writing : $!"; 
open FP_NGD_HDL_FILE, "<$NGD_hdl_file" or die "Cannot Open $NGD_hdl_file file for reading : $!";

print FP_IP_GEN_VHDL "Library IEEE;\n";
print FP_IP_GEN_VHDL "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL "Library unisim;\n";
print FP_IP_GEN_VHDL "use unisim.vcomponents.all;\n\n";
print FP_IP_GEN_VHDL "entity $ip_gen_top_module is\n";
print FP_IP_GEN_VHDL "end entity $ip_gen_top_module;\n\n\n";
print FP_IP_GEN_VHDL "architecture arch_$ip_gen_top_module of $ip_gen_top_module is\n";
print FP_IP_GEN_VHDL "\n";

$start_extracting = 0;
while (<FP_NGD_HDL_FILE>) {
    if ( /Entity\s*\b$module_name\b/i ) {
        s/Entity\b/component/i;
        $start_extracting = 1;
    }
    if ($start_extracting == 1) {
        if (/End\s.*\b$module_name\b/i) {
            $start_extracting = 0;
            print FP_IP_GEN_VHDL "end component $module_name;\n";
        }
    }
    if ($start_extracting == 1) {
        print FP_IP_GEN_VHDL $_;
        if (/.*\s*:\s*(in|out)\s+std_logic/i) {
            s/^\s*//;#delete leading spaces
            s/\s+/ /; # Convert multiple spaces to single
            s/:=.*//; # Delete init values
            push(@comp_fields, $_);
        }
    }
}
close FP_NGD_HDL_FILE;


# Generate Component instation and determine number of INPUT and OUTPUT
# Create a List variable with this info. but writing to the actual VHDL file happens later


push(@component_instance, "u_ip_gen : $module_name\n");
push(@component_instance, "\tport map (\n");
$number_of_inputs = 0;
$number_of_outputs = 0;
foreach $comp_field (@comp_fields) {
    $comp_field =~ s/:/=>/;
    chomp($comp_field);
    if ( $comp_field =~ /\bin\b/i ) {
        if ($comp_field =~ /\bstd_logic\b/i) {
            $comp_field =~ s/\bin\b.*/jtag_in_reg($number_of_inputs)/i;
            $number_of_inputs++;
        } elsif ($comp_field =~ /\bstd_logic_vector\b/i) {
            $comp_field =~ s/\bin\b.*std_logic_vector\s*\(\s*(\d+)\s+downto\s+(\d+)\s*\).*/jtag_in_reg(#async_in_count#)/i;
            $start_count = $number_of_inputs;
            $number_of_inputs = $number_of_inputs + $1 - $2;
            $comp_field =~ s/#async_in_count#/$number_of_inputs downto $start_count/;
            $number_of_inputs++;
        }
    } elsif ( $comp_field =~ /\bout\b/i) {
        if ($comp_field =~ /\bstd_logic\b/i) {
            $comp_field =~ s/\bout\b.*/jtag_out_reg($number_of_outputs)/i;
            $number_of_outputs++;
        } elsif ($comp_field =~ /\bstd_logic_vector\b/i) {
            $comp_field =~ s/\bout\b.*std_logic_vector\s*\(\s*(\d+)\s+downto\s+(\d+)\s*\).*/jtag_out_reg(#async_out_count#)/i;
            $start_count = $number_of_outputs;
            $number_of_outputs = $number_of_outputs + $1 - $2;
            $comp_field =~ s/#async_out_count#/$number_of_outputs downto $start_count/;
            $number_of_outputs++;
        }
    }
    push(@component_instance, "\t\t$comp_field,\n");
}
push(@component_instance, "\t);\n");
print FP_IP_GEN_VHDL "-- Number of Input ports : $number_of_inputs\n";
print FP_IP_GEN_VHDL "-- Number of outputs ports : $number_of_outputs\n\n";
$jtag_out_reg_sz = $number_of_outputs - 1;
$jtag_in_reg_sz = $number_of_inputs - 1;

$jtag_in_reg_sz_1 = $jtag_in_reg_sz - 1;
$jtag_out_reg_sz_1 = $jtag_out_reg_sz - 1;

print FP_IP_GEN_VHDL "signal iTCK, iTDI, i_reset, i_shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL "signal jTCK, jTDI, j_reset, j_shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL "\n";
print FP_IP_GEN_VHDL "signal jtag_in_reg, user_i_reg   : std_logic_vector($jtag_in_reg_sz downto 0) := (others => '0');\n";
print FP_IP_GEN_VHDL "signal jtag_out_reg, user_j_reg  : std_logic_vector($jtag_out_reg_sz downto 0) := (others => '0');\n";
print FP_IP_GEN_VHDL "\n";
print FP_IP_GEN_VHDL "begin\n";
print FP_IP_GEN_VHDL "\n";
print FP_IP_GEN_VHDL "\n";

print FP_IP_GEN_VHDL "-- Output Boundary SCAN for INPUT Ports\n\n";
print FP_IP_GEN_VHDL "U_BSCAN_i: BSCAN_VIRTEX5\n";
print FP_IP_GEN_VHDL "\tgeneric map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tJTAG_CHAIN => 1\n";
print FP_IP_GEN_VHDL "\t)\n";
print FP_IP_GEN_VHDL "\tport map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tCAPTURE => open,\n";
print FP_IP_GEN_VHDL "\t\tDRCK => iTCK,\n";
print FP_IP_GEN_VHDL "\t\tRESET => i_reset,\n";
print FP_IP_GEN_VHDL "\t\tSEL => open,\n";
print FP_IP_GEN_VHDL "\t\tSHIFT => i_shift,\n";
print FP_IP_GEN_VHDL "\t\tTDI => iTDI,\n";
print FP_IP_GEN_VHDL "\t\tUPDATE => OPEN,\n";
print FP_IP_GEN_VHDL "\t\tTDO => '0'\n";
print FP_IP_GEN_VHDL "\t);\n\n";
print FP_IP_GEN_VHDL "proc_user_i_reg_out: process(i_reset, iTCK)\n";
print FP_IP_GEN_VHDL "begin\n";
print FP_IP_GEN_VHDL "\tif (i_reset = '1') then\n";
print FP_IP_GEN_VHDL "\t\tuser_i_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL "\t\tjtag_in_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL "\telsif (iTCK'event and iTCK = '1') then\n";
print FP_IP_GEN_VHDL "\t\tif (i_shift = '1') then\n";
print FP_IP_GEN_VHDL "\t\t\tuser_i_reg <= user_i_reg($jtag_in_reg_sz_1 downto 0) & iTDI;\n";
print FP_IP_GEN_VHDL "\t\telse\n";
print FP_IP_GEN_VHDL "\t\t\tjtag_in_reg <= user_i_reg;\n";
print FP_IP_GEN_VHDL "\t\tend if;\n";
print FP_IP_GEN_VHDL "\tend if;\n";
print FP_IP_GEN_VHDL "end process;\n";

print FP_IP_GEN_VHDL "-- Output Boundary SCAN for OUTPUT Ports\n\n";
print FP_IP_GEN_VHDL "U_BSCAN_j: BSCAN_VIRTEX5\n";
print FP_IP_GEN_VHDL "\tgeneric map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tJTAG_CHAIN => 2\n";
print FP_IP_GEN_VHDL "\t)\n";
print FP_IP_GEN_VHDL "\tport map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tCAPTURE => open,\n";
print FP_IP_GEN_VHDL "\t\tDRCK => jTCK,\n";
print FP_IP_GEN_VHDL "\t\tRESET => j_reset,\n";
print FP_IP_GEN_VHDL "\t\tSEL => open,\n";
print FP_IP_GEN_VHDL "\t\tSHIFT => j_shift,\n";
print FP_IP_GEN_VHDL "\t\tTDI => OPEN,\n";
print FP_IP_GEN_VHDL "\t\tUPDATE => OPEN,\n";
print FP_IP_GEN_VHDL "\t\tTDO => user_j_reg($jtag_out_reg_sz)\n";
print FP_IP_GEN_VHDL "\t);\n\n";
print FP_IP_GEN_VHDL "proc_user_j_reg_out: process(j_reset, iTCK)\n";
print FP_IP_GEN_VHDL "begin\n";
print FP_IP_GEN_VHDL "\tif (j_reset = '1') then\n";
print FP_IP_GEN_VHDL "\t\tuser_j_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL "\telsif (jTCK'event and jTCK = '1') then\n";
print FP_IP_GEN_VHDL "\t\tif (j_shift = '1') then\n";
print FP_IP_GEN_VHDL "\t\t\tuser_j_reg <= user_j_reg($jtag_out_reg_sz_1 downto 0) & user_j_reg($jtag_out_reg_sz);\n";
print FP_IP_GEN_VHDL "\t\telse\n";
print FP_IP_GEN_VHDL "\t\t\tuser_j_reg <= jtag_out_reg;\n";
print FP_IP_GEN_VHDL "\t\tend if;\n";
print FP_IP_GEN_VHDL "\tend if;\n";
print FP_IP_GEN_VHDL "end process;\n";



$component_instance_line_count = $#component_instance;
foreach $component_instance_line (@component_instance) {
    # This is needed to take out the comma from the last line!
    if ($component_instance_line_count == 1) {
        $component_instance_line =~ s/,\n/\n/;
        print FP_IP_GEN_VHDL $component_instance_line;
    } else {
        print FP_IP_GEN_VHDL $component_instance_line;
    }
    $component_instance_line_count--;
}

print FP_IP_GEN_VHDL "\n\nend architecture arch_$ip_gen_top_module;\n";
close FP_IP_GEN_VHDL;


print "\t******* Creating $IP_GEN_TOP_PRJ_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_PRJ, ">$IP_GEN_TOP_PRJ_file" or die "Cannot Open $IP_GEN_TOP_PRJ_file for writing : $!"; 
print FP_IP_GEN_TOP_PRJ "vhdl work \"$ip_gen_top_module".".vhd\"";
close FP_IP_GEN_TOP_PRJ;

print "\t******* Creating $IP_GEN_TOP_UCF_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_UCF, ">$IP_GEN_TOP_UCF_file" or die "Cannot Open $IP_GEN_TOP_UCF_file for writing : $!"; 
print FP_IP_GEN_TOP_UCF "NET \"iTCK\" TIG;";
print FP_IP_GEN_TOP_UCF "NET \"jTCK\" TIG;";
print FP_IP_GEN_TOP_UCF "INST \"u_ip_gen\" AREA_GROUP = \"AG_U_IP_GEN\";";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" RANGE=SLICE_X6Y100:SLICE_X11Y109;";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" GROUP=CLOSED;";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" PLACE=CLOSED;";


close FP_IP_GEN_TOP_UCF;

$IP_GEN_MAKEFILE = "$library_name\/Makefile";
#Create Makefile
open FP_IP_GEN_MAKEFILE, ">$IP_GEN_MAKEFILE" or die "Cannot Open $IP_GEN_MAKEFILE for writing : $!"; 
print "\t******* Creating $IP_GEN_MAKEFILE ********\n";
print FP_IP_GEN_MAKEFILE "TARGET=$ip_gen_top_module\n";
print FP_IP_GEN_MAKEFILE "DEVICE=$DEVICE_TYPE\n\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_0 = -intstyle ise -w -g DebugBitstream:No -g Binary:no -g CRC:Enable -m\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_1 = -g CclkPin:PullUp -g M0Pin:PullUp -g M1Pin:PullUp -g M2Pin:PullUp -g ProgPin:PullUp\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_2 = -g DonePin:PullUp -g InitPin:Pullup -g CsPin:Pullup -g DinPin:Pullup -g BusyPin:Pullup\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_3 = -g RdWrPin:Pullup -g TckPin:PullUp -g TdiPin:PullUp -g TdoPin:PullUp -g TmsPin:PullUp\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_4 = -g UnusedPin:Pullnone\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_5 = -g DCIUpdateMode:AsRequired -g StartUpClk:CCLK -g DONE_cycle:4 -g GTS_cycle:5 -g GWE_cycle:6\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTS_6 = -g LCK_cycle:NoWait -g Security:None -g DonePipe:No -g DriveDone:No -g UserID:\$(Bit_file_ID)\n";
print FP_IP_GEN_MAKEFILE "BITGEN_OPTIONS = \$(BITGEN_OPTS_0) \$(BITGEN_OPTS_1) \$(BITGEN_OPTS_2) \$(BITGEN_OPTS_3) \$(BITGEN_OPTS_4) \$(BITGEN_OPTS_5) \$(BITGEN_OPTS_6)\n\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_par.mcs: \$(TARGET)_par.bit\n";
print FP_IP_GEN_MAKEFILE "\tpromgen -w -p mcs -c FF -o \$(TARGET)_par -u 0 \$(TARGET)_par.bit\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET).ibs: \$(TARGET)_par.ncd\n";
print FP_IP_GEN_MAKEFILE "\tibiswriter -intstyle silent -allmodels \$(TARGET)_par.ncd \$(TARGET).ibs\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_par.bit: \$(TARGET)_par.ncd\n";
print FP_IP_GEN_MAKEFILE "\tnetgen -intstyle silent -ofmt vhdl -pcf \$(TARGET).pcf -w \$(TARGET)_par.ncd \$(TARGET)_par.vhd\n";
print FP_IP_GEN_MAKEFILE "\ttrce -intstyle silent -a -e 5 -u -skew -l 10 \$(TARGET)_par.ncd -o \$(TARGET).twr \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\tbitgen \$(BITGEN_OPTIONS) \$(TARGET)_par.ncd \n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_par.ncd: \$(TARGET)_map.ncd\n";
print FP_IP_GEN_MAKEFILE "\tpar -w -intstyle silent -ol std -pl std -rl std -t 1 \$(TARGET)_map.ncd \$(TARGET)_par.ncd \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_map.ncd: \$(TARGET).ngd\n";
print FP_IP_GEN_MAKEFILE "\tmap -timing -intstyle silent -p \$(DEVICE) -cm area -pr b -k 4 -c 100 -o \$(TARGET)_map.ncd \$(TARGET).ngd \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET).ngd: \$(TARGET).ngc\n";
print FP_IP_GEN_MAKEFILE "\tnetgen -intstyle silent -ofmt vhdl -w \$(TARGET).ngc \$(TARGET)_xst.vhd\n";
print FP_IP_GEN_MAKEFILE "\tngdbuild -intstyle silent -verbose -nt timestamp -dd _ngo -p \$(DEVICE) -uc $IP_GEN_TOP_UCF_file_name \$(TARGET).ngc \$(TARGET).ngd\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET).ngc:\n";
print FP_IP_GEN_MAKEFILE "\txst -ifn \$(TARGET).xst -intstyle silent\n";
print FP_IP_GEN_MAKEFILE "clean:\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).lso\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).ngc\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).ngr\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).srp\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_xst.nlf\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_xst.vhd\n";
print FP_IP_GEN_MAKEFILE "\t-rm -rf dump.xst\n";
print FP_IP_GEN_MAKEFILE "\t-rm -rf xst_work_lib\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).ngd \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).bld \n";
print FP_IP_GEN_MAKEFILE "\t-rm -rf _ngo \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_map.mrp \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_map.ncd \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_map.ngm \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.pad \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.par \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.ncd \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.nlf \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.sdf \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.unroutes \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.xpi \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par_pad.csv \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par_pad.txt \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.vhd \n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET).twr\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.bgn\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.bit\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.drc\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.msk\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.mcs\n";
print FP_IP_GEN_MAKEFILE "\t-rm -f \$(TARGET)_par.prm\n";

close FP_IP_GEN_MAKEFILE;
                                                                                                                                                                                                                                                                                                                                                                                                      bin/xproj.pl                                                                                        0000750 0161652 0024461 00000051615 10645742110 013736  0                                                                                                    ustar   sanjayr                         mkgroup-l-d                                                                                                                                                                                                            #!perl

if ($ARGV[1] eq "-pld")
{
    $XILINX_PART = "xcr3256xl-10-TQ144";

    $dir_structure[0] = "$ARGV[0]";
    $dir_structure[1] = "$ARGV[0]\\build";
    $dir_structure[2] = "$ARGV[0]\\sim_mti";
    $dir_structure[3] = "$ARGV[0]\\src";

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
    @files_status = (0, 0, 0, 0, 0);
    $files[0] ="$dir_structure[1]\\Makefile";
    $files[1] ="$dir_structure[1]\\$ARGV[0].xst";
    $files[2] ="$dir_structure[1]\\$ARGV[0].prj";
    $files[3] ="$dir_structure[1]\\$ARGV[0].ucf";
    $files[4] ="$dir_structure[2]\\sim.do";
    $files[5] ="$dir_structure[3]\\$ARGV[0].vhd";

    for ($i = 0; $i < @files; $i++)
    {
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
        open(fp, ">$files[0]");
        print fp "# Makefile Auto Created by xproj.pl\n";
        print fp "\n";
        print fp "\n";
        print fp "TARGET=$ARGV[0]\n";
        print fp "PROJECT_FILE=\$(TARGET).prj\n";
        print fp "TOP_MODULE=\$(TARGET)\n";
        print fp "DEVICE=$XILINX_PART\n";
        print fp "\n";
        print fp "\n";
        print fp "\n";
        print fp "\$(TARGET).jed: \$(TARGET).vm6\n";
        print fp "	hprep6 -s IEEE1149 -n \$(TARGET) -i \$(TARGET)\n";
        print fp "\n";
        print fp "\$(TARGET).vm6: \$(TARGET).ngd\n";
        print fp "	cpldfit -intstyle silent -p \$(DEVICE) -ofmt vhdl -optimize speed -htmlrpt -loc on -slew fast -init low -inputs 36 -pterms 25 \$(TARGET).ngd\n";
        print fp "\n";
        print fp "\$(TARGET).ngd: \$(TARGET).ngc\n";
        print fp "	netgen 	-intstyle silent -ofmt vhdl -w \$(TARGET).ngc \$(TARGET)_xst.vhd\n";
        print fp "	ngdbuild -intstyle silent -dd _ngo -p \$(DEVICE) \$(TARGET).ngc \$(TARGET).ngd\n";
        print fp "\n";
        print fp "\$(TARGET).ngc:\n";
        print fp "	xst -ifn \$(TARGET).xst -intstyle silent\n";
        print fp "\n";
        print fp "\n";
        print fp "\n";
        print fp "clean:\n";
        print fp "	-rm -f \$(TARGET).lso\n";
        print fp "	-rm -f \$(TARGET).ngc\n";
        print fp "	-rm -f \$(TARGET).ngr\n";
        print fp "	-rm -f \$(TARGET).srp\n";
        print fp "	-rm -f \$(TARGET).pcf\n";
        print fp "	-rm -f \$(TARGET)_xst.nlf\n";
        print fp "	-rm -f \$(TARGET)_xst.vhd\n";
        print fp "	-rm -rf dump.xst\n";
        print fp "	-rm -rf xst_work_lib\n";
        print fp "	-rm -f \$(TARGET).ngd \n";
        print fp "	-rm -f \$(TARGET).bld \n";
        print fp "	-rm -f \$(TARGET).vm6 \n";
        print fp "	-rm -f \$(TARGET).gyd \n";
        print fp "	-rm -f \$(TARGET).rpt \n";
        print fp "	-rm -f \$(TARGET).pnx \n";
        print fp "	-rm -f \$(TARGET).mfd \n";
        print fp "	-rm -f \$(TARGET).pad \n";
        print fp "	-rm -f \$(TARGET).jed \n";
        print fp "	-rm -f \$(TARGET)_pad.csv \n";
	print fp "	-rm -f *.xml\n";
	print fp "	-rm -f tmperr.err\n";
	print fp "	-rm -rf _ngo\n";
	print fp "	-rm -rf \$(TARGET)_html\n";

        close(fp);
    }

    # Create Generic .xst file
    if ($files_status[1] == 0)
    {
        open(fp, ">$files[1]");
        print fp "set -tmpdir .\/\n";
        print fp "set -xsthdpdir .\/\n";
        print fp "run\n";
        print fp "-ifn $ARGV[0].prj\n";
        print fp "-ofn $ARGV[0]\n";
        print fp "-top $ARGV[0]\n";
        print fp "-p $XILINX_PART\n";
        print fp "-ofmt NGC\n";
        print fp "-ifmt mixed\n";
        print fp "-opt_mode Speed\n";
        print fp "-opt_level 2\n";
        print fp "-iuc NO\n";
        print fp "-keep_hierarchy NO\n";
        print fp "-rtlview Yes\n";
        print fp "-hierarchy_separator /\n";
        print fp "-bus_delimiter <>\n";
        print fp "-case maintain\n";
        print fp "-verilog2001 YES\n";
        print fp "-fsm_extract YES -fsm_encoding Auto\n";
        print fp "-safe_implementation No\n";
        print fp "-mux_extract YES\n";
        print fp "-resource_sharing YES\n";
        print fp "-iobuf YES\n";
        print fp "-pld_mp YES\n";
        print fp "-pld_xp YES\n";
        print fp "-wysiwyg NO\n";
        print fp "-equivalent_register_removal YES\n";
        close(fp);
    }
    # Create Generic .prj file
    if ($files_status[2] == 0)
    {
        open(fp, ">$files[2]");
        print fp "vhdl work \"..\/src\/$ARGV[0].vhd\"\n";
        close(fp);
    }
    # Create Generic .ucf file
    if ($files_status[3] == 0)
    {
        open(fp, ">$files[3]");
        print fp "#Basic Constraint file Example\n";
        print fp "#--------------------------------------------------------------\n";
        print fp "#NET \"SYS_CLK\" TNM_NET = \"SYS_CLK\"\n";
        print fp "#TIMESPEC \"TS_SYS_CLK\" = PERIOD \"SYS_CLK\" 10 ns HIGH 50 %\n";
        print fp "#OFFSET = IN 6 ns BEFORE \"SYS_CLK\"\n";
        print fp "#OFFSET = OUT 11 ns AFTER \"SYS_CLK\"\n";
        print fp "#NET \"cntrl0_DDR_A<0>\"  LOC = \"C26\" | IOSTANDARD = SSTL2_II\n"; 
        print fp "#--------------------------------------------------------------\n";
        close(fp);
    }
    # Create MTI do file
    if ($files_status[4] == 0)
    {
        open(fp, ">$files[4]");

        print fp "# Do file auto generated from xproj.pl\n";
        print fp "set LIB_NAME $ARGV[0]\n";
        print fp "set MAKEFILE false\n";
        print fp "set TOP_MODULE $ARGV[0]\n";
        print fp "\n";
        print fp "if {\$MAKEFILE} {\n";
        print fp "    make\n";
        print fp "} else {\n";
        print fp "    exec rm -rf \$LIB_NAME\n";
        print fp "    vlib \$LIB_NAME\n";
        print fp "    vcom -2002 -work \$LIB_NAME ..\/src\/\$TOP_MODULE.vhd\n";
        print fp "\n";
        print fp "    exec vmake \$LIB_NAME > Makefile \n";
        print fp "}\n";
        print fp "\n";
        print fp "vsim -t ps \$LIB_NAME.\$TOP_MODULE\n";
        print fp "radix hex\n";
        print fp "# \n";
        print fp "log -r \/*\n";
        print fp "add wave \/*\n";
        print fp "\n";
        print fp "set PRD 10\n";
        print fp "vcd file \$TOP_MODULE.vcd\n";
        print fp "vcd add \/*\n";
        print fp "\n";
        print fp "force reset 1\n";
        print fp "force clk 0 [expr \$PRD/2] ns, 1 \$PRD ns -r \$PRD ns\n";
        print fp "run [expr \$PRD*200] ns\n";
        print fp "force reset 0\n";
        print fp "run [expr \$PRD*2200] ns\n";
        close(fp);
    }
    # Create template toplevel VHDL file
    if ($files_status[5] == 0)
    {
        open(fp, ">$files[5]");
        print fp "-- Created by xproj.pl\n\n";
        print fp "Library IEEE;\n";
        print fp "use IEEE.std_logic_1164.all;\n";
        print fp "use IEEE.std_logic_arith.all;\n";
        print fp "use IEEE.std_logic_unsigned.all;\n";
        print fp "Library unisim;\n";
        print fp "use unisim.vcomponents.all;\n";
        print fp "\n";
        print fp "entity $ARGV[0] is port (\n";
        print fp "    reset : in std_logic;\n";
        print fp "    clk   : in std_logic;\n";
        print fp "    count : out std_logic_vector(7 downto 0)\n";
        print fp ");\n";
        print fp "end entity $ARGV[0];\n";
        print fp "\n";
        print fp "architecture $ARGV[0]_arch of $ARGV[0] is\n";
        print fp "\n";
        print fp "signal i_count : integer range 0 to 255 := 0;\n";
        print fp "begin\n";
        print fp "\n";
        print fp "proc_count: process(clk)\n";
        print fp "begin\n";
        print fp "     if (clk'event and clk = '1') then\n";
        print fp "            if (reset = '1') then\n";
        print fp "                i_count <= 0;\n";
        print fp "            elsif (i_count < 255) then\n";
        print fp "                i_count <= i_count + 1;\n";
        print fp "            else\n";
        print fp "                i_count <= 0;\n";
        print fp "            end if;\n";
        print fp "            count <= conv_std_logic_vector(i_count, 8);\n";
        print fp "    end if;\n";
        print fp "end process;\n";
        print fp "end architecture $ARGV[0]_arch;\n";
        close(fp);
    }
}
elsif ($ARGV[1] eq "-fpga")
{
    $XILINX_PART = "xc5vlx50t-1-ff1136";

    $dir_structure[0] = "$ARGV[0]";
    $dir_structure[1] = "$ARGV[0]\\build";
    $dir_structure[2] = "$ARGV[0]\\sim_mti";
    $dir_structure[3] = "$ARGV[0]\\src";

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
    @files_status = (0, 0, 0, 0, 0);
    $files[0] ="$dir_structure[1]\\Makefile";
    $files[1] ="$dir_structure[1]\\$ARGV[0].xst";
    $files[2] ="$dir_structure[1]\\$ARGV[0].prj";
    $files[3] ="$dir_structure[1]\\$ARGV[0].ucf";
    $files[4] ="$dir_structure[2]\\sim.do";
    $files[5] ="$dir_structure[3]\\$ARGV[0].vhd";

    for ($i = 0; $i < @files; $i++)
    {
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
        open(fp, ">$files[0]");
        print fp "# Makefile Auto Created by xproj.pl\n";
        print fp "\n";
        print fp "\n";
        print fp "TARGET=$ARGV[0]\n";
        print fp "PROJECT_FILE=\$(TARGET).prj\n";
        print fp "TOP_MODULE=\$(TARGET)\n";
        print fp "DEVICE=$XILINX_PART\n";
        print fp "IP_dir_1=../ila\n";
        print fp "IP_dir_2=../coregen\n";
        print fp "Bit_file_ID=0xAAAAAAAA\n";
        print fp "\n";
        print fp "IP_dirs = -sd \$(IP_dir_1) -sd \$(IP_dir_2)\n";
        print fp "\n";
        print fp "BITGEN_OPTS_0 = -intstyle ise -w -g DebugBitstream:No -g Binary:no -g CRC:Enable -m\n";
        print fp "BITGEN_OPTS_1 = -g CclkPin:PullUp -g M0Pin:PullUp -g M1Pin:PullUp -g M2Pin:PullUp -g ProgPin:PullUp\n";
        print fp "BITGEN_OPTS_2 = -g DonePin:PullUp -g InitPin:Pullup -g CsPin:Pullup -g DinPin:Pullup -g BusyPin:Pullup\n";
        print fp "BITGEN_OPTS_3 = -g RdWrPin:Pullup -g TckPin:PullUp -g TdiPin:PullUp -g TdoPin:PullUp -g TmsPin:PullUp\n";
        print fp "BITGEN_OPTS_4 = -g UnusedPin:PullDown\n";
        print fp "BITGEN_OPTS_5 = -g DCIUpdateMode:AsRequired -g StartUpClk:CCLK -g DONE_cycle:4 -g GTS_cycle:5 -g GWE_cycle:6\n";
        print fp "BITGEN_OPTS_6 = -g LCK_cycle:NoWait -g Security:None -g DonePipe:No -g DriveDone:No -g UserID:\$(Bit_file_ID)\n";
        print fp "BITGEN_OPTIONS = \$(BITGEN_OPTS_0) \$(BITGEN_OPTS_1) \$(BITGEN_OPTS_2) \$(BITGEN_OPTS_3) \$(BITGEN_OPTS_4) \$(BITGEN_OPTS_5) \$(BITGEN_OPTS_6)\n";
        print fp "\n";
        print fp "\n";
        print fp "\$(TARGET)_par.mcs: \$(TARGET)_par.bit\n";
        print fp "	promgen -w -p mcs -c FF -o \$(TARGET)_par -u 0 \$(TARGET)_par.bit\n";
        print fp "\n";
        print fp "\$(TARGET).ibs: \$(TARGET)_par.ncd\n";
        print fp "	ibiswriter -intstyle silent -allmodels \$(TARGET)_par.ncd \$(TARGET).ibs\n";
        print fp "\n";
        print fp "\$(TARGET)_par.bit: \$(TARGET)_par.ncd\n";
        print fp "	netgen -intstyle silent -ofmt vhdl -pcf \$(TARGET).pcf -w \$(TARGET)_par.ncd \$(TARGET)_par.vhd\n";
        print fp "	trce -intstyle silent -a -e 5 -u -skew -l 10 \$(TARGET)_par.ncd -o \$(TARGET).twr \$(TARGET).pcf\n";
        print fp "	bitgen \$(BITGEN_OPTIONS) \$(TARGET)_par.ncd \n";
        print fp "\n";
        print fp "\$(TARGET)_par.ncd: \$(TARGET)_map.ncd\n";
        print fp "	par -w -intstyle silent -ol std -pl std -rl std -t 1 \$(TARGET)_map.ncd \$(TARGET)_par.ncd \$(TARGET).pcf\n";
        print fp "\n";
        print fp "\$(TARGET)_map.ncd: \$(TARGET).ngd\n";
        print fp "	map -timing -intstyle silent -ignore_keep_hierarchy -p \$(DEVICE) -cm area -pr b -k 4 -c 100 -o \$(TARGET)_map.ncd \$(TARGET).ngd \$(TARGET).pcf\n";
        print fp "\n";
        print fp "\$(TARGET).ngd: \$(TARGET).ngc\n";
        print fp "	netgen 	-intstyle silent -ofmt vhdl -w \$(TARGET).ngc \$(TARGET)_xst.vhd\n";
        print fp "	ngdbuild -intstyle silent -verbose -nt timestamp -dd _ngo -uc \$(TARGET).ucf -p \$(DEVICE) \$(IP_dirs) \$(TARGET).ngc \$(TARGET).ngd\n";
        print fp "\n";
        print fp "\$(TARGET).ngc:\n";
        print fp "	xst -ifn \$(TARGET).xst -intstyle silent\n";
        print fp "\n";
        print fp "\n";
        print fp "\n";
        print fp "clean:\n";
        print fp "	-rm -f \$(TARGET).lso\n";
        print fp "	-rm -f \$(TARGET).ngc\n";
        print fp "	-rm -f \$(TARGET).ngr\n";
        print fp "	-rm -f \$(TARGET).srp\n";
        print fp "	-rm -f \$(TARGET).pcf\n";
        print fp "	-rm -f \$(TARGET)_xst.nlf\n";
        print fp "	-rm -f \$(TARGET)_xst.vhd\n";
        print fp "	-rm -rf dump.xst\n";
        print fp "	-rm -rf xst_work_lib\n";
        print fp "	-rm -f \$(TARGET).ngd \n";
        print fp "	-rm -f \$(TARGET).bld \n";
        print fp "	-rm -rf _ngo \n";
        print fp "	-rm -f \$(TARGET)_map.mrp \n";
        print fp "	-rm -f \$(TARGET)_map.ncd \n";
        print fp "	-rm -f \$(TARGET)_map.ngm \n";
        print fp "	-rm -f \$(TARGET)_par.pad \n";
        print fp "	-rm -f \$(TARGET)_par.par \n";
        print fp "	-rm -f \$(TARGET)_par.ncd \n";
        print fp "	-rm -f \$(TARGET)_par.nlf \n";
        print fp "	-rm -f \$(TARGET)_par.sdf \n";
        print fp "	-rm -f \$(TARGET)_par.unroutes \n";
        print fp "	-rm -f \$(TARGET)_par.xpi \n";
        print fp "	-rm -f \$(TARGET)_par_pad.csv \n";
        print fp "	-rm -f \$(TARGET)_par_pad.txt \n";
        print fp "	-rm -f \$(TARGET)_par.vhd \n";
        print fp "	-rm -f \$(TARGET).twr\n";
        print fp "	-rm -f \$(TARGET)_par.bgn\n";
        print fp "	-rm -f \$(TARGET)_par.bit\n";
        print fp "	-rm -f \$(TARGET)_par.drc\n";
        print fp "	-rm -f \$(TARGET)_par.msk\n";
        print fp "	-rm -f \$(TARGET)_par.mcs\n";
        print fp "	-rm -f \$(TARGET)_par.prm\n";
        close(fp);
    }

    # Create Generic .xst file
    if ($files_status[1] == 0)
    {
        open(fp, ">$files[1]");
        print fp "set -tmpdir .\/\n";
        print fp "set -xsthdpdir .\/\n";
        print fp "run\n";
        print fp "-ifn $ARGV[0].prj\n";
        print fp "-ofn $ARGV[0]\n";
        print fp "-top $ARGV[0]\n";
        print fp "-p $XILINX_PART\n";
        print fp "-ofmt NGC\n";
        print fp "-ifmt mixed\n";
        print fp "-opt_mode Speed\n";
        print fp "-opt_level 2\n";
        print fp "-iuc NO\n";
        print fp "-keep_hierarchy YES\n";
        print fp "-rtlview Yes\n";
        print fp "-glob_opt AllClockNets\n";
        print fp "-read_cores YES\n";
        print fp "-write_timing_constraints NO\n";
        print fp "-cross_clock_analysis NO\n";
        print fp "-hierarchy_separator /\n";
        print fp "-bus_delimiter <>\n";
        print fp "-case maintain\n";
        print fp "-verilog2001 YES\n";
        print fp "-fsm_extract YES -fsm_encoding Auto\n";
        print fp "-safe_implementation No\n";
        print fp "-fsm_style lut\n";
        print fp "-ram_extract Yes\n";
        print fp "-ram_style Auto\n";
        print fp "-rom_extract Yes\n";
        print fp "-mux_style Auto\n";
        print fp "-decoder_extract YES\n";
        print fp "-priority_extract YES\n";
        print fp "-shreg_extract YES\n";
        print fp "-shift_extract YES\n";
        print fp "-xor_collapse YES\n";
        print fp "-rom_style Auto\n";
        print fp "-mux_extract YES\n";
        print fp "-resource_sharing YES\n";
        print fp "-use_dsp48 auto\n";
        print fp "-iobuf YES\n";
        print fp "-max_fanout 500\n";
        print fp "-register_duplication YES\n";
        print fp "-register_balancing No\n";
        print fp "-slice_packing YES\n";
        print fp "-optimize_primitives NO\n";
        print fp "-use_clock_enable Auto\n";
        print fp "-use_sync_set Auto\n";
        print fp "-use_sync_reset Auto\n";
        print fp "-iob auto\n";
        print fp "-equivalent_register_removal YES\n";
        print fp "-slice_utilization_ratio_maxmargin 5\n";
        close(fp);
    }
    # Create Generic .prj file
    if ($files_status[2] == 0)
    {
        open(fp, ">$files[2]");
        print fp "vhdl work \"..\/src\/$ARGV[0].vhd\"\n";
        close(fp);
    }
    # Create Generic .ucf file
    if ($files_status[3] == 0)
    {
        open(fp, ">$files[3]");
        print fp "#Basic Constraint file Example\n";
        print fp "#--------------------------------------------------------------\n";
        print fp "#NET \"SYS_CLK\" TNM_NET = \"SYS_CLK\";\n";
        print fp "#TIMESPEC \"TS_SYS_CLK\" = PERIOD \"SYS_CLK\" 10 ns HIGH 50 %;\n";
        print fp "#OFFSET = IN 6 ns BEFORE \"SYS_CLK\";\n";
        print fp "#OFFSET = OUT 11 ns AFTER \"SYS_CLK\";\n";
        print fp "#NET \"cntrl0_DDR_A<0>\"  LOC = \"C26\" | IOSTANDARD = SSTL2_II;\n"; 
        print fp "#--------------------------------------------------------------\n";
        close(fp);
    }
    # Create MTI do file
    if ($files_status[4] == 0)
    {
        open(fp, ">$files[4]");

        print fp "# Do file auto generated from xproj.pl\n";
        print fp "set LIB_NAME $ARGV[0]\n";
        print fp "set MAKEFILE false\n";
        print fp "set TOP_MODULE $ARGV[0]\n";
        print fp "\n";
        print fp "if {\$MAKEFILE} {\n";
        print fp "    make\n";
        print fp "} else {\n";
        print fp "    exec rm -rf \$LIB_NAME\n";
        print fp "    vlib \$LIB_NAME\n";
        print fp "    vcom -2002 -work \$LIB_NAME ..\/src\/\$TOP_MODULE.vhd\n";
        print fp "\n";
        print fp "    exec vmake \$LIB_NAME > Makefile \n";
        print fp "}\n";
        print fp "\n";
        print fp "vsim -t ps \$LIB_NAME.\$TOP_MODULE\n";
        print fp "radix hex\n";
        print fp "# \n";
        print fp "log -r \/*\n";
        print fp "add wave \/*\n";
        print fp "\n";
        print fp "set PRD 10\n";
        print fp "vcd file \$TOP_MODULE.vcd\n";
        print fp "vcd add \/*\n";
        print fp "\n";
        print fp "force reset 1\n";
        print fp "force clk 0 [expr \$PRD/2] ns, 1 \$PRD ns -r \$PRD ns\n";
        print fp "run [expr \$PRD*200] ns\n";
        print fp "force reset 0\n";
        print fp "run [expr \$PRD*2200] ns\n";
        close(fp);
    }
    # Create template toplevel VHDL file
    if ($files_status[5] == 0)
    {
        open(fp, ">$files[5]");
        print fp "-- Created by xproj.pl\n\n";
        print fp "Library IEEE;\n";
        print fp "use IEEE.std_logic_1164.all;\n";
        print fp "use IEEE.std_logic_arith.all;\n";
        print fp "use IEEE.std_logic_unsigned.all;\n";
        print fp "Library unisim;\n";
        print fp "use unisim.vcomponents.all;\n";
        print fp "\n";
        print fp "entity $ARGV[0] is port (\n";
        print fp "    reset : in std_logic;\n";
        print fp "    clk   : in std_logic;\n";
        print fp "    count : out std_logic_vector(7 downto 0)\n";
        print fp ");\n";
        print fp "end entity $ARGV[0];\n";
        print fp "\n";
        print fp "architecture $ARGV[0]_arch of $ARGV[0] is\n";
        print fp "\n";
        print fp "signal i_count : integer range 0 to 255 := 0;\n";
        print fp "begin\n";
        print fp "\n";
        print fp "proc_count: process(clk)\n";
        print fp "begin\n";
        print fp "     if (clk'event and clk = '1') then\n";
        print fp "            if (reset = '1') then\n";
        print fp "                i_count <= 0;\n";
        print fp "            elsif (i_count < 255) then\n";
        print fp "                i_count <= i_count + 1;\n";
        print fp "            else\n";
        print fp "                i_count <= 0;\n";
        print fp "            end if;\n";
        print fp "            count <= conv_std_logic_vector(i_count, 8);\n";
        print fp "    end if;\n";
        print fp "end process;\n";
        print fp "end architecture $ARGV[0]_arch;\n";
        close(fp);
    }
}
else
{
    print "\n !ERROR\n";
    print "\n Usage :\n";
    print "\t xproj project_name -fpga\n \t\t OR \n\t xproj project_name -pld\n";
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   