/*
 ===============================================================================================
 *                           Copyright (C) 2023-2026 andkorzh
 *
 *
 *                This program is free software; you can redistribute it and/or
 *                modify it under the terms of the GNU General Public License
 *                as published by the Free Software Foundation; either version 2
 *                of the License, or (at your option) any later version.
 *
 *                This program is distributed in the hope that it will be useful,
 *                but WITHOUT ANY WARRANTY; without even the implied warranty of
 *                MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *                GNU General Public License for more details.
 *
 *                                FPGA  DENDY (Cyclone II)
 *
 *   This design is inspired by Wiki BREAKNES. I tried to replicate the design of the real
 * NMOS processor MOS 6502 as much as possible. The Logsim 6502 model was taken as the basis
 * for the design of the circuit diagram
 *
 *  author andkorzh
 *  Thanks:
 *      HardWareMan: author of the concept of synchronously core NES PPU, help & support.
 *
 *      Org (ogamespec): help & support, C++ Cycle accurate model NES, Author: Wiki BREAKNES
 *          
 *      Nukeykt: help & support
 *
 ===============================================================================================
*/

module FPGA_DENDY(
// Clocks
input N_CLK,            // Clock 14.318 MHz for NTSC
input P_CLK,            // Clock 17.734 MHz for PAL (DENDY)
// Inputs
input MODE_IN,          // PAL mode
input DENDY_IN,         // DENDY mode
input RES,              // Reset
input IRQ,              // Interrupt request input
input J1D,              // Joy 1 data
input J2D,              // Joy 2 data
input nVRAMA10,         // VRAM Mirroring mode
input VRAMCS,           // VRAM enble (CIRAM_CE)
// Outputs
inout [7:0]DBUS,        // Data bus
output M2,              // M2 Cycle
output RnW,             // Read/Write
output DB_DIR,          // DATA BUS LEVEL SHIFTER CONTROL
output reg nROMSEL,     // Cartridge ROM select
output [14:0]AB,        // Address BUS
output DPCM_PWM,        // DMC PWM output
output [5:0]So,         // SQA + SQB + TRIA + RND output
output LE,              // Write peripheral port $4016 bit [0]
output SCK1,            // Joy 1 clock
output SCK2,            // Joy 2 clock
output nRD,             // VRAM (CHR ROM) Read Strobe
output nWR,             // VRAM          Write Strobe
output ALE,             // ALE VRAM Address Low Byte Latch Strobe Output
output PD_DIR,          // PD BUS LEVEL SHIFTER CONTROL
inout  [7:0]PD_BUS,     // PPU Graphics Data Bus Input
output [13:8]PA,        // WRAM (CHR ROM) Address
output [17:0]RGB,       // RGB output R6 + G6 + B6
output [2:0]EMPH,       // EMPHASIS R G B
output SYNC             // Composite sync output
);

// Module connections
wire Clk;
wire Clk2;
wire [15:0]ADR;
wire [3:0]SQA, SQB, RND, TRIA;
wire [6:0]DMC;
wire [1:0]nIN;
wire [2:0]OUT;
wire nR4015;
wire PPU_INT;
wire [13:0]PAo;
wire HSYNC;
wire VSYNC;
wire SUBCLK;

// Variables
reg nWRAMCS, nPPU_CE;
reg [9:0]ALE_REG;
// Combinatorics
assign DB_DIR = nIN[0] & nIN[1] & nWRAMCS & nPPU_CE & nR4015 & RnW;
assign AB[14:0] = ADR[14:0];
// Joystick port
assign LE      =  OUT[0];
assign SCK1    = ~nIN[0] ? ~M2 : 1'hZ;
assign SCK2    = ~nIN[1] ? ~M2 : 1'hZ;
assign DBUS[0] = ~nIN[0] ? J1D : 1'hZ;
assign DBUS[0] = ~nIN[1] ? J2D : 1'hZ;

// PLL
PLL MOD_PLL(
 ~MODE_IN | ~DENDY_IN,
N_CLK,
P_CLK,
Clk,
Clk2
);
// APU
RP2A03 APU(
Clk2,
~MODE_IN,
~DENDY_IN,
~PPU_INT,
IRQ,
~RES,
DBUS[7:0],
DBUS[7:0],
ADR[15:0],
RnW,
M2,
SQA[3:0],
SQB[3:0],
RND[3:0],
TRIA[3:0],
DMC[6:0],
So[5:0],
OUT[2:0],
nIN[1:0],
nR4015
);

wire [7:0]WRAMBUS;
//WRAM
//         address, clock,  data,           wren,             q
SRAM WRAM( ADR[10:0], Clk, DBUS[7:0], ~( RnW | nWRAMCS ), WRAMBUS[7:0] );
// Outputting WRAM values to the data bus
assign DBUS[7:0] = ~( ~RnW | nWRAMCS ) ? WRAMBUS[7:0] : 8'hZZ;

// DPCM Output
DMC_PWM DMCOut(
Clk2,
DMC[6:0],
DPCM_PWM
);


// PPU
RP2C02_LITE PPU(
Clk,
Clk2,
~MODE_IN,
~DENDY_IN,
1'b1,       // ODD_EN
1'b1,       // nRES
1'b0,       // PALSEL0
1'b0,       // PALSEL1
RnW,        // RnW
nPPU_CE,    // nDBE
ADR[2:0],   // AB Bus
VRAMCS ? VRAMBUS[7:0] : PD_BUS[7:0], // PD In
DBUS[7:0],
RGB[17:0],
EMPH[2:0],
PAo[13:0],
PPU_INT,    // INT
ALE,
nWR,
nRD,
SYNC,
HSYNC,
VSYNC,
SUBCLK
);

wire [7:0]VRAMBUS;
//VRAM
//                    address,        clock,  data,           wren,               q
SRAM VRAM({ ~nVRAMA10, ALE_REG[9:0]}, Clk,  PAo[7:0], ~( nWR | ~VRAMCS ) , VRAMBUS[7:0] );
assign PD_BUS[7:0] = nRD ? PAo[7:0] : 8'hZZ;
assign PA[13:8]    = PAo[13:8];
assign PD_DIR = nRD;

always @(posedge Clk)begin
                // Address decoder
                nROMSEL <= ~( M2 &  ADR[15] );
                nWRAMCS <=   ~M2 |  ADR[13] | ADR[14] | ADR[15];
                nPPU_CE <=   ~M2 | ~ADR[13] | ADR[14] | ADR[15];
                // ALE LATCH
                if (ALE) ALE_REG[9:0] <= PAo[9:0];
                      end
endmodule