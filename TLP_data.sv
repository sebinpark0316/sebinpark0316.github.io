module TLP_Data (
    input logic [267:0] tlp_data_i,   // TLP 데이터
    input logic tlp_data_valid_i,    // TLP 데이터 유효 신호
    input logic clk,                 // 클럭 신호
    input logic rst_n,               // 리셋 신호
    input logic [31:0] CRC ,
    input logic [31:0]LCRC,
    input logic [11:0] sequence_num,
    input logic [11:0] NRS,
    input logic tlp_data_ready_i,
    output logic [223:0] tlp_data_o,    // 255~32비트 출
    output logic comp
);

    // 255~32비트를 저장하는 레지스터
    logic [223:0] tlp_data_reg;         // 현재 클럭에서 저장
    logic [223:0] tlp_data_reg_delayed; // 1클럭 딜레이를 위한 레지스터
    logic comp_reg;

    // 비동기 리셋 및 클럭에 따라 동작
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_data_reg <= 224'b0;  // 리셋 시 초기화
            comp_reg <=0;
        end
        else if (tlp_data_valid_i) begin
            tlp_data_reg <= tlp_data_i[255:32]; // TLP 데이터의 255~32비트를 저장
            comp_reg <=1'b1;
        end
    end

    // 1클럭 딜레이 후 tlp_data 출력
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_data_reg_delayed <= 224'b0; // 리셋 시 초기화
            comp<=1'b0;
        end else begin
            tlp_data_reg_delayed <= tlp_data_reg; // 1클럭 딜레이
            comp = comp_reg;
        end
    end

    // tlp_data 출력
// TLP 데이터 출력 (조건을 보다 명확히 설정)
assign tlp_data_o = (rst_n && tlp_data_valid_i&&tlp_data_ready_i) ? (
    (NRS == sequence_num && CRC == LCRC) ? tlp_data_reg_delayed : 224'b0
) : 224'b0;




endmodule