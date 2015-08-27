#!perl

$ERROR_MSG = "\n!ERROR\n\n Usage:\n\t config_prohibit_ucf_gen XMIN YMIN XMAX YMAX Xstride Ystride\n\n";

$XMIN = $ARGV[0];
$YMIN = $ARGV[1];
$XMAX = $ARGV[2];
$YMAX = $ARGV[3];
$Xstride = $ARGV[4];
$Ystride = $ARGV[5];


if ($#ARGV < 3) {
    print $ERROR_MSG;
    exit(0);
} else {
    print "XYmin($XMIN, $YMIN) : XYmax($XMAX, $YMAX) : $Xstride, $Ystride\n";
    if ( $XMIN >= $XMAX) {      
        print "ERROR : XMIN of $XMIN Should be less than XMAX of $XMAX !\n";
        exit(0);
    }
    if ( $YMIN >= $YMAX) {      
        print "ERROR : YMIN of $YMIN Should be less than YMAX of $YMAX !\n";
        exit(0);
    }
    for ( $x = $XMIN; $x < $XMAX; $x = $x + $Xstride) {
        $strng = "SLICE_X".$x."Y0:SLICE_X".$x."Y"."$YMAX;";
        print "CONFIG PROHIBIT = $strng\n"; 
    }
    for ($y = ($YMIN+$Ystride); $y < $YMAX; $y = $y + $Ystride) {
        $strng = "SLICE_X0Y".$y.":SLICE_X".$XMAX."Y"."$y;";
        print "CONFIG PROHIBIT = $strng\n"; 
    
    }


}
