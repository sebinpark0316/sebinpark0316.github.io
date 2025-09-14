module TLP_LCRC (
    input logic [267:0] tlp_data_i,   // TLP 데이터
    input logic tlp_data_valid_i,      // TLP 데이터 유효 신호
    input logic clk,                   // 클럭 신호
    input logic rst_n,                 // 리셋 신호
    output logic [31:0] LCRC           // LCRC 출력
);

    // LCRC 값을 저장하는 레지스터
    logic [31:0] LCRC_reg;             // 파이프라인 레지스터
    logic [31:0] LCRC_reg_delayed;     // 1클럭 딜레이를 위한 레지스터

    // 비동기 리셋 및 클럭에 따라 동작
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LCRC_reg <= 32'b0;  // 리셋 시 LCRC 값 초기화
        end
        else if (tlp_data_valid_i) begin
            LCRC_reg <= tlp_data_i[31:0]; // TLP 데이터의 하위 32비트를 LCRC_reg에 저장
        end
    end

    // 1클럭 딜레이 후 LCRC 출력
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LCRC_reg_delayed <= 32'b0;
        end else begin
            LCRC_reg_delayed <= LCRC_reg;  // 1클럭 딜레이
        end
    end

    // LCRC 출력
    assign LCRC = LCRC_reg_delayed;  // 1 클럭 딜레이 후 LCRC_reg 값을 출력

endmodule
