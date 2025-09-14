module ReLU  #(parameter dataWidth=16,weightIntWidth=4,IntWidthExtend=10) (
    input           clk,
    input   [2*dataWidth+IntWidthExtend-1:0]   x,
    output  reg [dataWidth-1:0]  out
);

always @(posedge clk)
begin
    if($signed(x) >= 0)
    begin
        if(|x[$left(x)-:weightIntWidth+IntWidthExtend+1]) // check whether the abs(value) is larger than 1. EEE3063, update it on your own
            out <= {1'b0,{(dataWidth-1){1'b1}}}; //positive saturate
        else
            out <=x[2*dataWidth-weightIntWidth-1-:dataWidth]; // EEE3063, update it on your own
    end
    else 
        out <= 0;      
end
endmodule