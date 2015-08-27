#!/usr/bin/perl
use File::Copy;

my @io_ports;
my @comp_fields;
my @ip_gen_top_rtl_pre;
my @ip_gen_top_rtl;
my @component_instance;


$Error_msg = "\nIncorrect Arguments !!\nusage:\n\txil_ip_gen -lib Library_name xst_cmd.xst module_name io_ports.txt [[-sd core_search path1] [-sd core_seach_path2] ...]\n\n";
$Error_msg1 = "xst_cmd_file.xst     : Original XST command file (each xst command in a seperate line)\n"; 
$Error_msg2 = "module_name          : Any module in the design that needs to be packaged as an IP\n";
$Error_msg3 = "io_ports.txt         : Regular text file with one port per line that gets portedout to IO pins (clocks, HSIO, Memory IO etc)\n"; 
$Error_msg4 = "-sd core_search_path : Path to externally generated cores (coregen / 3rd party cores etc)\n\n\n"; 
 
# DEfault Device type
$DEVICE_TYPE = "";

if ($#ARGV <= 4) {
    print $Error_msg;
    print $Error_msg1;
    print $Error_msg2;
    print $Error_msg3;
    print $Error_msg4;
    die;
} elsif ($ARGV[0] ne "-lib") {
    print $Error_msg;
    print $Error_msg1;
    print $Error_msg2;
    print $Error_msg3;
    print $Error_msg4;
    die;
} elsif ( ! (-e $ARGV[1])) {
    mkdir $ARGV[1], 0755 or die "Cannot Create Directory $ARGV[0] : $!";
}

$core_search_path = "";
if ($#ARGV > 1) {
    for ($i = 2; $i < ($#ARGV+1); $i++) {
        $input_arg = $ARGV[$i];
        if ($input_arg=~/^-sd/i) {
            $core_search_path = $core_search_path." -sd ".$ARGV[$i+1];
            $i++;
        }
    }
}

$library_name = $ARGV[1]; 
$module_name = $ARGV[3];
$module_name_ncf = "$library_name\/$module_name".".ncf"; 
$module_xst_command_file = "$module_name"."_ip_gen.xst";
$NGC_file = "$library_name\/coregen\/$module_name".".ngc";
$NGD_file = "$library_name\/$module_name".".ngd";
$NGD_vhdl_file = "$library_name\/$module_name"."_ngd.vhd";
$ip_gen_top_module = $library_name;
$IP_GEN_VHDL_file = "$library_name\/src\/$ip_gen_top_module".".vhd";
$IP_GEN_TOP_PRJ_file = "$library_name\/build\/$ip_gen_top_module".".prj";
$IP_GEN_TOP_UCF_file_name = "$ip_gen_top_module".".ucf";
$IP_GEN_TOP_UCF_file = "$library_name\/src\/$IP_GEN_TOP_UCF_file_name";

print "\t******* Parsing io_ports file $ARGV[4] *******\n";
open FP_IO_PORTS, "<$ARGV[4]" or die "Cannot Open $ARGV[4] file for reading : $!";
while (<FP_IO_PORTS>) {
        s/^\s*//;#delete leading spaces
        s/\s*$//;#delete training spaces
	chomp;
        push(@io_ports, $_);
}
close FP_IO_PORTS;

open FP_XST, "<$ARGV[2]" or die "Cannot Open $ARGV[2] file for reading : $!";


while (<FP_XST>) {
    if (/^-p\s.*/i) {
	chomp;
        $DEVICE_TYPE = $_;
        $DEVICE_TYPE =~ s/^-p\s*(\w.*)/$1/;
	print "\tDevice = $DEVICE_TYPE : Found \n";
    }
}
close FP_XST;

if ($DEVICE_TYPE eq "") {
    print " Device not Specified in the $ARGV[2] file\n";
    exit(0);
    }
system("perl -S xproj.pl $library_name $DEVICE_TYPE");

open FP_XST, "<$ARGV[2]" or die "Cannot Open $ARGV[2] file for reading : $!";
open FP_IP_XST, ">$module_xst_command_file" or die "Cannot Create intermedeate XST file $module_xst_command_file: $!";

while (<FP_XST>) {
    if (/^-ofn\s.*/i) {
        print FP_IP_XST "-ofn $library_name\/coregen\/$module_name\n";
    } elsif (/^-ifn\s.*/i) {
        print FP_IP_XST;
    } elsif (/^-iuc\s.*/i) {
        print FP_IP_XST "-iuc NO\n";
    } elsif (/^-top\s.*/i) {
        print FP_IP_XST "-top $module_name\n";
    } elsif (/^-write_timing_constraints\s.*/i) {
        print FP_IP_XST "-write_timing_constraints NO\n"; # DO NOT write TIMESPEC into the ngc as these are in the global Namespace and might conflict
    } elsif (/^-read_cores\s.*/i) {
        print FP_IP_XST "-read_cores OPTIMIZE\n"; # Ensure all core are read in and incorporated into the final netlist
    } elsif (/^-keep_hierarchy\s.*/i) {
        print FP_IP_XST "-keep_hierarchy YES\n";
    } elsif (/^-iobuf\s.*/i) {
        print FP_IP_XST "-iobuf NO\n";
    } elsif (/^-sd.*/i) {
        print FP_IP_XST;
    } else {
        print FP_IP_XST;
    }
}


close FP_XST;
close FP_IP_XST;



print "\t******* Synthesizing $module_name ********\n";
print "\txst -ifn $module_xst_command_file -intstyle silent\n";
system("xst -ifn $module_xst_command_file -intstyle silent") == 0 or die "\tXST Synthesis Failed! : $?\n";
wait;
print "\t******* running NGDBUILD on $module_name ********\n";

system("rm -rf $library_name\/xst_tmp\/*");
print "\tngdbuild -verbose -p $DEVICE_TYPE $NGC_file $NGD_file $core_search_path\n";
system("ngdbuild -verbose -p $DEVICE_TYPE $NGC_file $NGD_file $core_search_path") == 0 or die "\tNGDBUILD Failed : $?\n"; 
print "\t******* running NETGEN on $module_name ********\n";
print "\tnetgen -ofmt vhdl -fn -w $NGD_file $NGD_vhdl_file\n";
system("netgen -ofmt vhdl -fn -w $NGD_file $NGD_vhdl_file") == 0 or die "\tNETGEN Failed : $?\n";

print "\t******* Creating $IP_GEN_VHDL_file ********\n";
open FP_IP_GEN_VHDL_jtag_i, ">$library_name\/src\/jtag_user_reg_i.vhd" or die "Cannot Open jtag_user_reg_i.vhd for writing : $!"; 
print FP_IP_GEN_VHDL_jtag_i "Library IEEE;\n";
print FP_IP_GEN_VHDL_jtag_i "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL_jtag_i "Library unisim;\n";
print FP_IP_GEN_VHDL_jtag_i "use unisim.vcomponents.all;\n\n";
print FP_IP_GEN_VHDL_jtag_i "entity jtag_user_reg_i is\n";
print FP_IP_GEN_VHDL_jtag_i "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL_jtag_i "    port (\n";
print FP_IP_GEN_VHDL_jtag_i "	jtag_in_reg : out std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL_jtag_i "end entity jtag_user_reg_i;\n\n\n";
print FP_IP_GEN_VHDL_jtag_i "architecture jtag_user_reg_i_arch of jtag_user_reg_i is\n\n";
print FP_IP_GEN_VHDL_jtag_i "signal iTCK    : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_i "signal iTDI    : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_i "signal i_shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_i "signal shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_i "signal user_i_reg : std_logic_vector((WIDTH-1) downto 0) := (others => '0');\n\n";
print FP_IP_GEN_VHDL_jtag_i "begin\n\n";
print FP_IP_GEN_VHDL_jtag_i "	proc_user_i_reg_out: process(iTCK)\n\n";
print FP_IP_GEN_VHDL_jtag_i "	begin\n";
print FP_IP_GEN_VHDL_jtag_i "		if (iTCK'event and iTCK = '1') then\n";
print FP_IP_GEN_VHDL_jtag_i "			jtag_in_reg <= user_i_reg;\n";
print FP_IP_GEN_VHDL_jtag_i "			if (shift = '1') then\n";
print FP_IP_GEN_VHDL_jtag_i "				user_i_reg <= user_i_reg((WIDTH-2) downto 0) & iTDI;\n";
print FP_IP_GEN_VHDL_jtag_i "			end if;\n";
print FP_IP_GEN_VHDL_jtag_i "		end if;\n";
print FP_IP_GEN_VHDL_jtag_i "	end process;\n\n";
print FP_IP_GEN_VHDL_jtag_i "U_BSCAN_i: BSCAN_VIRTEX5\n";
print FP_IP_GEN_VHDL_jtag_i "\tgeneric map\n";
print FP_IP_GEN_VHDL_jtag_i "\t(\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tJTAG_CHAIN => 1\n";
print FP_IP_GEN_VHDL_jtag_i "\t)\n";
print FP_IP_GEN_VHDL_jtag_i "\tport map\n";
print FP_IP_GEN_VHDL_jtag_i "\t(\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tCAPTURE => open,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tDRCK => iTCK,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tRESET => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tSEL => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tSHIFT => i_shift,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tTDI => iTDI,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tUPDATE => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tTDO => '0'\n";
print FP_IP_GEN_VHDL_jtag_i "\t);\n\n";
print FP_IP_GEN_VHDL_jtag_i "u_BUFG: BUFG\n";
print FP_IP_GEN_VHDL_jtag_i "\tport map (\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tI => i_shift,\n";
print FP_IP_GEN_VHDL_jtag_i "\t\tO => shift\n";
print FP_IP_GEN_VHDL_jtag_i "\t);\n\n";

print FP_IP_GEN_VHDL_jtag_i "end architecture jtag_user_reg_i_arch;\n";
close FP_IP_GEN_VHDL_jtag_i;


open FP_IP_GEN_VHDL_jtag_o, ">$library_name\/src\/jtag_user_reg_o.vhd" or die "Cannot Open jtag_user_reg_o.vhd for writing : $!"; 

print FP_IP_GEN_VHDL_jtag_o "Library IEEE;\n";
print FP_IP_GEN_VHDL_jtag_o "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL_jtag_o "Library unisim;\n";
print FP_IP_GEN_VHDL_jtag_o "use unisim.vcomponents.all;\n\n";
print FP_IP_GEN_VHDL_jtag_o "entity jtag_user_reg_o is\n";
print FP_IP_GEN_VHDL_jtag_o "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL_jtag_o "    port (\n";
print FP_IP_GEN_VHDL_jtag_o "    jtag_out_reg : in std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL_jtag_o "end entity jtag_user_reg_o;\n\n";
print FP_IP_GEN_VHDL_jtag_o "architecture jtag_user_reg_o_arch of jtag_user_reg_o is\n\n";
print FP_IP_GEN_VHDL_jtag_o "signal oTCK    : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_o "signal oTDO    : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_o "signal shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_o "signal i_shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL_jtag_o "signal user_o_reg : std_logic_vector((WIDTH-1) downto 0) := (others => '0');\n\n";
print FP_IP_GEN_VHDL_jtag_o "begin\n";
print FP_IP_GEN_VHDL_jtag_o "    proc_user_o_reg_out: process(oTCK)\n";
print FP_IP_GEN_VHDL_jtag_o "    begin\n";
print FP_IP_GEN_VHDL_jtag_o "        if (oTCK'event and oTCK = '1') then\n";
print FP_IP_GEN_VHDL_jtag_o "            case shift is\n";
print FP_IP_GEN_VHDL_jtag_o "                when '1' => \n";
print FP_IP_GEN_VHDL_jtag_o "                   user_o_reg <= user_o_reg((WIDTH-2) downto 0) & user_o_reg((WIDTH-1));\n";
print FP_IP_GEN_VHDL_jtag_o "                when others  => \n";
print FP_IP_GEN_VHDL_jtag_o "                   user_o_reg <= jtag_out_reg;\n";
print FP_IP_GEN_VHDL_jtag_o "            end case;\n";
print FP_IP_GEN_VHDL_jtag_o "        end if;\n";
print FP_IP_GEN_VHDL_jtag_o "    end process;\n";
print FP_IP_GEN_VHDL_jtag_o "    oTDO <= user_o_reg((WIDTH-1));\n\n";
print FP_IP_GEN_VHDL_jtag_o "U_BSCAN_o: BSCAN_VIRTEX5\n";
print FP_IP_GEN_VHDL_jtag_o "\tgeneric map\n";
print FP_IP_GEN_VHDL_jtag_o "\t(\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tJTAG_CHAIN => 2\n";
print FP_IP_GEN_VHDL_jtag_o "\t)\n";
print FP_IP_GEN_VHDL_jtag_o "\tport map\n";
print FP_IP_GEN_VHDL_jtag_o "\t(\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tCAPTURE => open,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tDRCK => oTCK,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tRESET => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tSEL => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tSHIFT => i_shift,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tTDI => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tUPDATE => OPEN,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tTDO => oTDO\n";
print FP_IP_GEN_VHDL_jtag_o "\t);\n\n";
print FP_IP_GEN_VHDL_jtag_o "u_BUFG: BUFG\n";
print FP_IP_GEN_VHDL_jtag_o "\tport map (\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tI => i_shift,\n";
print FP_IP_GEN_VHDL_jtag_o "\t\tO => shift\n";
print FP_IP_GEN_VHDL_jtag_o "\t);\n\n";
print FP_IP_GEN_VHDL_jtag_o "end architecture jtag_user_reg_o_arch;\n";
close FP_IP_GEN_VHDL_jtag_o;

#create ip_gen_{module_name}.vhd
open FP_NGD_HDL_FILE, "<$NGD_vhdl_file" or die "Cannot Open $NGD_vhdl_file file for reading : $!";

push (@ip_gen_top_rtl_pre, "Library IEEE;\n");
push (@ip_gen_top_rtl_pre,"use IEEE.std_logic_1164.all;\n\n");
push (@ip_gen_top_rtl_pre,"Library unisim;\n");
push (@ip_gen_top_rtl_pre,"use unisim.vcomponents.all;\n\n");
push (@ip_gen_top_rtl_pre,"entity $ip_gen_top_module is port (\n");
push (@ip_gen_top_rtl,"\txil_ip_top_reset : in std_logic\n");
push (@ip_gen_top_rtl,");\n");
push (@ip_gen_top_rtl,"end entity $ip_gen_top_module;\n\n\n");
push (@ip_gen_top_rtl,"architecture arch_$ip_gen_top_module of $ip_gen_top_module is\n\n");
push (@ip_gen_top_rtl,"component jtag_user_reg_i is\n");
push (@ip_gen_top_rtl,"    generic (WIDTH : integer := 100);\n");
push (@ip_gen_top_rtl,"    port (\n");
push (@ip_gen_top_rtl,"    jtag_in_reg : out std_logic_vector((WIDTH-1) downto 0));\n");
push (@ip_gen_top_rtl,"end component jtag_user_reg_i;\n\n");
push (@ip_gen_top_rtl,"component jtag_user_reg_o is\n");
push (@ip_gen_top_rtl,"    generic (WIDTH : integer := 100);\n");
push (@ip_gen_top_rtl,"    port (\n");
push (@ip_gen_top_rtl,"    jtag_out_reg : in std_logic_vector((WIDTH-1) downto 0));\n");
push (@ip_gen_top_rtl,"end component jtag_user_reg_o;\n\n");

push (@ip_gen_top_rtl,"\n");

$start_extracting = 0;
while (<FP_NGD_HDL_FILE>) {
    if ( /Entity\s*\b$module_name\b/i ) {
        s/Entity\b/component/i;
        $start_extracting = 1;
    }
    if ($start_extracting == 1) {
        if (/End\s.*\b$module_name\b/i) {
            $start_extracting = 0;
            push (@ip_gen_top_rtl,"end component $module_name;\n");
        }
    }
    if ($start_extracting == 1) {
        push (@ip_gen_top_rtl,$_);
        if (/.*\s*:\s*(in|out)\s+std_logic/i) {
            s/^\s*//;#delete leading spaces
            s/\s+/ /; # Convert multiple spaces to single
            chomp;
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
    $IO_PORT_FOUND = 0;
    my @tags_val = split(':', $comp_field);
    $tags_val[0] =~ s/^\s*//; 
    $tags_val[0] =~ s/\s*$//; 
    foreach $io_port (@io_ports) {
        if ($io_port eq $tags_val[0]) {
            push (@ip_gen_top_rtl_pre, "\t");
            push (@ip_gen_top_rtl_pre, $comp_field);
            push (@ip_gen_top_rtl_pre, "\n");
            $IO_PORT_FOUND = 1;
        }
    }
    $comp_field =~ s/:=.*//; # Delete init values
    $comp_field =~ s/:/=>/;
    if ($IO_PORT_FOUND == 1) {
        if ( $comp_field =~ /\bout\b/i ) {
            $comp_field =~ s/\bout\b.*/$tags_val[0]/;
        } elsif ( $comp_field =~ /\bin\b/i )  {
            $comp_field =~ s/\bin\b.*/$tags_val[0]/;
        } else {
            $comp_field =~ s/\binout\b.*/$tags_val[0]/;
        }
    } else {
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
    }
    push(@component_instance, "\t\t$comp_field,\n");
}
push(@component_instance, "\t);\n");
push (@ip_gen_top_rtl,"-- Number of Input ports : $number_of_inputs\n");
push (@ip_gen_top_rtl,"-- Number of outputs ports : $number_of_outputs\n\n");
$jtag_out_reg_sz = $number_of_outputs - 1;
$jtag_in_reg_sz = $number_of_inputs - 1;

$jtag_in_reg_sz_1 = $jtag_in_reg_sz - 1;
$jtag_out_reg_sz_1 = $jtag_out_reg_sz - 1;

push (@ip_gen_top_rtl,"\n");
push (@ip_gen_top_rtl,"signal jtag_in_reg : std_logic_vector($jtag_in_reg_sz downto 0) := (others => '0');\n");
push (@ip_gen_top_rtl,"signal jtag_out_reg : std_logic_vector($jtag_out_reg_sz downto 0) := (others => '0');\n");
push (@ip_gen_top_rtl,"\n");
push (@ip_gen_top_rtl,"begin\n");
push (@ip_gen_top_rtl,"\n");
push (@ip_gen_top_rtl,"\n");

push (@ip_gen_top_rtl,"-- Output Boundary SCAN for INPUT Ports\n\n");
push (@ip_gen_top_rtl,"U_JTAG_USER_REG_i: jtag_user_reg_i\n");
push (@ip_gen_top_rtl,"\tgeneric map (WIDTH => $number_of_inputs)\n");
push (@ip_gen_top_rtl,"\tport  map (\n");
push (@ip_gen_top_rtl,"\t\tjtag_in_reg => jtag_in_reg);\n\n");

push (@ip_gen_top_rtl,"-- Output Boundary SCAN for OUTPUT Ports\n\n");
push (@ip_gen_top_rtl,"U_JTAG_USER_REG_o: jtag_user_reg_o\n");
push (@ip_gen_top_rtl,"\tgeneric map (WIDTH => $number_of_outputs)\n");
push (@ip_gen_top_rtl,"\t port map (\n");
push (@ip_gen_top_rtl,"\t\tjtag_out_reg => jtag_out_reg);\n\n");


$component_instance_line_count = $#component_instance;
foreach $component_instance_line (@component_instance) {
    # This is needed to take out the comma from the last line!
    if ($component_instance_line_count == 1) {
        $component_instance_line =~ s/,\n/\n/;
        push (@ip_gen_top_rtl,$component_instance_line);
    } else {
        push (@ip_gen_top_rtl,$component_instance_line);
    }
    $component_instance_line_count--;
}

push (@ip_gen_top_rtl,"\n\nend architecture arch_$ip_gen_top_module;\n");

open FP_IP_GEN_VHDL, ">$IP_GEN_VHDL_file" or die "Cannot Open ip_gen_$module_name for writing : $!"; 
foreach $ip_gen_top_rtl_string (@ip_gen_top_rtl_pre) {
    print FP_IP_GEN_VHDL $ip_gen_top_rtl_string;
}
foreach $ip_gen_top_rtl_string (@ip_gen_top_rtl) {
    print FP_IP_GEN_VHDL $ip_gen_top_rtl_string;
}
close FP_IP_GEN_VHDL;


print "\t******* Creating $IP_GEN_TOP_PRJ_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_PRJ, ">$IP_GEN_TOP_PRJ_file" or die "Cannot Open $IP_GEN_TOP_PRJ_file for writing : $!"; 
print FP_IP_GEN_TOP_PRJ "vhdl work \"..\/src\/jtag_user_reg_i.vhd\"\n";
print FP_IP_GEN_TOP_PRJ "vhdl work \"..\/src\/jtag_user_reg_o.vhd\"\n";
print FP_IP_GEN_TOP_PRJ "vhdl work \"..\/src\/$ip_gen_top_module".".vhd\"\n";
close FP_IP_GEN_TOP_PRJ;

print "\t******* Creating $IP_GEN_TOP_UCF_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_UCF, ">$IP_GEN_TOP_UCF_file" or die "Cannot Open $IP_GEN_TOP_UCF_file for writing : $!"; 
print FP_IP_GEN_TOP_UCF "SYSTEM_JITTER = 300 ps;\n\n";
print FP_IP_GEN_TOP_UCF "NET \"U_JTAG_USER_REG_i\/iTCK\" TNM_NET = \"iTCK\";\n";
print FP_IP_GEN_TOP_UCF "NET \"U_JTAG_USER_REG_o\/oTCK\" TNM_NET = \"oTCK\";\n\n";
print FP_IP_GEN_TOP_UCF "TIMESPEC \"TS_iTCK\" = FROM \"iTCK\"  2 ns DATAPATHONLY;\n";
print FP_IP_GEN_TOP_UCF "TIMESPEC \"TS_oTCK\" = TO \"oTCK\" 2 ns DATAPATHONLY;\n\n";

print FP_IP_GEN_TOP_UCF "\nINST \"U_JTAG_USER_REG_i\" AREA_GROUP = \"AG_U_JTAG_USER_REG_i\";\n";
print FP_IP_GEN_TOP_UCF "INST \"U_JTAG_USER_REG_o\" AREA_GROUP = \"AG_U_JTAG_USER_REG_o\";\n";
print FP_IP_GEN_TOP_UCF "\nINST \"u_ip_gen\" AREA_GROUP = \"AG_U_IP_GEN\";\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=SLICE_X22Y66:SLICE_X33Y78;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=DSP48_X0Y0:DSP48_X0Y31;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=RAMB36_X1Y0:RAMB36_X1Y15;\n";

print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" GROUP=CLOSED;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" PLACE=CLOSED;\n\n";


close FP_IP_GEN_TOP_UCF;
