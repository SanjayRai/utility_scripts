// Created : 9:22:14, Tue Dec 13, 2011 : Sanjay Rai

module jtag_user_reg_io
#(
    parameter WIDTH_IN = 100,
    parameter WIDTH_OUT = 100
)
(
    input TCK,
    input iTDI,
    input shift_i,
    input shift_o,
    output oTDO,
    output [(WIDTH_IN-1):0] jtag_in_reg,
    input [(WIDTH_OUT-1):0] jtag_out_reg
);

reg [(WIDTH_OUT-1):0] user_o_reg = 0;
reg [(WIDTH_IN-1):0] user_i_reg = 0;
reg [(WIDTH_IN-1):0] jtag_in_reg_i = 0;
reg [(WIDTH_OUT-1):0] jtag_out_reg_i = 0;

always @ (posedge TCK)
begin
    jtag_in_reg_i <= user_i_reg;
    jtag_out_reg_i <= jtag_out_reg;
    if (shift_i)
    begin
        if (WIDTH_IN == 1)
            user_i_reg <= iTDI;
        else
            user_i_reg <= {user_i_reg[(WIDTH_IN-2):0], iTDI};
    end
end
assign jtag_in_reg = jtag_in_reg_i;

always @ (posedge TCK)
begin
    case(shift_o)
        1'b1 : user_o_reg <= {user_o_reg[(WIDTH_OUT-2):0], user_o_reg[(WIDTH_OUT-1)]};
        default: user_o_reg <= jtag_out_reg_i;
    endcase
end
assign oTDO = user_o_reg[(WIDTH_OUT-1)];


endmodule
