`timescale 1ns/100fs

module tb_<xproj_srai_design_name> ();

    localparam time PRD = 10;

    reg clk = 0;
    reg reset = 1;
    wire [7:0] count;

    always
    begin
        clk = #(PRD/2) ~clk ;
    end

    initial 
    begin
        $monitor ("At Time = %t, Count = %d", $time, count);
        reset = 1;
        reset = #(200*PRD) 0;
        #(200*PRD) $display("SImulation End!!");
    end

    <xproj_srai_design_name> UUT (
            .reset(reset),
            .clk(clk),
            .count(count)
        );


endmodule
