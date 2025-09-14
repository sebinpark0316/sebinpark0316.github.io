module RX_URP_PCIE_ARBITER #(
    N_MASTER = 2,              // Number of masters
    DATA_SIZE = 224            // Data size in bits
)(
    input   wire                clk,
    input   wire                rst_n, // Active low reset

    input   wire [N_MASTER-1:0]  src_valid_i,      // Valid signals from each master
    output  reg [N_MASTER-1:0]   src_ready_o,      // Ready signals for each master
    input   wire [DATA_SIZE-1:0] src_data_i [N_MASTER-1:0] , // Data inputs from each master

    output  reg                 dst_valid_o,       // Output valid signal to destination
    input   wire                dst_ready_i,       // Ready signal from destination
    output  reg [DATA_SIZE-1:0] dst_data_o         // Data output to destination
);

    // Internal signals to handle arbitration and selection
    reg [DATA_SIZE-1:0] selected_data;  // Data to send to destination
    reg selected_valid;                  // Valid signal for selected data

    // Arbiter logic for selecting which input to send based on priority
    always_comb begin
        selected_data = {DATA_SIZE{1'b0}}; // Default data is 0
        selected_valid = 1'b0;              // Default valid signal is 0

        // If VC1 (second master) is valid and ready, send VC1's data
        if (src_valid_i[1] && dst_ready_i) begin
            selected_data = src_data_i[1];
            selected_valid = 1'b1;
        end else if (src_valid_i[0] && dst_ready_i) begin
            // If VC1 is not valid or not ready, send VC0's data
            selected_data = src_data_i[0];
            selected_valid = 1'b1;
        end
    end

    // Update the output signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_valid_o <= 1'b0;
            dst_data_o  <= {DATA_SIZE{1'b0}};
        end else begin
            dst_valid_o <= selected_valid && dst_ready_i;
            dst_data_o  <= selected_data;
        end
    end

// Ready signal logic for each master (asynchronous)
    assign src_ready_o[1] = (selected_data == src_data_i[1]);
    assign src_ready_o[0] = (selected_data == src_data_i[0]);

endmodule