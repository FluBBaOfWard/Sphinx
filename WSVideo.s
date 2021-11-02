// Bandai WonderSwan Graphics emulation

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
	.global wsvDoScanline
	.global copyScrollValues
	.global wsvConvertTileMaps
	.global wsvConvertSprites
	.global wsvBufferWindows
	.global wsvRead
	.global wsVideoW


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
wsVideoReset:		;@ r0=frameIrqFunc, r1=hIrqFunc, r2=ram+LUTs, r3=HWType 0=color, r12=geptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	mov r0,geptr
	ldr r1,=wsVideoSize/4
	bl memclr_					;@ Clear WSVideo state

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
	add r2,r2,#0x140
	str r2,[geptr,#paletteMonoRAM]
	add r2,r2,#0x20
	add r2,r2,#0x200
	str r2,[geptr,#gfxRAMSwap]
	ldr r0,=SCROLL_BUFF
	str r0,[geptr,#scrollBuff]

	strb r3,[geptr,#wsvMachine]
	cmp r3,#HW_WS
	movne r0,#0xC0				;@ Use Color mode.
	moveq r0,#0x00				;@ Use B&W mode.
	strb r0,[geptr,#wsvVideoMode]

	b wsvRegistersReset

dummyIrqFunc:
	bx lr
;@----------------------------------------------------------------------------
wsvRegistersReset:
;@----------------------------------------------------------------------------
//	mov r0,#0xC0
//	strb r0,[geptr,#wsvInterruptEnable]
//	mov r0,#0xC6
//	strb r0,[geptr,#wsvTotalLines]	;@ Total number of scanlines?
	mov r0,#0xFF
	strb r0,[geptr,#wsvWinXSize]	;@ Window size
	strb r0,[geptr,#wsvWinYSize]
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
	add r1,r5,#wsVideoState
	mov r2,#(wsVideoStateEnd-wsVideoState)
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x3360+(wsVideoStateEnd-wsVideoState)
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
	add r0,r5,#wsVideoState
	add r1,r4,r2
	mov r2,#(wsVideoStateEnd-wsVideoState)
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
	ldr r0,=0x3360+(wsVideoStateEnd-wsVideoState)
	bx lr

	.pool
;@----------------------------------------------------------------------------
#ifdef GBA
	.section .ewram,"ax"
#endif
;@----------------------------------------------------------------------------
wsvBufferWindows:
;@----------------------------------------------------------------------------
	ldr r0,[geptr,#wsvWinXPos]	;@ Win pos/size
	ldr r0,=0xB0F00000
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
wsvRead:					;@ I/O read (0x00-0x3F)
;@----------------------------------------------------------------------------
	and r0,r0,#0xFF
	ldr pc,[pc,r0,lsl#2]
	.long 0
IN_Table:
	.long wsvRegR				;@ 0x00
	.long wsvRegR
	.long wsvVCountR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0x08
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x10
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvWSUnmappedR		;@ 0x18
	.long wsvWSUnmappedR
	.long wsvUnknownR
	.long wsvWSUnmappedR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x20
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0x28
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x30
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0x38
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x40
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvImportantR			;@ 0x48
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x50
	.long wsvWSUnmappedR
	.long wsvRegR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR		;@ 0x58
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR

	.long wsvRegR				;@ 0x60
	.long wsvWSUnmappedR
	.long wsvRegR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR		;@ 0x68
	.long wsvWSUnmappedR
	.long wsvRegR
	.long wsvRegR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR

	.long wsvRegR				;@ 0x70
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvWSUnmappedR		;@ 0x78
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR

	.long wsvRegR				;@ 0x80
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0x88
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR

	.long wsvRegR				;@ 0x90
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0x98
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvWSUnmappedR

	.long wsvHWTypeR			;@ 0xA0, Color or mono
	.long wsvWSUnmappedR
	.long wsvRegR
	.long wsvUnknownR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR				;@ 0xA8
	.long wsvRegR
	.long wsvImportantR			;@ 0xAA VBlank counter
	.long wsvRegR
	.long wsvUnknownR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR
	.long wsvWSUnmappedR

	.long wsvRegR				;@ 0xB0
	.long wsvRegR
	.long wsvRegR				;@ 0xB2 Interrupt enable
	.long wsvImportantR			;@ 0xB3 communication direction
	.long wsvRegR				;@ 0xB4 Interrupt status
	.long IOPortA_R				;@ 0xB5 keypad
	.long wsvZeroR				;@ 0xB6 Interrupt acknowledge
	.long wsvUnknownR
	.long wsvWSUnmappedR		;@ 0xB8
	.long wsvWSUnmappedR
	.long wsvImportantR			;@ 0xBA int-eeprom even byte read
	.long wsvImportantR			;@ 0xBB int-eeprom odd byte read
	.long wsvRegR
	.long wsvRegR
	.long wsvImportantR			;@ 0xBE int-eeprom status
	.long wsvRegR

	.long wsvRegR				;@ 0xC0
	.long wsvRegR
	.long wsvRegR
	.long wsvRegR
	.long wsvImportantR			;@ 0xC4 ext-eeprom even byte read
	.long wsvImportantR			;@ 0xC5 ext-eeprom odd byte read
	.long wsvRegR
	.long wsvRegR
	.long wsvImportantR			;@ 0xC8 ext-eeprom status
	.long wsvUnknownR
	.long wsvImportantR			;@ 0xCA rtc status
	.long wsvImportantR			;@ 0xCB rtc read
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR

	.long wsvUnknownR			;@ 0xD0
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR			;@ 0xD8
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR

	.long wsvUnknownR			;@ 0xE0
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR			;@ 0xE8
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR

	.long wsvUnknownR			;@ 0xF0
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR			;@ 0xF8
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
	.long wsvUnknownR
;@----------------------------------------------------------------------------
wsvUnknownR:
;@----------------------------------------------------------------------------
	mov r11,r11				;@ No$GBA breakpoint
	ldr r2,=0x826EBAD0
;@----------------------------------------------------------------------------
wsvWSUnmappedR:
;@----------------------------------------------------------------------------
	mov r0,#0x90
	bx lr
;@----------------------------------------------------------------------------
wsvZeroR:
;@----------------------------------------------------------------------------
wsvWSCUnmappedR:
;@----------------------------------------------------------------------------
	mov r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
wsvImportantR:
	mov r11,r11				;@ No$GBA breakpoint
;@----------------------------------------------------------------------------
wsvRegR:
	add r2,geptr,#wsvRegs
	ldrb r0,[r2,r0]
	bx lr

;@----------------------------------------------------------------------------
wsvVCountR:					;@ 0x03
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#scanline]
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
wsvHWTypeR:					;@ 0xA0
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvHardwareType]
	ldrb r1,[geptr,#wsvMachine]
	cmp r1,#0
	orreq r0,r0,#2
	bx lr

;@----------------------------------------------------------------------------
wsVideoW:					;@ I/O write (0x00-0xFF)
;@----------------------------------------------------------------------------
	and r0,r0,#0xFF
	ldr pc,[pc,r0,lsl#2]
	.long 0
OUT_Table:
	.long wsvRegW				;@ 0x00 Display control
	.long wsvRegW				;@ 0x01 Background color
	.long wsvReadOnlyW			;@ 0x02 Current scan line
	.long wsvRegW				;@ 0x03 Scan line compare
	.long wsvRegW				;@ 0x04 Sprite table address
	.long wsvRegW				;@ 0x05 Sprite to start with
	.long wsvRegW				;@ 0x06 Last sprite
	.long wsvRegW				;@ 0x07 Map table address
	.long wsvRegW				;@ 0x08 Window X-Position
	.long wsvRegW				;@ 0x09 Window Y-Position
	.long wsvRegW				;@ 0x0A Window X-Size
	.long wsvRegW				;@ 0x0B Window Y-Size
	.long wsvRegW				;@ 0x0C Sprite window X-Position
	.long wsvRegW				;@ 0x0D Sprite window Y-Position
	.long wsvRegW				;@ 0x0E Sprite window X-Size
	.long wsvRegW				;@ 0x0F Sprite window Y-Size

	.long wsvBgScrXW			;@ 0x10
	.long wsvBgScrYW
	.long wsvFgScrXW
	.long wsvFgScrYW
	.long wsvRegW				;@ 0x14 LCD control (on/off?)
	.long wsvRegW				;@ 0x15 LCD icons
	.long wsvRegW				;@ 0x16 Total scan lines
	.long wsvRegW				;@ 0x17 Vsync line
	.long wsvUnmappedW			;@ 0x18
	.long wsvUnmappedW
	.long wsvUnknownW
	.long wsvUnmappedW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW

	.long wsvRegW				;@ 0x20
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW				;@ 0x28
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW

	.long wsvRegW				;@ 0x30
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW				;@ 0x38
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW

	.long wsvRegW				;@ 0x40	DMA, source
	.long wsvRegW
	.long wsvRegW
	.long wsvUnmappedW
	.long wsvRegW				;@ DMA destination
	.long wsvUnknownW
	.long wsvRegW				;@ DMA length
	.long wsvRegW
	.long wsvDMAStartW			;@ 0x48, only WSC
	.long wsvUnmappedW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvUnmappedW
	.long wsvRegW
	.long wsvRegW

	.long wsvUnknownW			;@ 0x50
	.long wsvUnmappedW
	.long wsvRegW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW			;@ 0x58
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW

	.long wsvRegW				;@ 0x60
	.long wsvUnmappedW
	.long wsvUnknownW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW			;@ 0x68
	.long wsvUnmappedW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW

	.long wsvReadOnlyW			;@ 0x70
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvUnmappedW			;@ 0x78
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW

	.long wsvRegW				;@ 0x80
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW				;@ 0x88
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW

	.long wsvRegW				;@ 0x90 Audio control
	.long wsvRegW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW				;@ 0x98
	.long wsvRegW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvUnmappedW

	.long wsvHW					;@ 0xA0 Hardware type, HW_WSC / HW_WS.
	.long wsvUnmappedW
	.long wsvRegW				;@ 0xA2 Timer control
	.long wsvUnknownW
	.long wsvHTimerLowW			;@ 0xA4 HBlank timer low
	.long wsvHTimerHighW		;@ 0xA5 HBlank timer high
	.long wsvVTimerLowW			;@ 0xA6 VBlank timer low
	.long wsvVTimerHighW		;@ 0xA7 HBlank timer high
	.long wsvReadOnlyW			;@ 0xA8
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvReadOnlyW
	.long wsvUnknownW
	.long wsvUnmappedW
	.long wsvUnmappedW
	.long wsvUnmappedW

	.long wsvRegW				;@ 0xB0
	.long wsvRegW				;@ 0xB1 Serial data
	.long wsvRegW				;@ 0xB2 Interrupt enable
	.long wsvRegW				;@ 0xB1 Serial status
	.long wsvReadOnlyW			;@ 0xB4 Interrupt status
	.long wsvRegW				;@ 0xB5 Input Controls
	.long wsvIntAckW			;@ 0xB6 Interrupt acknowledge
	.long wsvUnknownW
	.long wsvUnmappedW			;@ 0xB8
	.long wsvUnmappedW
	.long wsvImportantW			;@ 0xBA int-eeprom data low
	.long wsvImportantW			;@ 0xBB int-eeprom data high
	.long wsvImportantW			;@ 0xBC int-eeprom address low
	.long wsvImportantW			;@ 0xBD int-eeprom address high
	.long wsvImportantW			;@ 0xBD int-eeprom status/command
	.long wsvUnknownW

	.long BankSwitch4_F_W		;@ 0xC0
	.long wsvRegW
	.long BankSwitch2_W
	.long BankSwitch3_W
	.long wsvImportantW			;@ 0xC4 ext-eeprom even byte write
	.long wsvImportantW			;@ 0xC5 ext-eeprom odd byte write
	.long wsvRegW
	.long wsvRegW
	.long wsvRegW				;@ 0xC8
	.long wsvUnknownW
	.long wsvImportantW			;@ 0xCA RTC data
	.long wsvImportantW			;@ 0xCB RTC command
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW

	.long wsvUnknownW			;@ 0xD0
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW			;@ 0xD8
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW

	.long wsvUnknownW			;@ 0xE0
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW			;@ 0xE8
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW

	.long wsvUnknownW			;@ 0xF0
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW			;@ 0xF8
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW
	.long wsvUnknownW

;@----------------------------------------------------------------------------
wsvReadOnlyW:
;@----------------------------------------------------------------------------
wsvUnmappedW:
;@----------------------------------------------------------------------------
	mov r11,r11				;@ No$GBA breakpoint
	bx lr
;@----------------------------------------------------------------------------
wsvUnknownW:
;@----------------------------------------------------------------------------
	ldr r2,=0x826EBAD1
;@----------------------------------------------------------------------------
wsvImportantW:
	mov r11,r11				;@ No$GBA breakpoint
;@----------------------------------------------------------------------------
wsvRegW:
	add r2,geptr,#wsvRegs
	strb r1,[r2,r0]
	bx lr

;@----------------------------------------------------------------------------
wsvBgScrXW:					;@ 0x10, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#wsvBGXScroll]
	strb r1,[geptr,#wsvBGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvBgScrYW:					;@ 0x11, Background Vertical Scroll register
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#wsvBGXScroll]
	strb r1,[geptr,#wsvBGYScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvFgScrXW:					;@ 0x12, Foreground Horizontal Scroll register
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#wsvBGXScroll]
	strb r1,[geptr,#wsvFGXScroll]
	b scrollCnt

;@----------------------------------------------------------------------------
wsvFgScrYW:					;@ 0x13, Foreground Vertical Scroll register
;@----------------------------------------------------------------------------
	ldr r2,[geptr,#wsvBGXScroll]
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
	add r1,r3,r1,lsl#2
	ldmfd sp!,{r3}
sy2:
	stmdbhi r1!,{r2}			;@ Fill backwards from scanline to lastline
	subs r0,r0,#1
	bhi sy2
	bx lr

scrollLine: .long 0 ;@ ..was when?

;@----------------------------------------------------------------------------
wsvRefW:					;@ 0x16, Total number of scanlines?
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvTotalLines]
	bx lr
;@----------------------------------------------------------------------------
wsvDMAStartW:				;@ 0x48, only WSC, word transfer. steals 5+2n cycles.
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvDMAStart]
	tst r1,#0x80
	bxeq lr

	stmfd sp!,{r4-r7,lr}
	and r1,r1,#0x40				;@ Inc/dec
	mov r7,geptr
	ldrh r4,[geptr,#wsvDMASource]
	ldrb r0,[geptr,#wsvDMASrcBnk]
	orr r4,r4,r0,lsl#16			;@ r4=source

	ldrh r5,[geptr,#wsvDMADest]	;@ r5=destination

	ldrh r6,[geptr,#wsvDMALength];@ r6=length
	cmp r6,#0
	beq dmaEnd
	;@ sub cycles,cycles,r6

dmaLoop:
	mov r0,r4
	bl cpuReadByte
	mov r1,r0
	mov r0,r5
	bl cpuWriteByte
	add r4,r4,#1
	add r5,r5,#1
	subs r6,r6,#1
	bne dmaLoop

	mov geptr,r7
	strh r4,[geptr,#wsvDMASource]
	mov r4,r4,lsr#16
	strb r4,[geptr,#wsvDMASrcBnk]
	strh r5,[geptr,#wsvDMADest]

	strh r6,[geptr,#wsvDMALength]
	cmp r6,#0
	strbeq r0,[geptr,#wsvDMAStart]
dmaEnd:
	;@ sub cycles,cycles,#5

	ldmfd sp!,{r4-r7,lr}
	bx lr
;@----------------------------------------------------------------------------
wsvHW:					;@ 0xA0, Color/Mono, boot rom lock
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvHardwareType]
	and r0,r0,#1
	orr r1,r1,r0
	strb r1,[geptr,#wsvHardwareType]
	eor r0,r0,r1
	tst r1,#1			;@ Boot rom locked?
	bxeq lr
	mov r1,#0xff
	b BankSwitch4_F_W	;@ Map back cartridge.

;@----------------------------------------------------------------------------
wsvHTimerLowW:			;@ 0xA4 HBlank timer low
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvHBlTimerFreq]
	strb r1,[geptr,#wsvHBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvHTimerHighW:			;@ 0xA5 HBlank timer high
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvHBlTimerFreq+1]
	strb r1,[geptr,#wsvHBlCounter+1]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerLowW:			;@ 0xA6 VBlank timer low
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvVBlTimerFreq]
	strb r1,[geptr,#wsvVBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerHighW:			;@ 0xA7 HBlank timer high
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvVBlTimerFreq+1]
	strb r1,[geptr,#wsvVBlCounter+1]
	bx lr
;@----------------------------------------------------------------------------
wsvIntAckW:				;@ 0xB6
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvInterruptStatus]
	bic r0,r0,r1
	strb r0,[geptr,#wsvInterruptStatus]
	bx lr


;@----------------------------------------------------------------------------
wsvConvertTileMaps:		;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	ldr r5,=0xFE00FE00
	ldr r6,=0x00010001
	ldr r10,[geptr,#gfxRAM]

	ldrb r1,[geptr,#wsvVideoMode]
	adr lr,tMapRet
	ands r1,r1,#0xE0
	beq bgMono
	b bgColor

tMapRet:
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
midFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
//	bl wsvTransferVRAM
	ldr r0,=tmpOamBuffer		;@ Destination
	ldr r0,[r0]
	bl wsvConvertSprites
	bl wsvBufferWindows

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
endFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r0,[geptr,#wsvVideoMode]
	adr lr,TransRet
	ands r0,r0,#0xE0
	beq TransferVRAM4Layered
	cmp r0,#0xC0
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

	ldrb r2,[geptr,#wsvTimerControl]
	tst r2,#0x4						;@ VBlank timer enabled?
	beq noTimerVblIrq
	mov r0,#0
	ldrh r1,[geptr,#wsvVBlCounter]
	subs r1,r1,#1
	bmi noTimerVblIrq
	moveq r0,#5						;@ 5 = VBlank timer
	eor r2,r2,#0x8
	tsteq r2,#0x8					;@ Repeat?
	ldrheq r1,[geptr,#wsvVBlTimerFreq]
	strh r1,[geptr,#wsvVBlCounter]
	cmp r0,#0
	blne setInterrupt
noTimerVblIrq:
	mov r0,#6					;@ 6 = VBlank
	bl setInterrupt

	mov r0,#1
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
	stmfd sp!,{lr}

	ldrb r1,[geptr,#wsvLineCompare]
	cmp r0,r1
	moveq r0,#4
	bleq setInterrupt

	ldr geptr,=wsv_0
	ldrb r2,[geptr,#wsvTimerControl]
	tst r2,#0x1						;@ HBlank timer enabled?
	beq noTimerHblIrq
	mov r0,#0
	ldrh r1,[geptr,#wsvHBlCounter]
	subs r1,r1,#1
	bmi noTimerHblIrq
	moveq r0,#7						;@ 7 = HBlank timer
	eor r2,r2,#0x2
	tsteq r2,#0x2					;@ Repeat?
	ldrheq r1,[geptr,#wsvHBlTimerFreq]
	strh r1,[geptr,#wsvHBlCounter]
	cmp r0,#0
	blne setInterrupt
noTimerHblIrq:

	ldmfd sp!,{lr}
	mov r0,#1
	bx lr

;@----------------------------------------------------------------------------
T_data:
	.long DIRTYTILES+0x200
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
T4Data:
	.long DIRTYTILES+0x100
	.long wsRAM+0x2000
	.long CHR_DECODE
	.long BG_GFX+0x08000		;@ BGR tiles
	.long BG_GFX+0x0C000		;@ BGR tiles 2
	.long SPRITE_GFX			;@ SPR tiles
	.long 0x44444444			;@ Extra bitplane
;@----------------------------------------------------------------------------
TransferVRAM4Layered:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r12,lr}
	adr r0,T4Data
	ldmia r0,{r4-r10}
	mov r11,#-1
	mov r1,#0

tileLoop4_0:
	ldr r12,[r4]
	str r11,[r4],#4
	tst r12,#0x000000FF
	addne r1,r1,#0x20
	bleq tileLoop4_1
	tst r12,#0x0000FF00
	addne r1,r1,#0x20
	bleq tileLoop4_1
	tst r12,#0x00FF0000
	addne r1,r1,#0x20
	bleq tileLoop4_1
	tst r12,#0xFF000000
	addne r1,r1,#0x20
	bleq tileLoop4_1
	cmp r1,#0x2000
	bne tileLoop4_0

	ldmfd sp!,{r4-r12,pc}

tileLoop4_1:
	ldr r0,[r5,r1]

	ands r3,r0,#0x000000FF
	ldrne r3,[r6,r3,lsl#2]
	ands r2,r0,#0x0000FF00
	ldrne r2,[r6,r2,lsr#6]
	orrne r3,r3,r2,lsl#1

	str r3,[r8,r1,lsl#1]
	str r3,[r9,r1,lsl#1]
	orr r3,r3,r10
	str r3,[r7,r1,lsl#1]
	add r1,r1,#2

	ands r3,r0,#0x00FF0000
	ldrne r3,[r6,r3,lsr#14]
	ands r2,r0,#0xFF000000
	ldrne r2,[r6,r2,lsr#22]
	orrne r3,r3,r2,lsl#1

	str r3,[r8,r1,lsl#1]
	str r3,[r9,r1,lsl#1]
	orr r3,r3,r10
	str r3,[r7,r1,lsl#1]
	add r1,r1,#2

	tst r1,#0x1C
	bne tileLoop4_1

	bx lr

;@-------------------------------------------------------------------------------
;@ bgChrFinish	;end of frame...
;@-------------------------------------------------------------------------------
;@	ldr r5,=0xFE00FE00
;@ MSB          LSB
;@ hvbppppnnnnnnnnn
bgColor:
	ldrb r1,[geptr,#wsvMapTblAdr]
	and r1,r1,#0x07
	add r1,r10,r1,lsl#11
	stmfd sp!,{lr}
	bl bgm16Start
	ldmfd sp!,{lr}

	ldrb r1,[geptr,#wsvMapTblAdr]
	and r1,r1,#0x70
	add r1,r10,r1,lsl#7

bgm16Start:
	mov r2,#0x400
bgm16Loop:
	ldr r3,[r1],#4				;@ Read from WonderSwan Tilemap RAM

	and r4,r5,r3				;@ Mask out palette, flip & bank
	bic r3,r3,r5
	orr r4,r4,r4,lsr#7			;@ Switch palette vs flip + bank
	and r4,r5,r4,lsl#3			;@ Mask again
	orr r3,r3,r4				;@ Add palette, flip + bank.

	str r3,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, background
	subs r2,r2,#2
	bne bgm16Loop

	bx lr

;@-------------------------------------------------------------------------------
;@ bgChrFinish	;end of frame...
;@-------------------------------------------------------------------------------
;@	ldr r5,=0xFE00FE00
;@	ldr r6,=0x00010001
;@ MSB          LSB
;@ hvbppppnnnnnnnnn
bgMono:
	ldrb r1,[geptr,#wsvMapTblAdr]
	and r1,r1,#0x03
	add r1,r10,r1,lsl#11
	stmfd sp!,{lr}
	bl bgm4Start
	ldmfd sp!,{lr}

	ldrb r1,[geptr,#wsvMapTblAdr]
	and r1,r1,#0x30
	add r1,r10,r1,lsl#7

bgm4Start:
	mov r2,#0x400
bgm4Loop:
	ldr r3,[r1],#4				;@ Read from WonderSwan Tilemap RAM

	and r4,r5,r3				;@ Mask out palette, flip & bank
	bic r3,r3,r5
	orr r4,r4,r4,lsr#7			;@ Switch palette vs flip + bank
	and r4,r5,r4,lsl#3			;@ Mask again
	orr r3,r3,r4				;@ Add palette, flip + bank.
	and r4,r3,r6,lsl#14			;@ Mask out palette bit 3
	orr r3,r3,r4,lsr#5			;@ Add as bank bit (GBA/NDS)

	str r3,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, background
	subs r2,r2,#2
	bne bgm4Loop

	bx lr

;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r6}
	ldr r1,[geptr,#scrollBuff]

	mov r2,#(SCREEN_HEIGHT-GAME_HEIGHT)/2
	add r0,r0,r2,lsl#3			;@ 8 bytes per row
	mov r3,#0x100-(SCREEN_WIDTH-GAME_WIDTH)/2
	sub r3,r3,r2,lsl#16
	ldr r4,=0x00FF00FF
	mov r2,#GAME_HEIGHT
setScrlLoop:
	ldr r5,[r1],#4
	mov r6,r5,lsr#16
	mov r5,r5,lsl#16
	orr r6,r6,r6,lsl#8
	orr r5,r5,r5,lsr#8
	and r6,r4,r6
	and r5,r4,r5,lsr#8
	add r6,r6,r3
	add r5,r5,r3
	stmia r0!,{r5,r6}
	subs r2,r2,#1
	bne setScrlLoop

	ldmfd sp!,{r4-r6}
	bx lr

;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x400		;@ 0x400=AGB OBJ priority 1
;@----------------------------------------------------------------------------
wsvConvertSprites:			;@ in r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,lr}

	ldr r1,[geptr,#gfxRAM]
	ldrb r2,[geptr,#wsvSprTblAdr]
	and r2,r2,#0x3F
	add r1,r1,r2,lsl#9
	ldrb r2,[geptr,#wsvSpriteStart]	;@ First sprite
//	and r2,r2,#0x7F
	add r1,r1,r2,lsl#2

	ldrb r7,[geptr,#wsvSpriteEnd]	;@ Last sprite
//	and r7,r7,#0x7F
	subs r7,r7,r2
	movmi r7,#0
	rsb r6,r7,#128				;@ Max number of sprites minus used.
	ble skipSprites

	mov r2,#(SCREEN_WIDTH-GAME_WIDTH)/2		;@ GBA/NDS X offset
	mov r5,#(SCREEN_HEIGHT-GAME_HEIGHT)/2	;@ GBA/NDS Y offset
	orr r5,r2,r5,lsl#24
dm5:
	ldr r2,[r1],#4				;@ WonderSwan OBJ, r0=Tile,Attrib,Ypos,Xpos.
	add r3,r5,r2,lsl#8
	mov r3,r3,lsr#24			;@ Ypos
	mov r4,r2,lsr#24			;@ Xpos
	cmp r4,#240
	addpl r4,r4,#0x100
	add r4,r4,r5
	mov r4,r4,lsl#23
	orr r3,r3,r4,lsr#7
	and r4,r2,#0xC000
	orr r3,r3,r4,lsl#14			;@ Flip

	str r3,[r0],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r3,r2,lsl#23
	mov r3,r3,lsr#23
	and r4,r2,#0x0E00			;@ Palette
	orr r3,r3,r4,lsl#3
	tst r2,#0x2000				;@ Priority
	orreq r3,r3,#PRIORITY

	strh r3,[r0],#4				;@ Store OBJ Atr 2. Pattern, palette.
	subs r7,r7,#1
	bne dm5
skipSprites:
	mov r2,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
skipSprLoop:
	str r2,[r0],#8
	subs r6,r6,#1
	bhi skipSprLoop
	ldmfd sp!,{r4-r7,pc}

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
CHR_DECODE:
	.space 0x400
SCROLL_BUFF:
	.space 160*4

#endif // #ifdef __arm__
