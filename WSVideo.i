;@ ASM header for the SNK K1GE/K2GE Graphics Engine emulator
;@

#define HW_K2GE		(0)
#define HW_K1GE		(1)
#define NGP_COLOR	HW_K2GE
#define NGP_MONO	HW_K1GE


/** Game screen width in pixels */
#define GAME_WIDTH  (160)
/** Game screen height in pixels */
#define GAME_HEIGHT (152)

	geptr		.req r12
						;@ K2GE.s
	.struct 0
scanline:		.long 0		;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

k2GEState:					;@
k2GERegs:
kgeWinXPos:		.byte 0		;@ Window X-Position
kgeWinYPos:		.byte 0		;@ Window Y-Position
kgeWinXSize:	.byte 0		;@ Window X-Size
kgeWinYSize:	.byte 0		;@ Window Y-Size
kgeBGXScroll:	.byte 0,0	;@ Background X-Scroll
kgeBGYScroll:	.byte 0,0	;@ Background Y-Scroll
kgeFGXScroll:	.byte 0,0	;@ Foreground X-Scroll
kgeFGYScroll:	.byte 0,0	;@ Foreground Y-Scroll

kgeSprXOfs:		.byte 0
kgeSprYOfs:		.byte 0
kgeIrqEnable:	.byte 0
kgeRef:			.byte 0
kgeBGCol:		.byte 0
kgeBGPrio:		.byte 0
kgeLedEnable:	.byte 0
kgeLedBlink:	.byte 0
kgeMode:		.byte 0
kgeModeChange:	.byte 0

kgeLedOnOff:	.byte 0		;@ Bit 0, Led On/Off.
kgeModel:		.byte 0		;@ HW_K2GE / HW_K1GE.
//kgePadding1:	.space 1

ledCounter:		.long 0
windowData:		.long 0
k2GEStateSize:

frameIrqFunc:	.long 0		;@ V-Blank Irq
periodicIrqFunc:.long 0		;@ H-Blank Irq

dirtyTiles:		.space 4
gfxRAM:			.long 0		;@ 0x3000
sprRAM:			.long 0		;@ 0x0140
paletteMonoRAM:	.long 0		;@ 0x0020
paletteRAM:		.long 0		;@ 0x0200
gfxRAMSwap:		.long 0		;@ 0x3000
scrollBuff:		.long 0

k2GESize:

;@----------------------------------------------------------------------------

