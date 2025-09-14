module TLP_Sequence (
    input logic [267:0] tlp_data_i,   // TLP 데이터
    input logic tlp_data_valid_i,    // TLP 데이터 유효 신호
    input logic clk,                 // 클럭 신호
    input logic rst_n,               // 리셋 신호
    output logic [11:0] sequence_num // 상위 12비트 출력
);

    // 상위 12비트를 저장하는 레지스터
    logic [11:0] sequence_num_reg;         // 현재 클럭에서 저장
    logic [11:0] sequence_num_reg_delayed; // 1클럭 딜레이를 위한 레지스터

    // 비동기 리셋 및 클럭에 따라 동작
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sequence_num_reg <= 12'b0;  // 리셋 시 초기화
        end
        else if (tlp_data_valid_i) begin
            sequence_num_reg <= tlp_data_i[267:256]; // TLP 데이터의 상위 12비트를 저장
        end
    end

    // 1클럭 딜레이 후 sequence_num 출력
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sequence_num_reg_delayed <= 12'b0; // 리셋 시 초기화
        end else begin
            sequence_num_reg_delayed <= sequence_num_reg; // 1클럭 딜레이
        end
    end

    // sequence_num 출력
    assign sequence_num = sequence_num_reg_delayed; // 1 클럭 딜레이된 값을 출력

endmodule