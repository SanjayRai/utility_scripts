#!perl

$start_time = time;
$running_time = $start_time;
#
#
my $LOC_val;

my @primitives_from_xdl_1_file;
my %primitives_from_xdl_1_file_loc;
my %primitives_from_xdl_1_file_bel;
my %primitives_from_xdl_1_file_shape;
my %primitives_from_xdl_1_file_shape_loc;

my @primitives_from_xdl_2_file;
my %primitives_from_xdl_2_file_loc;
my %primitives_from_xdl_2_file_bel;
my %primitives_from_xdl_2_file_shape;
my %primitives_from_xdl_2_file_shape_loc;

$WRITE_RLOCS = 0;

$USAGE = "\n Usage :\n\t cmp_ncd file_1.ncd file_2.ncd [-Iinstance_name_to_extract]\n";

if (($#ARGV < 1) | ($#ARGV > 2)) {
    print "\n !ERROR Wrong Number of Arguments ($#ARGV)\n";
    print $USAGE; 
    die;
} 

if ($#ARGV == 2) {
    $ip_instance = $ARGV[2];
    $include_instances = $ip_instance."/"; 
    $include_instances =~ s/^-I//;
    $include_instances =~s/\//\\\//g;
    $include_instances =~s/\./\\\./g;
    $include_instances =~ s/#/.*|/;
    $include_instances = "(".$include_instances."\.*)";
} else {
    $include_instances = ".*";
}



$file_1_ncd = $ARGV[0];
$file_2_ncd = $ARGV[1];
$file_1_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name_1 = $1;
$file_2_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name_2 = $1;
$primitives_v5 = "SLICEM|SLICEL|RAMB36_EXP|RAMB36SDP_EXP|RAMB18X2|RAMBFIFO18_36|FIFO36_72_EXP|FIFO36_EXP|DSP48|DSP48A|DSP48E";

    print "Working.....\n\tInput NCD File\t= $ARGV[0]\n\tInput NCD File\t= $ARGV[1]\n";
    print "\tCreating XDL Files ....";
    `xdl -ncd2xdl $ARGV[0] $design_name_1.xdl`;
    `xdl -ncd2xdl $ARGV[1] $design_name_2.xdl`;
    $xdl_gen_elapsed_time = time - $running_time;
    $running_time = time;
    print "  $xdl_gen_elapsed_time Seconds\n";
    open FP_XDL_1, "$design_name_1.xdl" or die $!; # Open Input xdl file for reading file
    open FP_XDL_2, "$design_name_2.xdl" or die $!; # Open Input xdl file for reading file

    print "\nInstance being Extracted to NCF File : $include_instances\n";

    $xdl1_primitive_count = 0;
    $extract_LOCS = 0;
    while (<FP_XDL_1>) {
        # Check Device Type First
        if (/^design\b/i) {
            @device_type_tokens = split;
            $device_type = $device_type_tokens[2];
            if ($device_type =~ /^xc5v.*/i) {
                print "\tDevice Type\t= $device_type\n";
                print "\tCreating XDL Database....";
            } else {
                print "\n\tDevice Type = $device_type NOT SUPPORTED Exiting!!\n";
                close FP_XDL_1;
                die;
            }
        }
        s/inst.*XDL_DUMMY.*//;
        s/cfg *"//;
        s/\\\s/_/; # Substitute \  with an _ (ie Space with _) THis helps remove _INST_PROP.*
        if (/^inst\b.*\b($primitives_v5)\b/i) {
            $extract_LOCS = 1;
		$shape="";
            s/placed//; #Eliminate keyword placed
            s/,//g; # Eliminate ,'s
            s/\s*$/\n/;
            @fields = split;
            $LOC_val= $fields[4];
        } elsif ($extract_LOCS == 1) {
            if(/\s;\s/) {
                $extract_LOCS = 0;
            } else {

		if (/_INST_PROP::XDL_SHAPE_MEMBER:Shape_\d+:\d+,\d+\s.*/) {
			$shape = $_;
			chomp($shape);
			$shape =~ s/^.*_INST_PROP::XDL_SHAPE_MEMBER:(Shape_\d+:\d+,\d+)\s.*/$1/;
			$primitives_from_xdl_1_file_shape{$LOC_val} = $shape; 
			$primitives_from_xdl_1_file_shape_loc{$shape} = $LOC_val; 

                        $primitive_from_xdl_1_file_shape_name = $shape;
                        $primitive_from_xdl_1_file_shape_name =~ s/(Shape_\d+):0,0.*/$1/;
                        $xdl_1_shape_written{$primitive_from_xdl_1_file_shape_name} = 0;
		}

                s/_INST_PROP::XDL_SHAPE_DESC:\w.*:CARRY,\w.*\\"(\w.*)\\"/CARRY_INIT:$1:/;
		s/_INST_PROP::.*//;
		s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
		s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy

                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    if ($token=~/([ABCD]\dLUT):.+:\#LUT/) {
                        $BEL = $1;
                    } elsif ($token=~/([ABCD]FF):.+:\#FF/) {
                        $BEL = $1;
                    } elsif ($token=~/RAMB36_EXP:.+:/) {
                        #$BEL = $1;
                        $BEL = "BRAM";
                    } elsif ($token=~/DSP48E:.+:/) {
                        #$BEL = $1;
                        $BEL = "DSP48E";
                    } elsif ($token=~/CARRY4:.+:/) {
                        $BEL = "CARRY4";
                        $primitives_from_xdl_file_CARRY4{$LOC_val} = "TRUE"; 
                    }
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if ($token=~/$include_instances/i) {
                        if($token ne "") {
                            $xdl1_primitive_count++;
                             push(@primitives_from_xdl_1_file, $token);
                             $primitives_from_xdl_1_file_loc{$token} = $LOC_val; 
                             $primitives_from_xdl_1_file_bel{$token} = $BEL; 
                         }
                    } # token collection
                }
            }
        }
    }
    close FP_XDL_1;
    $xdl_1_database_elapsed_time = time - $running_time;
    print "  $xdl_1_database_elapsed_time Seconds\n";


    $xdl2_primitive_count = 0;
    $extract_LOCS = 0;
    while (<FP_XDL_2>) {
        # Check Device Type First
        if (/^design\b/i) {
            @device_type_tokens = split;
            $device_type = $device_type_tokens[2];
            if ($device_type =~ /^xc5v.*/i) {
                print "\tDevice Type\t= $device_type\n";
                print "\tCreating XDL Database....";
            } else {
                print "\n\tDevice Type = $device_type NOT SUPPORTED Exiting!!\n";
                close FP_XDL_2;
                die;
            }
        }
        s/inst.*XDL_DUMMY.*//;
        s/cfg *"//;
        s/\\\s/_/; # Substitute \  with an _ (ie Space with _) THis helps remove _INST_PROP.*
        if (/^inst\b.*\b($primitives_v5)\b/i) {
            $extract_LOCS = 1;
		$shape="";
            s/placed//; #Eliminate keyword placed
            s/,//g; # Eliminate ,'s
            s/\s*$/\n/;
            @fields = split;
            $LOC_val= $fields[4];
        } elsif ($extract_LOCS == 1) {
            if(/\s;\s/) {
                $extract_LOCS = 0;
            } else {

		if (/_INST_PROP::XDL_SHAPE_MEMBER:Shape_\d+:\d+,\d+\s.*/) {
			$shape = $_;
			chomp($shape);
			$shape =~ s/^.*_INST_PROP::XDL_SHAPE_MEMBER:(Shape_\d+:\d+,\d+)\s.*/$1/;
			$primitives_from_xdl_2_file_shape{$LOC_val} = $shape; 
			$primitives_from_xdl_2_file_shape_loc{$shape} = $LOC_val; 

                        $primitive_from_xdl_2_file_shape_name = $shape;
                        $primitive_from_xdl_2_file_shape_name =~ s/(Shape_\d+):0,0.*/$1/;
                        $xdl_2_shape_written{$primitive_from_xdl_2_file_shape_name} = 0;
		}

                s/_INST_PROP::XDL_SHAPE_DESC:\w.*:CARRY,\w.*\\"(\w.*)\\"/CARRY_INIT:$1:/;
		s/_INST_PROP::.*//;
		s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
		s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy

                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    if ($token=~/([ABCD]\dLUT):.+:\#LUT/) {
                        $BEL = $1;
                    } elsif ($token=~/([ABCD]FF):.+:\#FF/) {
                        $BEL = $1;
                    } elsif ($token=~/RAMB36_EXP:.+:/) {
                        #$BEL = $1;
                        $BEL = "BRAM";
                    } elsif ($token=~/DSP48E:.+:/) {
                        #$BEL = $1;
                        $BEL = "DSP48E";
                    } elsif ($token=~/CARRY4:.+:/) {
                        $BEL = "CARRY4";
                        $primitives_from_xdl_file_CARRY4{$LOC_val} = "TRUE"; 
                    }
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if ($token=~/$include_instances/i) {
			if($token ne "") {
                            $xdl2_primitive_count++;
                             push(@primitives_from_xdl_2_file, $token);
                             $primitives_from_xdl_2_file_loc{$token} = $LOC_val; 
                             $primitives_from_xdl_2_file_bel{$token} = $BEL; 
			} # token collection
		    }
                }
            }
        }
    }
    close FP_XDL_2;
    $xdl_2_database_elapsed_time = time - $running_time;
    print "  $xdl_2_database_elapsed_time Seconds\n";

    open FP_LOG, ">cmp_ncd_mismatch_loc.log" or die $!;
    open FP_DIFF, ">cmp_ncd_diff.log" or die $!;
    $total_primitive_count = 0;
    $matched_primitive_count = 0;
    foreach $primitive_instance (@primitives_from_xdl_2_file) {
    $total_primitive_count++;
        if( exists $primitives_from_xdl_1_file_loc{$primitive_instance} ) {
            if ($primitives_from_xdl_2_file_loc{$primitive_instance} eq $primitives_from_xdl_1_file_loc{$primitive_instance}) {
                if ($primitives_from_xdl_2_file_bel{$primitive_instance} eq $primitives_from_xdl_2_file_bel{$primitive_instance}) {
                    $matched_primitive_count++
                } else {
		    print FP_LOG "\n$primitive_instance BEL mismatched :\n\t$primitives_from_xdl_2_file_loc{$primitive_instance} <$design_name_2> :: $primitives_from_xdl_1_file_loc{$primitive_instance} <$design_name_1>\n";
		}
            } else {
		    print FP_LOG "\n$primitive_instance LOC mismatched :\n\t$primitives_from_xdl_2_file_loc{$primitive_instance} <$design_name_2> :: $primitives_from_xdl_1_file_loc{$primitive_instance} <$design_name_1>\n";
	    }

        } else {
                print FP_DIFF "$primitive_instance was not found in $design_name_1\n";
	}
    }


$elapsed_time = time - $start_time;

$percentage_1 = ($matched_primitive_count*100)/$total_primitive_count;
print "Primitives in $design_name_1 = $xdl1_primitive_count\n";
print "Primitives in $design_name_2 = $xdl2_primitive_count\n";
print "Total Primitives tested      = $total_primitive_count\n";
print "Total Matched Primitives     = $matched_primitive_count\n";
print "Ave Percentage Match         = <$percentage_1 %>\n\n";

print "Total Elapsed time = $elapsed_time Seconds\n\n";

print FP_LOG "Primitives in $design_name_1 = $xdl1_primitive_count\n";
print FP_LOG "Primitives in $design_name_2 = $xdl2_primitive_count\n";
print FP_LOG "Total Primitives tested      = $total_primitive_count\n";
print FP_LOG "Total Matched Primitives     = $matched_primitive_count\n";
print FP_LOG "Ave Percentage Match         = <$percentage_1 %>\n\n";
print FP_LOG "Total Elapsed time = $elapsed_time Seconds\n\n";

close FP_LOG;
close FP_DIFF;
