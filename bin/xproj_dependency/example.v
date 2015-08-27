`timescale 1ns/100fs

//module test1_counter (clk, reset, count);
module <xproj_srai_design_name> ( input clk, reset,
                       output [7:0] count);

    reg [7:0] i_count = 53; //Init Value


    always @ (posedge clk)
    begin
        if (reset == 1) //Synchronous reset
        begin
            i_count <= 20;
        end
        else if (i_count < 255)
        begin
            i_count <= i_count + 1;
        end
        else
        begin
            i_count <= 0;
        end
    end

    assign count = i_count;

endmodule

        


