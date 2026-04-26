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
 *                                       FPGA  DENDY
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
// Такты
input N_CLK,           //
input P_CLK,           //
// Входы
input MODE_IN,         //
input DENDY_IN,        //
input RES,             //
input IRQ,             //
input J1D,             //
input J2D,             //
input nVRAMA10,        //
input VRAMCS,          //
// Выходы
inout [7:0]DBUS,       //
output M2_out,         //
output RnW_EXT,        //
output DB_DIR,         //
output nROMSEL,        //
output [14:0]A,        //
output DPCM_PWM,       //
output [5:0]So,        //
output LE,             //
output SCK1,           //
output SCK2,           //
output reg nRD_EXT,    //
output reg nWR_EXT,    //
output ALE,            //
output PD_DIR,         //
inout  [7:0]PD_BUS,    //
output [13:8]PA,       //
output [17:0]RGB,      //
output [2:0]EMPH,      //
output SYNC            //
);

// Связи модулей
wire Clk;
wire Clk2;
wire M2;
wire [15:0]ADR;
wire [3:0]SQA;
wire [3:0]SQB;
wire [3:0]RND;
wire [3:0]TRIA;
wire [6:0]DMC;
wire [1:0]nIN;
wire [2:0]OUT;
wire RnW;

wire PPU_INT;
wire nRD;
wire nWR;
wire PPU_REN;
wire [13:0]PAo;
wire HSYNC;
wire VSYNC;
wire SUBCLK;

// Переменные
reg [9:0]ALE_REG;

// Комбинаторика
assign A[14:0] = ADR[14:0];
assign DB_DIR = nIN[0] & nIN[1] & nWRAMCS & ~PPU_REN & RnW;
assign RnW_EXT = RnW;
assign M2_out = M2;
// Декодер адреса
wire nWRAMCS, nPPU_CE;
assign nROMSEL = ~( M2 &  ADR[15] );
assign nWRAMCS =   ~M2 |  ADR[13] | ADR[14] | ADR[15];
assign nPPU_CE =   ~M2 | ~ADR[13] | ADR[14] | ADR[15];
// Порты джойстиков
assign LE   = OUT[0];
assign SCK1    = ~nIN[0] ? ~M2 : 1'hZ;
assign SCK2    = ~nIN[1] ? ~M2 : 1'hZ;
assign DBUS[0] = ~nIN[0] ? J1D : 1'hZ;
assign DBUS[0] = ~nIN[1] ? J2D : 1'hZ;

wire PAL;
assign PAL =  ~MODE_IN | ~DENDY_IN;

PLL MOD_PLL(
PAL,
N_CLK,
P_CLK,
Clk,
Clk2
);

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
nIN[1:0]
);

wire [7:0]WRAMBUS;
//WRAM
//             address, clock,   data,         wren,               q
SRAM MOD_WRAM( A[10:0], Clk, DBUS[7:0], ~( RnW | nWRAMCS ), WRAMBUS[7:0] );
// Вывод значений WRAM на шину данных
assign DBUS[7:0] = ~( ~RnW | nWRAMCS ) ? WRAMBUS[7:0] : 8'hZZ;

// Вывод DPCM
DMC_PWM DMCOut(
Clk2,
DMC[6:0],
DPCM_PWM
);



RP2C02_LITE PPU(
Clk,
Clk2,
PAL,
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
SUBCLK,
PPU_REN
);


wire [7:0]VRAMBUS;
//VRAM
//                        address,        clock, data,           wren,               q
SRAM MOD_VRAM( { ~nVRAMA10, ALE_REG[9:0]}, Clk, PAo[7:0], ~( nWR | ~VRAMCS ) , VRAMBUS[7:0] );
assign PD_BUS[7:0] = nRD ? PAo[7:0] : 8'hZZ;
assign PA[13:8]    = PAo[13:8];
assign PD_DIR = nRD;


always @(posedge Clk)begin
                if (ALE) ALE_REG[9:0] <= PAo[9:0];

                nRD_EXT <= nRD;
                nWR_EXT <= nWR;
                      end
endmodule