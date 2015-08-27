#!/usr/bin/perl
use File::Copy;

my @comp_fields;
my @component_instance;
my @clock_constraints;


$Error_msg = "Wrong Arguments !\n\tusage:\n\t\txil_ip_gen_post_synthesis -lib Library_name xst_cmd_file.xst module_name module_name.xcf -[EDIF|NGC]\n";

# DEfault Device type
$DEVICE_TYPE = "xc5vlx50t-1-ff1136a";

if ($#ARGV != 5) {
    print $Error_msg;
    die;
} elsif ($ARGV[0] ne "-lib") {
    print $Error_msg;
    die;
} elsif ( ! (-e $ARGV[1])) {
    mkdir $ARGV[1], 0755 or die "Cannot Create Directory $ARGV[0] : $!";
    mkdir "$ARGV[1]\/xst_tmp", 0755 or die "Cannot Create Directory $ARGV[0]\/xst_tmp : $!";
}

if ($ARGV[5] eq "-EDIF") {
    $NETLIST_TYPE = "edf";
} elsif ($ARGV[5] eq "-NGC") {
    $NETLIST_TYPE = "ngc";
} else {
    print "$Error_msg";
    die;
}


$library_name = $ARGV[1]; 
$module_name = $ARGV[3];
$module_name_ncf = "$library_name\/$module_name".".ncf"; 
$module_name_xcf = $ARGV[4];
$Netlist_file = "$library_name\/$module_name".".$NETLIST_TYPE";
$NGD_file = "$library_name\/$module_name".".ngd";
$NGD_vhdl_file = "$library_name\/$module_name"."_ngd.vhd";
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
open FP_IP_GEN_TOP_XST, ">$IP_GEN_TOP_XST_file" or die "Cannot Open $IP_GEN_TOP_XST_file for writing : $!"; 
`cp $module_name.$NETLIST_TYPE $library_name`;

while (<FP_XST>) {
    if (/^set *-tmpdir\s.*/i) {
        print FP_IP_GEN_TOP_XST "set -tmpdir .\/xst_tmp\n";
    } elsif (/^set *-xsthdpdir\s.*/i) {
        print FP_IP_GEN_TOP_XST "-xsthdpdir .\/xst_tmp\n";
    } elsif (/^-ofn\s.*/i) {
        print FP_IP_GEN_TOP_XST "-ofn $ip_gen_top_module\n";
    } elsif (/^-ifn\s.*/i) {
        print FP_IP_GEN_TOP_XST "-ifn $ip_gen_top_module".".prj\n";
    } elsif (/^-iuc\s.*/i) {
        print FP_IP_GEN_TOP_XST "-iuc NO\n";
    } elsif (/^-top\s.*/i) {
        print FP_IP_GEN_TOP_XST "-top $ip_gen_top_module\n";
    } elsif (/^-write_timing_constraints\s.*/i) {
        print FP_IP_GEN_TOP_XST "-write_timing_constraints NO\n"; # DO NOT write TIMESPEC into the ngc as these are in the global Namespace and might conflict
    } elsif (/^-read_cores\s.*/i) {
        print FP_IP_GEN_TOP_XST "-read_cores YES\n"; #This ensures the IP_MODULE is read and the Clock_buffers are inserted (xcf constraint to say this must exist)
    } elsif (/^-keep_hierarchy\s.*/i) {
        print FP_IP_GEN_TOP_XST "-keep_hierarchy YES\n";
    } elsif (/^-iobuf\s.*/i) {
        print FP_IP_GEN_TOP_XST "-iobuf NO\n";
    } elsif (/^-p\s.*/i) {
        print FP_IP_GEN_TOP_XST;
	chomp;
        $DEVICE_TYPE = $_;
        $DEVICE_TYPE =~ s/^-p\s*(\w.*)/$1/;
	print "\tDevice = $DEVICE_TYPE : Found \n";
    } else {
        print FP_IP_GEN_TOP_XST;
    }
}


close FP_XST;
close FP_IP_GEN_TOP_XST;

print "\t******* running NGDBUILD on $module_name ********\n";

print "\tngdbuild -verbose -nt timestamp -dd _ngo -p $DEVICE_TYPE $Netlist_file $NGD_file\n";
system("ngdbuild -verbose -nt timestamp -dd _ngo -p $DEVICE_TYPE $Netlist_file $NGD_file") == 0 or die "\tNGDBUILD Failed : $?\n"; 
print "\t******* running NETGEN on $module_name ********\n";
print "\tnetgen -ofmt vhdl -fn -w $NGD_file $NGD_vhdl_file\n";
system("netgen -ofmt vhdl -fn -w $NGD_file $NGD_vhdl_file") == 0 or die "\tNETGEN Failed : $?\n";

print "\t******* Creating $IP_GEN_VHDL_file's ********\n";
open FP_IP_GEN_VHDL_jtag_i, ">$library_name\/jtag_user_reg_i.vhd" or die "Cannot Open jtag_user_reg_i.vhd for writing : $!"; 
print FP_IP_GEN_VHDL_jtag_i "Library IEEE;\n";
print FP_IP_GEN_VHDL_jtag_i "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL_jtag_i "entity jtag_user_reg_i is\n";
print FP_IP_GEN_VHDL_jtag_i "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL_jtag_i "    port (\n";
print FP_IP_GEN_VHDL_jtag_i "	i_reset : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_i "	iTCK    : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_i "	iTDI    : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_i "	i_shift : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_i "	jtag_in_reg : out std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL_jtag_i "end entity jtag_user_reg_i;\n\n\n";
print FP_IP_GEN_VHDL_jtag_i "architecture jtag_user_reg_i_arch of jtag_user_reg_i is\n\n";
print FP_IP_GEN_VHDL_jtag_i "signal user_i_reg : std_logic_vector((WIDTH-1) downto 0) := (others => '0');\n\n";
print FP_IP_GEN_VHDL_jtag_i "begin\n\n";
print FP_IP_GEN_VHDL_jtag_i "	proc_user_i_reg_out: process(i_reset, iTCK)\n\n";
print FP_IP_GEN_VHDL_jtag_i "	begin\n";
print FP_IP_GEN_VHDL_jtag_i "		if (i_reset = '1') then\n";
print FP_IP_GEN_VHDL_jtag_i "			user_i_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL_jtag_i "			jtag_in_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL_jtag_i "		elsif (iTCK'event and iTCK = '1') then\n";
print FP_IP_GEN_VHDL_jtag_i "			if (i_shift = '1') then\n";
print FP_IP_GEN_VHDL_jtag_i "				user_i_reg <= user_i_reg((WIDTH-2) downto 0) & iTDI;\n";
print FP_IP_GEN_VHDL_jtag_i "			else\n";
print FP_IP_GEN_VHDL_jtag_i "				jtag_in_reg <= user_i_reg;\n";
print FP_IP_GEN_VHDL_jtag_i "			end if;\n";
print FP_IP_GEN_VHDL_jtag_i "		end if;\n";
print FP_IP_GEN_VHDL_jtag_i "	end process;\n";
print FP_IP_GEN_VHDL_jtag_i "end architecture jtag_user_reg_i_arch;\n";
close FP_IP_GEN_VHDL_jtag_i;


open FP_IP_GEN_VHDL_jtag_o, ">$library_name\/jtag_user_reg_o.vhd" or die "Cannot Open jtag_user_reg_o.vhd for writing : $!"; 

print FP_IP_GEN_VHDL_jtag_o "Library IEEE;\n";
print FP_IP_GEN_VHDL_jtag_o "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL_jtag_o "entity jtag_user_reg_o is\n";
print FP_IP_GEN_VHDL_jtag_o "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL_jtag_o "    port (\n";
print FP_IP_GEN_VHDL_jtag_o "    o_reset : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_o "    oTCK    : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_o "    oTDO    : out std_logic;\n";
print FP_IP_GEN_VHDL_jtag_o "    o_shift : in std_logic;\n";
print FP_IP_GEN_VHDL_jtag_o "    jtag_out_reg : in std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL_jtag_o "end entity jtag_user_reg_o;\n\n";
print FP_IP_GEN_VHDL_jtag_o "architecture jtag_user_reg_o_arch of jtag_user_reg_o is\n\n";
print FP_IP_GEN_VHDL_jtag_o "signal user_o_reg : std_logic_vector((WIDTH-1) downto 0) := (others => '0');\n\n";
print FP_IP_GEN_VHDL_jtag_o "begin\n";
print FP_IP_GEN_VHDL_jtag_o "    proc_user_o_reg_out: process(o_reset, oTCK)\n";
print FP_IP_GEN_VHDL_jtag_o "    begin\n";
print FP_IP_GEN_VHDL_jtag_o "        if (o_reset = '1') then\n";
print FP_IP_GEN_VHDL_jtag_o "            user_o_reg <= (others => '0');\n";
print FP_IP_GEN_VHDL_jtag_o "        elsif (oTCK'event and oTCK = '1') then\n";
print FP_IP_GEN_VHDL_jtag_o "            if (o_shift = '1') then\n";
print FP_IP_GEN_VHDL_jtag_o "                user_o_reg <= user_o_reg((WIDTH-2) downto 0) & user_o_reg((WIDTH-1));\n";
print FP_IP_GEN_VHDL_jtag_o "            else\n";
print FP_IP_GEN_VHDL_jtag_o "                user_o_reg <= jtag_out_reg;\n";
print FP_IP_GEN_VHDL_jtag_o "            end if;\n";
print FP_IP_GEN_VHDL_jtag_o "        end if;\n";
print FP_IP_GEN_VHDL_jtag_o "    end process;\n";
print FP_IP_GEN_VHDL_jtag_o "    oTDO <= user_o_reg((WIDTH-1));\n";
print FP_IP_GEN_VHDL_jtag_o "end architecture jtag_user_reg_o_arch;\n";
close FP_IP_GEN_VHDL_jtag_o;

#create ip_gen_{module_name}.vhd
open FP_IP_GEN_VHDL, ">$IP_GEN_VHDL_file" or die "Cannot Open ip_gen_$module_name for writing : $!"; 
open FP_NGD_HDL_FILE, "<$NGD_vhdl_file" or die "Cannot Open $NGD_vhdl_file file for reading : $!";

print FP_IP_GEN_VHDL "Library IEEE;\n";
print FP_IP_GEN_VHDL "use IEEE.std_logic_1164.all;\n\n";
print FP_IP_GEN_VHDL "Library unisim;\n";
print FP_IP_GEN_VHDL "use unisim.vcomponents.all;\n\n";
print FP_IP_GEN_VHDL "entity $ip_gen_top_module is\n";
print FP_IP_GEN_VHDL "end entity $ip_gen_top_module;\n\n\n";
print FP_IP_GEN_VHDL "architecture arch_$ip_gen_top_module of $ip_gen_top_module is\n\n";
print FP_IP_GEN_VHDL "component jtag_user_reg_i is\n";
print FP_IP_GEN_VHDL "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL "    port (\n";
print FP_IP_GEN_VHDL "    i_reset : in std_logic;\n";
print FP_IP_GEN_VHDL "    iTCK    : in std_logic;\n";
print FP_IP_GEN_VHDL "    iTDI    : in std_logic;\n";
print FP_IP_GEN_VHDL "    i_shift : in std_logic;\n";
print FP_IP_GEN_VHDL "    jtag_in_reg : out std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL "end component jtag_user_reg_i;\n\n";
print FP_IP_GEN_VHDL "component jtag_user_reg_o is\n";
print FP_IP_GEN_VHDL "    generic (WIDTH : integer := 100);\n";
print FP_IP_GEN_VHDL "    port (\n";
print FP_IP_GEN_VHDL "    o_reset : in std_logic;\n";
print FP_IP_GEN_VHDL "    oTCK    : in std_logic;\n";
print FP_IP_GEN_VHDL "    oTDO    : out std_logic;\n";
print FP_IP_GEN_VHDL "    o_shift : in std_logic;\n";
print FP_IP_GEN_VHDL "    jtag_out_reg : in std_logic_vector((WIDTH-1) downto 0));\n";
print FP_IP_GEN_VHDL "end component jtag_user_reg_o;\n\n";

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

# Parse the XCF file to extract clock signals to include in the UCF file
open FP_XCF_FILE, "<$module_name_xcf" or die "Cannot Open $module_name_xcf file for reading : $!";

while (<FP_XCF_FILE>) {
	if (/.*NET\s.*\sTNM_NET\s.*/i) {
		s/(.*NET\s)\s*"?(\s*\w+\s*)"?\s*(\sTNM_NET\s.*)/$1"u_ip_gen\/$2"$3/;
		push(@clock_constraints, $_);
	} elsif (/.*TIMESPEC\s.*/i) { 
		push(@clock_constraints, $_);
	} elsif (/.*TIMEGRP\s.*/i) { 
		push(@clock_constraints, $_);
	}
}
close FP_XCF_FILE;
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
print FP_IP_GEN_VHDL "signal oTCK, oTDO, O_reset, O_shift : std_logic := '0';\n";
print FP_IP_GEN_VHDL "\n";
print FP_IP_GEN_VHDL "signal jtag_in_reg : std_logic_vector($jtag_in_reg_sz downto 0) := (others => '0');\n";
print FP_IP_GEN_VHDL "signal jtag_out_reg : std_logic_vector($jtag_out_reg_sz downto 0) := (others => '0');\n";
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
print FP_IP_GEN_VHDL "U_JTAG_USER_REG_i: jtag_user_reg_i\n";
print FP_IP_GEN_VHDL "\tgeneric map (WIDTH => $number_of_inputs)\n";
print FP_IP_GEN_VHDL "\tport  map (\n";
print FP_IP_GEN_VHDL "\t\ti_reset => i_reset, \n";
print FP_IP_GEN_VHDL "\t\tiTCK    => iTCK,\n";
print FP_IP_GEN_VHDL "\t\tiTDI    => iTDI,\n";
print FP_IP_GEN_VHDL "\t\ti_shift => i_shift,\n";
print FP_IP_GEN_VHDL "\t\tjtag_in_reg => jtag_in_reg);\n\n";

print FP_IP_GEN_VHDL "-- Output Boundary SCAN for OUTPUT Ports\n\n";
print FP_IP_GEN_VHDL "U_BSCAN_o: BSCAN_VIRTEX5\n";
print FP_IP_GEN_VHDL "\tgeneric map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tJTAG_CHAIN => 2\n";
print FP_IP_GEN_VHDL "\t)\n";
print FP_IP_GEN_VHDL "\tport map\n";
print FP_IP_GEN_VHDL "\t(\n";
print FP_IP_GEN_VHDL "\t\tCAPTURE => open,\n";
print FP_IP_GEN_VHDL "\t\tDRCK => oTCK,\n";
print FP_IP_GEN_VHDL "\t\tRESET => o_reset,\n";
print FP_IP_GEN_VHDL "\t\tSEL => open,\n";
print FP_IP_GEN_VHDL "\t\tSHIFT => o_shift,\n";
print FP_IP_GEN_VHDL "\t\tTDI => OPEN,\n";
print FP_IP_GEN_VHDL "\t\tUPDATE => OPEN,\n";
print FP_IP_GEN_VHDL "\t\tTDO => oTDO\n";
print FP_IP_GEN_VHDL "\t);\n\n";
print FP_IP_GEN_VHDL "U_JTAG_USER_REG_o: jtag_user_reg_o\n";
print FP_IP_GEN_VHDL "\tgeneric map (WIDTH => $number_of_outputs)\n";
print FP_IP_GEN_VHDL "\t port map (\n";
print FP_IP_GEN_VHDL "\t\to_reset => o_reset ,\n";
print FP_IP_GEN_VHDL "\t\toTCK    => oTCK,\n";
print FP_IP_GEN_VHDL "\t\toTDO    => oTDO,\n";
print FP_IP_GEN_VHDL "\t\to_shift => o_shift,\n";
print FP_IP_GEN_VHDL "\t\tjtag_out_reg => jtag_out_reg);\n";


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
print FP_IP_GEN_TOP_PRJ "vhdl work \"jtag_user_reg_i.vhd\"\n";
print FP_IP_GEN_TOP_PRJ "vhdl work \"jtag_user_reg_o.vhd\"\n";
print FP_IP_GEN_TOP_PRJ "vhdl work \"$ip_gen_top_module".".vhd\"\n";
close FP_IP_GEN_TOP_PRJ;

print "\t******* Creating $IP_GEN_TOP_UCF_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_UCF, ">$IP_GEN_TOP_UCF_file" or die "Cannot Open $IP_GEN_TOP_UCF_file for writing : $!"; 
print FP_IP_GEN_TOP_UCF "NET \"iTCK\" TIG;\n";
print FP_IP_GEN_TOP_UCF "NET \"oTCK\" TIG;\n\n";

foreach $clock_constraint (@clock_constraints) {
	print FP_IP_GEN_TOP_UCF $clock_constraint 
}
print FP_IP_GEN_TOP_UCF "\nINST \"U_JTAG_USER_REG_i\" AREA_GROUP = \"AG_U_JTAG_USER_REG_i\";\n";
print FP_IP_GEN_TOP_UCF "INST \"U_JTAG_USER_REG_o\" AREA_GROUP = \"AG_U_JTAG_USER_REG_o\";\n";
print FP_IP_GEN_TOP_UCF "\nINST \"u_ip_gen\" AREA_GROUP = \"AG_U_IP_GEN\";\n";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" RANGE=SLICE_X22Y66:SLICE_X33Y78;\n";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" RANGE=DSP48_X0Y0:DSP48_X0Y31;\n";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" RANGE=RAMB36_X1Y0:RAMB36_X1Y15;\n";

print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" GROUP=CLOSED;\n";
print FP_IP_GEN_TOP_UCF "AREA_GROUP \"AG_U_IP_GEN\" PLACE=CLOSED;\n\n";


close FP_IP_GEN_TOP_UCF;

$IP_GEN_MAKEFILE = "$library_name\/Makefile";
#Create Makefile
open FP_IP_GEN_MAKEFILE, ">$IP_GEN_MAKEFILE" or die "Cannot Open $IP_GEN_MAKEFILE for writing : $!"; 
print "\t******* Creating $IP_GEN_MAKEFILE ********\n";
print FP_IP_GEN_MAKEFILE "TARGET=$ip_gen_top_module\n";
print FP_IP_GEN_MAKEFILE "DEVICE=$DEVICE_TYPE\n\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_0 = -intstyle ise -w -g DebugBitstream:No -g Binary:no -g CRC:Enable -m\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_1 = -g CclkPin:PullUp -g M0Pin:PullUp -g M1Pin:PullUp -g M2Pin:PullUp -g ProgPin:PullUp\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_2 = -g DonePin:PullUp -g InitPin:Pullup -g CsPin:Pullup -g DinPin:Pullup -g BusyPin:Pullup\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_3 = -g RdWrPin:Pullup -g TckPin:PullUp -g TdiPin:PullUp -g TdoPin:PullUp -g TmsPin:PullUp\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_4 = -g UnusedPin:Pullnone\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_5 = -g DCIUpdateMode:AsRequired -g StartUpClk:CCLK -g DONE_cycle:4 -g GTS_cycle:5 -g GWE_cycle:6\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTS_6 = -g LCK_cycle:NoWait -g Security:None -g DonePipe:No -g DriveDone:No -g UserID:\$(Bit_file_ID)\n";
print FP_IP_GEN_MAKEFILE "#BITGEN_OPTIONS = \$(BITGEN_OPTS_0) \$(BITGEN_OPTS_1) \$(BITGEN_OPTS_2) \$(BITGEN_OPTS_3) \$(BITGEN_OPTS_4) \$(BITGEN_OPTS_5) \$(BITGEN_OPTS_6)\n\n";
print FP_IP_GEN_MAKEFILE "#\$(TARGET)_par.mcs: \$(TARGET)_par.bit\n";
print FP_IP_GEN_MAKEFILE "#\tpromgen -w -p mcs -c FF -o \$(TARGET)_par -u 0 \$(TARGET)_par.bit\n";
print FP_IP_GEN_MAKEFILE "#\$(TARGET).ibs: \$(TARGET)_par.ncd\n";
print FP_IP_GEN_MAKEFILE "#\tibiswriter -intstyle silent -allmodels \$(TARGET)_par.ncd \$(TARGET).ibs\n";
print FP_IP_GEN_MAKEFILE "#\$(TARGET)_par.bit: \$(TARGET)_par.ncd\n";
print FP_IP_GEN_MAKEFILE "#\tnetgen -intstyle silent -ofmt vhdl -pcf \$(TARGET).pcf -w \$(TARGET)_par.ncd \$(TARGET)_par.vhd\n";
print FP_IP_GEN_MAKEFILE "#\ttrce -intstyle silent -a -e 5 -u -skew -l 10 \$(TARGET)_par.ncd -o \$(TARGET).twr \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "#\tbitgen \$(BITGEN_OPTIONS) \$(TARGET)_par.ncd \n";
print FP_IP_GEN_MAKEFILE "#\textract_locs_ip_inst \$(TARGET).ngd \$(TARGET)_par.ncd u_ip_gen -RLOC \$(TARGET)\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_par.ncd: \$(TARGET)_map.ncd\n";
print FP_IP_GEN_MAKEFILE "\tpar -w -intstyle silent -ol std -pl std -rl std -t 1 \$(TARGET)_map.ncd \$(TARGET)_par.ncd \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET)_map.ncd: \$(TARGET).ngd\n";
print FP_IP_GEN_MAKEFILE "\tmap -timing -intstyle silent -p \$(DEVICE) -cm area -pr b -k 4 -c 100 -o \$(TARGET)_map.ncd \$(TARGET).ngd \$(TARGET).pcf\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET).ngd: \$(TARGET).ngc\n";
print FP_IP_GEN_MAKEFILE "#\tnetgen -intstyle silent -ofmt vhdl -w \$(TARGET).ngc \$(TARGET)_xst.vhd\n";
print FP_IP_GEN_MAKEFILE "\tngdbuild -intstyle silent -verbose -nt timestamp -dd _ngo -p \$(DEVICE) -uc $IP_GEN_TOP_UCF_file_name \$(TARGET).ngc \$(TARGET).ngd\n";
print FP_IP_GEN_MAKEFILE "\$(TARGET).ngc:\n";
print FP_IP_GEN_MAKEFILE "\txst -ifn \$(TARGET).xst -intstyle silent\n";
print FP_IP_GEN_MAKEFILE "clean:\n";
print FP_IP_GEN_MAKEFILE "\t-rm -rf xst_tmp\/*\n";
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
