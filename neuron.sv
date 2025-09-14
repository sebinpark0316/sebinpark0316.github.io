`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Created by Vipin Kizheppatt 
// Create Date: 13.11.2018 17:11:05
// Design Name: 
// Module Name: perceptron
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created 
// Additional Comments:
// Modified by Taewook Kang, May. 2024
//////////////////////////////////////////////////////////////////////////////////
//`define DEBUG
`include "include.v"

module neuron #(parameter layerNo=0,neuronNo=0,numWeight=784,dataWidth=16,sigmoidSize=5,weightIntWidth=1,
                actType="relu",biasFile="",weightFile="")(
    input           clk,
    input           rst,
    input [dataWidth-1:0]    myinput,
    input           myinputValid,
    input           weightValid,
    input           biasValid,
    input [31:0]    weightValue,
    input [31:0]    biasValue,
    input [31:0]    config_layer_num,
    input [31:0]    config_neuron_num,
    output[dataWidth-1:0]    out,
    output reg      outvalid   
    );
    
    parameter addressWidth = $clog2(numWeight);
    parameter IntWidthExtend = addressWidth;
    
    reg         wen;
    wire        ren;
    reg [addressWidth-1:0] w_addr;
    reg [addressWidth:0]   r_addr;//read address has to reach until numWeight hence width is 1 bit more
    reg [dataWidth-1:0]  w_in;
    wire signed [dataWidth-1:0] w_out;
    reg signed [2*dataWidth-1:0]  mul; 
    reg signed [2*dataWidth-1+IntWidthExtend:0]  sum;
    reg signed [2*dataWidth-1:0]  bias;
    reg [31:0]    biasReg[0:0];
    reg         weight_valid;
    reg         mult_valid;
    wire        mux_valid;
    reg         sigValid; 
    wire signed [2*dataWidth-1+IntWidthExtend:0] comboAdd;
    wire signed [2*dataWidth-1+IntWidthExtend:0] BiasAdd;
    reg  signed [dataWidth-1:0] myinputd;
    reg muxValid_d;
    reg muxValid_f;
    reg addr=0;
   //Loading weight values into the momory
    always @(posedge clk)
    begin
        if(rst)
        begin
            w_addr <= {addressWidth{1'b1}};
            wen <=0;
        end
        else if(weightValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
        begin
            w_in <= weightValue;
            w_addr <= w_addr + 1;
            wen <= 1;
        end
        else
            wen <= 0;
    end
	
    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    assign BiasAdd = bias + sum;
    assign ren = myinputValid;
    
	`ifdef pretrained
		initial
		begin
			$readmemb(biasFile,biasReg);
		end
		always @(posedge clk)
		begin
            bias <= {biasReg[addr][dataWidth-1:0],{dataWidth{1'b0}}};
        end
	`else
		always @(posedge clk)
		begin
			if(biasValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
			begin
				bias <= {biasValue[dataWidth-1:0],{dataWidth{1'b0}}};
			end
		end
	`endif
    
    
    always @(posedge clk)
    begin
        if(rst|outvalid)
            r_addr <= 0;
        else if(myinputValid)
            r_addr <= r_addr + 1;
    end
    
    always @(posedge clk)
    begin
        mul  <= myinputd * w_out;
    end
    
    
    always @(posedge clk)
    begin
        if(rst|outvalid)
            sum <= 0;
        else if((r_addr == numWeight) & muxValid_f) sum <= BiasAdd; 
        else if(mux_valid) sum <= comboAdd;
    end
    
    always @(posedge clk)
    begin
        if(rst) begin
            myinputd <= 0;
            weight_valid <=0;
            mult_valid <= 0;
            sigValid <= 0;
            outvalid <=0;
            muxValid_d <=0;
            muxValid_f <= 0;
        end
        else begin
            myinputd <= myinput;
            weight_valid <= myinputValid;
            mult_valid <= weight_valid;
            sigValid <= ((r_addr == numWeight) & muxValid_f) ? 1'b1 : 1'b0;
            outvalid <= sigValid;
            muxValid_d <= mux_valid;
            muxValid_f <= !mux_valid & muxValid_d;
    end
    
    
    //Instantiation of Memory for Weights
    Weight_Memory #(.numWeight(numWeight),.neuronNo(neuronNo),.layerNo(layerNo),.addressWidth(addressWidth),
                    .dataWidth(dataWidth),.weightFile(weightFile)) 
    WM(
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );
    
    
	generate
		if(actType == "sigmoid")
		begin:siginst
		//EEE3063: Need to put overflow handling here.
		//Instantiation of ROM for sigmoid
			Sig_ROM #(.inWidth(sigmoidSize),.dataWidth(dataWidth)) s1(
			.clk(clk),
			.x(sum[2*dataWidth-1-:sigmoidSize]),
			.out(out)
		);
		end
		else
		begin:ReLUinst
		  wire signed [2*dataWidth-1:0] sum_temp;
		  assign sum_temp = sum[2*dataWidth-1:0];
			ReLU #(.dataWidth(dataWidth),.weightIntWidth(weightIntWidth),.IntWidthExtend(IntWidthExtend)) s1 (
			.clk(clk),
			.x(sum),
			.out(out)
		);
		end
	endgenerate

    `ifdef DEBUG
    always @(posedge clk)
    begin
        if(outvalid)
            $display(neuronNo,,,,"%b",out);
    end
    `endif
endmodule
