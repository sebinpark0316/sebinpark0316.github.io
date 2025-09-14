module SGDMAC_WRITER
#(
  parameter DATA_WIDTH   = 32,
  parameter ADDR_WIDTH   = 32
)
(
  input  wire                     clk,
  input  wire                     rst_n,

  input  wire [48:0]              fetcher_data_i,
  input  wire                     fetcher_valid_i,
  output logic                    fetcher_ready_o,
  input  wire                     fetcher_done_i,

  input  wire [DATA_WIDTH-1:0]    fifo_rdata_i,
  input  wire                     fifo_empty_i,
  output logic                    fifo_rden_o,
  input  wire                     fifo_aempty_i,
  input  wire  [8:0]              fifo_cnt_i,

  output logic [ADDR_WIDTH-1:0]   awaddr_o,
  output logic [3:0]              awlen_o,
  output logic [2:0]              awsize_o,
  output logic [1:0]              awburst_o,
  output logic                    awvalid_o,
  input  wire                     awready_i,

  output logic [DATA_WIDTH-1:0]   wdata_o,
  output logic [DATA_WIDTH/8-1:0] wstrb_o,
  output logic                    wlast_o,
  output logic                    wvalid_o,
  input  wire                     wready_i,

  input  wire                     bvalid_i,
  output logic                    bready_o,

  input  wire                     reader_done_i,
  output logic                    writer_done_o,
  input  wire                     start_i
);

  typedef enum logic [2:0] {
    IDLE   = 3'b000,
    WAIT   = 3'b001,
    AW     = 3'b010,
    WRITE  = 3'b011,
    BRESP  = 3'b100
  } state_t;

  state_t state, state_n;
  logic [31:0] desc_addr, desc_addr_n;
  logic [15:0] desc_len, desc_len_n;
  logic [3:0]  wcnt, wcnt_n;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      desc_addr   <= 0;
      desc_len    <= 0;
      wcnt        <= 0;
    end else begin
      state       <= state_n;
      desc_addr   <= desc_addr_n;
      desc_len    <= desc_len_n;
      wcnt        <= wcnt_n;
    end
  end

  always_comb begin
    state_n         = state;
    desc_addr_n     = desc_addr;
    desc_len_n      = desc_len;
    wcnt_n          = wcnt;

    fetcher_ready_o = 0;
    fifo_rden_o     = 0;

    awvalid_o       = 0;
    wvalid_o        = 0;
    wlast_o         = 0;
    writer_done_o   = 0;

    if (state == IDLE) begin
      writer_done_o = 1;
      if (start_i) begin
        state_n = WAIT;
      end
    end
    else if (state == WAIT) begin
      fetcher_ready_o = 1;
      if (fetcher_valid_i && (fetcher_data_i[16:1] != 0)) begin
        desc_addr_n = fetcher_data_i[48:17];
        desc_len_n  = fetcher_data_i[16:1];
        state_n     = AW;
      end
    end
    else if (state == AW) begin
      awvalid_o = 1;
      if (awready_i) begin
        desc_addr_n = desc_addr + 64;                       
        wcnt_n      = awlen_o;                               
        desc_len_n  = (desc_len >= 64) ? (desc_len - 64) : 0; 
        state_n     = WRITE;
      end
    end
    else if (state == WRITE) begin
      if (wcnt < fifo_cnt_i) begin
        wvalid_o = 1;
        wlast_o  = (wcnt == 0);
        if (wready_i) begin
          fifo_rden_o = 1;
          if (wlast_o) begin
            if (desc_len_n == 0) begin
              state_n = (fetcher_done_i && reader_done_i) ? BRESP : WAIT;
            end else begin
              state_n = AW;
            end
          end else begin
            wcnt_n = wcnt - 1;
          end
        end
      end
    end
    else if (state == BRESP) begin
      if (bvalid_i) begin
        state_n = IDLE;
      end
    end
    else begin
      state_n = IDLE;
    end
  end


  assign awaddr_o  = desc_addr;
  assign awlen_o   = (desc_len >= 64) ? 4'hF : (desc_len[5:2] - 1);
  assign awsize_o  = 3'b010;    
  assign awburst_o = 2'b01;   

  assign wdata_o   = fifo_rdata_i;
  assign wstrb_o   = {DATA_WIDTH/8{1'b1}}; 
  assign bready_o  = 1;

endmodule
