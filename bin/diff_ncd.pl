#!perl

$start_time = time;
$running_time = $start_time;
#
#
my $LOC_val;

my @primitives_from_xdl_1_file;
my %primitives_from_xdl_1_file_loc;

my @primitives_from_xdl_2_file;
my %primitives_from_xdl_2_file_loc;

$WRITE_RLOCS = 0;

$USAGE = "\n Usage :\n\t diff_ncd file_1.ncd file_2.ncd\n";

if (($#ARGV < 1) | ($#ARGV > 1)) {
    print "\n !ERROR Wrong Number of Arguments ($#ARGV)\n";
    print $USAGE; 
    die;
} 


$file_1_ncd = $ARGV[0];
$file_2_ncd = $ARGV[1];
$file_1_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name_1 = $1;
$file_2_ncd =~ s/(^.*)\.(ncd)/$2/;
$design_name_2 = $1;

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
        if (/^inst\b.*/i) {
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

                s/_INST_PROP::XDL_SHAPE_DESC:\w.*:CARRY,\w.*\\"(\w.*)\\"/CARRY_INIT:$1:/;
		s/_INST_PROP::.*//;
		s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
		s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy

                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if($token ne "") {
                        $xdl1_primitive_count++;
                         push(@primitives_from_xdl_1_file, $token);
                         $primitives_from_xdl_1_file_loc{$token} = $LOC_val; 
                     }
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
        if (/^inst\b.*/i) {
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

                s/_INST_PROP::XDL_SHAPE_DESC:\w.*:CARRY,\w.*\\"(\w.*)\\"/CARRY_INIT:$1:/;
		s/_INST_PROP::.*//;
		s/_.*?_PROP::.*?\s/ /; # TurnOff greedy
		s/\s_.*?:.*:.*?\s/ /; # TurnOff greedy

                s/^\s*//; # Delete Leading Edge Spaces
                s/\s*/ /; # Convert Multiple spaces to single
                s/\s"//;
                @tokens = split;
                foreach $token (@tokens) {
                    $token =~ s/.*?:(.*?):.*/$1/; # Turnoff Greedy Matching with ?
                    if($token ne "") {
                        $xdl2_primitive_count++;
                         push(@primitives_from_xdl_2_file, $token);
                         $primitives_from_xdl_2_file_loc{$token} = $LOC_val; 
                    } # token collection
                }
            }
        }
    }
    close FP_XDL_2;
    $xdl_2_database_elapsed_time = time - $running_time;
    print "  $xdl_2_database_elapsed_time Seconds\n";

    open FP_LOG, ">diff_ncd.log" or die $!;
    $matched_primitive_count = 0;
    $proto_count = 0;
    $write_thru_count = 0;
    foreach $primitive_instance (@primitives_from_xdl_2_file) {
        if ($primitive_instance =~ /^ProtoComp\d+.CYINIT|_rt\b|\bGND_\d+\b|\bVCC_\d+\b|\bGND\.SLICE|\bVCC\.SLICE/) {
                $write_thru_count++;
        } elsif( exists $primitives_from_xdl_1_file_loc{$primitive_instance} ) {
                $matched_primitive_count++
        } else {
                print FP_LOG "$primitive_instance was not found in $design_name_1\n";
	}
    }

    print FP_LOG "Primitives in $design_name_1 = $xdl1_primitive_count\n";
    print FP_LOG "Primitives in $design_name_2 = $xdl2_primitive_count\n";
    print FP_LOG "Total Elapsed time = $elapsed_time Seconds\n\n";
    print FP_LOG "\n\n#------***********************************************************--------#\n\n";

    $matched_primitive_count = 0;
    $proto_count = 0;
    $write_thru_count = 0;
    foreach $primitive_instance (@primitives_from_xdl_1_file) {
        if ($primitive_instance =~ /^ProtoComp\d+.CYINIT|_rt\b|\bGND_\d+\b|\bVCC_\d+\b|\bGND\.SLICE|\bVCC\.SLICE/) {
                $write_thru_count++;
        } elsif( exists $primitives_from_xdl_2_file_loc{$primitive_instance} ) {
                $matched_primitive_count++
        } else {
                print FP_LOG "$primitive_instance was not found in $design_name_2\n";
	}
    }

$elapsed_time = time - $start_time;

print "Primitives in $design_name_1 = $xdl1_primitive_count\n";
print "Primitives in $design_name_2 = $xdl2_primitive_count\n";
print "ProtoCount = $proto_count\n"; 
print "ProtoCount = $write_thru_count\n"; 

print "Total Elapsed time = $elapsed_time Seconds\n\n";

print FP_LOG "Primitives in $design_name_1 = $xdl1_primitive_count\n";
print FP_LOG "Primitives in $design_name_2 = $xdl2_primitive_count\n";
print FP_LOG "Total Elapsed time = $elapsed_time Seconds\n\n";

close FP_LOG;
