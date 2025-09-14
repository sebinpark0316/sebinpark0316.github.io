module sequence_gen (
    input logic [223:0] tlp_data_i,       // TLP 데이터
    input logic         tlp_data_valid_i, // TLP 데이터 유효 신호
    input logic         clk,
    input logic         rst_n,
    output logic [11:0] sequence_num      // 순차번호
);

    // 내부 상태 저장 레지스터
    logic [11:0] sequence_reg;            // 순차번호 레지스터
    logic [223:0] prev_tlp_data;          // 이전 TLP 데이터 저장 레지스터
    logic [11:0] next_sequence;           // 계산된 다음 순차번호
    logic         first_tlp_received;     // 첫 번째 TLP 데이터 여부 플래그

    // 초기 플래그 상태 및 순차번호 업데이트 로직
    always_comb begin
        // 기본값 설정
        next_sequence = sequence_reg;

        if (tlp_data_valid_i && (prev_tlp_data != tlp_data_i)&&(tlp_data_i != 0)) begin
            if (first_tlp_received) begin
                if (sequence_reg == 12'd4095) begin
                    next_sequence = 12'b0; // 4095 이후 0으로 초기화
                end else begin
                    next_sequence = sequence_reg + 12'd1; // 순차번호 증가
                end
            end
        end
    end

    // 데이터와 상태 저장
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sequence_reg       <= 12'b0;        // 리셋 시 초기화
            prev_tlp_data      <= 224'b0;       // 리셋 시 이전 데이터 초기화
            first_tlp_received <= 1'b0;         // 첫 데이터 수신 여부 초기화
        end else begin
            sequence_reg <= next_sequence;      // 계산된 순차번호 저장

            if (tlp_data_valid_i) begin
                if (!first_tlp_received) begin
                    first_tlp_received <= 1'b1;  // 첫 TLP 수신 시 플래그 설정
                end
                prev_tlp_data <= tlp_data_i;    // 현재 데이터를 이전 데이터로 저장
            end
        end
    end

    // 순차번호 출력
    always_comb begin
        sequence_num = sequence_reg;
    end

endmodule