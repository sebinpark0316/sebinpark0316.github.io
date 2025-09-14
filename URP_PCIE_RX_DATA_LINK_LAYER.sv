module URP_PCIE_RX_DATA_LINK_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,

    // TX interface     
    input   logic   [267:0]         tlp_data_i,
    input   logic                   tlp_data_valid_i,
    output  logic                   tlp_data_ready_o,

    output  logic   [31:0]          dllp_o,
    output  logic                   dllp_valid_o,
    input   logic                   dllp_ready_i,

    // Transaction layer interface
    output  logic   [223:0]         tlp_data_o,
    output  logic                   tlp_data_valid_o,
    input   logic                   tlp_data_ready_i
    
);

    
    // 내부 신호
    logic [31:0] CRC;
    logic [31:0] LCRC;
    logic [11:0] sequence_num;
    logic [11:0] NRS;
    logic comp;
    
    // CRC_check 모듈 인스턴스화
    CRC_check crc_check_inst (
        .tlp_data_i(tlp_data_i),  // TLP 데이터
        .tlp_data_valid_i(tlp_data_valid_i), // 유효 신호
        .clk(clk),  // 클럭 신호
        .rst_n(rst_n),  // 리셋 신호
        .CRC(CRC)  // CRC 출력
    );

    // TLP_LCRC 모듈 인스턴스화
    TLP_LCRC tlp_lcrc_inst (
        .tlp_data_i(tlp_data_i),  // TLP 데이터
        .tlp_data_valid_i(tlp_data_valid_i), // 유효 신호
        .clk(clk),  // 클럭 신호
        .rst_n(rst_n),  // 리셋 신호
        .LCRC(LCRC)  // LCRC 출력
    );
    
      // TLP_Sequence 모듈 인스턴스화
    TLP_Sequence tlp_sequence_inst (
        .tlp_data_i(tlp_data_i),        // TLP 데이터
        .tlp_data_valid_i(tlp_data_valid_i), // 데이터 유효 신호
        .clk(clk),                      // 클럭 신호
        .rst_n(rst_n),                  // 리셋 신호
        .sequence_num(sequence_num)     // 상위 12비트 출력
    );
    
        // TLP_Data 모듈 인스턴스화
    TLP_Data tlp_data_inst (
        .tlp_data_i(tlp_data_i),        // 입력 데이터
        .tlp_data_valid_i(tlp_data_valid_i), // 유효 신호
        .clk(clk),                      // 클럭 신호
        .rst_n(rst_n),  
         .CRC(CRC) ,
         .LCRC(LCRC),
          .sequence_num(sequence_num),
          .NRS(NRS),                // 리셋 신호
        .tlp_data_o(tlp_data_o), 
        .tlp_data_ready_i(tlp_data_ready_i),
        .comp(comp)          // 출력 데이터
    );
    logic [11:0] NRS_reg;


    // 동작 조건에 따라 NRS를 업데이트
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            NRS_reg <= 12'b0;
 // 리셋 시 NRS 값 초기화
        end
        else if (tlp_data_valid_i&& CRC!=12'b0) begin
            if ((CRC == LCRC) && (NRS_reg == sequence_num)) begin
                NRS_reg <= NRS_reg + 1'b1;  // 조건을 만족하면 NRS 값을 1 증가

            end
        end
    end

    // NRS 출력
    assign NRS = NRS_reg;
    
assign dllp_o = (!rst_n || !tlp_data_valid_i || !dllp_ready_i) ? 32'b0 : (
    (CRC != LCRC) ? {8'h10, 24'b0} : (
        (NRS < sequence_num) ? {8'h10, 24'b0} : {8'h00, 24'b0}
    )
);

assign tlp_data_valid_o = (rst_n && (CRC == LCRC) &&  (NRS >= sequence_num) && comp) ? 1'b1 : 1'b0;

assign tlp_data_ready_o = (rst_n && tlp_data_ready_i && comp ) ? 1'b1 : 1'b0;

assign dllp_valid_o = (rst_n && dllp_ready_i && (NRS >= sequence_num) && (CRC == LCRC)) ? 1'b1 : 1'b0;
endmodule


