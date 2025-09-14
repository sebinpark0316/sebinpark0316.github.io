module TLP_buffer (
input logic [223:0] tlp_data_i, // TLP 데이터
input logic tlp_data_valid_i, // TLP 데이터 유효 신호
input logic clk,
input logic rst_n,
output logic [223:0] tlp_data
);



always_ff @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
// 리셋 시 출력 초기화
tlp_data <= 224'b0;
end else if (tlp_data_valid_i) begin
// 유효한 데이터가 들어오면 출력에 저장

tlp_data <= tlp_data_i;
end
end

endmodule