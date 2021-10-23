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
	.global k2GEDoScanline
	.global copyScrollValues
	.global k2GEConvertTileMaps
	.global k2GEConvertSprites
	.global k2GEConvertTiles
	.global k2GEBufferWindows
	.global k2GE_R
	.global wsvVCountR
	.global GetHInt

	.global k2GEBgScrXW
	.global k2GEBgScrYW
	.global k2GEFgScrXW
	.global k2GEFgScrYW
	.global wsvTileMapBaseW


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
	ldrne r0,=k2GEPaletteW
	ldreq r0,=k2GEBadW
	ldr r1,=k2GEPalPtr
	str r0,[r1],#4
	str r0,[r1],#4
	ldrne r0,=k2GEExtraW
	ldreq r0,=k1GEExtraW
	ldr r1,=k2GEExtraPtr
	str r0,[r1],#4

	b k2GERegistersReset

dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
k2GERegistersReset:
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
	ldr r0,=0x0FFF
	ldr r1,[geptr,#paletteRAM]
	add r1,r1,#0x100
	strh r0,[r1,#0xE0]			;@ 0x83E0. Default background colour
	strh r0,[r1,#0xF0]			;@ 0x83F0. Default window colour

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
	mov r2,#(k2GEStateSize-k2GEState)
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x3360+(k2GEStateSize-k2GEState)
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
	mov r2,#(k2GEStateSize-k2GEState)
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
	ldr r0,=0x3360+(k2GEStateSize-k2GEState)
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
k2GE_R:						;@ I/O read (0x8000-0x8FFF)
;@----------------------------------------------------------------------------
	and r2,r0,#0x0F00
	ldr pc,[pc,r2,lsr#6]
	.long 0
	.long k2GERegistersR		;@ 0x80XX
	.long k2GEPaletteMonoR		;@ 0x81XX
	.long k2GEPaletteR			;@ 0x82XX
	.long k2GEPaletteR			;@ 0x83XX
	.long k2GELedR				;@ 0x84XX
	.long k2GEBadR				;@ 0x85XX
	.long k2GEBadR				;@ 0x86XX
	.long k2GEExtraR			;@ 0x87XX
	.long k2GESpriteR			;@ 0x88XX
	.long k2GEBadR				;@ 0x89XX
	.long k2GEBadR				;@ 0x8AXX
	.long k2GEBadR				;@ 0x8BXX
	.long k2GESpriteR			;@ 0x8CXX
	.long k2GEBadR				;@ 0x8DXX
	.long k2GEBadR				;@ 0x8EXX
	.long k2GEBadR				;@ 0x8FXX

k2GERegistersR:
	ands r0,r0,#0xFF
	beq k2GEIrqEnableR
	cmp r0,#0x02
	beq k2GEWinHStartR
	cmp r0,#0x03
	beq k2GEWinVStartR
	cmp r0,#0x04
	beq k2GEWinHSizeR
	cmp r0,#0x05
	beq k2GEWinVSizeR
	cmp r0,#0x06
	beq k2GERefreshR
	cmp r0,#0x08
	beq k2GEHCountR
	cmp r0,#0x09
	beq k2GEVCountR
	cmp r0,#0x10
	beq k2GEStatusR
	cmp r0,#0x12
	beq k2GEBgColR
	cmp r0,#0x20
	beq k2GESprOfsXR
	cmp r0,#0x21
	beq k2GESprOfsYR
	cmp r0,#0x30
	beq k2GEBgPrioR
	cmp r0,#0x32
	beq k2GEBgScrXR
	cmp r0,#0x33
	beq k2GEBgScrYR
	cmp r0,#0x34
	beq k2GEFgScrXR
	cmp r0,#0x35
	beq k2GEFgScrYR
k2GEBadR:
	mov r11,r11					;@ No$GBA breakpoint
	ldr r0,=0x826EBAD0
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
k2GEIrqEnableR:				;@ 0x8000
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeIrqEnable]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinHStartR:				;@ 0x8002
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinXPos]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinVStartR:				;@ 0x8003
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinYPos]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinHSizeR:				;@ 0x8004
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinXSize]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinVSizeR:				;@ 0x8005
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeWinYSize]
	bx lr
;@----------------------------------------------------------------------------
k2GERefreshR:				;@ 0x8006
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeRef]
	bx lr
;@----------------------------------------------------------------------------
k2GEHCountR:				;@ 0x8008
;@----------------------------------------------------------------------------
//	mov r0,t9cycles,lsr#T9CYC_SHIFT+2	;@
	bx lr
;@----------------------------------------------------------------------------
k2GEVCountR:				;@ 0x8009
;@----------------------------------------------------------------------------
;@	mov t9cycles,#0				;@
	ldrb r0,[geptr,#scanline]
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
k2GESprOfsXR:				;@ 0x8020
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeSprXOfs]
	bx lr
;@----------------------------------------------------------------------------
k2GESprOfsYR:				;@ 0x8021
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeSprYOfs]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgPrioR:				;@ 0x8030
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeBGPrio]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgScrXR:				;@ 0x8032, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeBGXScroll]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgScrYR:				;@ 0x8033
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeBGYScroll]
	bx lr
;@----------------------------------------------------------------------------
k2GEFgScrXR:				;@ 0x8034
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeFGXScroll]
	bx lr
;@----------------------------------------------------------------------------
k2GEFgScrYR:				;@ 0x8035
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#kgeFGYScroll]
	bx lr
;@----------------------------------------------------------------------------
wsvVCountR:					;@ 0x03
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#scanline]
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
GetHInt:					;@ Out r0 = 0 / 1, if HInt is happening or not.
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr r1,[geptr,#scanline]
	cmp r1,#151					;@ Should this be WIN_VStart + WIN_VSize?
	movmi r0,#1
	cmp r1,#198
	moveq r0,#1
	ldrb r1,[geptr,#kgeIrqEnable]
	and r0,r0,r1,lsr#6
	bx lr

;@----------------------------------------------------------------------------
wsVideoW:						;@ I/O write (0x00-0x7F)?
;@----------------------------------------------------------------------------
	and r2,r1,#0xF0
	ldr pc,[pc,r2,lsr#2]
	.long 0
	.long k2GERegistersW		;@ 0x00
	.long k2GEPaletteMonoW		;@ 0x01
k2GEPalPtr:
	.long k2GEPaletteW			;@ 0x02
	.long k2GEPaletteW			;@ 0x03
	.long k2GELedW				;@ 0x04
	.long k2GEBadW				;@ 0x05
	.long k2GEBadW				;@ 0x06
k2GEExtraPtr:
	.long k2GEExtraW			;@ 0x07
	.long k2GESpriteW			;@ 0x08
	.long k2GEBadW				;@ 0x09
	.long k2GEBadW				;@ 0x0A
	.long k2GEBadW				;@ 0x0B
	.long k2GESpriteW			;@ 0x0C
	.long k2GEBadW				;@ 0x0D
	.long k2GEBadW				;@ 0x0E
	.long k2GEBadW				;@ 0x0F

k2GERegistersW:
	ands r1,r1,#0xFF
	beq k2GEIrqEnableW
	cmp r1,#0x02
	beq k2GEWinHStartW
	cmp r1,#0x03
	beq k2GEWinVStartW
	cmp r1,#0x04
	beq k2GEWinHSizeW
	cmp r1,#0x05
	beq k2GEWinVSizeW
	cmp r1,#0x06
	beq k2GERefW
	cmp r1,#0x12
	beq k2GEBgColW
	cmp r1,#0x30
	beq k2GEBgPrioW
	cmp r1,#0x32
	beq k2GEBgScrXW
	cmp r1,#0x33
	beq k2GEBgScrYW
	cmp r1,#0x34
	beq k2GEFgScrXW
	cmp r1,#0x35
	beq k2GEFgScrYW
k2GEBadW:
								;@ Cool Boarders writes 0x80 to 0x8011 and 0x00 to 8036.
	mov r11,r11					;@ No$GBA breakpoint
	ldr r0,=0x826EBAD1
	bx lr
;@----------------------------------------------------------------------------
k2GEIrqEnableW:				;@ 0x8000
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeIrqEnable]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinHStartW:				;@ 0x8002
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeWinXPos]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinVStartW:				;@ 0x8003
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeWinYPos]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinHSizeW:				;@ 0x8004
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeWinXSize]
	bx lr
;@----------------------------------------------------------------------------
k2GEWinVSizeW:				;@ 0x8005
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeWinYSize]
	bx lr
;@----------------------------------------------------------------------------
k2GERefW:					;@ 0x8006, Total number of scanlines
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeRef]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgColW:					;@ 0x8012
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeBGCol]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgPrioW:				;@ 0x8030
;@----------------------------------------------------------------------------
	strb r0,[geptr,#kgeBGPrio]
	bx lr
;@----------------------------------------------------------------------------
k2GEBgScrXW:				;@ 0x8032, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#kgeBGXScroll]
#else
	ldr r2,[geptr,#kgeBGXScroll]
	ldr r3,[geptr,#kgeFGXScroll]
#endif
	strb r0,[geptr,#kgeBGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
k2GEBgScrYW:				;@ 0x8033, Background Vertical Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#kgeBGXScroll]
#else
	ldr r2,[geptr,#kgeBGXScroll]
	ldr r3,[geptr,#kgeFGXScroll]
#endif
	strb r0,[geptr,#kgeBGYScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
k2GEFgScrXW:				;@ 0x8034, Foreground Horizontal Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#kgeBGXScroll]
#else
	ldr r2,[geptr,#kgeBGXScroll]
	ldr r3,[geptr,#kgeFGXScroll]
#endif
	strb r0,[geptr,#kgeFGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
k2GEFgScrYW:				;@ 0x8035, Foreground Vertical Scroll register
;@----------------------------------------------------------------------------
#ifdef NDS
	ldrd r2,r3,[geptr,#kgeBGXScroll]
#else
	ldr r2,[geptr,#kgeBGXScroll]
	ldr r3,[geptr,#kgeFGXScroll]
#endif
	strb r0,[geptr,#kgeFGYScroll]
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
wsvTileMapBaseW:			;@ 0x07
;@----------------------------------------------------------------------------
	bx lr
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
	beq k2GERegistersReset
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
	stmfd sp!,{r4-r9,lr}

	ldr r1,=wsRAM
	ldr r5,=0xFE00FE00
	ldr r7,=0x20002000
	ldr r8,=0xC000C000
	ldr r9,=0x1E001E00
	mov r6,#64

	adr lr,bgRet0
	ldrb r2,[geptr,#kgeMode]	;@ Color mode
	tst r2,#0x80
	beq bgColor
	bne bgMono
bgRet0:
noChange:
	ldmfd sp!,{r4-r9,pc}

;@----------------------------------------------------------------------------
midFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
//	bl k2GETransferVRAM
	ldr r0,=tmpOamBuffer		;@ Destination
	ldr r0,[r0]
	bl k2GEConvertSprites
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
	ldrb r0,[geptr,#kgeBGXScroll]
	bl k2GEBgScrXW
	ldrb r0,[geptr,#kgeFGXScroll]
	bl k2GEFgScrXW
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
k2GEDoScanline:
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

;@----------------------------------------------------------------------------
;@bgChrFinish	;@ End of frame... r0=destination, r1=source
;@----------------------------------------------------------------------------
;@	ldr r5,=0xFE00FE00
;@	ldr r7,=0x20002000
;@	ldr r8,=0xC000C000
;@	ldr r9,=0x1E001E00
;@ MSB          LSB
;@ hvcCCCCnnnnnnnnn
bgColor:
	ldr r3,[r1],#4				;@ Read from NeoGeo Pocket Tilemap RAM
	bic r2,r3,r5
	and r4,r3,r9
	orr r2,r2,r4,lsl#3			;@ Color
	and r3,r3,r8				;@ Mask NGP flip bits
	orr r3,r3,r3,lsr#2
	and r3,r8,r3,lsl#1
	orr r2,r2,r3,lsr#4			;@ XY flip

	str r2,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, foreground
	tst r0,#0x3C				;@ 32 tiles wide
	subseq r6,r6,#1
	bne bgColor

	bx lr
;@----------------------------------------------------------------------------
;@bgChrFinish	;@ End of frame... r0=destination, r1=source
;@----------------------------------------------------------------------------
;@	ldr r5,=0xFE00FE00
;@	ldr r7,=0x20002000
;@	ldr r8,=0xC000C000
;@	ldr r9,=0x1E001E00
;@ MSB          LSB
;@ hvcCCCCnnnnnnnnn
bgMono:
	ldr r3,[r1],#4				;@ Read from NeoGeo Pocket Tilemap RAM
	bic r2,r3,r5
	and r4,r3,r7
	orr r2,r2,r4,lsr#1			;@ Color
	and r3,r3,r8				;@ Mask NGP flip bits
	orr r3,r3,r3,lsr#2
	and r3,r8,r3,lsl#1
	orr r2,r2,r3,lsr#4			;@ XY flip

	str r2,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, foreground
	tst r0,#0x3C				;@ 32 tiles wide
	subseq r6,r6,#1
	bne bgMono

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
k2GEConvertSprites:			;@ in r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination

	ldr r10,[geptr,#sprRAM]
	add r9,r10,#0x100			;@ Spr palette

	ldrb r7,[geptr,#kgeMode]	;@ Color mode
	ldrb r0,[geptr,#kgeSprXOfs]	;@ Sprite offset X
	ldrb r5,[geptr,#kgeSprYOfs]	;@ Sprite offset Y
	add r0,r0,#(SCREEN_WIDTH-GAME_WIDTH)/2		;@ GBA/NDS X offset
	add r5,r5,#(SCREEN_HEIGHT-GAME_HEIGHT)/2	;@ GBA/NDS Y offset
	orr r5,r5,r0,lsl#24
	mov r4,r5

	mov r8,#64					;@ Number of sprites
dm5:
	ldr r0,[r10],#4				;@ NGP OBJ, r4=Tile,Attrib,Xpos,Ypos.
	ands r6,r0,#0x1800			;@ Prio
	beq skipSprite
	movs r2,r0,lsl#22			;@ 0x400=X-Chain, 0x200=Y-Chain
	addcs r1,r0,r4,lsr#8		;@ X-Chain
	addcc r1,r0,r5,lsr#8		;@ X-Offset
	addmi r3,r4,r0,lsr#24		;@ Y-Chain
	addpl r3,r5,r0,lsr#24		;@ Y-Offset
	and r1,r1,#0xFF0000
	and r4,r3,#0xFF				;@ Save Y-pos
	orr r3,r4,r1				;@ Xpos
	orr r4,r4,r1,lsl#8			;@ Save X-pos
	movs r2,r0,lsl#17			;@ Test H- & V-flip
	orrcs r3,r3,#0x10000000		;@ H-flip
	orrmi r3,r3,#0x20000000		;@ V-flip

	str r3,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r0,r0,ror#9
	mov r3,r0,lsr#23			;@ Tilenumber
	and r0,r0,#0x10
	mov r0,r0,lsr#4
	tst r7,#0x80
	ldrbeq r0,[r9],#1			;@ Color palette
	orr r3,r3,r0,lsl#12
#ifdef NDS
	rsb r6,r6,#0x1800			;@ Convert prio NDS
#elif GBA
	rsb r6,r6,#0x2000			;@ Convert prio GBA
#endif
	orr r3,r3,r6,lsr#1

	strh r3,[r11],#4			;@ Store OBJ Atr 2. Pattern, palette.
dm4:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
skipSprite:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	add r9,r9,#1
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
