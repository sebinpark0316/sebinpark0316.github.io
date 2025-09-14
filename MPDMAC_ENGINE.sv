// Copyright (c) 2024 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

module MPDMAC_ENGINE #(
    parameter MAX_MAT_WIDTH = 32
)
(
    input   wire                        clk,
    input   wire                        rst_n,

    // from TRDMAC_CFG(SFRs)
    input   wire    [31:0]              src_addr_i,
    input   wire    [31:0]              dst_addr_i,
    input   wire    [5:0]               mat_width_i,
    input   wire                        start_i,
    output  wire                        done_o,

    // AMBA AXI interface (AW channel)
    output  wire    [3:0]               awid_o,
    output  wire    [31:0]              awaddr_o,
    output  wire    [3:0]               awlen_o,
    output  wire    [2:0]               awsize_o,
    output  wire    [1:0]               awburst_o,
    output  wire                        awvalid_o,
    input   wire                        awready_i,

    // AMBA AXI interface (W channel)
    output  wire    [3:0]               wid_o,
    output  wire    [31:0]              wdata_o,
    output  wire    [3:0]               wstrb_o,
    output  wire                        wlast_o,
    output  wire                        wvalid_o,
    input   wire                        wready_i,

    // AMBA AXI interface (B channel)
    input   wire    [3:0]               bid_i,
    input   wire    [1:0]               bresp_i,
    input   wire                        bvalid_i,
    output  wire                        bready_o,

    // AMBA AXI interface (AR channel)
    output  wire    [3:0]               arid_o,
    output  wire    [31:0]              araddr_o,
    output  wire    [3:0]               arlen_o,
    output  wire    [2:0]               arsize_o,
    output  wire    [1:0]               arburst_o,
    output  wire                        arvalid_o,
    input   wire                        arready_i,

    // AMBA AXI interface (R channel)
    input   wire    [3:0]               rid_i,
    input   wire    [31:0]              rdata_i,
    input   wire    [1:0]               rresp_i,
    input   wire                        rlast_i,
    input   wire                        rvalid_i,
    output  wire                        rready_o
);
    //Design here
    localparam int BYTES_PER_ELEM = 4;
    localparam CNT_WIDTH = $clog2(MAX_MAT_WIDTH);
    
    // row, column position check functions for mirror padding
    function logic is_last_col(input logic [5:0] col, input logic [5:0] width);
            return col == (width - 1);
        endfunction
    function logic is_left_border(input logic [5:0] col);
        return col == 1;
    endfunction
    function logic is_padding_zone(input logic [5:0] col, input logic [5:0] width);
        return col > (width/2);
    endfunction
    function logic is_right_border_d2(input logic [5:0] col, input logic [5:0] width);
        return col == (width - 1);
    endfunction
    function logic is_raw_matrix(input logic [5:0] col, input logic [5:0] col2, input logic [5:0] width);
        return (col > 0) && (col2 < (width/2));
    endfunction
    function logic is_last_row(input logic [5:0] row, input logic [5:0] width);
        return row == (width + 3);
    endfunction
    
    // mnemonics for state values
    enum logic [1:0] {READ_IDLE, READ_REQ_ADDR, READ_RECV} rd_state, rd_state_n;
    enum logic [1:0] {WRITE_IDLE, WRITE_BURST_START, WRITE_TRAN} wr_state, wr_state_n;

    reg[31:0] src_addr, src_addr_n;
    reg[31:0] dst_addr, dst_addr_n;
    reg[3:0] wcnt, wcnt_n;
    reg arvalid, rready, awvalid, wvalid, wlast, done;

    // row and column pointer

    reg [CNT_WIDTH:0]  row_ptr, row_ptr_n;
    reg [CNT_WIDTH-1:0]  col_ptr, col_ptr_n;
    reg [CNT_WIDTH-1:0]  col_ptr_d1, col_ptr_d2;

    reg [31:0] pipe_data1, pipe_data2;

    // FIFO interface
    wire                        fifo_full,
                                fifo_empty;
    reg                         fifo_wren,
                                fifo_rden;
    wire [3:0]  fifo_cnt_o;
    wire [31:0] fifo_data_i;

    // Mirror padding address setup
    wire [31:0] row_stride = mat_width_i * BYTES_PER_ELEM;
    wire [31:0] back_two_rows = row_stride * 2; 
    wire[31:0] src_back_addr = src_addr - back_two_rows;
    wire row_end_back = (row_ptr_n == mat_width_i + 2);
    wire [31:0] half_row = mat_width_i * 2;

    //initial conditon and 4x4 matrix condition burst length
    wire is_short_burst = (rd_state == READ_IDLE) || 
                        ((row_ptr == mat_width_i + 2) && (mat_width_i == 4));

    // Sequential updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state   <= READ_IDLE;
            wr_state   <= WRITE_IDLE;
            src_addr <= 0;
            dst_addr <= 0;
            wcnt <= 0;
            row_ptr <= 0;
            col_ptr <= 0;
            pipe_data1 <= 0;
            pipe_data2 <= 0;
            col_ptr_d1 <= 0;
            col_ptr_d2 <= 0;
        end else begin
            rd_state <= rd_state_n;
            wr_state <= wr_state_n;
            src_addr <= src_addr_n;
            dst_addr <= dst_addr_n;
            wcnt       <= wcnt_n;
            row_ptr    <= row_ptr_n;
            col_ptr    <= col_ptr_n;
            pipe_data1 <= rdata_i;
            pipe_data2 <= pipe_data1;
            col_ptr_d1 <= col_ptr;
            col_ptr_d2 <= col_ptr_d1;
        end
    end

    // Read & write FSM combinational
    always_comb begin
        // defaults
        rd_state_n = rd_state;
        wr_state_n = wr_state;
        src_addr_n  = src_addr;
        dst_addr_n  = dst_addr;
        wcnt_n     = wcnt;
        row_ptr_n  = row_ptr;
        col_ptr_n  = col_ptr;
        arvalid = 0;
        rready = 0;
        awvalid = 0;
        wvalid = 0;
        wlast = 0;
        fifo_rden = 0;
        
        done = 0; 

        case (rd_state)
            READ_IDLE: begin
                if (start_i) begin
                    src_addr_n = src_addr_i + row_stride;
                    row_ptr_n   = 1;
                    rd_state_n  = READ_REQ_ADDR;
                end
            end
            READ_REQ_ADDR: begin
                arvalid = 1'b1;
                if (arready_i) begin
                    src_addr_n = src_addr + half_row;
                    rd_state_n = READ_RECV;
                end
            end
            READ_RECV: begin
                rready = 1'b1;
                if (rvalid_i) begin
                    col_ptr_n = col_ptr + 1;
                    if (is_last_col(col_ptr, mat_width_i)) begin
                        col_ptr_n = 0;
                        row_ptr_n = row_ptr_n + 1;
                        if (row_ptr_n == 2) src_addr_n = src_addr_i;
                        else if (row_end_back) src_addr_n =src_back_addr;
                    end
                    // next state on last beat
                    if (rlast_i) begin
                        rd_state_n = (is_last_row(row_ptr_n, mat_width_i)) ? READ_IDLE : READ_REQ_ADDR;
                    end
                end
            end
        endcase

        case(wr_state)
            WRITE_IDLE : begin
            done = 1;
            if(start_i) begin
                dst_addr_n = dst_addr_i;
                wr_state_n = WRITE_BURST_START;
            end
            end

            WRITE_BURST_START: begin
            if(fifo_cnt_o >0)begin 
                awvalid = 1;
                if (awready_i) begin       
                        dst_addr_n = dst_addr_n + 64;
                        wcnt_n = awlen_o;
                        wr_state_n = WRITE_TRAN;
                    end
                end
            end

            WRITE_TRAN: begin
            if(fifo_cnt_o > 0)begin
                    wvalid = 1;
                    wlast = (wcnt==4'd0);
                    if (wready_i) begin
                        fifo_rden = 1;
                        if (wlast) begin
                            if (is_last_row(row_ptr, mat_width_i)) begin
                                wr_state_n = WRITE_IDLE;
                                done = 1;
                            end
                            else begin
                                wr_state_n = WRITE_BURST_START;
                            end
                        end
                        else begin
                            wcnt_n = wcnt - 1;
                        end
                    end
                end
            end
        endcase
    end

    //Padding zone use rdata_i, else pipeline data used
    assign fifo_data_i = (is_left_border(col_ptr) || 
    is_last_col(col_ptr, mat_width_i) || 
    is_padding_zone(col_ptr_n, mat_width_i) ||
    is_right_border_d2(col_ptr_d2,mat_width_i)) ?rdata_i : pipe_data2;

    //In Raw, Padding zone write data if FIFO
    assign fifo_wren =(is_raw_matrix(col_ptr,col_ptr_d2,mat_width_i)||
    is_padding_zone(col_ptr,mat_width_i)||
    is_padding_zone(col_ptr_d1,mat_width_i)||
    is_padding_zone(col_ptr_n,mat_width_i))? 1: 0; 

    // FIFO instantiation
    MPDMAC_FIFO  pad_fifo (
        .clk(clk), .rst_n (rst_n), .full_o(fifo_full),
        .wren_i(fifo_wren), .wdata_i(fifo_data_i), .empty_o(fifo_empty),
        .rden_i(fifo_rden), .rdata_o(wdata_o), .counter_o (fifo_cnt_o)
    );


    // AXI output assignments
    assign  done_o = done;

    assign awid_o    = 4'd0;
    assign awaddr_o  = dst_addr;
    assign awlen_o   = is_short_burst ? 4'd3 : 4'd15;
    assign awsize_o = 3'b010; 
    assign awburst_o = 2'b01;
    assign awvalid_o = awvalid;

    assign wid_o     = 4'd0;
    assign wstrb_o   = 4'b1111;
    assign wlast_o   = wlast;
    assign wvalid_o  = wvalid;

    assign bready_o  = 1'b1;


    assign  arvalid_o = arvalid;
    assign  araddr_o  = src_addr;
    assign  arid_o = 4'd0;
    assign  arlen_o = (mat_width_i/2)-1;
    assign  arsize_o = 3'b010;   // 4 bytes per transfer
    assign  arburst_o = 2'b01;    // incremental

    assign rready_o  = rready;
endmodule