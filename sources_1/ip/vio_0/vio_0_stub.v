// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Sun Oct 11 17:17:58 2026
// Host        : maxi-HP-ENVY-15-Notebook-PC running 64-bit Ubuntu 26.04.1 LTS
// Command     : write_verilog -force -mode synth_stub {/home/maxi/Documentos/4B -
//               CLP/TP_Final/TP_Final_PWM_Sottile_Espinola/TP_Final_PWM_Sottile_Espinola.srcs/sources_1/ip/vio_0/vio_0_stub.v}
// Design      : vio_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2018.3" *)
module vio_0(clk, probe_in0, probe_out0)
/* synthesis syn_black_box black_box_pad_pin="clk,probe_in0[2:0],probe_out0[0:0]" */;
  input clk;
  input [2:0]probe_in0;
  output [0:0]probe_out0;
endmodule
