module SGDMAC_READER (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [48:0]              fetcher_reader_data_i,
    input  wire                     fetcher_valid_i,
    output reg                      fetcher_ready_o,

    output  wire    [3:0]           arid_o,
    output  wire    [31:0]          araddr_o,
    output  wire    [3:0]           arlen_o,
    output  wire    [2:0]           arsize_o,
    output  wire    [1:0]           arburst_o,
    output  wire                    arvalid_o,
    input   wire                    arready_i,

    input   wire    [31:0]          rdata_i,
    input   wire    [1:0]           rresp_i,
    input   wire                    rlast_i,
    input   wire                    rvalid_i,
    output  wire                    rready_o,

    output reg      [31:0]          fifo_wdata_o,
    output reg                      fifo_wren_o,
    input  wire                     fifo_full_i,

    output reg                      reader_done_o
);

    typedef enum logic [1:0] { IDLE, RREQ, READ } state_t;

    state_t state_reg;
    reg [31:0] desc_addr;
    reg [15:0] desc_len;
    reg arvalid, rready;

    logic [3:0] arlen;
    assign arlen = (desc_len >= 64) ? 4'hF : ((desc_len >> 2) - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg    <= IDLE;
            desc_addr <= 0;
            desc_len  <= 0;
        end else begin
            if (state_reg == IDLE && fetcher_valid_i) begin
                desc_addr <= fetcher_reader_data_i[48:17];
                desc_len  <= fetcher_reader_data_i[16:1];
                state_reg    <= RREQ;
            end else if (state_reg == RREQ && arready_i) begin
                desc_addr <= desc_addr + 64;
                state_reg    <= READ;
            end else if (state_reg == READ && rvalid_i && !fifo_full_i) begin
                if (rlast_i) begin
                    if (desc_len <= 64) begin
                        state_reg <= IDLE;
                    end else begin
                        desc_len <= desc_len - 64;
                        state_reg <= RREQ;
                    end
                end
            end
        end
    end

    always_comb begin
        fetcher_ready_o = (state_reg == IDLE);
        reader_done_o   = (state_reg == IDLE);
        arvalid     = (state_reg == RREQ);
        rready      = (state_reg == READ) && !fifo_full_i;

        fifo_wren_o     = 0;
        if (state_reg == READ && rvalid_i && !fifo_full_i) begin
            fifo_wdata_o = rdata_i;
            fifo_wren_o  = 1;
        end
    end

    assign arid_o    = 4'd1;
    assign araddr_o  = desc_addr;
    assign arlen_o   = arlen;
    assign arsize_o  = 3'b010;
    assign arburst_o = 2'b01;
    assign arvalid_o = arvalid;
    assign rready_o  = rready;

endmodule
