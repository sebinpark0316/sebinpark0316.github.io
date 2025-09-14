module AXI2APB_TOP #(
    parameter ADDR_WIDTH            = 32,
    parameter DATA_WIDTH            = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // AXI Write Address Channel
    input  wire                     awid_i,
    input  wire [ADDR_WIDTH-1:0]    awaddr_i,
    input  wire [3:0]               awlen_i,
    input  wire [2:0]               awsize_i,
    input  wire [1:0]               awburst_i,
    input  wire                     awvalid_i,
    output wire                     awready_o,

    // AXI Write Data Channel
    input  wire                     wid_i,
    input  wire [DATA_WIDTH-1:0]    wdata_i,
    input  wire [3:0]               wstrb_i,
    input  wire                     wlast_i,
    input  wire                     wvalid_i,
    output wire                     wready_o,

    // AXI Write Response Channel
    output wire                     bid_o,
    output wire [1:0]               bresp_o,
    output wire                     bvalid_o,
    input  wire                     bready_i,

    // AXI Read Address Channel
    input  wire                     arid_i,
    input  wire [ADDR_WIDTH-1:0]    araddr_i,
    input  wire [3:0]               arlen_i,
    input  wire [2:0]               arsize_i,
    input  wire [1:0]               arburst_i,
    input  wire                     arvalid_i,
    output wire                     arready_o,

    // AXI Read Data Channel
    output wire                     rid_o,
    output wire [DATA_WIDTH-1:0]    rdata_o,
    output wire [1:0]               rresp_o,
    output wire                     rlast_o,
    output wire                     rvalid_o,
    input  wire                     rready_i,

    // APB Master Interface
    output wire [ADDR_WIDTH-1:0]    paddr_o,
    output wire [DATA_WIDTH-1:0]    pwdata_o,
    output wire                     pwrite_o,
    output wire                     penable_o,
    output wire [1:0]               psel_o,
    input  wire [DATA_WIDTH-1:0]    prdata_i,
    input  wire                     pready_i,
    input  wire                     pslverr_i
);

    // fill your code.
// Address decoder
    function automatic [1:0] sel (input [ADDR_WIDTH-1:0] a);
        case (a[31:12])
            20'h0001F: sel = 2'b01;
            20'h0002F: sel = 2'b10;
            default  : sel = 2'b00;
        endcase
    endfunction

    // FIFO instances
    localparam FIFO_DEPTH_LG2 = 4;
    logic wf_wr,wf_rd,wf_full,wf_empty; logic [31:0] wf_rdata;
    logic rf_wr,rf_rd,rf_full,rf_empty; logic [31:0] rf_rdata;

    BRIDGE_FIFO #(FIFO_DEPTH_LG2, DATA_WIDTH) WF (clk, rst_n,
                                              wf_full, wf_wr, wdata_i,
                                              wf_empty, wf_rd, wf_rdata);
    BRIDGE_FIFO #(FIFO_DEPTH_LG2, DATA_WIDTH) RF (clk, rst_n,
                                              rf_full, rf_wr, prdata_i,
                                              rf_empty, rf_rd, rf_rdata);

    // FSM enums and regs
    typedef enum logic [1:0] {W_IDLE, W_SETUP, W_EN, W_RESP} wst_t;
    typedef enum logic [1:0] {R_IDLE, R_SETUP, R_WAIT} rst_t;

    wst_t w_state, w_state_n;
    rst_t r_state, r_state_n;

    logic [ADDR_WIDTH-1:0] w_addr, w_addr_n, r_addr, r_addr_n;
    logic [4:0] w_len, w_len_n, r_len, r_len_n;
    logic [1:0] w_type, w_type_n;

    logic [31:0] pwdata_reg, pwdata_next;

    // APB local mux
    logic [ADDR_WIDTH-1:0] w_paddr, r_paddr;
    logic [1:0] w_psel, r_psel;
    logic w_pen, r_pen, w_pwr, r_pwr;

    assign paddr_o   = (w_state != W_IDLE) ? w_paddr : r_paddr;
    assign psel_o    = (w_state != W_IDLE) ? w_psel  : r_psel;
    assign penable_o = (w_state != W_IDLE) ? w_pen   : r_pen;
    assign pwrite_o  = (w_state != W_IDLE) ? w_pwr   : r_pwr;
    assign pwdata_o  = (w_state == W_SETUP) ? pwdata_next : pwdata_reg;

    // Handshake
    wire aw_hs = awvalid_i && awready_o;
    wire write_on = (w_state != W_IDLE) || aw_hs;

    assign awready_o = (w_state == W_IDLE) && !wf_full;
    assign wready_o  = write_on && !wf_full;

    assign bid_o     = awid_i;
    assign bresp_o   = 2'b00;
    assign bvalid_o  = (w_state == W_RESP);

    assign arready_o = (r_state == R_IDLE) && (w_state == W_IDLE) && !rf_full;
    assign rid_o     = arid_i;
    assign rresp_o   = 2'b00;
    assign rvalid_o  = !rf_empty;
    assign rdata_o   = rf_rdata;
    assign rlast_o   = (r_len == 5'd1) && rvalid_o;

    assign wf_wr = wvalid_i & wready_o;
    assign rf_rd = rvalid_o & rready_i;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            w_state <= W_IDLE; w_addr <= 0; w_len <= 0; w_type <= 0;
            r_state <= R_IDLE; r_addr <= 0; r_len <= 0;
            pwdata_reg <= 0;
        end else begin
            w_state <= w_state_n; w_addr <= w_addr_n; w_len <= w_len_n; w_type <= w_type_n;
            r_state <= r_state_n; r_addr <= r_addr_n; r_len <= r_len_n;
            if (wf_rd) pwdata_reg <= wf_rdata;
        end
    end

    // Write FSM
    always_comb begin
        w_state_n=w_state; w_addr_n=w_addr; w_len_n=w_len; w_type_n=w_type;
        wf_rd=0; pwdata_next='0;
        w_paddr=w_addr; w_psel=sel(w_addr); w_pen=0; w_pwr=0;

        case (w_state)
            W_IDLE: if (aw_hs) begin
                        w_addr_n = awaddr_i;
                        w_len_n  = awlen_i + 1;
                        w_type_n = awburst_i;
                        w_state_n = W_SETUP;
                    end
            W_SETUP: if (!wf_empty) begin
                        w_pwr = 1;
                        wf_rd = 1;
                        pwdata_next = wf_rdata;
                        w_state_n = W_EN;
                     end
            W_EN: begin
                    w_pwr = 1; w_pen = 1;
                    if (pready_i) begin
                        if (w_len == 5'd1) begin
                            w_state_n = W_RESP;
                        end else begin
                            w_len_n = w_len - 1;
                            if (w_type == 2'b01) w_addr_n = w_addr + 4;
                            w_state_n = W_SETUP;
                        end
                    end
                  end
            W_RESP: if (bready_i) w_state_n = W_IDLE;
        endcase
    end

    // Read FSM
    always_comb begin
        r_state_n = r_state; r_addr_n = r_addr; r_len_n = r_len; rf_wr = 0;
        r_paddr = 0; r_psel = 0; r_pen = 0; r_pwr = 0;

        if (w_state == W_IDLE) begin
            case (r_state)
                R_IDLE: if (arvalid_i && arready_o) begin
                            r_addr_n = araddr_i;
                            r_len_n = arlen_i + 1;
                            r_state_n = R_SETUP;
                        end
                R_SETUP: begin
                            r_paddr = r_addr;
                            r_psel = sel(r_addr);
                            r_state_n = R_WAIT;
                         end
                R_WAIT: begin
                            r_paddr = r_addr;
                            r_psel = sel(r_addr);
                            r_pen = 1;
                            if (pready_i) begin
                                rf_wr = 1;
                                if (r_len == 5'd1) begin
                                    r_state_n = R_IDLE;
                                end else begin
                                    r_len_n = r_len - 1;
                                    if (arburst_i == 2'b01) r_addr_n = r_addr + 4;
                                    r_state_n = R_SETUP;
                                end
                            end
                         end
            endcase
        end
    end
    
endmodule
