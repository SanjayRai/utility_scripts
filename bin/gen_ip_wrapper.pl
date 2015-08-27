#!/usr/bin/perl

my @io_ports;
my @comp_fields;
my %port_input_object_size;
my %port_output_object_size;
my %port_input_toplevel_object_size;
my %port_output_toplevel_object_size;
my %port_input_toplevel_object_type;
my %port_output_toplevel_object_type;

# Prints Human Readable Time and Date
@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$Date_and_Time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
$ERROR_MSG = "\n !ERROR\n \n Usage :\n \t gen_ip_wrapper module_name\n\n";

$XPROJ_DEPENDENCY_DIR = "/home/sanjayr/bin/xproj_dependency/";
$JTAG_IO_REG_VERILOG_FILE = $XPROJ_DEPENDENCY_DIR."jtag_user_reg_io.v";

$input_verilog_file = "$ARGV[0]".".v";
$module_name = $ARGV[0];
$io_ports_file = "$module_name"."_io.txt";
$ip_gen_top_module = "$ARGV[0]"."_ip_top";
$IP_GEN_V_file = "$ip_gen_top_module".".v";
$IP_GEN_TOP_UCF_file = "$ip_gen_top_module".".ucf";
$IP_GEN_TOP_XDC_file = "$ip_gen_top_module".".xdc";

print "\t******* Parsing io_ports file $io_ports_file *******\n";
open FP_IO_PORTS, "<$io_ports_file" or die "Cannot Open $io_ports_file file for reading : $! $ERROR_MSG";
while (<FP_IO_PORTS>) {
        s/^\s*//;#delete leading spaces
        s/\s*$//;#delete training spaces
	chomp;
        push(@io_ports, $_);
}
close FP_IO_PORTS;

open(fp, ">jtag_user_reg_io.v") or die "Cannot Open jtag_user_reg_io.vhd file for writing : $! $ERROR_MSG";
open(FP_JTAG_HDL_FILE,"<$JTAG_IO_REG_VERILOG_FILE") or die "Cannot Open $JTAG_IO_REG_VERILOG_FILE file for reading $! $ERROR_MSG";
print fp "\/\/ Created : $Date_and_Time : Sanjay Rai\n\n";
while (<FP_JTAG_HDL_FILE>) {
    print fp;
}
close fp;
close FP_JTAG_HDL_FILE;

open FP_INPUT_VERILOG_FILE, "<$input_verilog_file" or die "Cannot Open $input_verilog_file file for reading : $! $ERROR_MSG";
$start_extracting = 0;
while (<FP_INPUT_VERILOG_FILE>) {
    if ( /module\s*\b$module_name\b/i ) {
        $start_extracting = 1;
    }
    if ($start_extracting == 1) {
        if (/\b\);/) {
            $start_extracting = 0;
        }
    }
    if ($start_extracting == 1) {
        if (/(^\s*input\b|^\s*output\b)/) {
            s/=.*//; # Delete init values
            s/\breg\b//; # Delete reg 
            s/\bwire\b//; # Delete reg 
            s/^\s*//g;#delete leading spaces
            s/\s+/ /g; # Convert multiple spaces to single
            s/,.*$//g; # only one input/output per line remove everything else
            s/\/\/.*$//g; # Remove all inlinen comments
            s/\s*?$//; #remove trailing spaces
            chomp;
            push(@comp_fields, $_);
        }
    }
}
close FP_INPUT_VERILOG_FILE;


# Generate Component instation and determine number of INPUT and OUTPUT
# Create a List variable with this info. but writing to the actual VHDL file happens later

$jtag_out_reg_sz = 0;
$jtag_in_reg_sz = 0;
$number_of_inputs = 0;
$number_of_outputs = 0;
foreach $comp_field (@comp_fields) {
    $IO_PORT_FOUND = 0;
    my @tags_val = split(' ', $comp_field);
    $tags_val[0] =~ s/^\s*//; 
    $tags_val[0] =~ s/\s*$//; 

    $IO_PORT_IS_TOP_LEVEL = 0;
    foreach $io_port (@io_ports) {
        if ($io_port eq $tags_val[$#tags_val]) {
            $IO_PORT_IS_TOP_LEVEL = 1;
        }
    }

    if ( $tags_val[0] eq "input") {
        if ($#tags_val > 1) {
            $vec = $tags_val[1];
            $vec =~ s/\[//;
            $vec =~ s/\]//;
            $vec =~ s/\s*//;
            $vec =~ /(\d+):(\d+)/;
            $vec = abs($1 - $2) + 1;
            $port_input_object_size{$tags_val[2]} = $vec;
            if ($IO_PORT_IS_TOP_LEVEL == 1) {
                $port_input_toplevel_object_size{$tags_val[2]} = $vec;
                $port_input_toplevel_object_type{$tags_val[2]} = 1;
            } else {
                $jtag_in_reg_sz += $vec;
                $port_input_toplevel_object_type{$tags_val[2]} = 0;
            }
        } else {
            $port_input_object_size{$tags_val[1]} = 0;
            if ($IO_PORT_IS_TOP_LEVEL == 1) {
                $port_input_toplevel_object_size{$tags_val[1]} = 0;
                $port_input_toplevel_object_type{$tags_val[1]} = 1;
            } else {
                $jtag_in_reg_sz ++;
                $port_input_toplevel_object_type{$tags_val[1]} = 0;
            }
        }
    } elsif ( $tags_val[0] eq "output") {
        if ($#tags_val > 1) {
            $vec = $tags_val[1];
            $vec =~ s/\[//;
            $vec =~ s/\]//;
            $vec =~ s/\s*//;
            $vec =~ /(\d+):(\d+)/;
            $vec = abs($1 - $2) + 1;
            $port_output_object_size{$tags_val[2]} = $vec;
            if ($IO_PORT_IS_TOP_LEVEL == 1) {
                $port_output_toplevel_object_size{$tags_val[2]} = $vec;
                $port_output_toplevel_object_type{$tags_val[2]} = 1;
            } else {
                $jtag_out_reg_sz += $vec;
                $port_output_toplevel_object_type{$tags_val[2]} = 0;
            }
        } else {
            $port_output_object_size{$tags_val[1]} = 0;
            if ($IO_PORT_IS_TOP_LEVEL == 1) {
                $port_output_toplevel_object_size{$tags_val[1]} = 0;
                $port_output_toplevel_object_type{$tags_val[1]} = 1;
            } else {
                $jtag_out_reg_sz ++;
                $port_output_toplevel_object_type{$tags_val[1]} = 0;
            }
        }
    }
}

$JTAG_INPUT_REGISTER_SIZE = $jtag_in_reg_sz;
$JTAG_OUTPUT_REGISTER_SIZE = $jtag_out_reg_sz;
$jtag_in_reg_sz--;
$jtag_out_reg_sz--;
print "\t******* Creating $IP_GEN_V_file ********\n";
open FP_IP_GEN_V_FILE, ">$IP_GEN_V_file" or die "Cannot Open $IP_GEN_V_file for writing : $! $ERROR_MSG"; 

print FP_IP_GEN_V_FILE "// Created : $Date_and_Time : Sanjay Rai\n\n";
print FP_IP_GEN_V_FILE "module $ip_gen_top_module\n";
print FP_IP_GEN_V_FILE "\(\n";
while (($key, $val) = each(%port_input_toplevel_object_size)) {
    if ($val == 0) {
        print FP_IP_GEN_V_FILE "\tinput $key,\n";
    } else {
        $tmp_vec_sz = ($val-1);
        print FP_IP_GEN_V_FILE "\tinput [$tmp_vec_sz:0] $key,\n";
    }
}

while (($key, $val) = each(%port_output_toplevel_object_size)) {
    if ($val == 0) {
        print FP_IP_GEN_V_FILE "\toutput $key,\n";
    } else {
        $tmp_vec_sz = ($val-1);
        print FP_IP_GEN_V_FILE "\toutput [$tmp_vec_sz:0] $key,\n";
    }
}
print FP_IP_GEN_V_FILE "\tinput TCK,\n";
print FP_IP_GEN_V_FILE "\tinput shift_i,\n";
print FP_IP_GEN_V_FILE "\tinput shift_o,\n";
print FP_IP_GEN_V_FILE "\tinput iTDI,\n";
print FP_IP_GEN_V_FILE "\toutput oTDO\n";
print FP_IP_GEN_V_FILE "\);\n\n";
print FP_IP_GEN_V_FILE "wire [$jtag_in_reg_sz:0] JTAG_IN_REG;\n";
print FP_IP_GEN_V_FILE "wire [$jtag_out_reg_sz:0] JTAG_OUT_REG;\n\n"; 

print FP_IP_GEN_V_FILE "$module_name u_ip \(\n";

while (($key, $val) = each(%port_input_object_size)) {
    if($port_input_toplevel_object_type{$key} == 0) {
        if ($val == 0) {
            print FP_IP_GEN_V_FILE "\t.$key\(JTAG_IN_REG[$jtag_in_reg_sz]\),\n";
            $jtag_in_reg_sz--;
        } else {
            $vec_start_sz = $jtag_in_reg_sz;
            $jtag_in_reg_sz = $jtag_in_reg_sz - $val;
            $vec_end_sz = $jtag_in_reg_sz + 1;
            print FP_IP_GEN_V_FILE "\t.$key\(JTAG_IN_REG[$vec_start_sz:$vec_end_sz]\),\n";
        }
    } else {
        print FP_IP_GEN_V_FILE "\t.$key\($key\),\n";
    }
}
$size_of_port_output_object_size = keys(%port_output_object_size);
$output_port_num = 0;
while (($key, $val) = each(%port_output_object_size)) {
    $output_port_num++;
    if($port_output_toplevel_object_type{$key} == 0) {
        if ($val == 0) {
            if ($output_port_num == $size_of_port_output_object_size) {
                print FP_IP_GEN_V_FILE "\t.$key\(JTAG_OUT_REG[$jtag_out_reg_sz]\)\);\n\n";
            } else {
                print FP_IP_GEN_V_FILE "\t.$key\(JTAG_OUT_REG[$jtag_out_reg_sz]\),\n";
            }
            $jtag_out_reg_sz--;
        } else {
            $vec_start_sz = $jtag_out_reg_sz;
            $jtag_out_reg_sz = $jtag_out_reg_sz - $val;
            $vec_end_sz = $jtag_out_reg_sz +1 ;
            if ($output_port_num == $size_of_port_output_object_size) {
                print FP_IP_GEN_V_FILE "\t.$key\(JTAG_OUT_REG[$vec_start_sz:$vec_end_sz]\)\);\n\n";
            } else {
                print FP_IP_GEN_V_FILE "\t.$key\(JTAG_OUT_REG[$vec_start_sz:$vec_end_sz]\),\n";
            }
        }
    } else {
        if ($output_port_num == $size_of_port_output_object_size) {
            print FP_IP_GEN_V_FILE "\t.$key\($key\)\);\n\n";
        } else {
            print FP_IP_GEN_V_FILE "\t.$key\($key\),\n";
        }
    }
}

print FP_IP_GEN_V_FILE "jtag_user_reg_io # \(\n";
print FP_IP_GEN_V_FILE "\t.WIDTH_IN\($JTAG_INPUT_REGISTER_SIZE\),\n";
print FP_IP_GEN_V_FILE "\t.WIDTH_OUT\($JTAG_OUTPUT_REGISTER_SIZE\)\)\n";
print FP_IP_GEN_V_FILE "u_jtag_user_reg_io \(\n";
print FP_IP_GEN_V_FILE "\t.TCK\(TCK\),\n";
print FP_IP_GEN_V_FILE "\t.shift_i\(shift_i\),\n";
print FP_IP_GEN_V_FILE "\t.shift_o\(shift_o\),\n";
print FP_IP_GEN_V_FILE "\t.iTDI\(iTDI\),\n";
print FP_IP_GEN_V_FILE "\t.oTDO\(oTDO\),\n";
print FP_IP_GEN_V_FILE "\t.jtag_in_reg\(JTAG_IN_REG\),\n";
print FP_IP_GEN_V_FILE "\t.jtag_out_reg\(JTAG_OUT_REG\)\);\n";
print FP_IP_GEN_V_FILE "\nendmodule\n";
close FP_IP_GEN_V_FILE;


print "\t******* Creating $IP_GEN_TOP_UCF_file ********\n";
# Create Project file (prj file) for XST
open FP_IP_GEN_TOP_UCF, ">$IP_GEN_TOP_UCF_file" or die "Cannot Open $IP_GEN_TOP_UCF_file for writing : $!"; 
print FP_IP_GEN_TOP_UCF "SYSTEM_JITTER = 300 ps;\n\n";
print FP_IP_GEN_TOP_UCF "NET \"TCK\" TNM_NET = \"TCK\";\n\n";
print FP_IP_GEN_TOP_UCF "TIMESPEC \"TS_iTCK\" = FROM \"TCK\"  4 ns DATAPATHONLY;\n";
print FP_IP_GEN_TOP_UCF "TIMESPEC \"TS_oTCK\" = TO \"TCK\" 4 ns DATAPATHONLY;\n\n";

print FP_IP_GEN_TOP_UCF "INST \"u_jtag_user_reg_io\/jtag_in_reg_i*\" AREA_GROUP = \"AG_U_JTAG_USER_REG_i\";\n";
print FP_IP_GEN_TOP_UCF "INST \"u_jtag_user_reg_io\/jtag_out_reg_i*\" AREA_GROUP = \"AG_U_JTAG_USER_REG_o\";\n";
print FP_IP_GEN_TOP_UCF "\nINST \"u_ip\" AREA_GROUP = \"AG_U_IP_GEN\";\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=SLICE_X22Y66:SLICE_X33Y78;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=DSP48_X0Y0:DSP48_X0Y31;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" RANGE=RAMB36_X1Y0:RAMB36_X1Y15;\n";

print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" GROUP=CLOSED;\n";
print FP_IP_GEN_TOP_UCF "#AREA_GROUP \"AG_U_IP_GEN\" PLACE=CLOSED;\n\n";


close FP_IP_GEN_TOP_UCF;


print "\t******* Creating $IP_GEN_TOP_XDC_file ********\n";
open FP_IP_GEN_TOP_XDC, ">$IP_GEN_TOP_XDC_file" or die "Cannot Open $IP_GEN_TOP_XDC_file for writing : $!"; 
print FP_IP_GEN_TOP_XDC "#set_system_jitter 300\n\n";
print FP_IP_GEN_TOP_XDC "set_clock_uncertainty -setup 100\n\n";

print FP_IP_GEN_TOP_XDC "create_clock -period 50.000 -name sys_clk [get_ports sys_clk]\n";
print FP_IP_GEN_TOP_XDC "set_false_path -from [get_ports {iTDI shift_i shift_o}]\n";
print FP_IP_GEN_TOP_XDC "set_false_path -to [get_ports {oTDO}]\n";
print FP_IP_GEN_TOP_XDC "create_clock -period 1000.000 -name TCK [get_ports TCK]\n";
print FP_IP_GEN_TOP_XDC "set_clock_groups -asynchronous -group [get_clocks TCK] -group [get_clocks sys_clk]\n";

close FP_IP_GEN_TOP_XDC;
