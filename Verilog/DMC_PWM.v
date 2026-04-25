module DMC_PWM(
input Clk,
input [6:0]CH,
output pwm
);
reg [6:0]pwm_ctr_puls;
assign pwm = ( pwm_ctr_puls[6:0] < CH[6:0]) ? 1'b0 : 1'b1;
always @(negedge Clk)begin
pwm_ctr_puls[6:0] <= pwm_ctr_puls[6:0] + 1'b1;
                      end
endmodule