module SGDMAC_DESCRIPTOR_FETCHER
(
    input  wire                     clk,
    input  wire                     rst_n,       // active low

    // Configuration interface
    input  wire [31:0]              start_pointer_i,
    input  wire                     start_i,

    // AMBA AXI interface (AR channel)
    output  wire    [3:0]           arid_o,
    output  wire    [31:0]          araddr_o,
    output  wire    [3:0]           arlen_o,        
    output  wire    [2:0]           arsize_o,
    output  wire    [1:0]           arburst_o,
    output  wire                    arvalid_o,
    input   wire                    arready_i,

    // AMBA AXI interface (R channel)
    input   wire    [3:0]           rid_i,
    input   wire    [31:0]          rdata_i,
    input   wire    [1:0]           rresp_i,
    input   wire                    rlast_i,
    input   wire                    rvalid_i,
    output  wire                    rready_o,

    // WRITER, READER interface
    output  reg     [48:0]          fetcher_reader_data_o,   
    output  reg     [48:0]          fetcher_writer_data_o,      
    output  wire                    fetcher_valid_reader_o,
    output  wire                    fetcher_valid_writer_o,     
    input   wire                    fetcher_ready_reader_i,
    input   wire                    fetcher_ready_writer_i,   

    // Done flag
    output reg                      done_o
);

    typedef enum logic [1:0] {
        IDLE        = 2'd0,
        AR          = 2'd1,
        RDATA       = 2'd2
    } state_t;

    state_t                    state, next_state;

    reg     [1:0]              cnt, cnt_n;
    reg  [31:0]                desc_ptr, desc_ptr_n;
    reg  [3:0]                 count;

    reg                        rready;
    reg                        arvalid;

    wire                       fifo_full, fifo_empty;
    reg                        fifo_wren, fifo_rden;
    wire    [48:0]             fifo_rdata;



    reg                        fetcher_valid_reader_d;
    reg                        fetcher_valid_writer_d;
    reg    [48:0]              fetcher_writer_data;
    reg    [48:0]              fetcher_reader_data;

    reg                        fifo_none_reader;
    reg                        fifo_none_writer;
    reg                        fifo_empty_real;

    reg                        done;

    reg [31:0] desc_buf [0:3];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            desc_ptr        <= 32'd0;
            count        <= 4'd0;
            cnt          <= 2'd0;
            for (int i=0; i<4; i=i+1)
                desc_buf[i] <= 32'd0;
        end else begin
            state        <= next_state;
            desc_ptr        <= desc_ptr_n;
            cnt          <= cnt_n;
            if(state == RDATA && rvalid_i && rready_o) begin
                desc_buf[cnt] <= rdata_i;
            end
        end
    end

    always @(*) begin
        next_state   = state;
        desc_ptr_n      = desc_ptr;
        cnt_n        = cnt;

        rready       = 1'b0;
        fifo_wren    = 1'b0;
        done         = 1'b0;
        arvalid      = 1'b0;

        case (state)
            IDLE: begin  
                done  = 1'b1;
                if (start_i) begin
                    desc_ptr_n    = start_pointer_i;
                    next_state = AR;                
                end
            end

            AR: begin
                arvalid = 1'b1;                
                if (arready_i) begin
                    cnt_n      = 2'b00;
                    next_state = RDATA;
                end
            end

            RDATA: begin
                rready = 1'b1;
                if (rvalid_i && !fifo_full) begin
                    cnt_n = cnt + 1;
                    if (rlast_i) begin
                        fifo_wren = 1'b1;
                        desc_ptr_n   = rdata_i;
                        cnt_n     = 2'b00;
                        next_state = AR;
                        if(rdata_i == start_pointer_i) begin
                            next_state = IDLE;
                        end
                    end
                end
            end
        endcase
    end
    wire [48:0] packed_desc;
    assign packed_desc = {desc_buf[0][31:0], desc_buf[1][15:0], desc_buf[2][0]};

    SGDMAC_FIFO #(
        .DATA_WIDTH(49),
        .FIFO_DEPTH(16)
    ) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .full_o(fifo_full),
        .afull_o(),
        .wren_i(fifo_wren),
        .wdata_i(packed_desc),
        .empty_o(fifo_empty),
        .aempty_o(),
        .rden_i(fifo_rden),
        .rdata_o(fifo_rdata),
        .counter_o()
    );

    typedef enum logic [1:0] {
        DIDLE = 2'd0,
        DEMUX = 2'd1,
        WAIT  = 2'd2
    } state_d;
    state_d demux_state, demux_state_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            demux_state <= DIDLE;
        end else begin
            demux_state <= demux_state_n;
            if(demux_state_n == DEMUX) begin
                fetcher_reader_data <= fifo_rdata;
                fetcher_writer_data <= fifo_rdata;
            end
        end
    end

    always @(*) begin
        demux_state_n              = demux_state;
        fifo_rden                  = 1'b0;
        fetcher_valid_reader_d     = 1'b0;
        fetcher_valid_writer_d     = 1'b0;
        fifo_empty_real            = 1'b1;

        case (demux_state)
            DIDLE: begin
                if(!fifo_empty)
                    demux_state_n = DEMUX;
            end

            DEMUX: begin
                fifo_rden = 1'b1;
                if(!fetcher_reader_data[0]) begin
                    fetcher_valid_reader_d = 1'b1;
                    if(!fetcher_ready_reader_i)
                        demux_state_n = WAIT;
                    else
                        demux_state_n = DIDLE;
                end else begin
                    fetcher_valid_writer_d = 1'b1;
                    if(!fetcher_ready_writer_i)
                        demux_state_n = WAIT;
                    else
                        demux_state_n = DIDLE;
                end
            end

            WAIT: begin
                if(!fetcher_reader_data[0]) begin
                    fetcher_valid_reader_d = 1'b1;
                    if(!fetcher_ready_reader_i)
                        demux_state_n = WAIT;
                    else
                        demux_state_n = DIDLE;
                end else begin
                    fetcher_valid_writer_d = 1'b1;
                    if(!fetcher_ready_writer_i)
                        demux_state_n = WAIT;
                    else
                        demux_state_n = DIDLE;
                end
                if(fifo_empty)
                    fifo_empty_real = 1'b0;
            end
        endcase
    end

    assign  arid_o                  = 4'd0;
    assign  arlen_o                 = 4'd3;
    assign  arsize_o                = 3'b010;   
    assign  arburst_o               = 2'b01;
    assign  rready_o                = rready;
    assign  araddr_o                = desc_ptr;
    assign  arvalid_o               = arvalid;

    assign  fetcher_writer_data_o   = fetcher_writer_data;
    assign  fetcher_reader_data_o   = fetcher_reader_data;
    assign  fetcher_valid_reader_o  = fetcher_valid_reader_d;
    assign  fetcher_valid_writer_o  = fetcher_valid_writer_d;
    assign  done_o                  = done && fifo_empty && fifo_empty_real;

endmodule
