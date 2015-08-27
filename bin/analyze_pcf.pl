#!perl

$ERROR_MSG = "\n !ERROR\n \n Usage :\n \t analyze_pcf design_name.pcf TIME_GROUP_name\n\n";
if ($#ARGV < 1) {
    print $ERROR_MSG;
    exit(0);
} else {

    $PCF_FILE = $ARGV[0];
    $TIMEGRP_NAME = $ARGV[1];

    open (FP_pcf, "<$PCF_FILE") or die $!;

    $PRINT_LINE = 0;
    while (<FP_pcf>) {
        if (/^TIMEGRP\s$TIMEGRP_NAME\s=\s/) {
            $PRINT_LINE = 1;
        }
        if ($PRINT_LINE == 1) {
            if (/;$/) {
                $PRINT_LINE = 0;
            }
            s/^TIMEGRP\s$TIMEGRP_NAME\s=\s//;
            s/^\s+//;
            s/\bBEL\b//g;
            s/\bBEL\b//g;
            s/\bPIN\b//g;
            s/^\s+//;
            #s/\s+//g;
            s/;$//;
            s/"\s*"/ /g;
            s/"//g;
            @tmp_ary = split;
            push(@TIMEGRP_NAME, @tmp_ary);
        }
    }
            print "# Total Num of Elements = $#TIMEGRP_NAME\n";
            #print "select_objects -quiet [get_cells -quiet\\\n";
            print "highlight_objects -quiet -color yellow [get_cells -quiet\\\n";
            foreach $bel_name (@TIMEGRP_NAME) {
                print "$bel_name\\\n";
            }
            print "]\n";

    close (FP_pcf);
}
