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
wsVideoReset:		;@ r0=frameIrqFunc, r1=hIrqFunc, r2=ram+LUTs, r3=HWType 1=mono, r12=geptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	mov r0,geptr
	ldr r1,=wsVideoSize/4
	bl memclr_					;@ Clear WSVideo state

//	ldr r0,=DIRTYTILES
//	mov r1,#0
//	mov r2,#0x800
//	bl memset

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
	cmp r3,#HW_ASWAN
	movne r0,#0xC0				;@ Use Color mode.
	moveq r0,#0x00				;@ Use B&W mode.
//	strb r0,[geptr,#wsvVideoMode]

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
	and r1,r0,#0x000000FF		;@ H start
	and r2,r0,#0x00FF0000		;@ H end
	cmp r1,#GAME_WIDTH
	movpl r1,#GAME_WIDTH
	add r1,r1,#(SCREEN_WIDTH-GAME_WIDTH)/2
	cmp r2,#GAME_WIDTH<<16
	movpl r2,#GAME_WIDTH<<16
	add r2,r2,#((SCREEN_WIDTH-GAME_WIDTH)/2)<<16
	orr r1,r1,r2,lsl#8
	mov r1,r1,ror#24
	strh r1,[geptr,#windowData]

	and r1,r0,#0x0000FF00		;@ V start
	mov r2,r0,lsr#24			;@ V size
	cmp r1,#GAME_HEIGHT<<8
	movpl r1,#GAME_HEIGHT<<8
	add r1,r1,#((SCREEN_HEIGHT-GAME_HEIGHT)/2)<<8
	cmp r2,#GAME_HEIGHT
	movpl r2,#GAME_HEIGHT
	add r2,r2,#(SCREEN_HEIGHT-GAME_HEIGHT)/2
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
	.long wsvRegR				;@ 0x00 Display control
	.long wsvRegR				;@ 0x01 Background color
	.long wsvVCountR			;@ 0x02 Current scan line
	.long wsvRegR				;@ 0x03 Scan line compare
	.long wsvRegR				;@ 0x04 Sprite table address
	.long wsvRegR				;@ 0x05 Sprite to start with
	.long wsvRegR				;@ 0x06 Sprite count
	.long wsvRegR				;@ 0x07 Map table address
	.long wsvRegR				;@ 0x08 Window X-Position
	.long wsvRegR				;@ 0x09 Window Y-Position
	.long wsvRegR				;@ 0x0A Window X-Size
	.long wsvRegR				;@ 0x0B Window Y-Size
	.long wsvRegR				;@ 0x0C Sprite window X-Position
	.long wsvRegR				;@ 0x0D Sprite window Y-Position
	.long wsvRegR				;@ 0x0E Sprite window X-Size
	.long wsvRegR				;@ 0x0F Sprite window Y-Size

	.long wsvRegR				;@ 0x10 Bg scroll X
	.long wsvRegR				;@ 0x11 Bg scroll Y
	.long wsvRegR				;@ 0x12 Fg scroll X
	.long wsvRegR				;@ 0x13 Fg scroll Y
	.long wsvRegR				;@ 0x14 LCD control (on/off?)
	.long wsvRegR				;@ 0x15 LCD icons
	.long wsvRegR				;@ 0x16 Total scan lines
	.long wsvRegR				;@ 0x17 Vsync line
	.long wsvWSUnmappedR		;@ 0x18 ---
	.long wsvWSUnmappedR		;@ 0x19 ---
	.long wsvUnknownR			;@ 0x1A ???
	.long wsvWSUnmappedR		;@ 0x1B ---
	.long wsvRegR				;@ 0x1C Pal mono pool 0
	.long wsvRegR				;@ 0x1D Pal mono pool 1
	.long wsvRegR				;@ 0x1E Pal mono pool 2
	.long wsvRegR				;@ 0x1F Pal mono pool 3

	.long wsvRegR				;@ 0x20 Pal mono
	.long wsvRegR				;@ 0x21
	.long wsvRegR				;@ 0x22
	.long wsvRegR				;@ 0x23
	.long wsvRegR				;@ 0x24
	.long wsvRegR				;@ 0x25
	.long wsvRegR				;@ 0x26
	.long wsvRegR				;@ 0x27
	.long wsvRegR				;@ 0x28
	.long wsvRegR				;@ 0x29
	.long wsvRegR				;@ 0x2A
	.long wsvRegR				;@ 0x2B
	.long wsvRegR				;@ 0x2C
	.long wsvRegR				;@ 0x2D
	.long wsvRegR				;@ 0x2E
	.long wsvRegR				;@ 0x2F

	.long wsvRegR				;@ 0x30
	.long wsvRegR				;@ 0x31
	.long wsvRegR				;@ 0x32
	.long wsvRegR				;@ 0x33
	.long wsvRegR				;@ 0x34
	.long wsvRegR				;@ 0x35
	.long wsvRegR				;@ 0x36
	.long wsvRegR				;@ 0x37
	.long wsvRegR				;@ 0x38
	.long wsvRegR				;@ 0x39
	.long wsvRegR				;@ 0x3A
	.long wsvRegR				;@ 0x3B
	.long wsvRegR				;@ 0x3C
	.long wsvRegR				;@ 0x3D
	.long wsvRegR				;@ 0x3E
	.long wsvRegR				;@ 0x3F
			;@ DMA registers, only WSC
	.long wsvRegR				;@ 0x40 DMA source
	.long wsvRegR				;@ 0x41 DMA source
	.long wsvRegR				;@ 0x42 DMA source
	.long wsvWSUnmappedR		;@ 0x43 ---
	.long wsvRegR				;@ 0x44 DMA destination
	.long wsvRegR				;@ 0x45 DMA destination
	.long wsvRegR				;@ 0x46 DMA length
	.long wsvRegR				;@ 0x47 DMA length
	.long wsvImportantR			;@ 0x48 DMA control
	.long wsvWSUnmappedR		;@ 0x49 ---
	.long wsvRegR				;@ 0x4A Sound DMA source
	.long wsvRegR				;@ 0x4B Sound DMA source
	.long wsvRegR				;@ 0x4C Sound DMA source
	.long wsvWSUnmappedR		;@ 0x4D ---
	.long wsvRegR				;@ 0x4E Sound DMA length
	.long wsvRegR				;@ 0x4F Sound DMA length

	.long wsvRegR				;@ 0x50 Sound DMA length
	.long wsvWSUnmappedR		;@ 0x51 ---
	.long wsvRegR				;@ 0x52 Sound DMA control
	.long wsvWSUnmappedR		;@ 0x53 ---
	.long wsvWSUnmappedR		;@ 0x54 ---
	.long wsvWSUnmappedR		;@ 0x55 ---
	.long wsvWSUnmappedR		;@ 0x56 ---
	.long wsvWSUnmappedR		;@ 0x57 ---
	.long wsvWSUnmappedR		;@ 0x58 ---
	.long wsvWSUnmappedR		;@ 0x59 ---
	.long wsvWSUnmappedR		;@ 0x5A ---
	.long wsvWSUnmappedR		;@ 0x5B ---
	.long wsvWSUnmappedR		;@ 0x5C ---
	.long wsvWSUnmappedR		;@ 0x5D ---
	.long wsvWSUnmappedR		;@ 0x5E ---
	.long wsvWSUnmappedR		;@ 0x5F ---

	.long wsvRegR				;@ 0x60 Display mode
	.long wsvWSUnmappedR		;@ 0x61 ---
	.long wsvImportantR			;@ 0x62 WSC System / Power
	.long wsvWSUnmappedR		;@ 0x63 ---
	.long wsvWSUnmappedR		;@ 0x64 ---
	.long wsvWSUnmappedR		;@ 0x65 ---
	.long wsvWSUnmappedR		;@ 0x66 ---
	.long wsvWSUnmappedR		;@ 0x67 ---
	.long wsvWSUnmappedR		;@ 0x68 ---
	.long wsvWSUnmappedR		;@ 0x69 ---
	.long wsvImportantR			;@ 0x6A Hyper control
	.long wsvImportantR			;@ 0x6B Hyper Chan control
	.long wsvWSUnmappedR		;@ 0x6C ---
	.long wsvWSUnmappedR		;@ 0x6D ---
	.long wsvWSUnmappedR		;@ 0x6E ---
	.long wsvWSUnmappedR		;@ 0x6F ---

	.long wsvImportantR			;@ 0x70 Unknown70
	.long wsvImportantR			;@ 0x71 Unknown71
	.long wsvImportantR			;@ 0x72 Unknown72
	.long wsvImportantR			;@ 0x73 Unknown73
	.long wsvImportantR			;@ 0x74 Unknown74
	.long wsvImportantR			;@ 0x75 Unknown75
	.long wsvImportantR			;@ 0x76 Unknown76
	.long wsvImportantR			;@ 0x77 Unknown77
	.long wsvWSUnmappedR		;@ 0x78 ---
	.long wsvWSUnmappedR		;@ 0x79 ---
	.long wsvWSUnmappedR		;@ 0x7A ---
	.long wsvWSUnmappedR		;@ 0x7B ---
	.long wsvWSUnmappedR		;@ 0x7C ---
	.long wsvWSUnmappedR		;@ 0x7D ---
	.long wsvWSUnmappedR		;@ 0x7E ---
	.long wsvWSUnmappedR		;@ 0x7F ---

	.long wsvRegR				;@ 0x80 Sound Registers
	.long wsvRegR				;@ 0x81
	.long wsvRegR				;@ 0x82
	.long wsvRegR				;@ 0x83
	.long wsvRegR				;@ 0x84
	.long wsvRegR				;@ 0x85
	.long wsvRegR				;@ 0x86
	.long wsvRegR				;@ 0x87
	.long wsvRegR				;@ 0x88
	.long wsvRegR				;@ 0x89
	.long wsvRegR				;@ 0x8A
	.long wsvRegR				;@ 0x8B
	.long wsvRegR				;@ 0x8C
	.long wsvRegR				;@ 0x8D
	.long wsvRegR				;@ 0x8E
	.long wsvRegR				;@ 0x8F

	.long wsvRegR				;@ 0x90
	.long wsvRegR				;@ 0x91
	.long wsvImportantR			;@ 0x92 Noise LFSR value low
	.long wsvImportantR			;@ 0x93 Noise LFSR value high
	.long wsvRegR				;@ 0x94
	.long wsvRegR				;@ 0x95
	.long wsvRegR				;@ 0x96
	.long wsvRegR				;@ 0x97
	.long wsvRegR				;@ 0x98
	.long wsvRegR				;@ 0x99
	.long wsvRegR				;@ 0x9A
	.long wsvRegR				;@ 0x9B
	.long wsvRegR				;@ 0x9C
	.long wsvRegR				;@ 0x9D
	.long wsvRegR				;@ 0x9E
	.long wsvWSUnmappedR		;@ 0x9F ---

	.long wsvHWTypeR			;@ 0xA0 Color or mono HW
	.long wsvWSUnmappedR		;@ 0xA1 ---
	.long wsvRegR				;@ 0xA2 Timer Control
	.long wsvUnknownR			;@ 0xA3 ???
	.long wsvRegR				;@ 0xA4 HBlankTimer low
	.long wsvRegR				;@ 0xA5 HBlankTimer high
	.long wsvRegR				;@ 0xA6 VBlankTimer low
	.long wsvRegR				;@ 0xA7 VBlankTimer high
	.long wsvRegR				;@ 0xA8 HBlankTimer counter low
	.long wsvRegR				;@ 0xA9 HBlankTimer counter high
	.long wsvRegR				;@ 0xAA VBlankTimer counter low
	.long wsvRegR				;@ 0xAB VBlankTimer counter high
	.long wsvUnknownR			;@ 0xAC ???
	.long wsvWSUnmappedR		;@ 0xAD ---
	.long wsvWSUnmappedR		;@ 0xAE ---
	.long wsvWSUnmappedR		;@ 0xAF ---

	.long wsvRegR				;@ 0xB0 Interrupt base
	.long wsvRegR				;@ 0xB1 Serial data
	.long wsvRegR				;@ 0xB2 Interrupt enable
	.long wsvSerialStatusR		;@ 0xB3 Serial status
	.long wsvRegR				;@ 0xB4 Interrupt status
	.long IOPortA_R				;@ 0xB5 keypad
	.long wsvZeroR				;@ 0xB6 Interrupt acknowledge
	.long wsvUnknownR			;@ 0xB7 ???
	.long wsvWSUnmappedR		;@ 0xB8 ---
	.long wsvWSUnmappedR		;@ 0xB9 ---
	.long intEepromDataLowR		;@ 0xBA int-eeprom data low
	.long intEepromDataHighR	;@ 0xBB int-eeprom data high
	.long intEepromAdrLowR		;@ 0xBC int-eeprom address low
	.long intEepromAdrHighR		;@ 0xBD int-eeprom address high
	.long intEepromStatusR		;@ 0xBE int-eeprom status
	.long wsvUnknownR			;@ 0xBF ???

;@----------------------------------------------------------------------------
;@Cartridge
;@----------------------------------------------------------------------------

	.long wsvRegR				;@ 0xC0 Bank ROM 0x40000-0xF0000
	.long wsvRegR				;@ 0xC1 Bank SRAM 0x10000
	.long wsvRegR				;@ 0xC2 Bank ROM 0x20000
	.long wsvRegR				;@ 0xC3 Bank ROM 0x30000
	.long extEepromDataLowR		;@ 0xC4 ext-eeprom data low
	.long extEepromDataHighR	;@ 0xC5 ext-eeprom data high
	.long extEepromAdrLowR		;@ 0xC6 ext-eeprom address low
	.long extEepromAdrHighR		;@ 0xC7 ext-eeprom address high
	.long extEepromStatusR		;@ 0xC8 ext-eeprom status
	.long wsvUnknownR			;@ 0xC9 ???
	.long wsvImportantR			;@ 0xCA RTC status
	.long wsvImportantR			;@ 0xCB RTC read
	.long wsvImportantR			;@ 0xCC General purpose input/output enable, bit 3-0.
	.long wsvImportantR			;@ 0xCD General purpose input/output data, bit 3-0.
	.long wsvImportantR			;@ 0xCE WonderWitch flash
	.long wsvUnknownR			;@ 0xCF ???

	.long wsvUnknownR			;@ 0xD0 ???
	.long wsvUnknownR			;@ 0xD1 ???
	.long wsvUnknownR			;@ 0xD2 ???
	.long wsvUnknownR			;@ 0xD3 ???
	.long wsvUnknownR			;@ 0xD4 ???
	.long wsvUnknownR			;@ 0xD5 ???
	.long wsvUnknownR			;@ 0xD6 ???
	.long wsvUnknownR			;@ 0xD7 ???
	.long wsvUnknownR			;@ 0xD8 ???
	.long wsvUnknownR			;@ 0xD9 ???
	.long wsvUnknownR			;@ 0xDA ???
	.long wsvUnknownR			;@ 0xDB ???
	.long wsvUnknownR			;@ 0xDC ???
	.long wsvUnknownR			;@ 0xDD ???
	.long wsvUnknownR			;@ 0xDE ???
	.long wsvUnknownR			;@ 0xDF ???

	.long wsvUnknownR			;@ 0xE0 ???
	.long wsvUnknownR			;@ 0xE1 ???
	.long wsvUnknownR			;@ 0xE2 ???
	.long wsvUnknownR			;@ 0xE3 ???
	.long wsvUnknownR			;@ 0xE4 ???
	.long wsvUnknownR			;@ 0xE5 ???
	.long wsvUnknownR			;@ 0xE6 ???
	.long wsvUnknownR			;@ 0xE7 ???
	.long wsvUnknownR			;@ 0xE8 ???
	.long wsvUnknownR			;@ 0xE9 ???
	.long wsvUnknownR			;@ 0xEA ???
	.long wsvUnknownR			;@ 0xEB ???
	.long wsvUnknownR			;@ 0xEC ???
	.long wsvUnknownR			;@ 0xED ???
	.long wsvUnknownR			;@ 0xEE ???
	.long wsvUnknownR			;@ 0xEF ???

	.long wsvUnknownR			;@ 0xF0 ???
	.long wsvUnknownR			;@ 0xF1 ???
	.long wsvUnknownR			;@ 0xF2 ???
	.long wsvUnknownR			;@ 0xF3 ???
	.long wsvUnknownR			;@ 0xF4 ???
	.long wsvUnknownR			;@ 0xF5 ???
	.long wsvUnknownR			;@ 0xF6 ???
	.long wsvUnknownR			;@ 0xF7 ???
	.long wsvUnknownR			;@ 0xF8 ???
	.long wsvUnknownR			;@ 0xF9 ???
	.long wsvUnknownR			;@ 0xFA ???
	.long wsvUnknownR			;@ 0xFB ???
	.long wsvUnknownR			;@ 0xFC ???
	.long wsvUnknownR			;@ 0xFD ???
	.long wsvUnknownR			;@ 0xFE ???
	.long wsvUnknownR			;@ 0xFF ???
;@----------------------------------------------------------------------------
wsvUnknownR:
;@----------------------------------------------------------------------------
	mov r11,r11				;@ No$GBA breakpoint
	ldr r2,=0x826EBAD0
;@----------------------------------------------------------------------------
wsvWSUnmappedR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r2,=debugIOUnimplR
	blx r2
	ldmfd sp!,{lr}
	mov r0,#0x90
	bx lr
;@----------------------------------------------------------------------------
wsvZeroR:
;@----------------------------------------------------------------------------
wsvWSCUnmappedR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r2,=debugIOUnimplR
	blx r2
	ldmfd sp!,{lr}
	mov r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
wsvImportantR:
	mov r11,r11				;@ No$GBA breakpoint
	stmfd sp!,{r0,geptr,lr}
	ldr r2,=debugIOUnimplR
	blx r2
	ldmfd sp!,{r0,geptr,lr}
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
wsvHWTypeR:					;@ 0xA0
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvHardwareType]
	ldrb r1,[geptr,#wsvMachine]
	cmp r1,#HW_ASWAN
	orrne r0,r0,#2
	bx lr
;@----------------------------------------------------------------------------
wsvSerialStatusR:			;@ 0xB3
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvSerialStatus]
	orr r0,r0,#4			;@ Hack, send buffer always empty
	bx lr

;@----------------------------------------------------------------------------
wsvBnk0SlctR:				;@ 0xC0
;@----------------------------------------------------------------------------
	ldrb r0,[geptr,#wsvBnk0Slct]
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
	.long wsvSpriteFirstW		;@ 0x05 Sprite to start with
	.long wsvRegW				;@ 0x06 Sprite count
	.long wsvRegW				;@ 0x07 Map table address
	.long wsvRegW				;@ 0x08 Window X-Position
	.long wsvRegW				;@ 0x09 Window Y-Position
	.long wsvRegW				;@ 0x0A Window X-Size
	.long wsvRegW				;@ 0x0B Window Y-Size
	.long wsvRegW				;@ 0x0C Sprite window X-Position
	.long wsvRegW				;@ 0x0D Sprite window Y-Position
	.long wsvRegW				;@ 0x0E Sprite window X-Size
	.long wsvRegW				;@ 0x0F Sprite window Y-Size

	.long wsvBgScrXW			;@ 0x10 Bg scroll X
	.long wsvBgScrYW			;@ 0x11 Bg scroll Y
	.long wsvFgScrXW			;@ 0x12 Fg scroll X
	.long wsvFgScrYW			;@ 0x13 Fg scroll Y
	.long wsvRegW				;@ 0x14 LCD control (on/off?)
	.long wsvRegW				;@ 0x15 LCD icons
	.long wsvRegW				;@ 0x16 Total scan lines
	.long wsvRegW				;@ 0x17 Vsync line
	.long wsvUnmappedW			;@ 0x18 ---
	.long wsvUnmappedW			;@ 0x19 ---
	.long wsvUnknownW			;@ 0x1A ???
	.long wsvUnmappedW			;@ 0x1B ---
	.long wsvRegW				;@ 0x1C Pal mono pool 0
	.long wsvRegW				;@ 0x1D Pal mono pool 1
	.long wsvRegW				;@ 0x1E Pal mono pool 2
	.long wsvRegW				;@ 0x1F Pal mono pool 3

	.long wsvRegW				;@ 0x20 Pal mono 0 low
	.long wsvRegW				;@ 0x21 Pal mono 0 high
	.long wsvRegW				;@ 0x22 Pal mono 1 low
	.long wsvRegW				;@ 0x23 Pal mono 1 high
	.long wsvRegW				;@ 0x24 Pal mono 2 low
	.long wsvRegW				;@ 0x25 Pal mono 2 high
	.long wsvRegW				;@ 0x26 Pal mono 3 low
	.long wsvRegW				;@ 0x27 Pal mono 3 high
	.long wsvRegW				;@ 0x28 Pal mono 4 low
	.long wsvRegW				;@ 0x29 Pal mono 4 high
	.long wsvRegW				;@ 0x2A Pal mono 5 low
	.long wsvRegW				;@ 0x2B Pal mono 5 high
	.long wsvRegW				;@ 0x2C Pal mono 6 low
	.long wsvRegW				;@ 0x2D Pal mono 6 high
	.long wsvRegW				;@ 0x2E Pal mono 7 low
	.long wsvRegW				;@ 0x2F Pal mono 7 high

	.long wsvRegW				;@ 0x30 Pal mono 8 low
	.long wsvRegW				;@ 0x31 Pal mono 8 high
	.long wsvRegW				;@ 0x32 Pal mono 9 low
	.long wsvRegW				;@ 0x33 Pal mono 9 high
	.long wsvRegW				;@ 0x34 Pal mono A low
	.long wsvRegW				;@ 0x35 Pal mono A high
	.long wsvRegW				;@ 0x36 Pal mono B low
	.long wsvRegW				;@ 0x37 Pal mono B high
	.long wsvRegW				;@ 0x38 Pal mono C low
	.long wsvRegW				;@ 0x39 Pal mono C high
	.long wsvRegW				;@ 0x3A Pal mono D low
	.long wsvRegW				;@ 0x3B Pal mono D high
	.long wsvRegW				;@ 0x3C Pal mono E low
	.long wsvRegW				;@ 0x3D Pal mono E high
	.long wsvRegW				;@ 0x3E Pal mono F low
	.long wsvRegW				;@ 0x3F Pal mono F high
			;@ DMA registers, only WSC
	.long wsvRegW				;@ 0x40	DMA source
	.long wsvRegW				;@ 0x41 DMA src
	.long wsvRegW				;@ 0x42 DMA src
	.long wsvRegW				;@ 0x43 ---
	.long wsvRegW				;@ 0x44 DMA destination
	.long wsvRegW				;@ 0x45 DMA dst
	.long wsvRegW				;@ 0x46 DMA length
	.long wsvRegW				;@ 0x47 DMA len
	.long wsvDMAStartW			;@ 0x48 DMA control
	.long wsvUnmappedW			;@ 0x49 ---
	.long wsvRegW				;@ 0x4A	Sound DMA source
	.long wsvRegW				;@ 0x4B Sound DMA src
	.long wsvRegW				;@ 0x4C Sound DMA src
	.long wsvUnmappedW			;@ 0x4D ---
	.long wsvRegW				;@ 0x4E Sound DMA length
	.long wsvRegW				;@ 0x4F Sound DMA len

	.long wsvRegW				;@ 0x50 Sound DMA len
	.long wsvUnmappedW			;@ 0x51 ---
	.long wsvRegW				;@ 0x52 Sound DMA control
	.long wsvUnmappedW			;@ 0x53 ---
	.long wsvUnmappedW			;@ 0x54 ---
	.long wsvUnmappedW			;@ 0x55 ---
	.long wsvUnmappedW			;@ 0x56 ---
	.long wsvUnmappedW			;@ 0x57 ---
	.long wsvUnmappedW			;@ 0x58 ---
	.long wsvUnmappedW			;@ 0x59 ---
	.long wsvUnmappedW			;@ 0x5A ---
	.long wsvUnmappedW			;@ 0x5B ---
	.long wsvUnmappedW			;@ 0x5C ---
	.long wsvUnmappedW			;@ 0x5D ---
	.long wsvUnmappedW			;@ 0x5E ---
	.long wsvUnmappedW			;@ 0x5F ---

	.long wsvRegW				;@ 0x60 Display mode
	.long wsvUnmappedW			;@ 0x61 ---
	.long wsvImportantW			;@ 0x62 SwanCrystal/Power off
	.long wsvUnmappedW			;@ 0x63 ---
	.long wsvUnmappedW			;@ 0x64 ---
	.long wsvUnmappedW			;@ 0x65 ---
	.long wsvUnmappedW			;@ 0x66 ---
	.long wsvUnmappedW			;@ 0x67 ---
	.long wsvUnmappedW			;@ 0x68 ---
	.long wsvUnmappedW			;@ 0x69 ---
	.long wsvImportantW			;@ 0x6A Hyper control
	.long wsvImportantW			;@ 0x6B Hyper Chan control
	.long wsvUnmappedW			;@ 0x6C ---
	.long wsvUnmappedW			;@ 0x6D ---
	.long wsvUnmappedW			;@ 0x6E ---
	.long wsvUnmappedW			;@ 0x6F ---

	.long wsvReadOnlyW			;@ 0x70 Unknown70
	.long wsvReadOnlyW			;@ 0x71 Unknown71
	.long wsvReadOnlyW			;@ 0x72 Unknown72
	.long wsvReadOnlyW			;@ 0x73 Unknown73
	.long wsvReadOnlyW			;@ 0x74 Unknown74
	.long wsvReadOnlyW			;@ 0x75 Unknown75
	.long wsvReadOnlyW			;@ 0x76 Unknown76
	.long wsvReadOnlyW			;@ 0x77 Unknown77
	.long wsvUnmappedW			;@ 0x78 ---
	.long wsvUnmappedW			;@ 0x79 ---
	.long wsvUnmappedW			;@ 0x7A ---
	.long wsvUnmappedW			;@ 0x7B ---
	.long wsvUnmappedW			;@ 0x7C ---
	.long wsvUnmappedW			;@ 0x7D ---
	.long wsvUnmappedW			;@ 0x7E ---
	.long wsvUnmappedW			;@ 0x7F ---

	.long wsvRegW				;@ 0x80 Sound Ch1 pitch low
	.long wsvRegW				;@ 0x81 Sound Ch1 pitch high
	.long wsvRegW				;@ 0x82 Sound Ch2 pitch low
	.long wsvRegW				;@ 0x83 Sound Ch2 pitch high
	.long wsvRegW				;@ 0x84 Sound Ch3 pitch low
	.long wsvRegW				;@ 0x85 Sound Ch3 pitch high
	.long wsvRegW				;@ 0x86 Sound Ch4 pitch low
	.long wsvRegW				;@ 0x87 Sound Ch4 pitch high
	.long wsvRegW				;@ 0x88 Sound Ch1 volume
	.long wsvRegW				;@ 0x89 Sound Ch2 volume
	.long wsvRegW				;@ 0x8A Sound Ch3 volume
	.long wsvRegW				;@ 0x8B Sound Ch4 volume
	.long wsvRegW				;@ 0x8C Sweeep value
	.long wsvRegW				;@ 0x8D Sweep time
	.long wsvRegW				;@ 0x8E Noise control
	.long wsvRegW				;@ 0x8F Wave base

	.long wsvRegW				;@ 0x90 Sound control
	.long wsvRegW				;@ 0x91 Sound output
	.long wsvReadOnlyW			;@ 0x92 Noise LFSR value low
	.long wsvReadOnlyW			;@ 0x93 Noise LFSR value high
	.long wsvRegW				;@ 0x94 Sound voice control
	.long wsvRegW				;@ 0x95 Sound Hyper voice
	.long wsvImportantW			;@ 0x96 SND9697
	.long wsvImportantW			;@ 0x97 SND9697
	.long wsvImportantW			;@ 0x98 SND9899
	.long wsvImportantW			;@ 0x99 SND9899
	.long wsvReadOnlyW			;@ 0x9A
	.long wsvReadOnlyW			;@ 0x9B
	.long wsvReadOnlyW			;@ 0x9C
	.long wsvReadOnlyW			;@ 0x9D
	.long wsvReadOnlyW			;@ 0x9E
	.long wsvUnmappedW			;@ 0x9F ---

	.long wsvHW					;@ 0xA0 Hardware type, HW_ASWAN / HW_SPHINX.
	.long wsvUnmappedW			;@ 0xA1 ---
	.long wsvRegW				;@ 0xA2 Timer control
	.long wsvUnknownW			;@ 0xA3 ???
	.long wsvHTimerLowW			;@ 0xA4 HBlank timer low
	.long wsvHTimerHighW		;@ 0xA5 HBlank timer high
	.long wsvVTimerLowW			;@ 0xA6 VBlank timer low
	.long wsvVTimerHighW		;@ 0xA7 VBlank timer high
	.long wsvReadOnlyW			;@ 0xA8 HBlank counter low
	.long wsvReadOnlyW			;@ 0xA9 HBlank counter high
	.long wsvReadOnlyW			;@ 0xAA VBlank counter low
	.long wsvReadOnlyW			;@ 0xAB VBlank counter high
	.long wsvUnknownW			;@ 0xAC ???
	.long wsvUnmappedW			;@ 0xAD ---
	.long wsvUnmappedW			;@ 0xAE ---
	.long wsvUnmappedW			;@ 0xAF ---

	.long wsvRegW				;@ 0xB0 Interrupt base
	.long wsvRegW				;@ 0xB1 Serial data
	.long wsvRegW				;@ 0xB2 Interrupt enable
	.long wsvImportantW			;@ 0xB3 Serial status
	.long wsvReadOnlyW			;@ 0xB4 Interrupt status
	.long wsvRegW				;@ 0xB5 Input Controls
	.long wsvIntAckW			;@ 0xB6 Interrupt acknowledge
	.long wsvUnknownW			;@ 0xB7 ???
	.long wsvUnmappedW			;@ 0xB8 ---
	.long wsvUnmappedW			;@ 0xB9 ---
	.long intEepromDataLowW		;@ 0xBA int-eeprom data low
	.long intEepromDataHighW	;@ 0xBB int-eeprom data high
	.long intEepromAdrLowW		;@ 0xBC int-eeprom address low
	.long intEepromAdrHighW		;@ 0xBD int-eeprom address high
	.long intEepromCommandW		;@ 0xBE int-eeprom command
	.long wsvUnknownW			;@ 0xBF ???

;@----------------------------------------------------------------------------
;@Cartridge
;@----------------------------------------------------------------------------

	.long BankSwitch4_F_W		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long wsvImportantW			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_W			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_W			;@ 0xC3 Bank switch 0x30000
	.long extEepromDataLowW		;@ 0xC4 ext-eeprom data low
	.long extEepromDataHighW	;@ 0xC5 ext-eeprom data high
	.long extEepromAdrLowW		;@ 0xC6 ext-eeprom address low
	.long extEepromAdrHighW		;@ 0xC7 ext-eeprom address high
	.long extEepromCommandW		;@ 0xC8 ext-eeprom command
	.long wsvUnknownW			;@ 0xC9 ???
	.long wsvImportantW			;@ 0xCA RTC command
	.long wsvImportantW			;@ 0xCB RTC data
	.long wsvImportantW			;@ 0xCC General purpose input/output enable, bit 3-0.
	.long wsvImportantW			;@ 0xCD General purpose input/output data, bit 3-0.
	.long wsvImportantW			;@ 0xCE WonderWitch flash
	.long wsvUnknownW			;@ 0xCF ???

	.long wsvUnknownW			;@ 0xD0 ???
	.long wsvUnknownW			;@ 0xD1 ???
	.long wsvUnknownW			;@ 0xD2 ???
	.long wsvUnknownW			;@ 0xD3 ???
	.long wsvUnknownW			;@ 0xD4 ???
	.long wsvUnknownW			;@ 0xD5 ???
	.long wsvUnknownW			;@ 0xD6 ???
	.long wsvUnknownW			;@ 0xD7 ???
	.long wsvUnknownW			;@ 0xD8 ???
	.long wsvUnknownW			;@ 0xD9 ???
	.long wsvUnknownW			;@ 0xDA ???
	.long wsvUnknownW			;@ 0xDB ???
	.long wsvUnknownW			;@ 0xDC ???
	.long wsvUnknownW			;@ 0xDD ???
	.long wsvUnknownW			;@ 0xDE ???
	.long wsvUnknownW			;@ 0xDF ???

	.long wsvUnknownW			;@ 0xE0 ???
	.long wsvUnknownW			;@ 0xE1 ???
	.long wsvUnknownW			;@ 0xE2 ???
	.long wsvUnknownW			;@ 0xE3 ???
	.long wsvUnknownW			;@ 0xE4 ???
	.long wsvUnknownW			;@ 0xE5 ???
	.long wsvUnknownW			;@ 0xE6 ???
	.long wsvUnknownW			;@ 0xE7 ???
	.long wsvUnknownW			;@ 0xE8 ???
	.long wsvUnknownW			;@ 0xE9 ???
	.long wsvUnknownW			;@ 0xEA ???
	.long wsvUnknownW			;@ 0xEB ???
	.long wsvUnknownW			;@ 0xEC ???
	.long wsvUnknownW			;@ 0xED ???
	.long wsvUnknownW			;@ 0xEE ???
	.long wsvUnknownW			;@ 0xEF ???

	.long wsvUnknownW			;@ 0xF0 ???
	.long wsvUnknownW			;@ 0xF1 ???
	.long wsvUnknownW			;@ 0xF2 ???
	.long wsvUnknownW			;@ 0xF3 ???
	.long wsvUnknownW			;@ 0xF4 ???
	.long wsvUnknownW			;@ 0xF5 ???
	.long wsvUnknownW			;@ 0xF6 ???
	.long wsvUnknownW			;@ 0xF7 ???
	.long wsvUnknownW			;@ 0xF8 ???
	.long wsvUnknownW			;@ 0xF9 ???
	.long wsvUnknownW			;@ 0xFA ???
	.long wsvUnknownW			;@ 0xFB ???
	.long wsvUnknownW			;@ 0xFC ???
	.long wsvUnknownW			;@ 0xFD ???
	.long wsvUnknownW			;@ 0xFE ???
	.long wsvUnknownW			;@ 0xFF ???

;@----------------------------------------------------------------------------
wsvUnknownW:
;@----------------------------------------------------------------------------
wsvImportantW:
	add r2,geptr,#wsvRegs
	strb r1,[r2,r0]
;@----------------------------------------------------------------------------
wsvReadOnlyW:
;@----------------------------------------------------------------------------
wsvUnmappedW:
;@----------------------------------------------------------------------------
	mov r11,r11				;@ No$GBA breakpoint
	ldr r2,=debugIOUnimplW
	bx r2
;@----------------------------------------------------------------------------
wsvRegW:
	add r2,geptr,#wsvRegs
	strb r1,[r2,r0]
	bx lr

;@----------------------------------------------------------------------------
wsvSpriteFirstW:			;@ 0x05, First Sprite
;@----------------------------------------------------------------------------
	and r1,r1,#0x7F
	strb r1,[geptr,#wsvSpriteFirst]
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
	and r0,r0,#0x81
	orr r1,r1,r0
	strb r1,[geptr,#wsvHardwareType]
	eor r0,r0,r1
	tst r1,#1			;@ Boot rom locked?
	bxeq lr
	mov r1,#0xff
	b BankSwitch4_F_W	;@ Map back cartridge.

;@----------------------------------------------------------------------------
wsvTimerCtrlW:			;@ 0xA2 Timer control
;@----------------------------------------------------------------------------
	strb r1,[geptr,#wsvTimerControl]
	tst r1,#1
	ldrhne r0,[geptr,#wsvHBlTimerFreq]
	strhne r0,[geptr,#wsvHBlCounter]
	tst r1,#4
	ldrhne r0,[geptr,#wsvVBlTimerFreq]
	strhne r0,[geptr,#wsvVBlCounter]
	bx lr
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
	tst r1,#0x40				;@ 4 bit planes?
	beq bgMono
	b bgColor

tMapRet:
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
midFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
//	bl wsvTransferVRAM
	bl wsvBufferWindows

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
endFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r0,=tmpOamBuffer		;@ Destination
	ldr r0,[r0]
	bl wsvConvertSprites
	ldrb r0,[geptr,#wsvVideoMode]
	adr lr,TransRet
	ands r0,r0,#0xE0
	tst r0,#0x40
	beq TransferVRAM4Planar
	tst r0,#0x20
	bne TransferVRAM16Packed
	b TransferVRAM16Planar
TransRet:
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r1,[geptr,#wsvBGXScroll]
	bl wsvBgScrXW
	ldmfd sp!,{lr}
	bl endFrameGfx

	ldrb r2,[geptr,#wsvInterruptStatus]
	ldrb r0,[geptr,#wsvTimerControl]
	tst r0,#0x4						;@ VBlank timer enabled?
	beq noTimerVblIrq
	ldrh r1,[geptr,#wsvVBlCounter]
	subs r1,r1,#1
	bmi noTimerVblIrq
	orreq r2,r2,#0x20				;@ #5 = VBlank timer
	eor r0,r0,#0x8
	tsteq r0,#0x8					;@ Repeat?
	ldrheq r1,[geptr,#wsvVBlTimerFreq]
	strh r1,[geptr,#wsvVBlCounter]
noTimerVblIrq:
	orr r2,r2,#0x40					;@ #6 = VBlank
	strb r2,[geptr,#wsvInterruptStatus]

	mov r0,#1
	ldmfd sp!,{lr}
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
	ldrb r2,[geptr,#wsvInterruptStatus]
	ldrb r1,[geptr,#wsvLineCompare]
	cmp r0,r1
	orreq r2,r2,#0x10				;@ #4 = Line compare

	ldrb r0,[geptr,#wsvTimerControl]
	tst r0,#0x1						;@ HBlank timer enabled?
	beq noTimerHblIrq
	ldrh r1,[geptr,#wsvHBlCounter]
	subs r1,r1,#1
	bmi noTimerHblIrq
	orreq r2,r2,#0x80				;@ #7 = HBlank timer
	eor r0,r0,#0x2
	tsteq r0,#0x2					;@ Repeat?
	ldrheq r1,[geptr,#wsvHBlTimerFreq]
	strh r1,[geptr,#wsvHBlCounter]
noTimerHblIrq:
	strb r2,[geptr,#wsvInterruptStatus]

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
TransferVRAM16Planar:
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
TransferVRAM4Planar:
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
	ldrb r2,[geptr,#wsvSpriteFirst]	;@ First sprite
	add r1,r1,r2,lsl#2

	ldrb r7,[geptr,#wsvSpriteCount]	;@ Sprite count
	cmp r7,#128
	movpl r7,#128
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
