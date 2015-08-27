#! perl

open (FP, "<partgen.txt") or die $!; 

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
        foreach $device_name (@device) {
            $XILINX_DEVICE[$i] = $device_name."-".$_;
            $i++;
        }
    }
}
close(FP);

$match = 0;
foreach $XILINX_DEVICE_NAME (@XILINX_DEVICE) {
    if (uc($XILINX_DEVICE_NAME) eq uc($ARGV[0])) {
        $match = 1;
    } 
}

if ($match) {
    print "Part match : $XILINX_DEVICE_NAME :: $ARGV[0]\n";
} else {
    print "Part mismatch $ARGV[0]\n";
}

