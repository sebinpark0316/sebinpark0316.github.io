module SGDMAC_ARBITER
#(
    parameter DATA_SIZE = 32
)
(
    input  wire                   clk,
    input  wire                   rst_n,

    // output
    output reg                    dst_valid_o,
    input  wire                   dst_ready_i,
    output reg   [DATA_SIZE-1:0]  dst_data_o,

    // input
    input  wire                   data_reader_valid_i,
    output reg                    data_reader_ready_o,
    input  wire [DATA_SIZE-1:0]   data_reader_data_i,

    input  wire                   descriptor_valid_i,
    output reg                    descriptor_ready_o,
    input  wire [DATA_SIZE-1:0]   descriptor_data_i
);

    reg [3:0] last_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            last_data <= 4'd2;
        else if (dst_data_o != '0)
            last_data <= dst_data_o[DATA_SIZE-1 -: 4];
    end

    always @(*) begin
        dst_valid_o          = 1'b0;
        dst_data_o           = 1'b0;
        data_reader_ready_o  = 1'b0;
        descriptor_ready_o   = 1'b0;

        unique case (1'b1)
            (descriptor_valid_i && data_reader_valid_i): begin
                if (last_data == 4'd0) begin
                    dst_valid_o         = 1'b1;
                    dst_data_o          = descriptor_data_i;
                    descriptor_ready_o  = dst_ready_i;
                end
                else if (last_data == 4'd1) begin
                    dst_valid_o         = 1'b1;
                    dst_data_o          = data_reader_data_i;
                    data_reader_ready_o = dst_ready_i;
                end
            end

            descriptor_valid_i: begin
                dst_valid_o         = 1'b1;
                dst_data_o          = descriptor_data_i;
                descriptor_ready_o  = dst_ready_i;
            end

            data_reader_valid_i: begin
                dst_valid_o         = 1'b1;
                dst_data_o          = data_reader_data_i;
                data_reader_ready_o = dst_ready_i;
            end

            default: begin
                dst_valid_o         = 1'b0;
                dst_data_o          = 1'b0;
                data_reader_ready_o = 1'b0;
                descriptor_ready_o  = 1'b0;
            end
        endcase
    end

endmodule
