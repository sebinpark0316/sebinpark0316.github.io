module SGDMAC_CFG
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // AMBA APB interface
    input   wire                psel_i,
    input   wire                penable_i,
    input   wire    [11:0]      paddr_i,
    input   wire                pwrite_i,
    input   wire    [31:0]      pwdata_i,
    output  reg                 pready_o,
    output  reg     [31:0]      prdata_o,
    output  reg                 pslverr_o,

    // configuration registers
    output  reg     [31:0]      start_pointer_o,
    output  wire                start_o,
    input   wire                done_i
);
    reg     [31:0]              start_pointer;
    wire    wren                = psel_i & penable_i & pwrite_i;

    always @(posedge clk) begin
        if (!rst_n) begin
            start_pointer                <= 32'd0;

        end
        else if (wren) begin
            case (paddr_i)
                'h100: start_pointer     <= pwdata_i[31:0];
            endcase
        end
    end
    wire    start               = wren & (paddr_i=='h104) & pwdata_i[0];
    reg     [31:0]              rdata;

    always @(posedge clk) begin
        if (!rst_n) begin
            rdata               <= 32'd0;
        end
        else if (psel_i & !penable_i & !pwrite_i) begin
            case (paddr_i)
                'h0:   rdata            <= 32'h0101_2025;
                'h100: rdata            <= start_pointer;
                'h104: rdata            <= 32'd0;
                'h108: rdata            <= {31'd0, done_i};
                default: rdata          <= 32'd0;
            endcase
        end
    end

    assign  pready_o            = 1'b1;
    assign  prdata_o            = rdata;
    assign  pslverr_o           = 1'b0;

    assign  start_pointer_o     = start_pointer;
    assign  start_o             = start;

endmodule
