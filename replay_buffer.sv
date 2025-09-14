module replay_buffer (
    input   logic         clk,                  // 클록
    input   logic         rst_n,                // 리셋
    input logic [31:0] dllp_i,
    input logic dllp_valid_i,
    input   logic [267:0] link_packet,          // 입력 TLP
    output  logic [267:0] tlp_data_o,         // 출력 TLP
    output logic comp

);

    logic [267:0] buffer;  // 내부 버퍼 (268비트 크기)


// TLP 데이터와 버퍼를 관리하는 always_ff 블록
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buffer <= 268'b0;          // 리셋 시 버퍼 초기화
        tlp_data_o <= 268'b0;      // TLP 출력 초기화
    end else begin
        if (dllp_valid_i) begin
            if (dllp_i[31:24] == 8'h00) begin
                // 새로운 TLP를 버퍼에 저장하고 출력
                buffer <= link_packet;    
                tlp_data_o <= link_packet; 
            end else if (dllp_i[31:24] == 8'h10) begin
                // 기존 버퍼의 TLP를 출력
                tlp_data_o <= buffer;     
            end
        end
    end
end

// comp 로직을 독립적으로 관리하는 always_comb 블록
always_comb  begin
    // 기본값 설정
    comp = 1'b0;

    // tlp_data_o가 유효한 값일 때만 comp를 활성화
    if (link_packet != 268'b0) begin
        comp = 1'b1;
    end
end


endmodule