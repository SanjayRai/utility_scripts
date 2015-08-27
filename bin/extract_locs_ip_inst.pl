#!perl

$start_time = time;
$running_time = $start_time;
#
#
my $LOC_val;
my @primitives_from_xdl_file;
my %hdl_instance_names;
my %primitives_from_xdl_file_comment;
my %primitives_from_xdl_file_loc;
my %primitives_from_xdl_file_bel;
my %primitives_from_xdl_file_cfg_string;
my %primitives_from_xdl_file_shape;
my %primitives_from_xdl_file_shape_loc;
my %primitives_from_xdl_file_is_origin;
my %primitive_shape_campare_pattern;
my %primitives_from_xdl_file_HU_SET;
my %primitive_SHAPE_HAS_HU_SET;
my %number_of_disti_ram_in_slice;

$WRITE_RLOCS = 0;

$USAGE = "\n Usage :\n\t extract_locs_ip_inst file.ngd file.ncd [-Iinstance_name_to_extract] [-Einstance_path_to_exclude1#instance_path_to_exclude2]\n";

if (($#ARGV > 3) | ($#ARGV < 1)) {
    print "\n !ERROR Wrong Number of Arguments\n";
    print $USAGE; 
    die;
}


$file_ext_ngd = $ARGV[0];
$file_ext_ncd = $ARGV[1];
$file_ext_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name = $1;
$file_ext_ngd =~ s/(^.*)\.(ngd)/$2/;
$ngd_hdl_name = $1."_ngd.v";

$exclude_instances = "";
$include_instances = ".*";

$set_identifier = $ip_instance;

$ip_instance = $ARGV[2];

$out_file = $design_name."_extract_locs.ucf";

if ($#ARGV > 1) {
    for ($i = 2; $i < ($#ARGV+1); $i++) {
        $input_arg = $ARGV[$i];
        if ($input_arg=~/^-I/) {
            $include_instances = $input_arg."/"; 
            $include_instances =~ s/^-I//;
            $include_instances =~s/\//\\\//g;
            $include_instances =~s/\./\\\./g;
            $include_instances =~ s/#/\/.*|/;
            $include_instances = "(".$include_instances."\.*)";
        } elsif ($input_arg=~/^-E/) {
            $exclude_instances = $input_arg; 
            $exclude_instances =~ s/^-E//;
            $exclude_instances =~s/\//\\\//g;
            $exclude_instances =~s/\./\\\./g;
            $exclude_instances =~ s/#/|/;
            $exclude_instances = "(".$exclude_instances."\.*)";
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
    print "\tCreating XDL File ....";
    `xdl -ncd2xdl $ARGV[1] $design_name.xdl`;
    $xdl_gen_elapsed_time = time - $running_time;
    $running_time = time;
    print "  $xdl_gen_elapsed_time Seconds\n";
    open FP_XDL, "$design_name.xdl" or die $!; # Open Input xdl file for reading file
    print "\tCreating NGD Verilog FIle ....";
    `netgen -ofmt verilog -fn -w $ARGV[0] $ngd_hdl_name`;
    $netgen_elapsed_time = time - $running_time;
    $running_time = time;
    print "  $netgen_elapsed_time Seconds\n";
    open FP_NGD_HDL, "$ngd_hdl_name" or die $!; # Open Input xdl file for reading file


    # Read the file_ngd.v hdl file and make a list of all Instance names
    $prev_pram = "";
    print "\tCreating NGD Database....";
    $hdl_instance_index = 0;
    while (<FP_NGD_HDL>) {
        s/^\s*//; #remove LEading Edge Spaces
        s/\/\/.*//; # Remove Comments
        if (/.*\($/i) {
            s/^X_\w+\s*//i;
            s/\s*\($//i;
            s/\\//g;
            s/\s*//g;
	    s/(.*)\/RAMB.*_EXP\b/$1/g;

            #Check to see if name has a X_RAM appended at the end.
            #This impplies Distributed RAM and Delete this (Ex. Delete X_RAMS32, or X_RAMD128 etc)
            s/\/X_RAM[SD]\d+$//;

            if ( exists $hdl_instance_names{$_} ) {
            } else {
                $hdl_instance_names{$_} = $hdl_instance_index;
                $hdl_instance_index++;
            }
        }
    }
    close FP_NGD_HDL;
    $ngd_database_elapsed_time = time - $running_time;
    $running_time = time;
    print "  $ngd_database_elapsed_time Seconds\n";

    $extract_LOCS = 0;
    while (<FP_XDL>) {
        # Check Device Type First
        if (/^design\b/i) {
            @device_type_tokens = split;
            $device_type = $device_type_tokens[2];
            #if ($device_type =~ /^xc5v.*/i) {
                print "\tDevice Type\t= $device_type\n";
                print "\tCreating XDL Database....";
#             } else {
#                 print "\n\tDevice Type = $device_type NOT SUPPORTED Exiting!!\n";
#                 close FP_XDL;
#                 die;
#             }
        }
        s/inst.*XDL_DUMMY.*//;
        s/cfg *"//;
        s/\\\s/_/; # Substitute \  with an _ (ie Space with _) THis helps remove _INST_PROP.*
        #if (/^inst\b.*\b($primitives_v5)\b/i) {
        if (/^inst ".*?" ".*?",placed /) {
            $extract_LOCS = 1;
		$shape="";
            s/placed//; #Eliminate keyword placed
            s/,//g; # Eliminate ,'s
            s/\s*$/\n/;
            @fields = split;
            $LOC_val= $fields[4];
            $primitives_from_xdl_file_HU_SET{$LOC_val} = "FALSE"; 
	    $CFG_string = "";
        } elsif ($extract_LOCS == 1) {
            if(/\s;\s/) {
                $extract_LOCS = 0;
            } else {
		#if (/_INST_PROP::XDL_SHAPE_MEMBER:Shape_\d+:\d+,\d+\s.*/)
		if (/_INST_PROP::XDL_SHAPE_MEMBER:/) {
                    #if (/_INST_PROP::XDL_SHAPE_MEMBER:Shape_\d+:\d+,\d+\s.*/)
                    if (/_INST_PROP::XDL_SHAPE_MEMBER:.*:\d+,\d+\s.*/) {
                            $shape = $_;
                            chomp($shape);
                            $shape =~ s/.*_INST_PROP::XDL_SHAPE_MEMBER:(.*:\d+,\d+)\b.*/$1/;
                            if ($primitives_from_xdl_file_shape{$LOC_val} eq "") {
                                $primitives_from_xdl_file_shape{$LOC_val} = $shape; 
                                $primitives_from_xdl_file_shape_loc{$shape} = $LOC_val; 
                            } else {
                                $primitives_from_xdl_file_HU_SET{$LOC_val} = "TRUE"; 
                            }
                    }
                }

                if (/_INST_PROP::XDL_SHAPE_REFERENCEBLOCK:/) { # THis indicated HU_SET (So don't add U_SET's 
			$primitives_from_xdl_file_HU_SET{$LOC_val} = "TRUE"; 
                }

                if (/_INST_PROP::XDL_SHAPE_DESC:/) { # THis is only pertinent in the 0,0 Location of an RPM
                    $primitives_from_xdl_file_is_origin{$LOC_val} = "TRUE";
                }

                #s/_INST_PROP::XDL_SHAPE_DESC:\w.*:\w+,\w.*\\"(\w.*)\\"/CARRY_INIT:$1:/;
		s/_INST_PROP::.*//;
		s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
		s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy

                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
		    if ($token =~/\b([ABCMP]REG)::(\d)/) { #DSP48 REGISTER Configuration
			$CFG_string = $CFG_string.$1." = ".$2.":";
		    } elsif ($token =~/\b(DO\w*_REG)::(\d)/) { #BRAM REGISTER Configuration
			$CFG_string = $CFG_string.$1." = ".$2.":";
		    } elsif ($token =~/\b(DO\w*_REG_\w)::(\d)/) { #BRAM REGISTER Configuration
			$CFG_string = $CFG_string.$1." = ".$2.":";
		    }

                    $BEL = "";
                    if ($token=~/([ABCD]\dLUT):.+:/) {
                        $BEL = $1;
                        if ($token=~/[ABCD]\dLUT:.*?\/[DS]P.*?:#RAM:/) {
                            $token =~ s/.*?:(.*?)\/[DS]P.*?:#RAM:.*/$1/; # Turnoff Greedy Matching with ?
                            $BEL = "DISTI_RAM_wide";
                        }
                    } elsif ($token=~/(BUFG):.+:/) {
                        $BEL = "BUFG";
                    } elsif ($token=~/(BUFGCTRL):.+:/) {
                        $BEL = "BUFG";
                    } elsif ($token=~/([ABCD]FF):.+:/) {
                        $BEL = $1;
                    } elsif ($token=~/([ABCD]\dFF):.+:/) {
                        $BEL = $1;
                    } elsif ($token=~/RAMB.*?:.+:/) {
                        $BEL = "BRAM";
                    } elsif ($token=~/DSP48.*?:.+:/) {
                        $BEL = "DSP48";
                    } elsif ($token=~/PLL_ADV:.+:/) {
                        $BEL = "PLL";
                    }
                    $token =~ s/\\:/~~/; #Substitute Escape'd : with ~~ This for BUS signal Ex. in XDL a BUS is <63\:0>
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    $token =~ s/~~/:/; #Re-Substitute ~~ with :

                    if ($token=~/$exclude_instances/i) {
                        last;
                    } elsif ($token=~/$include_instances/i) {
                        if($token ne "") {
                             push(@primitives_from_xdl_file, $token);
                             $primitives_from_xdl_file_loc{$token} = $LOC_val; 
                             $primitives_from_xdl_file_bel{$token} = $BEL; 
                             $primitives_from_xdl_file_cfg_string{$token} = $CFG_string; 

                             #Count the number of DISTI_RAM per slice - Don't allow more than 2
                             $number_of_disti_ram_in_slice{$xdl_primitive_loc} = 0;
                        } # token collection

                    }
                }
            }
        }
    }
    close FP_XDL;
    $xdl_database_elapsed_time = time - $running_time;
    print "  $xdl_database_elapsed_time Seconds\n";

    open FP_out, ">$out_file" or die $!;
    open FP_LOG, ">extract_locs.log" or die $!;
    open FP_LOG_NGD_P, ">extract_locs_ngd_primitives.log" or die $!;
    open FP_LOG_XDL_P, ">extract_locs_xdl_primitives.csv" or die $!;
    open FP_LOG_XDL_P_dbg, ">extract_locs_xdl_dsp_bram.csv" or die $!;
    print FP_LOG "extract_locs $ARGV[0] $ARGV[1]\n";
    print FP_LOG "Following Tokens in the NGD file did not Match NCD instance names\n";

    foreach $tmp_init_loc (keys %primitives_from_xdl_file_shape) {
        $tmp_rloc_shape = $primitives_from_xdl_file_shape{$tmp_init_loc};
        $tmp_rloc_shape =~ s/(.*):\d+,\d+/$1_i/i;
        $primitive_SHAPE_HAS_HU_SET{$tmp_rloc_shape} = $primitives_from_xdl_file_HU_SET{$tmp_init_loc};
    }

    $Constrained_FF_count = 0;
    $Constrained_LUT_count = 0;
    $Total_LUT_count = 0;
    $Constrained_BRAM_count = 0;
    $Constrained_PLL_count = 0;
    $Constrained_DSP_BLOCK_count = 0;
    $Constrained_BUFG = 0;
    $Constrained_primitive_count = 0;

    print "\tOutput file\t= $out_file\n";
        foreach $hdl_instance_name ( sort (keys %hdl_instance_names)) {
            if( exists $primitives_from_xdl_file_loc{$hdl_instance_name} ) {
                $WRITE_RLOCS = 0;
                $xdl_primitive_loc = $primitives_from_xdl_file_loc{$hdl_instance_name};
                $xdl_primitive_bel = $primitives_from_xdl_file_bel{$hdl_instance_name};
                $xdl_primitive_shape = $primitives_from_xdl_file_shape{$xdl_primitive_loc};

                $mod_xdl_primitive_shape = $xdl_primitive_shape;
                $mod_xdl_primitive_shape =~ s/(.*):\d+,\d+/$1/;
                $curr_instance_string_compare = $primitive_shape_campare_pattern{$mod_xdl_primitive_shape};

                $write_constraints = 0;
                $write_bel_constraints = 0; 
                if (($xdl_primitive_bel eq "")) {
                    $write_bel_constraints = 0; 
                    $write_constraints = 0; # Added Sunday Sept. 21st (Experimental)
                } elsif (($xdl_primitive_bel eq "PLL")) {
                    $write_bel_constraints = 0; 
                    $write_constraints = 1; # Added Sunday Sept. 21st (Experimental)
                    $Constrained_PLL_count++;
                } elsif (($xdl_primitive_bel eq "BRAM")) {
                    $write_bel_constraints = 0; 
                    $write_constraints = 1; # Added Sunday Sept. 21st (Experimental)
                    $Constrained_BRAM_count++;
                    $primitives_from_xdl_file_comment{$xdl_primitive_loc} = "#BRAM , $primitives_from_xdl_file_cfg_string{$hdl_instance_name}";
                } elsif (($xdl_primitive_bel eq "BUFG")) {
                    $write_bel_constraints = 0; 
                    $write_constraints = 1;
                    $Constrained_BUFG++;
                    $primitives_from_xdl_file_comment{$xdl_primitive_loc} = "#BUFG";
                } elsif (($xdl_primitive_bel eq "DSP48")) {
                    $write_bel_constraints = 0; 
                    $write_constraints = 1; # Added Sunday Sept. 21st (Experimental)
                    $Constrained_DSP_BLOCK_count++;
                    $primitives_from_xdl_file_comment{$xdl_primitive_loc} = "#DSP48 , $primitives_from_xdl_file_cfg_string{$hdl_instance_name}";
                } elsif (($xdl_primitive_bel eq "DISTI_RAM_wide")) {
                    $Total_LUT_count++;
                    #Count the number of DISTI_RAM per slice - Don't allow more than 2
                    if ($number_of_disti_ram_in_slice{$xdl_primitive_loc} > 1) {
                        $write_bel_constraints = 0; 
                        $write_constraints = 0; # Added Sunday Sept. 21st (Experimental) 
                    } else {
                        $write_bel_constraints = 0; 
                        $write_constraints = 1; # Added Sunday Sept. 21st (Experimental) 
                        $Constrained_LUT_count += 2;
                        $primitives_from_xdl_file_comment{$xdl_primitive_loc} = "#DISTRIBUTED_RAM(WIDE)";
                    }
                    $number_of_disti_ram_in_slice{$xdl_primitive_loc}++;
                } elsif (($xdl_primitive_bel=~/[ABCD]\dLUT/)) {
                    $Total_LUT_count++;
                    if  ($xdl_primitive_shape ne "") {
                        $primitives_from_xdl_file_comment{$xdl_primitive_loc} = "#RPM : $xdl_primitive_shape";
                        $write_bel_constraints = 0; 
                        $write_constraints = 0; # Disables constraining all RPM's (Including Carry_logic chains), Shape, RPM
                        $WRITE_RLOCS = 0;
                        $tmp_rloc_shape = $xdl_primitive_shape;
                        $tmp_rloc_shape =~ s/(.*):\d+,\d+/$1_i/i;
                        $tmp_rloc = $xdl_primitive_shape;
                        $tmp_rloc =~ s/.*:(\d+),(\d+)/X$1Y$2/i;
                        # check if atleast one LOC has been written for a SHAPE if so don't write anymore
                        if ($xdl_shape_has_been_written{$tmp_rloc_shape} ne "TRUE") {
                            #$write_constraints = 1;
                            #$write_bel_constraints = 1; 
                            #$WRITE_RLOCS = 1;

                            $write_constraints = 0;
                            $write_bel_constraints = 0; 
                            $WRITE_RLOCS = 0;
                            #$Constrained_LUT_count++;
                        }
                    } else {
                        $write_bel_constraints = 1; 
                        $write_constraints = 1;
                        $Constrained_LUT_count++;
                    }
                } elsif (($xdl_primitive_bel=~/[ABCD]FF/)) {
                    $write_bel_constraints = 1; 
                    $write_constraints = 1;
                    $Constrained_FF_count++;
                } elsif (($xdl_primitive_bel=~/[ABCD]\dFF/)) {
                    $write_bel_constraints = 1; 
                    $write_constraints = 1;
                    $Constrained_FF_count++;
                }


                if ($write_constraints == 1) {
                    $primitive_constrain_level_in_UCF{$hdl_instance_name} ="SITE_Level"; 
                    if($write_bel_constraints == 0) {
                        if ($WRITE_RLOCS == 1) {
                            if ($primitives_from_xdl_file_is_origin{$xdl_primitive_loc} eq "TRUE") {
                                if ($xdl_shape_has_been_written{$tmp_rloc_shape} ne "TRUE") {
                                    $xdl_shape_has_been_written{$tmp_rloc_shape} = "TRUE";
                                }
                                $tmp_relative_location_origin = $xdl_primitive_loc;
                                $tmp_relative_location_origin =~ s/SLICE_(X\d+Y\d+)/$1/;
                                if( $primitive_SHAPE_HAS_HU_SET{$tmp_rloc_shape} eq "TRUE") {
                                    print FP_out "INST \"$hdl_instance_name\" RLOC = \"$tmp_rloc\" | RLOC_ORIGIN = \"$tmp_relative_location_origin\"; #$xdl_primitive_loc :: $tmp_rloc_shape\n";
                                } else {
                                    print FP_out "INST \"$hdl_instance_name\" RLOC = \"$tmp_rloc\" | U_SET = \"$tmp_rloc_shape\" | RLOC_ORIGIN = \"$tmp_relative_location_origin\"; #$xdl_primitive_loc :: $tmp_rloc_shape\n";
                                }
                            }
                        } else {
                            print FP_out "INST \"$hdl_instance_name\" LOC = \"$xdl_primitive_loc\";$primitives_from_xdl_file_comment{$xdl_primitive_loc}\n";
                        }
                    } else {
                        $primitive_constrain_level_in_UCF{$hdl_instance_name} ="BEL_Level"; 
                        if ($WRITE_RLOCS == 1) {
                            if ($primitives_from_xdl_file_is_origin{$xdl_primitive_loc} eq "TRUE") {
                                if ($xdl_shape_has_been_written{$tmp_rloc_shape} ne "TRUE") {
                                    $xdl_shape_has_been_written{$tmp_rloc_shape} = "TRUE";
                                }
                                $tmp_relative_location_origin = $xdl_primitive_loc;
                                $tmp_relative_location_origin =~ s/SLICE_(X\d+Y\d+)/$1/;
                                if( $primitive_SHAPE_HAS_HU_SET{$tmp_rloc_shape} eq "TRUE") {
                                    print FP_out "INST \"$hdl_instance_name\" RLOC = \"$tmp_rloc\" | BEL = \"$xdl_primitive_bel\" | RLOC_ORIGIN = \"$tmp_relative_location_origin\"; #$xdl_primitive_loc :: $tmp_rloc_shape\n";
                                } else {
                                    print FP_out "INST \"$hdl_instance_name\" RLOC = \"$tmp_rloc\" | BEL = \"$xdl_primitive_bel\" | U_SET = \"$tmp_rloc_shape\" | RLOC_ORIGIN = \"$tmp_relative_location_origin\"; #$xdl_primitive_loc :: $tmp_rloc_shape\n";
                                }
                            }
                        } else {
                            print FP_out "INST \"$hdl_instance_name\" LOC = \"$xdl_primitive_loc\" | BEL = \"$xdl_primitive_bel\";$primitives_from_xdl_file_comment{$xdl_primitive_loc}\n";
                        }
                    }
                } else {
                    # Has Shape parameter -   Part of the Shape Structure - Could be FF or LUT 
                    print FP_LOG "SH* $hdl_instance_name :: $xdl_primitive_loc :: $xdl_primitive_shape\n";
                }
            } else {
                # Doesn't Exist (DE)
                print FP_LOG "DE* $hdl_instance_name :: $xdl_primitive_loc :: $xdl_primitive_shape\n";
            }
        }

    print "\n";

    $UNConstrained_LUT_count = $Total_LUT_count - $Constrained_LUT_count;
    $percentage_LUT_constrained = ($Constrained_LUT_count/$Total_LUT_count)*100.0;
    print FP_out "#Constrained BUFG Count = $Constrained_BUFG\n";
    print FP_out "#Constrained FF Count = $Constrained_FF_count\n";
    print FP_out "#Constrained LUT Count = $Constrained_LUT_count (Total LUTs = $Total_LUT_count) : $percentage_LUT_constrained %\n";
    print FP_out "#Constrained BRAM Count = $Constrained_BRAM_count\n";
    print FP_out "#Constrained DSP Block Count = $Constrained_DSP_BLOCK_count\n";
    print FP_out "#<#UNConstrained LUT Count = $UNConstrained_LUT_count>\n";
    print "#Constrained BUFG Count = $Constrained_BUFG\n";
    print "#Constrained FF Count = $Constrained_FF_count\n";
    print "#Constrained LUT Count = $Constrained_LUT_count (Total LUTs = $Total_LUT_count) : $percentage_LUT_constrained %\n";
    print "#Constrained BRAM Count = $Constrained_BRAM_count\n";
    print "#Constrained DSP Block Count = $Constrained_DSP_BLOCK_count\n";
    print "#<#UNConstrained LUT Count = $UNConstrained_LUT_count>\n";

    close FP_out;



    print FP_LOG "tmp_loc::primitives_from_xdl_file_shape\n";
    foreach $tmp_shape (sort(keys %primitives_from_xdl_file_shape_loc)) {
            $tmp_rloc_shape = $primitives_from_xdl_file_shape_loc{$tmp_shape};
            $tmp_rloc_shape =~ s/(.*):\d+,\d+/$1_i/i;
            print FP_LOG "$tmp_shape :: $primitives_from_xdl_file_shape_loc{$tmp_shape} :: $primitive_SHAPE_HAS_HU_SET{$tmp_rloc_shape} \n";
    }
    close FP_LOG;
    # Print Primitives in XDL and NGD files for referance
    foreach $tmp_ngd_primitive (sort(keys %hdl_instance_names)) {
        print FP_LOG_NGD_P "$tmp_ngd_primitive\n";
    }
    close FP_LOG_NGD_P;

    print FP_LOG_XDL_P "Instance Name,LOCATION,BEL,SHAPE,Constraint_level,Comment\n";
    print FP_LOG_XDL_P_dbg "Instance Name,LOCATION,BEL,SHAPE,Constraint_level,Comment\n";
    foreach $tmp_xdl_primitive(sort(@primitives_from_xdl_file)) {
        $tmp_comment = $primitives_from_xdl_file_comment{$primitives_from_xdl_file_loc{$tmp_xdl_primitive}};
        $tmp_shape_name = $primitives_from_xdl_file_shape{$primitives_from_xdl_file_loc{$tmp_xdl_primitive}};
        $tmp_shape_name =~ s/,/:/g;
        #$tmp_shape_name =~ s/(.*:?):(\d+:\d+)/$1,$2/g;
        print FP_LOG_XDL_P "$tmp_xdl_primitive,$primitives_from_xdl_file_loc{$tmp_xdl_primitive},$primitives_from_xdl_file_bel{$tmp_xdl_primitive},$tmp_shape_name,$primitive_constrain_level_in_UCF{$tmp_xdl_primitive},$tmp_comment\n";
	if ($primitives_from_xdl_file_bel{$tmp_xdl_primitive} eq "BRAM") {
		print FP_LOG_XDL_P_dbg "$tmp_xdl_primitive,$primitives_from_xdl_file_loc{$tmp_xdl_primitive},$primitives_from_xdl_file_bel{$tmp_xdl_primitive},$tmp_shape_name,$primitive_constrain_level_in_UCF{$tmp_xdl_primitive},$tmp_comment\n";
	} elsif ($primitives_from_xdl_file_bel{$tmp_xdl_primitive} eq "DSP48") {
		print FP_LOG_XDL_P_dbg "$tmp_xdl_primitive,$primitives_from_xdl_file_loc{$tmp_xdl_primitive},$primitives_from_xdl_file_bel{$tmp_xdl_primitive},$tmp_shape_name,$primitive_constrain_level_in_UCF{$tmp_xdl_primitive},$tmp_comment\n";
	}
                
    }
    close FP_LOG_XDL_P;
    close FP_LOG_XDL_P_dbg;
}

$elapsed_time = time - $start_time;

print "\n:::Total Elapsed time = $elapsed_time Seconds\n";
