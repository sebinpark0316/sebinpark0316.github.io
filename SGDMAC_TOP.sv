module SGDMAC_TOP
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

    // AMBA AXI interface (AW channel)
    output  wire    [3:0]       awid_o,
    output  wire    [31:0]      awaddr_o,
    output  wire    [3:0]       awlen_o,
    output  wire    [2:0]       awsize_o,
    output  wire    [1:0]       awburst_o,
    output  wire                awvalid_o,
    input   wire                awready_i,

    // AMBA AXI interface (W channel)
    output  wire    [3:0]       wid_o,
    output  wire    [31:0]      wdata_o,
    output  wire    [3:0]       wstrb_o,
    output  wire                wlast_o,
    output  wire                wvalid_o,
    input   wire                wready_i,

    // AMBA AXI interface (B channel)
    input   wire    [3:0]       bid_i,
    input   wire    [1:0]       bresp_i,
    input   wire                bvalid_i,
    output  wire                bready_o,

    // AMBA AXI interface (AR channel)
    output  wire    [3:0]       arid_o,
    output  wire    [31:0]      araddr_o,
    output  wire    [3:0]       arlen_o,
    output  wire    [2:0]       arsize_o,
    output  wire    [1:0]       arburst_o,
    output  wire                arvalid_o,
    input   wire                arready_i,

    // AMBA AXI interface (R channel)
    input   wire    [3:0]       rid_i,
    input   wire    [31:0]      rdata_i,
    input   wire    [1:0]       rresp_i,
    input   wire                rlast_i,
    input   wire                rvalid_i,
    output  wire                rready_o
);

    wire    [31:0]              start_pointer;
    wire                        start;    

    wire        d_fifo_rden;
    wire        [31:0] d_fifo_rdata;
    wire        writer_done;
    wire        [8:0] fifo_cnt;

    wire [48:0]                     fetcher_writer_data;
    wire [48:0]                     fetcher_reader_data;
    wire                            fetcher_valid_r, fetcher_valid_w;
    wire                            fetcher_ready_r, fetcher_ready_w;
    wire                            fetcher_done;

    wire                            fetcher_arvalid, fetcher_rready, fetcher_arready;
    wire [3:0]                      fetcher_arid;
    wire [31:0]                     fetcher_araddr;
    wire [3:0]                      fetcher_arlen;
    wire [2:0]                      fetcher_arsize;
    wire [1:0]                      fetcher_arburst;


    wire [31:0] dr_fifo_wdata;
    wire        dr_fifo_wren;
    wire        reader_done;

    //reader(R)
    wire        r_arvalid, r_rready, r_arready;
    wire [3:0]  r_arid;
    wire [31:0] r_araddr;
    wire [3:0]  r_arlen;
    wire [2:0]  r_arsize;
    wire [1:0]  r_arburst;

    wire        data_fifo_full, data_fifo_empty, data_fifo_afull, data_fifo_aempty;
    SGDMAC_CFG u_cfg (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .psel_i                     (psel_i),
        .penable_i                  (penable_i),
        .paddr_i                    (paddr_i),
        .pwrite_i                   (pwrite_i),
        .pwdata_i                   (pwdata_i),
        .pready_o                   (pready_o),
        .prdata_o                   (prdata_o),
        .pslverr_o                  (pslverr_o),
        .start_pointer_o            (start_pointer),
        .start_o                    (start),
        .done_i                     (writer_done)
    );




      SGDMAC_DESCRIPTOR_FETCHER u_fetch (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .start_pointer_i             (start_pointer),
        .start_i                     (start),

        // AR
        .arid_o                      (fetcher_arid),
        .araddr_o                    (fetcher_araddr),
        .arlen_o                     (fetcher_arlen),
        .arsize_o                    (fetcher_arsize),
        .arburst_o                   (fetcher_arburst),
        .arvalid_o                   (fetcher_arvalid),
        .arready_i                   (fetcher_arready),

        // R
        .rid_i                       (rid_i),
        .rdata_i                     (rdata_i),
        .rresp_i                     (rresp_i),
        .rlast_i                     (rlast_i),
        .rvalid_i                    (rvalid_i),
        .rready_o                    (fetcher_rready),


        .fetcher_writer_data_o       (fetcher_writer_data),
        .fetcher_reader_data_o       (fetcher_reader_data),
        .fetcher_valid_reader_o      (fetcher_valid_r),
        .fetcher_valid_writer_o      (fetcher_valid_w),
        .fetcher_ready_reader_i      (fetcher_ready_r),
        .fetcher_ready_writer_i      (fetcher_ready_w),

        .done_o                      (fetcher_done)
    );



    SGDMAC_READER u_reader (
        .clk                    (clk),
        .rst_n                  (rst_n),

        .fetcher_reader_data_i                   (fetcher_reader_data),
        .fetcher_valid_i                         (fetcher_valid_r),
        .fetcher_ready_o                         (fetcher_ready_r),

        // AR
        .arid_o                 (r_arid),
        .araddr_o               (r_araddr),
        .arlen_o                (r_arlen),
        .arsize_o               (r_arsize),
        .arburst_o              (r_arburst),
        .arvalid_o              (r_arvalid),
        .arready_i              (r_arready),

        // R
        .rdata_i                (rdata_i),
        .rresp_i                (rresp_i),
        .rlast_i                (rlast_i),
        .rvalid_i               (rvalid_i),
        .rready_o               (r_rready),

        // FIFO write
        .fifo_wdata_o           (dr_fifo_wdata),
        .fifo_wren_o            (dr_fifo_wren),
        .fifo_full_i            (data_fifo_full),

        .reader_done_o          (reader_done)
    );




    SGDMAC_WRITER u_writer (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .fetcher_data_i         (fetcher_writer_data),
        .fetcher_valid_i        (fetcher_valid_w),
        .fetcher_ready_o        (fetcher_ready_w),
        .fetcher_done_i         (fetcher_done),
        // FIFO read
        .fifo_rdata_i           (d_fifo_rdata),
        .fifo_empty_i           (data_fifo_empty),
        .fifo_rden_o            (d_fifo_rden),
        .fifo_aempty_i          (data_fifo_aempty),
        .fifo_cnt_i             (fifo_cnt),
        // AW
        .awaddr_o               (awaddr_o),
        .awlen_o                (awlen_o),
        .awsize_o               (awsize_o),
        .awburst_o              (awburst_o),
        .awvalid_o              (awvalid_o),
        .awready_i              (awready_i),

        // W
        .wdata_o                (wdata_o),
        .wstrb_o                (wstrb_o),
        .wlast_o                (wlast_o),
        .wvalid_o               (wvalid_o),
        .wready_i               (wready_i),

        //B
        .bvalid_i               (bvalid_i),
        .bready_o               (bready_o),

        .reader_done_i          (reader_done),
        .writer_done_o          (writer_done),
        .start_i                (start)
    );


    SGDMAC_FIFO u_data_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .full_o   (data_fifo_full),
        .afull_o  (data_fifo_afull),
        .wren_i   (dr_fifo_wren),
        .wdata_i  (dr_fifo_wdata),
        .empty_o  (data_fifo_empty),
        .aempty_o (data_fifo_aempty),
        .rden_i   (d_fifo_rden),
        .rdata_o  (d_fifo_rdata),
        .counter_o (fifo_cnt)
    );


    SGDMAC_ARBITER  #(
        .DATA_SIZE              ($bits(arid_o)+$bits(araddr_o)+$bits(arlen_o)+$bits(arsize_o)+$bits(arburst_o))
    )   
    u_arbiter
    (
        .clk                    (clk),
        .rst_n                  (rst_n),

        .dst_valid_o            (arvalid_o),
        .dst_ready_i            (arready_i),
        .dst_data_o             ({arid_o, araddr_o, arlen_o, arsize_o, arburst_o}),

        .data_reader_valid_i    (r_arvalid),
        .data_reader_ready_o    (r_arready),
        .data_reader_data_i     ({r_arid, r_araddr, r_arlen, r_arsize, r_arburst}),

        .descriptor_valid_i     (fetcher_arvalid),
        .descriptor_ready_o     (fetcher_arready),
        .descriptor_data_i      ({fetcher_arid, fetcher_araddr, fetcher_arlen, fetcher_arsize, fetcher_arburst})
    );


    assign  rready_o                = (rid_i=='d0) ? fetcher_rready : r_rready;
endmodule
