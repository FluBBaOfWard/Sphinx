// SNK K2GE Graphics Engine emulation

#ifdef __arm__

#ifdef GBA
	#include "../Shared/gba_asm.h"
#elif NDS
	#include "../Shared/nds_asm.h"
#endif
#include "WSVideo.i"

	.global wsVideoInit
	.global wsVideoReset
	.global wsVideoSaveState
	.global wsVideoLoadState
	.global wsVideoGetStateSize
	.global k2GEConvertTiles
	.global wsvDoScanline
	.global copyScrollValues
	.global k2GEConvertTileMaps
	.global wsvConvertSprites
	.global k2GEConvertTiles
	.global k2GEBufferWindows
	.global k2GE_R
	.global wsvVCountR

	.global wsvDisplayControlW
	.global wsvSpriteTblAdrW
	.global wsvSpriteStartW
	.global wsvSpriteEndW
	.global wsvTileMapBaseW
	.global wsvBgScrXW
	.global wsvBgScrYW
	.global wsvFgScrXW
	.global wsvFgScrYW


	.syntax unified
	.arm

#if GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For anything else
#endif
	.align 2
;@----------------------------------------------------------------------------
wsVideoInit:					;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00			;@ Build chr decode tbl
	ldr r2,=CHR_DECODE			;@ 0x400
chrLutLoop:
	ands r0,r1,#0x01
	movne r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne chrLutLoop

	bx lr
;@----------------------------------------------------------------------------
wsVideoReset:		;@ r0=frameIrqFunc, r1=hIrqFunc, r2=ram+LUTs, r3=model, r12=geptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	mov r0,geptr
	ldr r1,=k2GESize/4
	bl memclr_					;@ Clear K2GE state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia geptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

	ldmfd sp!,{r0-r3,lr}
	cmp r0,#0
	adreq r0,dummyIrqFunc
	cmp r1,#0
	adreq r1,dummyIrqFunc
	str r0,[geptr,#frameIrqFunc]
	str r1,[geptr,#periodicIrqFunc]

	str r2,[geptr,#gfxRAM]
	add r0,r2,#0xFE00
	str r0,[geptr,#paletteRAM]
	add r2,r2,#0x3000
	str r2,[geptr,#sprRAM]
	add r2,r2,#0x140
	str r2,[geptr,#paletteMonoRAM]
	add r2,r2,#0x20
	str r2,[geptr,#paletteRAM]
	add r2,r2,#0x200
	str r2,[geptr,#gfxRAMSwap]
	ldr r0,=SCROLL_BUFF
	str r0,[geptr,#scrollBuff]

	strb r3,[geptr,#kgeModel]
	cmp r3,#HW_WS
	movne r0,#0x00				;@ Use Color mode.
	moveq r0,#0x80				;@ Use B&W mode.
	strb r0,[geptr,#kgeMode]

	b wsvRegistersReset

dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
wsvRegistersReset:
;@----------------------------------------------------------------------------
	mov r0,#0xC0
	strb r0,[geptr,#kgeIrqEnable]	;@ Both interrupts allowed
	mov r0,#0xC6
	strb r0,[geptr,#kgeRef]			;@ Refresh Rate value
	mov r0,#0xFF
	strb r0,[geptr,#kgeWinXSize]	;@ Window size
	strb r0,[geptr,#kgeWinYSize]
	mov r0,#0x80
	strb r0,[geptr,#kgeLedBlink]	;@ Flash cycle = 1.3s
	ldr r1,[geptr,#paletteMonoRAM]
	strb r0,[r1,#0x18]				;@ BGC on!

	bx lr
;@----------------------------------------------------------------------------
wsVideoSaveState:		;@ In r0=destination, r1=geptr. Out r0=state size.
	.type   wsVideoSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0					;@ Store destination
	mov r5,r1					;@ Store geptr (r1)

	ldr r1,[r5,#gfxRAM]
	ldr r2,=0x3360
	bl memcpy

	ldr r2,=0x3360
	add r0,r4,r2
	add r1,r5,#k2GEState
	mov r2,#(k2GEStateEnd-k2GEState)
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x3360+(k2GEStateEnd-k2GEState)
	bx lr
;@----------------------------------------------------------------------------
wsVideoLoadState:		;@ In r0=geptr, r1=source. Out r0=state size.
	.type   wsVideoLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store geptr (r0)
	mov r4,r1					;@ Store source

	ldr r0,[r5,#gfxRAM]
	ldr r2,=0x3360
	bl memcpy

	ldr r2,=0x3360
	add r0,r5,#k2GEState
	add r1,r4,r2
	mov r2,#(k2GEStateEnd-k2GEState)
	bl memcpy

	ldr r0,=DIRTYTILES
	mov r1,#0
	mov r2,#0x800
	bl memset

	mov geptr,r5
	bl endFrame
	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
wsVideoGetStateSize:	;@ Out r0=state size.
	.type   wsVideoGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x3360+(k2GEStateEnd-k2GEState)
	bx lr

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .ewram,"ax"
#endif
;@----------------------------------------------------------------------------
k2GEBufferWindows:
;@----------------------------------------------------------------------------
	ldr r0,[geptr,#kgeWinXPos]	;@ Win pos/size
	and r1,r0,#0x000000FF		;@ H start
	and r2,r0,#0x00FF0000		;@ H size
	cmp r1,#GAME_WIDTH
	movpl r1,#GAME_WIDTH
	add r1,r1,#(SCREEN_WIDTH-GAME_WIDTH)/2
	add r2,r2,r1,lsl#16
	cmp r2,#((SCREEN_WIDTH+GAME_WIDTH)/2)<<16
	movpl r2,#((SCREEN_WIDTH+GAME_WIDTH)/2)<<16
	orr r1,r1,r2,lsl#8
	mov r1,r1,ror#24
	strh r1,[geptr,#windowData]

	and r1,r0,#0x0000FF00		;@ V start
	mov r2,r0,lsr#24			;@ V size
	cmp r1,#GAME_HEIGHT<<8
	movpl r1,#GAME_HEIGHT<<8
	add r1,r1,#((SCREEN_HEIGHT-GAME_HEIGHT)/2)<<8
	add r2,r2,r1,lsr#8
	cmp r2,#(SCREEN_HEIGHT+GAME_HEIGHT)/2
	movpl r2,#(SCREEN_HEIGHT+GAME_HEIGHT)/2
	orr r1,r1,r2
	strh r1,[geptr,#windowData+2]

	bx lr
;@----------------------------------------------------------------------------
k2GE_R:						;@ I/O read (0x00-0x3F)
;@----------------------------------------------------------------------------
	and r2,r0,#0xE0
	ldr pc,[pc,r2,lsr#6]
	.long 0
	.long wsvRegistersR			;@ 0x0X
	.long k2GEPaletteR			;@ 0x2X
	.long k2GELedR				;@ 0x4X
	.long wsvBadR				;@ 0x6X
	.long k2GESpriteR			;@ 0x8X, Audio
	.long wsvBadR				;@ 0xAX
	.long k2GESpriteR			;@ 0xCX, Bank select, In/Out
	.long wsvBadR				;@ 0xEX

wsvRegistersR:
	ands r0,r0,#0xFF
	beq wsvDisplayControlR
	cmp r0,#0x03
	beq wsvVCountR
	cmp r0,#0x08
	beq wsvWinHStartR
	cmp r0,#0x09
	beq wsvWinVStartR
	cmp r0,#0x0A
	beq wsvWinHSizeR
	cmp r0,#0x0B
	beq wsvWinVSizeR
	cmp r0,#0x08
	beq k2GEHCountR
	cmp r0,#0x10
	beq wsvBgScrXR
	cmp r0,#0x11
	beq wsvBgScrYR
	cmp r0,#0x12
	beq wsvFgScrXR
	cmp r0,#0x13
	beq wsvFgScrYR
	cmp r0,#0x10
	beq k2GEStatusR
	cmp r0,#0x12
	beq k2GEBgColR
	cmp r0,#0x30
	beq k2GEBgPrioR
	cmp r0,#0xA6
	beq k2GERefreshR
wsvBadR:
	mov r11,r11					;@ No$GBA breakpoint
	ldr r0,=0x826EBAD0
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
wsvDisplayControlR:			;@ 0x00
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvDisplayControl]
	bx lr
;@----------------------------------------------------------------------------
wsvVCountR:					;@ 0x03
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#scanline]
	bx lr
;@----------------------------------------------------------------------------
wsvWinHStartR:				;@ 0x08
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinXPos]
	bx lr
;@----------------------------------------------------------------------------
wsvWinVStartR:				;@ 0x09
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinYPos]
	bx lr
;@----------------------------------------------------------------------------
wsvWinHSizeR:				;@ 0x0A
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinXSize]
	bx lr
;@----------------------------------------------------------------------------
wsvWinVSizeR:				;@ 0x0B
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinYSize]
	bx lr
;@----------------------------------------------------------------------------
wsvBgScrXR:					;@ 0x10, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvBGXScroll]
	bx lr
;@----------------------------------------------------------------------------
wsvBgScrYR:					;@ 0x11
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvBGYScroll]
	bx lr
;@----------------------------------------------------------------------------
wsvFgScrXR:					;@ 0x12
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvFGXScroll]
	bx lr
;@----------------------------------------------------------------------------
wsvFgScrYR:					;@ 0x13
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvFGYScroll]
	bx lr
;@----------------------------------------------------------------------------
k2GERefreshR:				;@ 0xA6
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeRef]
	bx lr
;@----------------------------------------------------------------------------
k2GEHCountR:				;@ 0x8008
;@----------------------------------------------------------------------------
//	mov r0,t9cycles,lsr#T9CYC_SHIFT+2	;@
	bx lr
;@----------------------------------------------------------------------------
k2GEStatusR:				;@ 0x8010
;@----------------------------------------------------------------------------
	ldr r0,[geptr,#scanline]
	cmp r0,#152					;@ Should this be WIN_VStart + WIN_VSize?
	movpl r0,#0x40				;@ in VBlank
	movmi r0,#0
	bx lr
;@----------------------------------------------------------------------------
k2GEBgColR:					;@ 0x8012
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeBGCol]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgPrioR:				;@ 0x8030
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeBGPrio]
	bx lr
;@----------------------------------------------------------------------------
k2GEPaletteMonoR:			;@ 0x8100-0x8118
;@----------------------------------------------------------------------------
	and r0,r0,#0xFF
	cmp r0,#0x19
	ldrmi r2,[geptr,#paletteMonoRAM]
	ldrbmi r0,[r2,r0]
	bx lr
;@----------------------------------------------------------------------------
k2GEPaletteR:				;@ 0x8200-0x83FF
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#paletteRAM]
	mov r0,r0,lsl#23
	ldrb r0,[r2,r0,lsr#23]
	bx lr
;@----------------------------------------------------------------------------
k2GELedR:					;@ 0x84XX
;@----------------------------------------------------------------------------
	ands r1,r0,#0xFF
	beq k2GELedEnableR
	cmp r1,#0x02
	beq k2GELedBlinkR
	mov r11,r11
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
k2GELedEnableR:				;@ 0x8400
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeLedEnable]
	bx lr
;@----------------------------------------------------------------------------
k2GELedBlinkR:				;@ 0x8402
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeLedBlink]
	bx lr
;@----------------------------------------------------------------------------
k2GEExtraR:					;@ 0x87XX
;@----------------------------------------------------------------------------
	ands r1,r0,#0xFF
	cmp r1,#0xE0
	beq wsVideoResetR
	cmp r1,#0xE2
	beq k2GEModeR
	cmp r1,#0xF0
	beq k2GEModeChangeR
	cmp r1,#0xFE
	beq k2GEInputPortR
	mov r11,r11
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
wsVideoResetR:					;@ 0x87E0
;@----------------------------------------------------------------------------
	mov r11,r11
	mov r0,#0					;@ should return 1? !!!
	bx lr
;@----------------------------------------------------------------------------
k2GEModeR:					;@ 0x87E2
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeMode]
	bx lr
;@----------------------------------------------------------------------------
k2GEModeChangeR:			;@ 0x87F0
;@----------------------------------------------------------------------------
	mov r11,r11
	ldrb r0,[geptr,#kgeModeChange]
	bx lr
;@----------------------------------------------------------------------------
k2GEInputPortR:				;@ 0x87FE (Reserved)
;@----------------------------------------------------------------------------
	mov r11,r11
	mov r0,#0x3F
//	orrne r0,r0,#0x40			;@ INP0
	bx lr
;@----------------------------------------------------------------------------
k2GESpriteR:				;@ 0x8800-0x88FF, 0x8C00-0x8C3F
;@----------------------------------------------------------------------------
	tst r0,#0x0700
	ldr r2,[geptr,#sprRAM]
	mov r1,r0,lsl#24
	addne r2,r2,#0x100
	tstne r1,#0xC0000000
	ldrbeq r0,[r2,r1,lsr#24]
	bx lr

;@----------------------------------------------------------------------------
wsVideoW:						;@ I/O write (0x00-0xFF)?
;@----------------------------------------------------------------------------
	and r2,r0,#0xE0
	ldr pc,[pc,r2,lsr#2]
	.long 0
	.long wsvRegistersW			;@ 0x0X
	.long k2GEPaletteW			;@ 0x2X
	.long k2GELedW				;@ 0x4X
	.long wsvBadW				;@ 0x6X
	.long k2GESpriteW			;@ 0x8X, Audio
	.long wsvBadW				;@ 0xAX
	.long k2GESpriteW			;@ 0xCX
	.long wsvBadW				;@ 0xEX

wsvRegistersW:
	ands r0,r0,#0xFF
	beq wsvDisplayControlW
	cmp r0,#0x04
	beq wsvSpriteTblAdrW
	cmp r0,#0x05
	beq wsvSpriteStartW
	cmp r0,#0x06
	beq wsvSpriteEndW
	cmp r0,#0x07
	beq wsvTileMapBaseW
	cmp r0,#0x08
	beq wsvWinHStartW
	cmp r0,#0x09
	beq wsvWinVStartW
	cmp r0,#0x0A
	beq wsvWinHSizeW
	cmp r0,#0x0B
	beq wsvWinVSizeW
	cmp r0,#0x10
	beq wsvBgScrXW
	cmp r0,#0x11
	beq wsvBgScrYW
	cmp r0,#0x12
	beq wsvFgScrXW
	cmp r0,#0x13
	beq wsvFgScrYW
	cmp r0,#0x12
	beq k2GEBgColW
	cmp r0,#0x30
	beq k2GEBgPrioW
	cmp r0,#0xA6
	beq k2GERefW
wsvBadW:
	mov r11,r11					;@ No$GBA breakpoint
	ldr r0,=0x826EBAD1
	bx lr

;@----------------------------------------------------------------------------
wsvDisplayControlW:			;@ 0x00
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvDisplayControl]
	bx lr
;@----------------------------------------------------------------------------
wsvSpriteTblAdrW:			;@ 0x04
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvSpriteTblAdr]
	bx lr
;@----------------------------------------------------------------------------
wsvSpriteStartW:			;@ 0x05
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvSpriteStart]
	bx lr
;@----------------------------------------------------------------------------
wsvSpriteEndW:				;@ 0x06
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvSpriteEnd]
	bx lr
;@----------------------------------------------------------------------------
wsvTileMapBaseW:			;@ 0x07
;@----------------------------------------------------------------------------
	strb r1,[geptr,#nameTable]
	bx lr
;@----------------------------------------------------------------------------
wsvWinHStartW:				;@ 0x08
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeWinXPos]
	bx lr
;@----------------------------------------------------------------------------
wsvWinVStartW:				;@ 0x09
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeWinYPos]
	bx lr
;@----------------------------------------------------------------------------
wsvWinHSizeW:				;@ 0x0A
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeWinXSize]
	bx lr
;@----------------------------------------------------------------------------
wsvWinVSizeW:				;@ 0x0B
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeWinYSize]
	bx lr
;@----------------------------------------------------------------------------
k2GERefW:					;@ 0xA6, Total number of scanlines?
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeRef]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgColW:					;@ 0x8012
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeBGCol]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgPrioW:				;@ 0x8030
;@----------------------------------------------------------------------------
	strb r1,[geptr,#kgeBGPrio]
	bx lr
;@----------------------------------------------------------------------------
wsvBgScrXW:					;@ 0x10, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#wsvBGXScroll]
#else
	ldr r2,[geptr,#wsvBGXScroll]
	ldr r3,[geptr,#wsvFGXScroll]
#endif
	strb r1,[geptr,#wsvBGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvBgScrYW:					;@ 0x11, Background Vertical Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#wsvBGXScroll]
#else
	ldr r2,[geptr,#wsvBGXScroll]
	ldr r3,[geptr,#wsvFGXScroll]
#endif
	strb r1,[geptr,#wsvBGYScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvFgScrXW:					;@ 0x12, Foreground Horizontal Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#wsvBGXScroll]
#else
	ldr r2,[geptr,#wsvBGXScroll]
	ldr r3,[geptr,#wsvFGXScroll]
#endif
	strb r1,[geptr,#wsvFGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvFgScrYW:					;@ 0x13, Foreground Vertical Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#wsvBGXScroll]
#else
	ldr r2,[geptr,#wsvBGXScroll]
	ldr r3,[geptr,#wsvFGXScroll]
#endif
	strb r1,[geptr,#wsvFGYScroll]
scrollCnt:

	ldr r1,[geptr,#scanline]	;@ r1=scanline
	add r1,r1,#1
	cmp r1,#159
	movhi r1,#159
	ldr r0,scrollLine
	subs r0,r1,r0
	strhi r1,scrollLine

	stmfd sp!,{r3}
	ldr r3,[geptr,#scrollBuff]
	add r1,r3,r1,lsl#3
	ldmfd sp!,{r3}
sy2:
	stmdbhi r1!,{r2,r3}			;@ Fill backwards from scanline to lastline
	subs r0,r0,#1
	bhi sy2
	bx lr

scrollLine: .long 0 ;@ ..was when?

;@----------------------------------------------------------------------------
k2GEPaletteMonoW:			;@ 0x8100-0x8118
;@----------------------------------------------------------------------------
	and r1,r1,#0xFF
	cmp r1,#0x18
	andmi r0,r0,#0x7
	ldrle r2,[geptr,#paletteMonoRAM]
	strble r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
k2GEPaletteW:				;@ 0x8200-0x83FF
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#paletteRAM]
	mov r1,r1,lsl#23
	strb r0,[r2,r1,lsr#23]
	bx lr
;@----------------------------------------------------------------------------
k2GELedW:					;@ 0x84XX
;@----------------------------------------------------------------------------
	ands r1,r1,#0xFF
	beq k2GELedEnableW
	cmp r1,#0x02
	beq k2GELedBlinkW
	mov r11,r11
	bx lr
;@----------------------------------------------------------------------------
k2GELedEnableW:				;@ 0x8400
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeLedEnable]
	bx lr
;@----------------------------------------------------------------------------
k2GELedBlinkW:				;@ 0x8402
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeLedBlink]
	mov r1,r0,lsl#16
	str r1,[geptr,#ledCounter]
	bx lr
;@----------------------------------------------------------------------------
k1GEExtraW:					;@ 0x87XX
;@----------------------------------------------------------------------------
	ands r1,r1,#0xFF
	cmp r1,#0xE0
	beq wsVideoResetW
	mov r11,r11
	bx lr
;@----------------------------------------------------------------------------
k2GEExtraW:					;@ 0x87XX
;@----------------------------------------------------------------------------
	ands r1,r1,#0xFF
	cmp r1,#0xE0
	beq wsVideoResetW
	cmp r1,#0xE2
	beq k2GEModeW
	cmp r1,#0xF0
	beq k2GEModeChangeW
	mov r11,r11
	bx lr
;@----------------------------------------------------------------------------
wsVideoResetW:				;@ 0x87E0
;@----------------------------------------------------------------------------
	cmp r0,#0x52
	beq wsvRegistersReset
	bx lr
;@----------------------------------------------------------------------------
k2GEModeW:					;@ 0x87E2
;@----------------------------------------------------------------------------
	ldrb r1,[geptr,#kgeModeChange]
	tst r1,#1
	and r0,r0,#0x80
	strbeq r0,[geptr,#kgeMode]
	bx lr
;@----------------------------------------------------------------------------
k2GEModeChangeW:			;@ 0x87F0
;@----------------------------------------------------------------------------
	cmp r0,#0x55
	cmpne r0,#0xAA
	and r0,r0,#1
	strbeq r0,[geptr,#kgeModeChange]
	bx lr
;@----------------------------------------------------------------------------
//k2GE_???_W				;@ 0x87F2
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
//k2GE_???_W				;@ 0x87F4
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
//k2GEInputPortW			;@ 0x87FE (Reserved)
;@----------------------------------------------------------------------------

;@----------------------------------------------------------------------------
k2GESpriteW:				;@ 0x8800-0x88FF, 0x8C00-0x8C3F
;@----------------------------------------------------------------------------
	tst r1,#0x0700
	ldr r2,[geptr,#sprRAM]
	mov r1,r1,lsl#24
	addne r2,r2,#0x100
	tstne r1,#0xC0000000
	strbeq r0,[r2,r1,lsr#24]
	bx lr

;@----------------------------------------------------------------------------
k2GEConvertTileMaps:		;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r10,r0
	ldr r5,=0xF000F000
	ldr r7,=0x00010001
	mov r6,#0
//	ldr r8,=TMAPBUFF
	ldr r11,=wsRAM
	mov r9,#32

	bl bgColor

	add r10,r10,#0x800
	ldr r5,=0xF000F000
	ldr r7,=0x00010001
	mov r6,#0
//	ldr r8,=TMAPBUFF
	ldr r11,=wsRAM
	mov r9,#32

	bl fgColor

	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
midFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
//	bl k2GETransferVRAM
	ldr r0,=tmpOamBuffer		;@ Destination
	ldr r0,[r0]
	bl wsvConvertSprites
	bl k2GEBufferWindows

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
endFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r0,=IO_regs
	ldrb r0,[r0,#0x60]
	and r0,r0,#0xE0
	cmp r0,#0xC0
	adr lr,TransRet
	beq TransferVRAM16Layered
	b TransferVRAM16Packed
TransRet:
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	stmfd sp!,{geptr,lr}
	ldrb r1,[geptr,#wsvBGXScroll]
	bl wsvBgScrXW
	ldmfd sp!,{lr}
	bl endFrameGfx

	ldr r2,=IO_regs
	ldrb r0,[r2,#0xB2]
	tst r0,#0x40				;@ VBlank IRQ?
	movne r0,#6					;@ 6 = VBlank
	blne setInterrupt
//	movne lr,pc
//	ldrne pc,[geptr,#frameIrqFunc]
	ldmfd sp!,{geptr,lr}
	bx lr
;@----------------------------------------------------------------------------
frameEndHook:
	mov r0,#0
	str r0,scrollLine

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia geptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

//	mov r0,#0					;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ zeroLine
	.long 75, midFrame			;@ Middle of screen
	.long 143, endFrame			;@ Last visible scanline
	.long 144, checkFrameIRQ	;@ frameIRQ
	.long 158, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
#ifdef GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
	.align 2
#endif
;@----------------------------------------------------------------------------
redoScanline:
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib geptr,{r1,r2}			;@ Write nextLineChange & lineState
	stmfd sp!,{lr}
	mov lr,pc
	bx r0
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
wsvDoScanline:
;@----------------------------------------------------------------------------
	ldmia geptr,{r0,r1}			;@ Read scanLine & nextLineChange
	cmp r0,r1
	bpl redoScanline
	add r0,r0,#1
	str r0,[geptr,#scanline]
;@----------------------------------------------------------------------------
checkScanlineIRQ:
;@----------------------------------------------------------------------------
//	cmp r0,#152
	mov r0,#1
	bx lr
	
//	stmfd sp!,{lr}
//	ldrb r0,[geptr,#kgeIrqEnable]
//	ands r0,r0,#0x40			;@ HIRQ enabled?
//	movne lr,pc
//	ldrne pc,[geptr,#periodicIrqFunc]

//	mov r0,#1
//	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
T_data:
	.long DIRTYTILES+0x200
VDP_RAM_ptr:
	.long wsRAM+0x4000
	.long CHR_DECODE
	.long BG_GFX+0x08000		;@ BGR tiles
	.long SPRITE_GFX			;@ SPR tiles
;@----------------------------------------------------------------------------
TransferVRAM16Packed:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r10,lr}
	adr r0,T_data
	ldmia r0,{r4-r8}
	ldr r6,=0xF0F0F0F0
	mov r9,#-1
	mov r1,#0

tileLoop16_0p:
	ldr r10,[r4]
	str r9,[r4],#4
	tst r10,#0x000000FF
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0x0000FF00
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0x00FF0000
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0xFF000000
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	cmp r1,#0x8000
	bne tileLoop16_0p

	ldmfd sp!,{r4-r10,pc}

tileLoop16_1p:
	ldr r0,[r5,r1]

	and r3,r6,r0,lsl#4
	and r0,r0,r6
	orr r3,r3,r0,lsr#4

	str r3,[r7,r1]
	str r3,[r8,r1]
	add r1,r1,#4
	tst r1,#0x1C
	bne tileLoop16_1p

	bx lr

;@----------------------------------------------------------------------------
TransferVRAM16Layered:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r10,lr}
	adr r0,T_data
	ldmia r0,{r4-r8}
	mov r9,#-1
	mov r1,#0

tileLoop16_0:
	ldr r10,[r4]
	str r9,[r4],#4
	tst r10,#0x000000FF
	addne r1,r1,#0x20
	bleq tileLoop16_1
	tst r10,#0x0000FF00
	addne r1,r1,#0x20
	bleq tileLoop16_1
	tst r10,#0x00FF0000
	addne r1,r1,#0x20
	bleq tileLoop16_1
	tst r10,#0xFF000000
	addne r1,r1,#0x20
	bleq tileLoop16_1
	cmp r1,#0x8000
	bne tileLoop16_0

	ldmfd sp!,{r4-r10,pc}

tileLoop16_1:
	ldr r0,[r5,r1]

	ands r3,r0,#0x000000FF
	ldrne r3,[r6,r3,lsl#2]
	ands r2,r0,#0x0000FF00
	ldrne r2,[r6,r2,lsr#6]
	orrne r3,r3,r2,lsl#1
	ands r2,r0,#0x00FF0000
	ldrne r2,[r6,r2,lsr#14]
	orrne r3,r3,r2,lsl#2
	ands r2,r0,#0xFF000000
	ldrne r2,[r6,r2,lsr#22]
	orrne r3,r3,r2,lsl#3

	str r3,[r7,r1]
	str r3,[r8,r1]
	add r1,r1,#4
	tst r1,#0x1C
	bne tileLoop16_1

	bx lr

;@-------------------------------------------------------------------------------
;@ bgChrFinish	;end of frame...
;@-------------------------------------------------------------------------------
;@	ldr r5,=0xF000F000
;@	ldr r7,=0x00010001
;@ MSB          LSB
;@ ---pcvhnnnnnnnnn
bgColor:
//	ldrb r1,[r8],#1				;@ Need to fix this up later!!!
	ldrb r1,[geptr,#nameTable]	;@ Need to fix this up later!!!
	and r1,r1,#0x07
	add r3,r11,r1,lsl#11
	add r3,r3,r6,lsl#6
	add r4,r10,r6,lsl#6
	add r6,r6,#1
	and r6,r6,#0x1F

bgm4Loop:
	ldr r0,[r3],#4				;@ Read from WonderSwan Tilemap RAM

	bic r1,r0,r5,lsr#3
	and r0,r0,r5,lsr#3
	and r2,r1,r5
	bic r1,r1,r5
	orr r1,r1,r2,lsr#4			;@ XY flip
	orr r1,r1,r0,lsl#3			;@ Color

	str r1,[r4],#4				;@ Write to GBA/NDS Tilemap RAM, foreground
	tst r4,#0x3C				;@ 32 tiles wide
	bne bgm4Loop
	subs r9,r9,#1
	bne bgColor

	bx lr

;@-------------------------------------------------------------------------------
;@ fgChrFinish	;end of frame...
;@-------------------------------------------------------------------------------
;@	ldr r5,=0xF000F000
;@	ldr r7,=0x00010001
;@ MSB          LSB
;@ ---pcvhnnnnnnnnn
fgColor:
//	ldrb r1,[r8],#1				;@ Need to fix this up later!!!
	ldrb r1,[geptr,#nameTable]	;@ Need to fix this up later!!!
	and r1,r1,#0x70
	add r3,r11,r1,lsl#7
	add r3,r3,r6,lsl#6
	add r4,r10,r6,lsl#6
	add r6,r6,#1
	and r6,r6,#0x1F

fgm4Loop:
	ldr r0,[r3],#4				;@ Read from WonderSwan Tilemap RAM

	bic r1,r0,r5,lsr#3
	and r0,r0,r5,lsr#3
	and r2,r1,r5
	bic r1,r1,r5
	orr r1,r1,r2,lsr#4			;@ XY flip
	orr r1,r1,r0,lsl#3			;@ Color

	str r1,[r4],#4				;@ Write to GBA/NDS Tilemap RAM, foreground
	tst r4,#0x3C				;@ 32 tiles wide
	bne fgm4Loop
	subs r9,r9,#1
	bne fgColor

	bx lr

;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5}
	ldr r1,[geptr,#scrollBuff]

	mov r2,#(SCREEN_HEIGHT-GAME_HEIGHT)/2
	add r0,r0,r2,lsl#3			;@ 8 bytes per row
	mov r4,#0x100-(SCREEN_WIDTH-GAME_WIDTH)/2
	sub r4,r4,r2,lsl#16
	mov r5,#GAME_HEIGHT
setScrlLoop:
	ldmia r1!,{r2,r3}
	add r2,r2,r4
	add r3,r3,r4
	stmia r0!,{r2,r3}
	subs r5,r5,#1
	bne setScrlLoop

	ldmfd sp!,{r4-r5}
	bx lr

;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x400		;@ 0x400=AGB OBJ priority 1
;@----------------------------------------------------------------------------
wsvConvertSprites:			;@ in r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination

	ldr r10,[geptr,#gfxRAM]
	ldrb r1,[geptr,#wsvSpriteTblAdr]
	and r1,r1,#0x3F
	add r10,r10,r1,lsl#9
	ldrb r1,[geptr,#wsvSpriteStart]
	add r10,r10,r1,lsl#2

	mov r0,#(SCREEN_WIDTH-GAME_WIDTH)/2		;@ GBA/NDS X offset
	mov r5,#(SCREEN_HEIGHT-GAME_HEIGHT)/2	;@ GBA/NDS Y offset
	orr r5,r0,r5,lsl#24

//	ldrb r9,[geptr,#wsvSpriteEnd]	;@ Last sprite
	mov r8,#128					;@ Total number of sprites
//	cmp r9,#0
//	beq dm4_3
dm5:
	ldr r0,[r10],#4				;@ WonderSwan OBJ, r0=Tile,Attrib,Ypos,Xpos.
	add r3,r5,r0,lsl#8
	mov r3,r3,lsr#24			;@ Ypos
	mov r4,r0,lsr#24			;@ Xpos
	cmp r4,#240
	addpl r4,r4,#0x100
	add r4,r4,r5
	mov r4,r4,lsl#23
	orr r3,r3,r4,lsr#7
	and r4,r0,#0xC000
	orr r3,r3,r4,lsl#14			;@ Flip

	str r3,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r3,r0,lsl#23
	mov r4,#0x0400
	orr r3,r4,r3,lsr#23
	and r4,r0,#0x0E00
	orr r3,r3,r4,lsl#3
	tst r0,#0x2000
	bicne r3,r3,#0x0400			;@ Priority

	strh r3,[r11],#4			;@ Store OBJ Atr 2. Pattern, palette.
dm4:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
skipSprite:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm4

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
CHR_DECODE:
	.space 0x400
SCROLL_BUFF:
	.space 160*8

#endif // #ifdef __arm__
