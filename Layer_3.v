module Layer_3 #(parameter NN = 10,numWeight=30,dataWidth=16,layerNum=1,sigmoidSize=10,weightIntWidth=4,actType="relu")
    (
    input           clk,
    input           rst,
    input           weightValid,
    input           biasValid,
    input [31:0]    weightValue,
    input [31:0]    biasValue,
    input [31:0]    config_layer_num,
    input [31:0]    config_neuron_num,
    input           x_valid,
    input [dataWidth-1:0]    x_in,
    output [NN-1:0]     o_valid,
    output [NN*dataWidth-1:0]  x_out
    );
genvar i;
generate
    for(i = 0; i<NN; i = i+1) begin
            neuron #(.numWeight(numWeight),.layerNo(layerNum),.neuronNo(i),.dataWidth(dataWidth),.sigmoidSize(sigmoidSize),.weightIntWidth(weightIntWidth),.actType(actType),
            .weightFile($sformatf("w_3_%1d.mif", i)), .biasFile($sformatf("b_3_%1d.mif", i)))
            n(
            .clk(clk),
            .rst(rst),
            .myinput(x_in),
            .weightValid(weightValid),
            .biasValid(biasValid),
            .weightValue(weightValue),
            .biasValue(biasValue),
            .config_layer_num(config_layer_num),
            .config_neuron_num(config_neuron_num),
            .myinputValid(x_valid),
            .out(x_out[i*dataWidth+:dataWidth]),
            .outvalid(o_valid[i])
        );
    end
endgenerate
endmodule