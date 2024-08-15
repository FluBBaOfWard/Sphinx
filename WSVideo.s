//
//  WSVideo.s
//  Bandai WonderSwan Video emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2024 Fredrik Ahlström. All rights reserved.
//

#ifdef __arm__

#ifdef GBA
	#include "../Shared/gba_asm.h"
#elif NDS
	#include "../Shared/nds_asm.h"
#endif
#include "Sphinx.i"
#include "../ARMV30MZ/ARMV30MZ.i"

	.global wsVideoInit
	.global wsVideoReset
	.global wsvSetCartMap
	.global wsvSetIOPortOut
	.global wsvDoScanline
	.global wsvRead
	.global wsvRead16
	.global wsvWrite
	.global wsvWrite16
	.global sphinxSaveState
	.global sphinxLoadState
	.global sphinxGetStateSize
	.global copyScrollValues
	.global wsvConvertTileMaps
	.global wsvConvertSprites
	.global wsvRefW
	.global wsvGetInterruptVector
	.global wsvSetInterruptExternal
	.global wsvPushVolumeButton
	.global wsvSetHeadphones
	.global wsvSetLowBattery

	.syntax unified
	.arm

#ifdef GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For anything else
#endif
	.align 2
;@----------------------------------------------------------------------------
wsVideoInit:				;@ Only need to be called once
;@----------------------------------------------------------------------------
	ldr r0,=CHR_DECODE			;@ Destination 0x400
	mov r1,#0xffffff00			;@ Build chr decode tbl
chrLutLoop:
	movs r2,r1,lsl#31
	movne r2,#0x10000000
	orrcs r2,r2,#0x01000000
	tst r1,r1,lsl#29
	orrmi r2,r2,#0x00100000
	orrcs r2,r2,#0x00010000
	tst r1,r1,lsl#27
	orrmi r2,r2,#0x00001000
	orrcs r2,r2,#0x00000100
	tst r1,r1,lsl#25
	orrmi r2,r2,#0x00000010
	orrcs r2,r2,#0x00000001
	str r2,[r0],#4
	adds r1,r1,#1
	bne chrLutLoop

	bx lr
;@----------------------------------------------------------------------------
wsVideoReset:		;@ r0=IrqFunc, r1=machine, r2=ram+LUTs, r3=SOC 0=mono,1=color,2=crystal, r12=spxptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	mov r0,spxptr
	ldr r1,=sphinxSize/4
	bl memclr_					;@ Clear Sphinx state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia spxptr,{r0-r2}		;@ Reset scanline, nextChange & lineState
	str r0,[spxptr,#serialIRQCounter]

	ldmfd sp!,{r0-r3}
	strb r1,[spxptr,#wsvMachine]
	strb r3,[spxptr,#wsvSOC]
	cmp r0,#0
	adreq r0,dummyIrqFunc
	str r0,[spxptr,#irqFunction]

	str r2,[spxptr,#gfxRAM]
	add r0,r2,#0xFE00
	str r0,[spxptr,#paletteRAM]
	ldr r0,=DISP_BUFF
	str r0,[spxptr,#dispBuff]
	ldr r0,=WINDOW_BUFF
	str r0,[spxptr,#windowBuff]
	ldr r0,=SCROLL_BUFF
	str r0,[spxptr,#scrollBuff]

	mov r0,r3
	bl wsvInitIOMap

	ldmfd sp!,{lr}
	b wsvRegistersReset

dummyIrqFunc:
	bx lr
;@----------------------------------------------------------------------------
wsvSetPowerOff:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0
	ldr r1,=powerIsOn
	strb r0,[r1]

	bl wsvRegistersReset
	ldrb r0,[spxptr,#wsvSystemCtrl3]
	orr r0,r0,#1
	strb r0,[spxptr,#wsvSystemCtrl3]
	bl setMuteSoundChip
	bl wsvUpdateIcons
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
wsvInitIOMap:		;@ r0=SOC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	ldr r1,=defaultInTable
	ldr r2,=defaultOutTable
	ldr r3,=ioInTable
	ldr r4,=ioOutTable
	mov r5,#0xC0
ioTblLoop:
	subs r5,r5,#1
	ldr lr,[r1,r5,lsl#2]
	str lr,[r3,r5,lsl#2]
	ldr lr,[r2,r5,lsl#2]
	str lr,[r4,r5,lsl#2]
	bhi ioTblLoop

	cmp r0,#SOC_SPHINX2
	ldmfdeq sp!,{r4,r5,pc}
	ldr r1,=wsvUnmappedR
	ldr r2,=wsvUnmappedW
	cmp r0,#SOC_ASWAN
	moveq r5,#0x40
	movne r5,#0x70			;@ SPHINX
ioASLoop:
	str r1,[r3,r5,lsl#2]
	str r2,[r4,r5,lsl#2]
	add r5,r5,#1
	cmp r5,#0x78
	bne ioASLoop
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------
wsvSetIOMode:		;@ r0=color mode, 0=mono !0=color.
;@ Should only be called on SPHINX/SPHINX2
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	ldr r3,=ioInTable
	ldr r4,=ioOutTable
	mov r5,#0x40
	cmp r0,#0
	beq modeMono
	ldr r1,=defaultInTable
	ldr r2,=defaultOutTable
ioMode1Loop:
	ldr lr,[r1,r5,lsl#2]
	str lr,[r3,r5,lsl#2]
	ldr lr,[r2,r5,lsl#2]
	str lr,[r4,r5,lsl#2]
	add r5,r5,#1
	cmp r5,#0x6C
	bne ioMode1Loop
	ldmfd sp!,{r4,r5,pc}

modeMono:
	ldr r1,=wsvUnmappedR
	ldr r2,=wsvUnmappedW
ioMode0Loop:
	cmp r5,#0x60				;@ Skip 0x60 since it's used to switch back to color mode.
	strne r1,[r3,r5,lsl#2]
	strne r2,[r4,r5,lsl#2]
	add r5,r5,#1
	cmp r5,#0x6C
	bne ioMode0Loop
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------
wsvSetCartMap:		;@ r0=inTable, r1=outTable
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}
	ldr r2,=cartInTable
	ldr r3,=cartOutTable
	mov r4,#0x40
cartTblLoop:
	ldr lr,[r0],#4
	str lr,[r2],#4
	ldr lr,[r1],#4
	str lr,[r3],#4
	subs r4,r4,#1
	bhi cartTblLoop

	ldmfd sp!,{r4,lr}
	bx lr
;@----------------------------------------------------------------------------
wsvSetIOPortOut:		;@ r0=port, r1=function
;@----------------------------------------------------------------------------
	ldr r2,=ioOutTable
	str r1,[r2,r0,lsl#2]
	bx lr
;@----------------------------------------------------------------------------
_debugIOUnmappedR:
;@----------------------------------------------------------------------------
	ldr r3,=debugIOUnmappedR
	bx r3
;@----------------------------------------------------------------------------
_debugIOUnimplR:
;@----------------------------------------------------------------------------
	ldr r3,=debugIOUnimplR
	bx r3
;@----------------------------------------------------------------------------
_debugIOUnmappedW:
;@----------------------------------------------------------------------------
	ldr r3,=debugIOUnmappedW
	bx r3
;@----------------------------------------------------------------------------
_debugSerialOutW:
;@----------------------------------------------------------------------------
	ldr r3,=debugSerialOutW
	bx r3
;@----------------------------------------------------------------------------
memCopy:
;@----------------------------------------------------------------------------
	ldr r3,=memcpy
;@----------------------------------------------------------------------------
thumbCallR3:
;@----------------------------------------------------------------------------
	bx r3
;@----------------------------------------------------------------------------
wsvRegistersReset:				;@ in r3=SOC
;@----------------------------------------------------------------------------
	adr r1,IO_Default
//	cmp r3,#SOC_SPHINX
//	adreq r1,WSC_IO_Default
//	adrhi r1,SC_IO_Default
	mov r2,#0x100
	add r0,spxptr,#wsvRegs
	stmfd sp!,{spxptr,lr}
	bl memCopy
	ldmfd sp!,{spxptr,lr}
	ldrb r1,[spxptr,#wsvSOC]
	cmp r1,#SOC_ASWAN
	mov r0,#0x84
	movne r0,#0x86
	strb r0,[spxptr,#wsvSystemCtrl1]
	mov r0,#LCD_ICON_TIME_VALUE
	strb r0,[spxptr,#wsvCartIconTimer]
	mov r0,#0x90
	movne r0,#0x9F
	strb r0,[spxptr,#wsvColor01]
	mov r0,#0x02
	movne r0,#0x03
	strb r0,[spxptr,#wsvHWVolume]
	cmp r1,#SOC_SPHINX2
	mov r0,#0
	moveq r0,#0x80
	strb r0,[spxptr,#wsvSystemCtrl3]

	ldrb r0,[spxptr,#wsvTotalLines]
	b wsvRefW

;@----------------------------------------------------------------------------
IO_Default:
	.byte 0x00, 0x00, 0x9d, 0xbb, 0x00, 0x00, 0x00, 0x26, 0xfe, 0xde, 0xf9, 0xfb, 0xdb, 0xd7, 0x7f, 0xf5
	.byte 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x9e, 0x9b, 0x00, 0x00, 0x00, 0x00, 0x99, 0xfd, 0xb7, 0xdf
	.byte 0x30, 0x57, 0x75, 0x76, 0x15, 0x73, 0x77, 0x77, 0x20, 0x75, 0x50, 0x36, 0x70, 0x67, 0x50, 0x77
	.byte 0x57, 0x54, 0x75, 0x77, 0x75, 0x17, 0x37, 0x73, 0x50, 0x57, 0x60, 0x77, 0x70, 0x77, 0x10, 0x73
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.byte 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00
	.byte 0x84, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4f, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.byte 0x00, 0xdb, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x42, 0x00, 0x83, 0x00
// Cartridge
	.byte 0x2f, 0x3f, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1
	.byte 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1
	.byte 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1
	.byte 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1, 0xd1

;@----------------------------------------------------------------------------
sphinxSaveState:		;@ In r0=destination, r1=spxptr. Out r0=state size.
	.type sphinxSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	add r1,r1,#sphinxState
	mov r2,#sphinxStateSize
	bl memCopy

	ldmfd sp!,{lr}
	mov r0,#sphinxStateSize
	bx lr
;@----------------------------------------------------------------------------
sphinxLoadState:		;@ In r0=spxptr, r1=source. Out r0=state size.
	.type sphinxLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store spxptr (r0)
	mov r4,r1					;@ Store source

	add r0,r5,#sphinxState
	mov r2,#sphinxStateSize
	bl memCopy

	mov spxptr,r5
	ldr r0,[spxptr,#nextLineChange]
	ldr r2,=lineStateTable
fixStateTableLoop:
	ldr r1,[r2],#8
	cmp r1,r0
	bne fixStateTableLoop
	ldr r1,[r2,#-4]!
	ldr r1,[spxptr,#lineState]

	bl clearDirtyTiles

	mov spxptr,r5
	bl drawFrameGfx

	bl reBankSwitchAll

	ldrb r1,[spxptr,#wsvSystemCtrl1]
	tst r1,#1					;@ Boot rom locked?
	movne r0,#0					;@ Remove boot rom overlay
	blne setBootRomOverlay

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
sphinxGetStateSize:	;@ Out r0=state size.
	.type sphinxGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#sphinxStateSize
	bx lr

	.pool
;@----------------------------------------------------------------------------
wsvRead16:					;@ I/O read word (0x00-0xFF)
;@----------------------------------------------------------------------------
	tst r0,r0,lsr#1				;@ Odd address?
	cmpcc r0,#0xC0				;@ Cart?
	subcs v30cyc,v30cyc,#1*CYCLE	;@ Eat an extra cpu cycle
	stmfd sp!,{r4,r5,lr}
	mov r4,r0
	bl wsvRead
	mov r5,r0
	add r0,r4,#1
	bl wsvRead
	orr r0,r5,r0,lsl#8
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------
wsvReadHigh:				;@ I/O read (0x0100-0xFFFF)
;@----------------------------------------------------------------------------
	mov r1,r0,lsl#23
	cmp r1,#0xB8<<23
	bcs wsvUnmappedR
	stmfd sp!,{r0,spxptr,lr}
	bl _debugIOUnmappedR
	ldmfd sp!,{r0,spxptr,lr}
	and r0,r0,#0xFF
;@----------------------------------------------------------------------------
wsvRead:					;@ I/O read (0x00-0xBF)
;@----------------------------------------------------------------------------
	cmp r0,#0x100
	ldrmi pc,[pc,r0,lsl#2]
	b wsvReadHigh
ioInTable:
	.space 0xC0*4

;@----------------------------------------------------------------------------
;@Cartridge					;@ I/O read cart (0xC0-0xFF)
;@----------------------------------------------------------------------------
cartInTable:
	.space 0x40*4
;@----------------------------------------------------------------------------
wsvUnmappedR:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	stmfd sp!,{spxptr,lr}
	bl _debugIOUnmappedR
	ldmfd sp!,{spxptr,lr}
	ldrb r0,[spxptr,#wsvVideoMode]
	tst r0,#0x80				;@ Color mode?
	moveq r0,#0x90
	movne r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
wsvZeroR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl _debugIOUnmappedR
	ldmfd sp!,{lr}
	mov r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
wsvUnknownR:
;@----------------------------------------------------------------------------
	ldr r2,=0x826EBAD0
;@----------------------------------------------------------------------------
wsvImportantR:
	mov r11,r11					;@ No$GBA breakpoint
	add r2,spxptr,#wsvRegs
	ldrb r1,[r2,r0]
	stmfd sp!,{r1,spxptr,lr}
	bl _debugIOUnimplR
	ldmfd sp!,{r0,spxptr,pc}
;@----------------------------------------------------------------------------
wsvRegR:
	add r2,spxptr,#wsvRegs
	ldrb r0,[r2,r0]
	bx lr
	.pool
;@----------------------------------------------------------------------------
wsvVCountR:					;@ 0x03
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#scanline]
	bx lr
;@----------------------------------------------------------------------------
wsvLCDVolumeR:				;@ 0x1A
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,spxptr,lr}
	bl _debugIOUnimplR
	ldmfd sp!,{r0,spxptr,lr}
	ldrb r0,[spxptr,#wsvLCDVolume]
	and r0,r0,#1				;@ Only keep bit 0
	ldrb r1,[spxptr,#wsvHWVolume]	;@ Only low 2 bits are ever set
	orr r0,r0,r1,lsl#2
	bx lr
;@----------------------------------------------------------------------------
wsvGetInterruptVector:		;@ return vector in r0
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvInterruptBaseR:			;@ 0xB0
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptStatus]
#ifdef GBA
	mov r1,r1,lsl#24
	mov r0,#7
intVecLoop:
	movs r1,r1,lsl#1
	bcs intFound
	subs r0,r0,#1
	bne intVecLoop
intFound:
#else
	clz r0,r1
	rsbs r0,r0,#31
	movmi r0,#0
#endif
	ldrb r1,[spxptr,#wsvInterruptBase]
	orr r0,r0,r1
	bx lr
;@----------------------------------------------------------------------------
wsvComByteR:				;@ 0xB1
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0x08				;@ #3 = Serial receive
	bl wsvClearInterruptPins
	ldmfd sp!,{lr}
	mov r0,#0
	strb r0,[spxptr,#wsvByteReceived]
	ldrb r0,[spxptr,#wsvComByte]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc0R:				;@ 0x4A, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaSource]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc1R:				;@ 0x4B, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaSource+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc2R:				;@ 0x4C, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaSource+2]
	and r0,r0,#0x0F
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen0R:				;@ 0x4E, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaLength]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen1R:				;@ 0x4F, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaLength+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen2R:				;@ 0x50, only WSC.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#sndDmaLength+2]
	bx lr

;@----------------------------------------------------------------------------
wsvHyperChanCtrlR:			;@ 0x6B, only WSC
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvHyperVCtrl+1]
	and r0,r0,#0x6F
	bx lr
;@----------------------------------------------------------------------------
wsvSerialStatusR:			;@ 0xB3
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSerialStatus]
	ldr r1,[spxptr,#serialIRQCounter]
	cmp r1,#0					;@ Send complete?
	orrmi r0,r0,#4
	ldrb r1,[spxptr,#wsvByteReceived]
	cmp r1,#0					;@ Receive buffer full?
	orrne r0,r0,#1
	bx lr

;@----------------------------------------------------------------------------
wsvWriteHigh:				;@ I/O write (0x0100-0xFFFF)
;@----------------------------------------------------------------------------
	mov r2,r1,lsl#23
	cmp r2,#0xB8<<23
	bcs wsvUnmappedW
	stmfd sp!,{r0,r1,spxptr,lr}
	bl _debugIOUnmappedW
	ldmfd sp!,{r0,r1,spxptr,lr}
	and r1,r1,#0xFF
	b wsvWrite
;@----------------------------------------------------------------------------
wsvWrite16:					;@ I/O write word (0x00-0xFF)
;@----------------------------------------------------------------------------
	tst r1,r1,lsr#1				;@ Odd address?
	cmpcc r1,#0xC0				;@ Cart?
	subcs v30cyc,v30cyc,#1*CYCLE	;@ Eat an extra cpu cycle
	stmfd sp!,{r0,r1,lr}
	and r0,r0,#0xFF
	bl wsvWrite
	ldmfd sp!,{r0,r1,lr}
	mov r0,r0,lsr#8
	add r1,r1,#1
;@----------------------------------------------------------------------------
wsvWrite:					;@ I/O write (0x00-0xBF)
;@----------------------------------------------------------------------------
	cmp r1,#0x100
	ldrmi pc,[pc,r1,lsl#2]
	b wsvWriteHigh
ioOutTable:
	.space 0xC0*4

;@----------------------------------------------------------------------------
;@Cartridge					;@ I/O write cart (0xC0-0xFF)
;@----------------------------------------------------------------------------
cartOutTable:
	.space 0x40*4

;@----------------------------------------------------------------------------
wsvUnknownW:
;@----------------------------------------------------------------------------
wsvImportantW:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
	stmfd sp!,{spxptr,lr}
	bl debugIOUnimplW
	ldmfd sp!,{spxptr,pc}
;@----------------------------------------------------------------------------
wsvReadOnlyW:
;@----------------------------------------------------------------------------
wsvUnmappedW:
;@----------------------------------------------------------------------------
	b _debugIOUnmappedW
;@----------------------------------------------------------------------------
wsvRegW:
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
;@----------------------------------------------------------------------------
wsvZeroW:
;@----------------------------------------------------------------------------
	bx lr

;@----------------------------------------------------------------------------
wsvDisplayCtrlW:			;@ 0x00, Display Control
;@----------------------------------------------------------------------------
	ldrb r2,[spxptr,#wsvDispCtrl]
	and r0,r0,#0x3F
	strb r0,[spxptr,#wsvDispCtrl]
dispCnt:
	ldr r1,[spxptr,#scanline]	;@ r1=scanline
	add r1,r1,#1
	cmp r1,#145
	movhi r1,#145
	ldr r0,[spxptr,#dispLine]
	subs r0,r1,r0
	strhi r1,[spxptr,#dispLine]

	ldr r3,[spxptr,#dispBuff]
	add r1,r3,r1
sy1:
	strbhi r2,[r1,#-1]!			;@ Fill backwards from scanline to lastline
	subs r0,r0,#1
	bhi sy1
	bx lr
;@----------------------------------------------------------------------------
wsvSpriteTblAdrW:			;@ 0x04, Sprite Table Address
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvVideoMode]
	tst r1,#0x80				;@ Color mode?
	andne r0,r0,#0x3F
	andeq r0,r0,#0x1F
	strb r0,[spxptr,#wsvSprTblAdr]
	bx lr
;@----------------------------------------------------------------------------
wsvSpriteFirstW:			;@ 0x05, First Sprite
;@----------------------------------------------------------------------------
	and r0,r0,#0x7F
	strb r0,[spxptr,#wsvSpriteFirst]
	bx lr
;@----------------------------------------------------------------------------
wsvMapAdrW:					;@ 0x07 Map table address
;@----------------------------------------------------------------------------
#ifdef __ARM_ARCH_5TE__
	ldrd r2,r3,[spxptr,#wsvBGScrollBak]
#else
	ldr r2,[spxptr,#wsvBGScrollBak]
	ldr r3,[spxptr,#wsvFGScrollBak]
#endif
	ldrb r1,[spxptr,#wsvVideoMode]
	tst r1,#0x80				;@ Color mode?
	andeq r0,r0,#0x77
	strb r0,[spxptr,#wsvMapTblAdr]
	strb r0,[spxptr,#wsvBGScrollBak+1]
	b scrollCnt
;@----------------------------------------------------------------------------
wsvFgWinX0W:				;@ 0x08, Foreground Window X start register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvFgWinY0W:				;@ 0x09, Foreground Window Y start register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvFgWinX1W:				;@ 0x0A, Foreground Window X end register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvFgWinY1W:				;@ 0x0B, Foreground Window Y end register
;@----------------------------------------------------------------------------
	ldr r2,[spxptr,#wsvFgWinXPos]
	add r1,r1,#wsvRegs
	strb r0,[spxptr,r1]

windowCnt:
	ldr r1,[spxptr,#scanline]	;@ r1=scanline
	add r1,r1,#1
	cmp r1,#145
	movhi r1,#145
	ldr r0,[spxptr,#windowLine]
	subs r0,r1,r0
	strhi r1,[spxptr,#windowLine]

	ldr r3,[spxptr,#windowBuff]
	add r1,r3,r1,lsl#2
sy3:
	stmdbhi r1!,{r2}			;@ Fill backwards from scanline to lastline
	subs r0,r0,#1
	bhi sy3
	bx lr
;@----------------------------------------------------------------------------
wsvBgScrXW:					;@ 0x10, Background Horizontal Scroll register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvBgScrYW:					;@ 0x11, Background Vertical Scroll register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvFgScrXW:					;@ 0x12, Foreground Horizontal Scroll register
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvFgScrYW:					;@ 0x13, Foreground Vertical Scroll register
;@----------------------------------------------------------------------------
#ifdef __ARM_ARCH_5TE__
	ldrd r2,r3,[spxptr,#wsvBGScrollBak]
#else
	ldr r2,[spxptr,#wsvBGScrollBak]
	ldr r3,[spxptr,#wsvFGScrollBak]
#endif
	add r1,r1,#wsvRegs
	strb r0,[spxptr,r1]
	add r1,r1,#(wsvBGScrollBak/2) - wsvBgXScroll
	strb r0,[spxptr,r1,lsl#1]

scrollCnt:
	stmfd sp!,{lr}
	ldr r1,[spxptr,#scanline]	;@ r1=scanline
	add r1,r1,#1
	cmp r1,#145
	movhi r1,#145
	ldr r0,[spxptr,#scrollLine]
	subs r0,r1,r0
	strhi r1,[spxptr,#scrollLine]

	ldr lr,[spxptr,#scrollBuff]
	add r1,lr,r1,lsl#3
sy4:
	stmdbhi r1!,{r2,r3}			;@ Fill backwards from scanline to lastline
	subs r0,r0,#1
	bhi sy4
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
wsvLCDIconW:				;@ 0x15, Enable/disable LCD icons
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvLCDIcons]
	ands r0,r0,#6
	bxeq lr
	cmp r0,#2
	movne r0,#0
	strb r0,[spxptr,#wsvOrientation]
	bx lr
;@----------------------------------------------------------------------------
wsvRefW:					;@ 0x16, Last scan line.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvTotalLines]
	cmp r0,#0x9E
	movmi r0,#0x9E
	cmp r0,#0xC8
	movpl r0,#0xC8
	add r0,r0,#1
	str r0,lineStateLastLine
	b setScreenRefresh
;@----------------------------------------------------------------------------
wsvDMASourceW:				;@ 0x40, only WSC.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMASource]
	bx lr
;@----------------------------------------------------------------------------
wsvDMASourceHW:				;@ 0x42, only WSC.
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvDMASource+2]
	bx lr
;@----------------------------------------------------------------------------
wsvDMADestW:				;@ 0x44, only WSC.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMADest]
	bx lr
;@----------------------------------------------------------------------------
wsvDMALengthW:				;@ 0x46, only WSC.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMALength]
	bx lr
;@----------------------------------------------------------------------------
wsvDMACtrlW:				;@ 0x48, only WSC, word transfer. steals 5+2*word cycles.
;@----------------------------------------------------------------------------
	and r0,r0,#0xC0
	strb r0,[spxptr,#wsvDMACtrl]
	tst r0,#0x80				;@ Start?
	bxeq lr

	stmfd sp!,{r4-r8,lr}
#ifdef __ARM_ARCH_5TE__
	ldrd r4,r5,[spxptr,#wsvDMASource]
#else
	ldr r4,[spxptr,#wsvDMASource]
	ldr r5,[spxptr,#wsvDMADest]	;@ r5=destination
#endif
	movs r6,r5,lsr#16			;@ r6=length
	beq dmaEnd
	mov r4,r4,lsl#12
	mov r5,r5,lsl#16
	sub v30cyc,v30cyc,#5*CYCLE
	sub v30cyc,v30cyc,r6,lsl#CYC_SHIFT

	and r7,r0,#0x40				;@ Inc/dec
	rsb r7,r7,#0x20
	mov r8,spxptr

dmaLoop:
	mov r0,r4
	bl dmaReadMem20W
	mov r1,r0
	mov r0,r5,lsr#4
	bl dmaWriteMem20W
	add r4,r4,r7,lsl#8
	add r5,r5,r7,lsl#12
	subs r6,r6,#2
	bne dmaLoop

	mov spxptr,r8
	mov r4,r4,lsr#12
	mov r5,r5,lsr#16
#ifdef __ARM_ARCH_5TE__
	strd r4,r5,[spxptr,#wsvDMASource]
#else
	str r4,[spxptr,#wsvDMASource]
	str r5,[spxptr,#wsvDMADest]	;@ Store dest plus clear length
#endif

	rsb r7,r7,#0x20
	strb r7,[spxptr,#wsvDMACtrl]
dmaEnd:
	ldmfd sp!,{r4-r8,lr}
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc0W:				;@ 0x4A, only WSC.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcL]
	strb r0,[spxptr,#sndDmaSource]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc1W:				;@ 0x4B, only WSC.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcL+1]
	strb r0,[spxptr,#sndDmaSource+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc2W:				;@ 0x4C, only WSC.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcH]
	strb r0,[spxptr,#sndDmaSource+2]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen0W:				;@ 0x4E, only WSC.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMALenL]
	strb r0,[spxptr,#sndDmaLength]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen1W:				;@ 0x4F, only WSC.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMALenL+1]
	strb r0,[spxptr,#sndDmaLength+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen2W:				;@ 0x50, only WSC.
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvSndDMALenH]
	strb r0,[spxptr,#sndDmaLength+2]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMACtrlW:				;@ 0x52, only WSC. steals 7n cycles.
;@----------------------------------------------------------------------------
	and r0,r0,#0xDF
	strb r0,[spxptr,#wsvSndDMACtrl]
	bx lr
;@----------------------------------------------------------------------------
wsvVideoModeW:				;@ 0x60, Video mode, WSColor
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvVideoMode]
	strb r0,[spxptr,#wsvVideoMode]
	eor r1,r1,r0
	tst r1,#0x80				;@ Color mode changed?
	bxeq lr
	and r0,r0,#0x80
	stmfd sp!,{lr}
	bl wsvSetIOMode
	ldmfd sp!,{lr}
	b intEepromSetSize
;@----------------------------------------------------------------------------
wsvSysCtrl3W:				;@ 0x62, only WSC
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSystemCtrl3]
	ands r0,r0,#1				;@ Power Off bit.
	orr r0,r0,r1				;@ OR SwanCrystal flag (bit 7).
	strb r0,[spxptr,#wsvSystemCtrl3]
	bxeq lr
	b wsvSetPowerOff
;@----------------------------------------------------------------------------
wsvHyperCtrlW:				;@ 0x6A, only WSC
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHyperVCtrl]
	bx lr
;@----------------------------------------------------------------------------
wsvHyperChanCtrlW:			;@ 0x6B, only WSC
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHyperVCtrl+1]
	tst r0,#0x10				;@ Reset Left/Right?
	bx lr
;@----------------------------------------------------------------------------
wsvFreqLW:					;@ 0x80,0x82,0x84,0x86 Sound frequency low
;@----------------------------------------------------------------------------
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
	and r1,r1,#6
	add r2,spxptr,#pcm1CurrentAddr
	strb r0,[r2,r1,lsl#1]
	bx lr
;@----------------------------------------------------------------------------
wsvFreqHW:					;@ 0x81,0x83,0x85,0x87 Sound frequency high
;@----------------------------------------------------------------------------
	and r0,r0,#7				;@ Only low 3 bits
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
	orr r0,r0,#8
	and r1,r1,#6
	add r2,spxptr,r1,lsl#1
	strb r0,[r2,#pcm1CurrentAddr+1]
	bx lr
;@----------------------------------------------------------------------------
wsvCh1VolumeW:				;@ 0x88 Sound Channel 1 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound1Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound1Vol]	;@ Each nibble is L & R
	b setCh1Volume
;@----------------------------------------------------------------------------
wsvCh2VolumeW:				;@ 0x89 Sound Channel 2 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound2Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound2Vol]	;@ Each nibble is L & R
	b setCh2Volume
;@----------------------------------------------------------------------------
wsvCh3VolumeW:				;@ 0x8A Sound Channel 3 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound3Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound3Vol]	;@ Each nibble is L & R
	b setCh3Volume
;@----------------------------------------------------------------------------
wsvCh4VolumeW:				;@ 0x8B Sound Channel 4 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound4Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound4Vol]	;@ Each nibble is L & R
	b setCh4Volume
;@----------------------------------------------------------------------------
wsvSweepTimeW:				;@ 0x8D Sound sweep time
;@----------------------------------------------------------------------------
	and r0,r0,#0x1F				;@ Only low 5 bits
	strb r0,[spxptr,#wsvSweepTime]
	add r0,r0,#1
	sub r0,r0,r0,lsl#26
	str r0,[spxptr,#sweep3CurrentAddr]
	bx lr
;@----------------------------------------------------------------------------
wsvNoiseCtrlW:				;@ 0x8E Noise Control
;@----------------------------------------------------------------------------
	and r1,r0,#0x17				;@ Only keep enable & tap bits
	strb r1,[spxptr,#wsvNoiseCtrl]
	ldr r1,[spxptr,#noise4CurrentAddr]
	mov r1,r1,lsr#12			;@ Clear taps
	tst r0,#0x08				;@ Reset?
	andne r1,r1,#0x4			;@ Keep Ch4 noise on/off
	tst r0,#0x10				;@ Enable calculation?
	biceq r1,r1,#0x8
	orrne r1,r1,#0x8
	and r0,r0,#7				;@ Which taps?
	adr r2,noiseTaps
	ldr r0,[r2,r0,lsl#2]
	orr r1,r0,r1,lsl#12
	str r1,[spxptr,#noise4CurrentAddr]
	bx lr
noiseTaps:
	.long 0x00000408			;@ Tap bit 7 & 14
	.long 0x00000048			;@ Tap bit 7 & 10
	.long 0x00000208			;@ Tap bit 7 & 13
	.long 0x00000009			;@ Tap bit 7 & 4
	.long 0x00000018			;@ Tap bit 7 & 8
	.long 0x0000000C			;@ Tap bit 7 & 6
	.long 0x00000028			;@ Tap bit 7 & 9
	.long 0x00000088			;@ Tap bit 7 & 11
;@----------------------------------------------------------------------------
wsvSampleBaseW:				;@ 0x8F Sample Base
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSampleBase]
	ldr r1,[spxptr,#gfxRAM]
	add r1,r1,r0,lsl#6
	str r1,[spxptr,#sampleBaseAddr]
	bx lr
;@----------------------------------------------------------------------------
wsvSoundCtrlW:				;@ 0x90 Sound Control
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundCtrl]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSoundCtrl]
	tst r0,#0x20				;@ Ch 2 voice on?
	ldr r2,=vol2_L
	ldreq r1,ch2OpCode
	ldrne r1,ch2OpCode+4
	str r1,[r2,#8]

	tst r0,#0x40				;@ Ch 3 sweep on?
	ldr r1,[spxptr,#sweep3CurrentAddr]
	biceq r1,r1,#0x100
	orrne r1,r1,#0x100
	str r1,[spxptr,#sweep3CurrentAddr]

	tst r0,#0x80				;@ Ch 4 noise on?
	ldr r1,[spxptr,#noise4CurrentAddr]
	biceq r1,r1,#0x4000
	orrne r1,r1,#0x4000
	str r1,[spxptr,#noise4CurrentAddr]

	b setAllChVolume
ch2OpCode:
	mlane r2,lr,r11,r2
	add r2,lr,r2
;@----------------------------------------------------------------------------
wsvSoundOutputW:			;@ 0x91 Sound ouput
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundOutput]
	and r0,r0,#0x0F				;@ Only low 4 bits
	and r1,r1,#0x80				;@ Keep Headphones bit
	orr r0,r0,r1
	strb r0,[spxptr,#wsvSoundOutput]
	b setSoundOutput
;@----------------------------------------------------------------------------
wsvPushVolumeButton:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundOutput]
	tst r0,#0x80				;@ Headphones?
	ldrb r0,[spxptr,#wsvHWVolume]
	subeq r0,r0,#1
;@----------------------------------------------------------------------------
wsvHWVolumeW:				;@ 0x9E HW Volume?
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSOC]
	cmp r1,#SOC_ASWAN
	moveq r1,#2
	movne r1,#3
	cmp r0,r1
	movcs r0,r1

	and r0,r0,#0x03				;@ Only low 2 bits
	strb r0,[spxptr,#wsvHWVolume]
	mov r1,#LCD_ICON_TIME_VALUE
	strb r1,[spxptr,#wsvSoundIconTimer]
	b setTotalVolume
;@----------------------------------------------------------------------------
wsvHWW:						;@ 0xA0, Color/Mono, boot rom lock
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSystemCtrl1]
	and r1,r1,#0x83				;@ These can't be changed once set.
	and r0,r0,#0x8D				;@ Only these bits can be set.
	orr r0,r0,r1
	strb r0,[spxptr,#wsvSystemCtrl1]
	eor r1,r1,r0
	tst r1,#1					;@ Boot rom locked?
	bxeq lr

	ldr r0,=ioOutTable			;@ Disable write to SPHINX2 registers
	ldr r1,=wsvUnmappedW
	mov r2,#0x70
sp2DisLoop:
	str r1,[r0,r2,lsl#2]
	add r2,r2,#1
	cmp r2,#0x78
	bne sp2DisLoop

	mov r0,#0					;@ Remove boot rom overlay
	b setBootRomOverlay

;@----------------------------------------------------------------------------
wsvTimerCtrlW:				;@ 0xA2 Timer control
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvTimerControl]
	bx lr
;@----------------------------------------------------------------------------
wsvHTimerLowW:				;@ 0xA4 HBlank timer low
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHBlTimerFreq]
	strb r0,[spxptr,#wsvHBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvHTimerHighW:				;@ 0xA5 HBlank timer high
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHBlTimerFreq+1]
	strb r0,[spxptr,#wsvHBlCounter+1]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerLowW:				;@ 0xA6 VBlank timer low
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvVBlTimerFreq]
	strb r0,[spxptr,#wsvVBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerHighW:				;@ 0xA7 VBlank timer high
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvVBlTimerFreq+1]
	strb r0,[spxptr,#wsvVBlCounter+1]
	bx lr

;@----------------------------------------------------------------------------
wsv0xACW:					;@ 0xAC
;@----------------------------------------------------------------------------
	ands r0,r0,#1				;@ Power Off bit?
	strb r0,[spxptr,#wsv0xAC]
	bxeq lr
	b wsvSetPowerOff
;@----------------------------------------------------------------------------
wsvInterruptBaseW:			;@ 0xB0
;@----------------------------------------------------------------------------
	bic r0,r0,#7
	strb r0,[spxptr,#wsvInterruptBase]
	bx lr
;@----------------------------------------------------------------------------
wsvComByteW:				;@ 0xB1
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,spxptr,lr}
	bl _debugSerialOutW
	ldmfd sp!,{r0,spxptr,lr}
	strb r0,[spxptr,#wsvComByte]
	ldrb r1,[spxptr,#wsvSerialStatus]
	tst r1,#0x40					;@ 0 = 9600, 1 = 38400 bps
	moveq r0,#2560					;@ 3072000/(9600/8)
	movne r0,#640					;@ 3072000/(38400/8)
	tst r1,#0x80					;@ Serial enabled?
	moveq r0,#-1
	str r0,[spxptr,#serialIRQCounter]
	mov r0,#0x01					;@ #0 = Serial transmit
	b wsvClearInterruptPins
;@----------------------------------------------------------------------------
wsvIntEnableW:				;@ 0xB2
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptPins]
	strb r0,[spxptr,#wsvInterruptEnable]
	and r0,r0,r1
	and r0,r0,#0x0F
	b wsvSetInterruptPins
;@----------------------------------------------------------------------------
wsvSerialStatusW:			;@ 0xB3
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSerialStatus]
	and r0,r0,#0xC0				;@ Mask out writeable bits. 0x20 is reset Overrun.
	strb r0,[spxptr,#wsvSerialStatus]
	eor r1,r1,r0
	tst r1,#0x80				;@ Serial enable changed?
	bxeq lr
	tst r0,#0x80				;@ Serial enable now?
	mov r0,#SERTX_IRQ_F			;@ #0 = Serial transmit buffer empty
	bne wsvSetInterruptPins
	orr r0,r0,#SERRX_IRQ_F		;@ #0, 3 = Serial transmit, receive
	b wsvClearInterruptPins
;@----------------------------------------------------------------------------
wsvIntAckW:					;@ 0xB6
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptStatus]
	bic r0,r1,r0
	ldrb r1,[spxptr,#wsvInterruptEnable]
	ldrb r2,[spxptr,#wsvInterruptPins]
	and r2,r2,r1
	and r2,r2,#0x0F
	orr r0,r0,r2
	strb r0,[spxptr,#wsvInterruptStatus]
	ldr pc,[spxptr,#irqFunction]
;@----------------------------------------------------------------------------
wsvNMICtrlW:				;@ 0xB7
;@----------------------------------------------------------------------------
	and r1,r0,#0x10
	strb r1,[spxptr,#wsvNMIControl]
	ldrb r0,[spxptr,#wsvLowBattery]
;@----------------------------------------------------------------------------
wsvSetLowBattery:			;@ r0 = on/off
;@----------------------------------------------------------------------------
	cmp r0,#0
	movne r0,#0x10
	strb r0,[spxptr,#wsvLowBattery]
	ldrb r1,[spxptr,#wsvNMIControl]
	and r0,r0,r1
	ldrb r1,[spxptr,#wsvLowBatPin]
	strb r0,[spxptr,#wsvLowBatPin]
	cmp r0,r1
	bne V30SetNMIPin
	bx lr

;@----------------------------------------------------------------------------
wsvSetHeadphones:			;@ r0 = on/off
;@----------------------------------------------------------------------------
	cmp r0,#0
	ldrb r0,[spxptr,#wsvSoundOutput]
	biceq r0,r0,#0x80
	orrne r0,r0,#0x80
	strb r0,[spxptr,#wsvSoundOutput]
	mov r1,#LCD_ICON_TIME_VALUE
	strb r1,[spxptr,#wsvSoundIconTimer]
	b setSoundOutput
;@----------------------------------------------------------------------------
wsvConvertTileMaps:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	ldr r5,=0xFE00FE00
	ldr r6,=0x00010001
	ldr r8,[spxptr,#scrollBuff]
	ldr r10,[spxptr,#gfxRAM]

	ldrb r1,[spxptr,#wsvVideoMode]
	adr lr,tMapRet
	tst r1,#0x40				;@ 4 bit planes?
	beq bgMap4Render
	b bgMap16Render

tMapRet:
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
midFrame:
;@----------------------------------------------------------------------------
	ldr r0,[spxptr,#wsvSprWinXPos]	;@ Win pos/size
	str r0,[spxptr,#sprWindowData]
	bx lr
;@----------------------------------------------------------------------------
endFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r2,[spxptr,#wsvDispCtrl]
	bl dispCnt
	ldr r2,[spxptr,#wsvFgWinXPos]
	bl windowCnt
#ifdef __ARM_ARCH_5TE__
	ldrd r2,r3,[spxptr,#wsvBGScrollBak]
#else
	ldr r2,[spxptr,#wsvBGScrollBak]
	ldr r3,[spxptr,#wsvFGScrollBak]
#endif
	bl scrollCnt
	bl gfxEndFrame
	bl wsvDMASprites

	mov r0,#0
	ldrh r1,[spxptr,#wsvVBlCounter]
	subs r1,r1,#1
	bmi noTimerVBlIrq
	orreq r0,r0,#VBLTM_IRQ_F		;@ #5 = VBlank timer
	ldrb r2,[spxptr,#wsvTimerControl]
	bne noVBlIrq
	tst r2,#0x8						;@ Repeat?
	ldrhne r1,[spxptr,#wsvVBlTimerFreq]
noVBlIrq:
	tst r2,#0x4						;@ VBlank timer enabled?
	strhne r1,[spxptr,#wsvVBlCounter]
noTimerVBlIrq:
	orr r0,r0,#VBLST_IRQ_F			;@ #6 = VBlank
	bl wsvSetInterruptPins

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
drawFrameGfx:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldrb r0,[spxptr,#wsvVideoMode]
	adr lr,TransRet
	and r1,r0,#0xC0
	cmp r1,#0xC0
	bne TransferVRAM4Planar
	tst r0,#0x20
	bne TransferVRAM16Packed
	b TransferVRAM16Planar
TransRet:
	bl wsvUpdateIcons

	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
frameEndHook:
	mov r0,#0
	str r0,[spxptr,#dispLine]
	str r0,[spxptr,#windowLine]
	str r0,[spxptr,#scrollLine]

	adr r2,lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia spxptr,{r0-r2}		;@ Reset scanline, nextChange & lineState
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ zeroLine
	.long 72, midFrame			;@ Middle of screen
	.long 144, endFrame			;@ After last visible scanline
	.long 145, drawFrameGfx		;@ frameIRQ
lineStateLastLine:
	.long 159, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
	.pool
#ifdef GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
	.align 2
#endif
;@----------------------------------------------------------------------------
redoScanline:
;@----------------------------------------------------------------------------
	ldr r2,[spxptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib spxptr,{r1,r2}		;@ Write nextLineChange & lineState
	adr lr,continueScanline
	bx r0
;@----------------------------------------------------------------------------
wsvDoScanline:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
continueScanline:
	ldmia spxptr,{r0,r1}		;@ Read scanLine & nextLineChange
	add r0,r0,#1
	cmp r0,r1
	bpl redoScanline
	str r0,[spxptr,#scanline]
;@----------------------------------------------------------------------------
checkScanlineIRQ:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvLineCompare]
	cmp r0,r1
	mov r0,#0
	orreq r0,r0,#LINE_IRQ_F		;@ #4 = Line compare

	ldr r2,[spxptr,#serialIRQCounter]
	cmp r2,#0
	subspl r2,r2,256			;@ Cycles per scanline
	str r2,[spxptr,#serialIRQCounter]
	orrcc r0,r0,#SERTX_IRQ_F	;@ #0 = Serial transmit

	ldrh r1,[spxptr,#wsvHBlCounter]
	subs r1,r1,#1
	bmi noTimerHBlIrq
	orreq r0,r0,#HBLTM_IRQ_F	;@ #7 = HBlank timer
	ldrb r2,[spxptr,#wsvTimerControl]
	bne noHBlIrq
	tst r2,#0x2					;@ Repeat?
	ldrhne r1,[spxptr,#wsvHBlTimerFreq]
noHBlIrq:
	tst r2,#0x1					;@ HBlank timer enabled?
	strhne r1,[spxptr,#wsvHBlCounter]
noTimerHBlIrq:
	bl wsvSetInterruptPins

	ldrb r0,[spxptr,#wsvSndDMACtrl]
	tst r0,#0x80
	blne doSoundDMA
#ifndef GBA
	ldr r0,[spxptr,#missingSamplesCnt]
	cmp r0,#0
	beq noExtraSound
	addmi r0,r0,#2
	subpl r0,r0,#2
	str r0,[spxptr,#missingSamplesCnt]
	bmi skipSound
	blhi soundUpdate
noExtraSound:
	bl soundUpdate
skipSound:
#endif

	ldr r0,[spxptr,#scanline]
	subs r0,r0,#144				;@ Return from emulation loop on this scanline
	movne r0,#1
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
wsvSetInterruptExternal:	;@ r0 = irq pin state
;@----------------------------------------------------------------------------
	cmp r0,#0
	mov r0,#EXTRN_IRQ_F			;@ External interrupt is bit/number 2.
	beq wsvClearInterruptPins
;@----------------------------------------------------------------------------
wsvSetInterruptPins:		;@ r0 = interrupt pins
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptPins]
	orr r1,r1,r0
	strb r1,[spxptr,#wsvInterruptPins]
	ldrb r1,[spxptr,#wsvInterruptEnable]
	ldrb r2,[spxptr,#wsvInterruptStatus]
	and r0,r0,r1
	orr r0,r0,r2
	cmp r0,r2
	bxeq lr
	strb r0,[spxptr,#wsvInterruptStatus]
	ldr pc,[spxptr,#irqFunction]
;@----------------------------------------------------------------------------
wsvClearInterruptPins:		;@ In r0 = interrupt pins
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptPins]
	bic r1,r1,r0
	strb r1,[spxptr,#wsvInterruptPins]
	bx lr
;@----------------------------------------------------------------------------
doSoundDMA:					;@ In r0 = SndDmaCtrl
;@----------------------------------------------------------------------------
	and r1,r0,#0x03				;@ DMA Frequency
	cmp r1,#3
	movne r1,#1
	moveq r1,#2
	rsb r2,r1,r1,lsl#3			;@ *7
	sub v30cyc,v30cyc,r2,lsl#CYC_SHIFT
	tst r0,#0x04				;@ Hold ?
	bne sdmaHold				;@ Hold
	stmfd sp!,{r4,lr}
	mov r4,r0
	ldr r2,[spxptr,#sndDmaSource]
	ldr r3,[spxptr,#sndDmaLength]
	mov r0,r2,lsl#12
	tst r4,#0x40				;@ Increase/decrease
	subne r2,r2,r1
	addeq r2,r2,r1
	subs r3,r3,r1
	blle checkSndDMAEnd			;@ Less or equal.
	str r2,[spxptr,#sndDmaSource]
	str r3,[spxptr,#sndDmaLength]
	bl cpuReadMem20				;@ Fetch data

	tst r4,#0x10				;@ Ch2Vol/HyperVoice
	ldmfd sp!,{r4,lr}
	beq wsvCh2VolumeW
	b setHyperVoiceValue
sdmaHold:
	tst r0,#0x10				;@ Ch2Vol/HyperVoice
	mov r0,#0
	beq wsvCh2VolumeW
	b setHyperVoiceValue
;@----------------------------------------------------------------------------
checkSndDMAEnd:
	tst r4,#0x08				;@ Loop?
	biceq r4,r4,#0x80			;@ Nope.
	strbeq r4,[spxptr,#wsvSndDMACtrl]
	bxeq lr
	ldrh r2,[spxptr,#wsvSndDMASrcL]
	ldrh r1,[spxptr,#wsvSndDMASrcH]
	orr r2,r2,r1,lsl#16
	ldrh r3,[spxptr,#wsvSndDMALenL]
	ldrh r1,[spxptr,#wsvSndDMALenH]
	orr r3,r3,r1,lsl#16
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
	ldr r9,=0x10101010
	mov r1,#0

tileLoop16_0p:
	ldr r10,[r4,r1,lsr#5]
	str r9,[r4,r1,lsr#5]
	tst r10,#0x00000010
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0x00001000
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0x00100000
	addne r1,r1,#0x20
	bleq tileLoop16_1p
	tst r10,#0x10000000
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
	ldr r9,=0x20202020
	mov r1,#0

tx16ColTileLoop0:
	ldr r10,[r4,r1,lsr#5]
	str r9,[r4,r1,lsr#5]
	tst r10,#0x00000020
	addne r1,r1,#0x20
	bleq tx16ColTileLoop1
	tst r10,#0x00002000
	addne r1,r1,#0x20
	bleq tx16ColTileLoop1
	tst r10,#0x00200000
	addne r1,r1,#0x20
	bleq tx16ColTileLoop1
	tst r10,#0x20000000
	addne r1,r1,#0x20
	bleq tx16ColTileLoop1
	cmp r1,#0x8000
	bne tx16ColTileLoop0

	ldmfd sp!,{r4-r10,pc}

tx16ColTileLoop1:
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
	bne tx16ColTileLoop1

	bx lr

;@----------------------------------------------------------------------------
T4Data:
	.long DIRTYTILES+0x100
	.long wsRAM+0x2000
	.long CHR_DECODE
	.long BG_GFX+0x08000		;@ BGR tiles
	.long BG_GFX+0x0C000		;@ BGR tiles 2
	.long SPRITE_GFX			;@ SPR tiles
	.long SPRITE_GFX+0x4000		;@ SPR tiles 2
	.long 0x44444444			;@ Extra bitplane, undirty mark
;@----------------------------------------------------------------------------
TransferVRAM4Planar:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r12,lr}
	adr r0,T4Data
	ldmia r0,{r4-r11}
	mov r1,#0

tx4ColTileLoop0:
	ldr r12,[r4,r1,lsr#5]
	str r11,[r4,r1,lsr#5]
	tst r12,#0x00000044
	addne r1,r1,#0x20
	bleq tx4ColTileLoop1
	tst r12,#0x00004400
	addne r1,r1,#0x20
	bleq tx4ColTileLoop1
	tst r12,#0x00440000
	addne r1,r1,#0x20
	bleq tx4ColTileLoop1
	tst r12,#0x44000000
	addne r1,r1,#0x20
	bleq tx4ColTileLoop1
	cmp r1,#0x2000
	bne tx4ColTileLoop0

	ldmfd sp!,{r4-r12,pc}

tx4ColTileLoop1:
	ldr r0,[r5,r1]

	ands r3,r0,#0x000000FF
	ldrne r3,[r6,r3,lsl#2]
	ands r2,r0,#0x0000FF00
	ldrne r2,[r6,r2,lsr#6]
	orrne r3,r3,r2,lsl#1

	str r3,[r8,r1,lsl#1]
	str r3,[r10,r1,lsl#1]
	orr r3,r3,r11
	str r3,[r7,r1,lsl#1]
	str r3,[r9,r1,lsl#1]
	add r1,r1,#2

	ands r3,r0,#0x00FF0000
	ldrne r3,[r6,r3,lsr#14]
	ands r2,r0,#0xFF000000
	ldrne r2,[r6,r2,lsr#22]
	orrne r3,r3,r2,lsl#1

	str r3,[r8,r1,lsl#1]
	str r3,[r10,r1,lsl#1]
	orr r3,r3,r11
	str r3,[r7,r1,lsl#1]
	str r3,[r9,r1,lsl#1]
	add r1,r1,#2

	tst r1,#0x1C
	bne tx4ColTileLoop1

	bx lr

;@-------------------------------------------------------------------------------
;@ bgMapFinish				;end of frame...
;@-------------------------------------------------------------------------------
;@	r5 = 0xFE00FE00
;@	r8 = scrollBuff
;@ MSB          LSB
;@ hvbppppnnnnnnnnn
bgMap16Render:
	stmfd sp!,{lr}
	ldrb r7,[r8,#1]!
	mov r1,#GAME_HEIGHT
bgM16AdrLoop:
	ldrb r9,[r8],#8
	cmp r9,r7
	bne bgM16AdrDone
	subs r1,r1,#1
	bne bgM16AdrLoop
	mov r9,#-1
bgM16AdrDone:
	orrne r7,r7,r9,lsl#24
	add r11,r10,#0x10000			;@ Size of wsRAM, ptr to DIRTYTILES.

	mov r2,#1						;@ Where the map is cached.
	and r1,r7,#0xf
	bl bgm16Start
	mov r2,#2
	mov r1,r7,lsr#24
	and r1,r1,#0xf
	cmp r9,#-1
	addeq r0,r0,#0x800
	blne bgm16Start

	mov r2,#3
	mov r1,r7,lsr#4
	and r1,r1,#0xf
	bl bgm16Start
	mov r2,#4
	mov r1,r7,lsr#28
	cmp r9,#-1
	addeq r0,r0,#0x800
	blne bgm16Start
	ldmfd sp!,{pc}

bgm16Start:
	add r3,spxptr,r2
	ldrb r4,[r3,#cachedMaps-1]!
	cmp r4,r1
	strbne r1,[r3]
	orrne r2,r2,#0x80000000
	orr r2,r2,r2,lsl#8
	add r8,r11,r1,lsl#6
	add r1,r10,r1,lsl#11
	b bgm16Loop2

bgm16Tst:
	add r1,r1,#0x40
	add r0,r0,#0x40
	tst r0,#0x7c0				;@ Only one screen
	bxeq lr
bgm16Loop2:
	ldrh r3,[r8],#2
	teq r2,r3
	beq bgm16Tst
	strh r2,[r8,#-2]
bgm16Loop:
	ldr r3,[r1],#4				;@ Read from WonderSwan Tilemap RAM

	and r4,r5,r3				;@ Mask out palette, flip & bank
	bic r3,r3,r5
	orr r4,r4,r4,lsr#7			;@ Switch palette vs flip + bank
	and r4,r5,r4,lsl#3			;@ Mask again
	orr r3,r3,r4				;@ Add palette, flip + bank.

	str r3,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, background
	tst r0,#0x3c				;@ One row at a time
	bne bgm16Loop
	tst r0,#0x7c0				;@ Only one screen
	bne bgm16Loop2

	bx lr

;@-------------------------------------------------------------------------------
;@ bgMapFinish				;end of frame...
;@-------------------------------------------------------------------------------
;@	r5 = 0xFE00FE00
;@	r6 = 0x00010001
;@	r8 = scrollBuff
;@ MSB          LSB
;@ hvbppppnnnnnnnnn
bgMap4Render:
	stmfd sp!,{lr}
	ldrb r7,[r8,#1]!
	mov r1,#GAME_HEIGHT
bgM4AdrLoop:
	ldrb r9,[r8],#8
	cmp r9,r7
	bne bgM4AdrDone
	subs r1,r1,#1
	bne bgM4AdrLoop
	mov r9,#-1
bgM4AdrDone:
	orrne r7,r7,r9,lsl#24
	add r11,r10,#0x10000			;@ Size of wsRAM, ptr to DIRTYTILES.

	mov r2,#1						;@ Where the map is cached.
	and r1,r7,#0xf
	bl bgm4Start
	mov r2,#2
	mov r1,r7,lsr#24
	and r1,r1,#0xf
	cmp r9,#-1
	addeq r0,r0,#0x800
	blne bgm4Start

	mov r2,#3
	mov r1,r7,lsr#4
	and r1,r1,#0xf
	bl bgm4Start
	mov r2,#4
	mov r1,r7,lsr#28
	cmp r9,#-1
	addeq r0,r0,#0x800
	blne bgm4Start
	ldmfd sp!,{pc}

bgm4Start:
	add r3,spxptr,r2
	ldrb r4,[r3,#cachedMaps-1]!
	cmp r4,r1
	strbne r1,[r3]
	orrne r2,r2,#0x80000000
	orr r2,r2,r2,lsl#8
	add r8,r11,r1,lsl#6
	add r1,r10,r1,lsl#11
	b bgm4Loop2

bgm4Tst:
	add r1,r1,#0x40
	add r0,r0,#0x40
	tst r0,#0x7c0				;@ Only one screen
	bxeq lr
bgm4Loop2:
	ldrh r3,[r8],#2
	teq r2,r3
	beq bgm4Tst
	strh r2,[r8,#-2]
bgm4Loop:
	ldr r3,[r1],#4				;@ Read from WonderSwan Tilemap RAM

	and r4,r5,r3				;@ Mask out palette, flip & bank
	bic r4,r4,r6,lsl#13			;@ Clear out bank bit
	bic r3,r3,r5
	orr r4,r4,r4,lsr#7			;@ Switch palette vs flip + bank
	and r4,r5,r4,lsl#3			;@ Mask again
	orr r3,r3,r4				;@ Add palette, flip + bank.
	and r4,r3,r6,lsl#14			;@ Mask out palette bit 2
	orr r3,r3,r4,lsr#5			;@ Add as bank bit (GBA/NDS)

	str r3,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, background
	tst r0,#0x3c				;@ One row at a time
	bne bgm4Loop
	tst r0,#0x7c0				;@ Only one screen
	bne bgm4Loop2

	bx lr

;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r8}
	ldr r1,[spxptr,#scrollBuff]
	ldrb r7,[r1,#1]

	mov r6,#((SCREEN_HEIGHT-GAME_HEIGHT)/2)<<23
	add r0,r0,r6,lsr#20			;@ 8 bytes per row
	mov r4,#(0x100-(SCREEN_WIDTH-GAME_WIDTH)/2)<<7
	sub r4,r4,r6
	mov r5,#GAME_HEIGHT
setScrlLoop:
	ldmia r1!,{r2,r3}
	eor r8,r7,r2,lsr#8
	bic r2,r2,#0xFF00
	add r2,r2,r4,lsr#7
	add r3,r3,r4,lsr#7
	cmn r6,r2,lsl#7
	eormi r2,r2,#0x1000000
	cmn r6,r3,lsl#7
	eormi r3,r3,#0x1000000
	tst r8,#0x0F
	eorne r2,r2,#0x1000000
	tst r8,#0xF0
	eorne r3,r3,#0x1000000
	stmia r0!,{r2,r3}
	add r6,r6,#1<<23
	subs r5,r5,#1
	bne setScrlLoop

	ldmfd sp!,{r4-r8}
	bx lr

;@----------------------------------------------------------------------------
wsvDMASprites:
;@----------------------------------------------------------------------------
	stmfd sp!,{spxptr,lr}

	add r0,spxptr,#wsvSpriteRAM			;@ Destination
	ldr r1,[spxptr,#gfxRAM]
	ldrb r2,[spxptr,#wsvSprTblAdr]
	add r1,r1,r2,lsl#9
	ldrb r2,[spxptr,#wsvSpriteFirst]	;@ First sprite
	add r1,r1,r2,lsl#2

	ldrb r3,[spxptr,#wsvSpriteCount]	;@ Sprite count
	add r3,r3,r2
	cmp r3,#128
	movpl r3,#128
	subs r2,r3,r2
	movmi r2,#0
	strb r2,[spxptr,#wsvLatchedSprCnt]
	ldmfdle sp!,{spxptr,pc}

	mov r2,r2,lsl#2
	bl memCopy

	ldmfd sp!,{spxptr,pc}

;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x400		;@ 0x400=AGB OBJ priority 1
;@----------------------------------------------------------------------------
wsvConvertSprites:			;@ in r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r8,lr}

	add r1,spxptr,#wsvSpriteRAM
	ldrb r7,[spxptr,#wsvLatchedSprCnt]
	ldrb r2,[spxptr,#wsvVideoMode]
	tst r2,#0x40				;@ 4 bit planes?
	movne r8,#0x0000
	moveq r8,#0x0800			;@ Palette bit 2
	cmp r7,#0
	rsb r6,r7,#128				;@ Max number of sprites minus used.
	beq skipSprites

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

//	tst r2,#0x1000				;@ WS Window enable
//	orrne r3,r3,#0x400			;@ Semi TRansparent obj
	str r3,[r0],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r3,r2,lsl#23
	mov r3,r3,lsr#23
	and r4,r2,#0x0E00			;@ Palette
	orr r3,r3,r4,lsl#3
	tst r2,#0x2000				;@ Priority
#ifdef NDS
	orreq r3,r3,#PRIORITY		;@ Prio NDS
#elif GBA
	orreq r3,r3,#PRIORITY*2		;@ Prio GBA
	orrne r3,r3,#PRIORITY		;@ Prio GBA
#endif
	tst r2,r8					;@ Palette bit 2 for 2bitplane
	orrne r3,r3,#0x200			;@ Opaque tiles

	strh r3,[r0],#4				;@ Store OBJ Atr 2. Pattern, palette, prio.
	subs r7,r7,#1
	bne dm5
skipSprites:
	mov r2,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
skipSprLoop:
	subs r6,r6,#1
	strpl r2,[r0],#8
	bhi skipSprLoop
	ldmfd sp!,{r4-r8,pc}

#ifdef GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#endif
;@----------------------------------------------------------------------------
wsvUpdateIcons:				;@ Remap IO regs to LCD icons and draw icons.
;@----------------------------------------------------------------------------
	ldr r1,[spxptr,#enabledLCDIcons]
	ldrb r0,[spxptr,#wsvLCDIcons]
	and r0,r0,#0x3F
	ldrb r2,[spxptr,#wsvHWVolume]
	and r2,r2,#3
	orr r0,r0,r2,lsl#6
	ldrb r2,[spxptr,#wsvSoundOutput]
	tst r2,#0x80				;@ Headphones?
	orrne r0,r0,#LCD_ICON_HEADPHONE
	ldrb r2,[spxptr,#wsvCartIconTimer]
	subs r2,r2,#1
	strbpl r2,[spxptr,#wsvCartIconTimer]
	orrhi r0,r0,#LCD_ICON_CARTRIDGE
	ldrb r2,[spxptr,#wsvLowBattery]
	cmp r2,#0
	orrne r0,r0,#LCD_ICON_BATTERY
	ldrb r2,[spxptr,#wsvSoundIconTimer]
	subs r2,r2,#1
	strbpl r2,[spxptr,#wsvSoundIconTimer]
	orrhi r0,r0,#LCD_ICON_TIME
	ldrb r2,[spxptr,#wsvSystemCtrl3]
	tst r2,#1
	orreq r0,r0,#LCD_ICON_POWER
	movne r0,#0
	eors r1,r1,r0
	bxeq lr
	str r0,[spxptr,#enabledLCDIcons]
;@----------------------------------------------------------------------------
wsvRedrawLCDIcons:			;@ In r0=
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvMachine]
	cmp r1,#HW_WONDERSWAN
	beq redrawMonoIcons
	cmp r1,#HW_POCKETCHALLENGEV2
	bxeq lr
;@----------------------------------------------------------------------------
redrawColorIcons:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	ldr r2,=BG_GFX+0x800*15
	add r1,r2,#0x40*24
	add r2,r2,#0x40*3+0x3C
	ldrh r4,[r1]
	tst r0,#LCD_ICON_DOT3
	ldrhne r3,[r1,#2]
	moveq r3,r4
	strh r3,[r2],#0x40

	ldrhne r3,[r1,#4]
	and r5,r0,#LCD_ICON_DOT3|LCD_ICON_DOT2
	cmp r5,#LCD_ICON_DOT3|LCD_ICON_DOT2
	ldrheq r3,[r1,#6]
	cmp r5,#LCD_ICON_DOT2
	ldrheq r3,[r1,#8]
	strh r3,[r2],#0x40

	ands r5,r0,#LCD_ICON_DOT2|LCD_ICON_DOT1
	ldrhne r3,[r1,#10]
	moveq r3,r4
	cmp r5,#LCD_ICON_DOT2|LCD_ICON_DOT1
	ldrheq r3,[r1,#12]
	cmp r5,#LCD_ICON_DOT1
	ldrheq r3,[r1,#14]
	strh r3,[r2],#0x40

	ands r5,r0,#LCD_ICON_DOT1|LCD_ICON_HORZ
	ldrhne r3,[r1,#16]
	moveq r3,r4
	cmp r5,#LCD_ICON_DOT1|LCD_ICON_HORZ
	ldrheq r3,[r1,#18]
	cmp r5,#LCD_ICON_HORZ
	ldrheq r3,[r1,#20]
	strh r3,[r2],#0x40
	tst r0,#LCD_ICON_HORZ
	ldrhne r3,[r1,#22]
	strh r3,[r2],#0x40

	tst r0,#LCD_ICON_VERT		;@ Vertical
	moveq r3,r4
	ldrhne r3,[r1,#24]
	strh r3,[r2],#0x40

	tst r0,#LCD_ICON_TIME
	tstne r0,#LCD_ICON_HEADPHONE	;@ HeadPhones
	moveq r3,r4
	ldrhne r3,[r1,#26]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#28]
	strh r3,[r2],#0x40

	bne clrVoluIcon
	tst r0,#LCD_ICON_TIME
	bne chkVoluIcon
clrVoluIcon:
	strh r4,[r2],#0x40		;@ No Volume when headphones
	strh r4,[r2],#0x40
	b chkBattIcon

chkVoluIcon:
	ands r5,r0,#LCD_ICON_VOLU	;@ HW Volume
	ldrheq r3,[r1,#30]
	ldrhne r3,[r1,#32]
	cmp r5,#LCD_ICON_VOL2
	ldrheq r3,[r1,#34]
	ldrhhi r3,[r1,#36]
	strh r3,[r2],#0x40
	ldrh r3,[r1,#38]
	strh r3,[r2],#0x40

chkBattIcon:
	tst r0,#LCD_ICON_BATTERY	;@ Low battery
	moveq r3,r4
	ldrhne r3,[r1,#40]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#42]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#44]
	strh r3,[r2],#0x40

	tst r0,#LCD_ICON_SLEEP		;@ Sleep Mode
	moveq r3,r4
	ldrhne r3,[r1,#46]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#48]
	strh r3,[r2],#0x40

	tst r0,#LCD_ICON_CARTRIDGE	;@ Cart OK?
	moveq r3,r4
	ldrhne r3,[r1,#50]
	strh r3,[r2],#0x40

	tst r0,#LCD_ICON_POWER		;@ Power On?
	moveq r3,r4
	ldrhne r3,[r1,#52]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#54]
	strh r3,[r2],#0x40

	ldmfd sp!,{r4-r5,pc}
;@----------------------------------------------------------------------------
redrawMonoIcons:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	ldr r2,=BG_GFX+0x800*15
	add r1,r2,#0x40*24
	add r2,r2,#0x40*21
	ldrh r4,[r1]

	tst r0,#LCD_ICON_POWER		;@ Power On?
	moveq r3,r4
	ldrhne r3,[r1,#0x02]
	strh r3,[r2,#0x04]

	tst r0,#LCD_ICON_CARTRIDGE	;@ Cart OK?
	moveq r3,r4
	ldrhne r3,[r1,#0x06]
	strh r3,[r2,#0x08]
	ldrhne r3,[r1,#0x08]
	strh r3,[r2,#0x0A]

	tst r0,#LCD_ICON_SLEEP		;@ Sleep Mode
	moveq r3,r4
	ldrhne r3,[r1,#0x0A]
	strh r3,[r2,#0x0C]

	tst r0,#LCD_ICON_BATTERY	;@ Low battery
	moveq r3,r4
	ldrhne r3,[r1,#0x10]
	strh r3,[r2,#0x12]
	ldrhne r3,[r1,#0x12]
	strh r3,[r2,#0x14]
	ldrhne r3,[r1,#0x14]
	strh r3,[r2,#0x16]
	ldrhne r3,[r1,#0x16]
	strh r3,[r2,#0x18]

	tst r0,#LCD_ICON_TIME
	tstne r0,#LCD_ICON_HEADPHONE	;@ HeadPhones
	moveq r3,r4
	ldrhne r3,[r1,#0x24]
	strh r3,[r2,#0x26]

	bne clrVoluIconMono
	tst r0,#LCD_ICON_TIME
	bne chkVoluIconMono
clrVoluIconMono:
	strh r4,[r2,#0x1A]
	strh r4,[r2,#0x1C]
	b chkHorzIcon

chkVoluIconMono:
	ands r5,r0,#LCD_ICON_VOLU	;@ HW Volume
	ldrh r3,[r1,#0x18]
	strh r3,[r2,#0x1A]
	strheq r4,[r2,#0x1C]
	cmp r5,#LCD_ICON_VOL1
	ldrheq r3,[r1,#0x1C]
	ldrhhi r3,[r1,#0x1A]
	strhpl r3,[r2,#0x1C]

chkHorzIcon:
	tst r0,#LCD_ICON_HORZ
	moveq r3,r4
	ldrhne r3,[r1,#0x2A]
	strh r3,[r2,#0x2C]
	ldrhne r3,[r1,#0x2C]
	strh r3,[r2,#0x2E]

	tst r0,#LCD_ICON_VERT		;@ Vertical
	moveq r3,r4
	ldrhne r3,[r1,#0x2E]
	strh r3,[r2,#0x30]

	tst r0,#LCD_ICON_DOT1
	moveq r3,r4
	ldrhne r3,[r1,#0x32]
	strh r3,[r2,#0x34]

	tst r0,#LCD_ICON_DOT2
	moveq r3,r4
	ldrhne r3,[r1,#0x34]
	strh r3,[r2,#0x36]

	tst r0,#LCD_ICON_DOT3
	moveq r3,r4
	ldrhne r3,[r1,#0x36]
	strh r3,[r2,#0x38]

	ldmfd sp!,{r4-r5,pc}

	.section .rodata
	.align 2
;@----------------------------------------------------------------------------
defaultInTable:
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
	.long wsvUnmappedR			;@ 0x18 ---
	.long wsvUnmappedR			;@ 0x19 ---
	.long wsvLCDVolumeR			;@ 0x1A Volume Icons
	.long wsvUnmappedR			;@ 0x1B ---
	.long wsvRegR				;@ 0x1C Pal mono pool 0
	.long wsvRegR				;@ 0x1D Pal mono pool 1
	.long wsvRegR				;@ 0x1E Pal mono pool 2
	.long wsvRegR				;@ 0x1F Pal mono pool 3

	.long wsvRegR				;@ 0x20 Pal mono 0 low
	.long wsvRegR				;@ 0x21 Pal mono 0 high
	.long wsvRegR				;@ 0x22 Pal mono 1 low
	.long wsvRegR				;@ 0x23 Pal mono 1 high
	.long wsvRegR				;@ 0x24 Pal mono 2 low
	.long wsvRegR				;@ 0x25 Pal mono 2 high
	.long wsvRegR				;@ 0x26 Pal mono 3 low
	.long wsvRegR				;@ 0x27 Pal mono 3 high
	.long wsvRegR				;@ 0x28 Pal mono 4 low
	.long wsvRegR				;@ 0x29 Pal mono 4 high
	.long wsvRegR				;@ 0x2A Pal mono 5 low
	.long wsvRegR				;@ 0x2B Pal mono 5 high
	.long wsvRegR				;@ 0x2C Pal mono 6 low
	.long wsvRegR				;@ 0x2D Pal mono 6 high
	.long wsvRegR				;@ 0x2E Pal mono 7 low
	.long wsvRegR				;@ 0x2F Pal mono 7 high

	.long wsvRegR				;@ 0x30 Pal mono 8 low
	.long wsvRegR				;@ 0x31 Pal mono 8 high
	.long wsvRegR				;@ 0x32 Pal mono 9 low
	.long wsvRegR				;@ 0x33 Pal mono 9 high
	.long wsvRegR				;@ 0x34 Pal mono A low
	.long wsvRegR				;@ 0x35 Pal mono A high
	.long wsvRegR				;@ 0x36 Pal mono B low
	.long wsvRegR				;@ 0x37 Pal mono B high
	.long wsvRegR				;@ 0x38 Pal mono C low
	.long wsvRegR				;@ 0x39 Pal mono C high
	.long wsvRegR				;@ 0x3A Pal mono D low
	.long wsvRegR				;@ 0x3B Pal mono D high
	.long wsvRegR				;@ 0x3C Pal mono E low
	.long wsvRegR				;@ 0x3D Pal mono E high
	.long wsvRegR				;@ 0x3E Pal mono F low
	.long wsvRegR				;@ 0x3F Pal mono F high
			;@ DMA registers, only WSC
	.long wsvRegR				;@ 0x40 DMA source
	.long wsvRegR				;@ 0x41 DMA source
	.long wsvRegR				;@ 0x42 DMA source
	.long wsvUnmappedR			;@ 0x43 ---
	.long wsvRegR				;@ 0x44 DMA destination
	.long wsvRegR				;@ 0x45 DMA destination
	.long wsvRegR				;@ 0x46 DMA length
	.long wsvRegR				;@ 0x47 DMA length
	.long wsvRegR				;@ 0x48 DMA control
	.long wsvUnmappedR			;@ 0x49 ---
	.long wsvSndDMASrc0R		;@ 0x4A Sound DMA source
	.long wsvSndDMASrc1R		;@ 0x4B Sound DMA source
	.long wsvSndDMASrc2R		;@ 0x4C Sound DMA source
	.long wsvUnmappedR			;@ 0x4D ---
	.long wsvSndDMALen0R		;@ 0x4E Sound DMA length
	.long wsvSndDMALen1R		;@ 0x4F Sound DMA length

	.long wsvSndDMALen2R		;@ 0x50 Sound DMA length
	.long wsvUnmappedR			;@ 0x51 ---
	.long wsvRegR				;@ 0x52 Sound DMA control
	.long wsvUnmappedR			;@ 0x53 ---
	.long wsvUnmappedR			;@ 0x54 ---
	.long wsvUnmappedR			;@ 0x55 ---
	.long wsvUnmappedR			;@ 0x56 ---
	.long wsvUnmappedR			;@ 0x57 ---
	.long wsvUnmappedR			;@ 0x58 ---
	.long wsvUnmappedR			;@ 0x59 ---
	.long wsvUnmappedR			;@ 0x5A ---
	.long wsvUnmappedR			;@ 0x5B ---
	.long wsvUnmappedR			;@ 0x5C ---
	.long wsvUnmappedR			;@ 0x5D ---
	.long wsvUnmappedR			;@ 0x5E ---
	.long wsvUnmappedR			;@ 0x5F ---

	.long wsvRegR				;@ 0x60 Display mode
	.long wsvUnmappedR			;@ 0x61 ---
	.long wsvImportantR			;@ 0x62 WSC System / Power
	.long wsvUnmappedR			;@ 0x63 ---
	.long wsvUnmappedR			;@ 0x64 ---
	.long wsvUnmappedR			;@ 0x65 ---
	.long wsvUnmappedR			;@ 0x66 ---
	.long wsvUnmappedR			;@ 0x67 ---
	.long wsvUnmappedR			;@ 0x68 ---
	.long wsvUnmappedR			;@ 0x69 ---
	.long wsvImportantR			;@ 0x6A Hyper control
	.long wsvHyperChanCtrlR		;@ 0x6B Hyper Chan control
	.long wsvUnmappedR			;@ 0x6C ---
	.long wsvUnmappedR			;@ 0x6D ---
	.long wsvUnmappedR			;@ 0x6E ---
	.long wsvUnmappedR			;@ 0x6F ---

	.long wsvImportantR			;@ 0x70 Unknown70, LCD settings on SC?
	.long wsvImportantR			;@ 0x71 Unknown71
	.long wsvImportantR			;@ 0x72 Unknown72
	.long wsvImportantR			;@ 0x73 Unknown73
	.long wsvImportantR			;@ 0x74 Unknown74
	.long wsvImportantR			;@ 0x75 Unknown75
	.long wsvImportantR			;@ 0x76 Unknown76
	.long wsvImportantR			;@ 0x77 Unknown77
	.long wsvUnmappedR			;@ 0x78 ---
	.long wsvUnmappedR			;@ 0x79 ---
	.long wsvUnmappedR			;@ 0x7A ---
	.long wsvUnmappedR			;@ 0x7B ---
	.long wsvUnmappedR			;@ 0x7C ---
	.long wsvUnmappedR			;@ 0x7D ---
	.long wsvUnmappedR			;@ 0x7E ---
	.long wsvUnmappedR			;@ 0x7F ---

	.long wsvRegR				;@ 0x80 Sound Ch1 pitch low
	.long wsvRegR				;@ 0x81 Sound Ch1 pitch high
	.long wsvRegR				;@ 0x82 Sound Ch2 pitch low
	.long wsvRegR				;@ 0x83 Sound Ch2 pitch high
	.long wsvRegR				;@ 0x84 Sound Ch3 pitch low
	.long wsvRegR				;@ 0x85 Sound Ch3 pitch high
	.long wsvRegR				;@ 0x86 Sound Ch4 pitch low
	.long wsvRegR				;@ 0x87 Sound Ch4 pitch high
	.long wsvRegR				;@ 0x88 Sound Ch1 volume
	.long wsvRegR				;@ 0x89 Sound Ch2 volume
	.long wsvRegR				;@ 0x8A Sound Ch3 volume
	.long wsvRegR				;@ 0x8B Sound Ch4 volume
	.long wsvRegR				;@ 0x8C Sweeep value
	.long wsvRegR				;@ 0x8D Sweep time
	.long wsvRegR				;@ 0x8E Noise control
	.long wsvRegR				;@ 0x8F Wave base

	.long wsvRegR				;@ 0x90 Sound control
	.long wsvRegR				;@ 0x91 Sound output
	.long wsvRegR				;@ 0x92 Noise LFSR value low
	.long wsvRegR				;@ 0x93 Noise LFSR value high
	.long wsvRegR				;@ 0x94 Sound voice control
	.long wsvRegR				;@ 0x95 Sound Hyper voice
	.long wsvImportantR			;@ 0x96 SND9697 SND_OUT_R (ch1-4) right output, 10bit.
	.long wsvImportantR			;@ 0x97 SND9697
	.long wsvImportantR			;@ 0x98 SND9899 SND_OUT_L (ch1-4) left output, 10bit.
	.long wsvImportantR			;@ 0x99 SND9899
	.long wsvImportantR			;@ 0x9A SND9A9B SND_OUT_M (ch1-4) mix output, 11bit.
	.long wsvImportantR			;@ 0x9B SND9A9B
	.long wsvUnknownR			;@ 0x9C SND9C
	.long wsvUnknownR			;@ 0x9D SND9D
	.long wsvImportantR			;@ 0x9E HW Volume
	.long wsvUnmappedR			;@ 0x9F ---

	.long wsvRegR				;@ 0xA0 Color or mono HW
	.long wsvUnmappedR			;@ 0xA1 ---
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
	.long wsvUnmappedR			;@ 0xAD ---
	.long wsvUnmappedR			;@ 0xAE ---
	.long wsvUnmappedR			;@ 0xAF ---

	.long wsvInterruptBaseR		;@ 0xB0 Interrupt base
	.long wsvComByteR			;@ 0xB1 Serial data
	.long wsvRegR				;@ 0xB2 Interrupt enable
	.long wsvSerialStatusR		;@ 0xB3 Serial status
	.long wsvRegR				;@ 0xB4 Interrupt status
	.long IOPortA_R				;@ 0xB5 keypad
	.long wsvZeroR				;@ 0xB6 Interrupt acknowledge
	.long wsvRegR				;@ 0xB7 NMI ctrl, bit 4.
	.long wsvUnmappedR			;@ 0xB8 ---
	.long wsvUnmappedR			;@ 0xB9 ---
	.long intEepromDataLowR		;@ 0xBA Internal eeprom data low
	.long intEepromDataHighR	;@ 0xBB Internal eeprom data high
	.long intEepromAdrLowR		;@ 0xBC Internal eeprom address low
	.long intEepromAdrHighR		;@ 0xBD Internal eeprom address high
	.long intEepromStatusR		;@ 0xBE Internal eeprom status
	.long wsvUnknownR			;@ 0xBF ???

;@----------------------------------------------------------------------------
defaultOutTable:
	.long wsvDisplayCtrlW		;@ 0x00 Display control
	.long wsvRegW				;@ 0x01 Background color
	.long wsvReadOnlyW			;@ 0x02 Current scan line
	.long wsvRegW				;@ 0x03 Scan line compare
	.long wsvSpriteTblAdrW		;@ 0x04 Sprite table address
	.long wsvSpriteFirstW		;@ 0x05 Sprite to start with
	.long wsvRegW				;@ 0x06 Sprite count
	.long wsvMapAdrW			;@ 0x07 Map table address
	.long wsvFgWinX0W			;@ 0x08 Window X-Position
	.long wsvFgWinY0W			;@ 0x09 Window Y-Position
	.long wsvFgWinX1W			;@ 0x0A Window X-End
	.long wsvFgWinY1W			;@ 0x0B Window Y-End
	.long wsvRegW				;@ 0x0C Sprite window X-Position
	.long wsvRegW				;@ 0x0D Sprite window Y-Position
	.long wsvRegW				;@ 0x0E Sprite window X-Size
	.long wsvRegW				;@ 0x0F Sprite window Y-Size

	.long wsvBgScrXW			;@ 0x10 Bg scroll X
	.long wsvBgScrYW			;@ 0x11 Bg scroll Y
	.long wsvFgScrXW			;@ 0x12 Fg scroll X
	.long wsvFgScrYW			;@ 0x13 Fg scroll Y
	.long wsvRegW				;@ 0x14 LCD control (on/off?)
	.long wsvLCDIconW			;@ 0x15 LCD icons
	.long wsvRefW				;@ 0x16 Total scan lines
	.long wsvRegW				;@ 0x17 Vsync line
	.long wsvUnmappedW			;@ 0x18 ---
	.long wsvUnmappedW			;@ 0x19 ---
	.long wsvUnknownW			;@ 0x1A Volume Icons, LCD sleep
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
	.long wsvDMASourceW			;@ 0x40	DMA source
	.long wsvRegW				;@ 0x41 DMA src
	.long wsvDMASourceHW		;@ 0x42 DMA src
	.long wsvZeroW				;@ 0x43 ---
	.long wsvDMADestW			;@ 0x44 DMA destination
	.long wsvRegW				;@ 0x45 DMA dst
	.long wsvDMALengthW			;@ 0x46 DMA length
	.long wsvRegW				;@ 0x47 DMA len
	.long wsvDMACtrlW			;@ 0x48 DMA control
	.long wsvRegW				;@ 0x49 DMA ctrl
	.long wsvSndDMASrc0W		;@ 0x4A	Sound DMA source
	.long wsvSndDMASrc1W		;@ 0x4B Sound DMA src
	.long wsvSndDMASrc2W		;@ 0x4C Sound DMA src
	.long wsvZeroW				;@ 0x4D Sound DMA src
	.long wsvSndDMALen0W		;@ 0x4E Sound DMA length
	.long wsvSndDMALen1W		;@ 0x4F Sound DMA len

	.long wsvSndDMALen2W		;@ 0x50 Sound DMA len
	.long wsvZeroW				;@ 0x51 Sound DMA len
	.long wsvSndDMACtrlW		;@ 0x52 Sound DMA control
	.long wsvZeroW				;@ 0x53 ---
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

	.long wsvVideoModeW			;@ 0x60 Display mode
	.long wsvUnmappedW			;@ 0x61 ---
	.long wsvSysCtrl3W			;@ 0x62 SwanCrystal/Power off
	.long wsvUnmappedW			;@ 0x63 ---
	.long wsvImportantW			;@ 0x64 Hyper Voice Left channel (lower byte)
	.long wsvImportantW			;@ 0x65 Hyper Voice Left channel (upper byte)
	.long wsvImportantW			;@ 0x66 Hyper Voice Right channel (lower byte)
	.long wsvImportantW			;@ 0x67 Hyper Voice Right channel (upper byte)
	.long wsvImportantW			;@ 0x68 Hyper Voice Shadow (lower byte? Left?)
	.long wsvImportantW			;@ 0x69 Hyper Voice Shadow (upper byte? Right?)
	.long wsvImportantW			;@ 0x6A Hyper Voice control
	.long wsvHyperChanCtrlW		;@ 0x6B Hyper Chan control
	.long wsvUnmappedW			;@ 0x6C ---
	.long wsvUnmappedW			;@ 0x6D ---
	.long wsvUnmappedW			;@ 0x6E ---
	.long wsvUnmappedW			;@ 0x6F ---

	.long wsvImportantW			;@ 0x70 Unknown70, LCD settings on SC?
	.long wsvImportantW			;@ 0x71 Unknown71
	.long wsvImportantW			;@ 0x72 Unknown72
	.long wsvImportantW			;@ 0x73 Unknown73
	.long wsvImportantW			;@ 0x74 Unknown74
	.long wsvImportantW			;@ 0x75 Unknown75
	.long wsvImportantW			;@ 0x76 Unknown76
	.long wsvImportantW			;@ 0x77 Unknown77
	.long wsvUnmappedW			;@ 0x78 ---
	.long wsvUnmappedW			;@ 0x79 ---
	.long wsvUnmappedW			;@ 0x7A ---
	.long wsvUnmappedW			;@ 0x7B ---
	.long wsvUnmappedW			;@ 0x7C ---
	.long wsvUnmappedW			;@ 0x7D ---
	.long wsvUnmappedW			;@ 0x7E ---
	.long wsvUnmappedW			;@ 0x7F ---

	.long wsvFreqLW				;@ 0x80 Sound Ch1 pitch low
	.long wsvFreqHW				;@ 0x81 Sound Ch1 pitch high
	.long wsvFreqLW				;@ 0x82 Sound Ch2 pitch low
	.long wsvFreqHW				;@ 0x83 Sound Ch2 pitch high
	.long wsvFreqLW				;@ 0x84 Sound Ch3 pitch low
	.long wsvFreqHW				;@ 0x85 Sound Ch3 pitch high
	.long wsvFreqLW				;@ 0x86 Sound Ch4 pitch low
	.long wsvFreqHW				;@ 0x87 Sound Ch4 pitch high
	.long wsvCh1VolumeW			;@ 0x88 Sound Ch1 volume
	.long wsvCh2VolumeW			;@ 0x89 Sound Ch2 volume
	.long wsvCh3VolumeW			;@ 0x8A Sound Ch3 volume
	.long wsvCh4VolumeW			;@ 0x8B Sound Ch4 volume
	.long wsvRegW				;@ 0x8C Sweeep value
	.long wsvSweepTimeW			;@ 0x8D Sweep time
	.long wsvNoiseCtrlW			;@ 0x8E Noise control
	.long wsvSampleBaseW		;@ 0x8F Sample base

	.long wsvSoundCtrlW			;@ 0x90 Sound control
	.long wsvSoundOutputW		;@ 0x91 Sound output
	.long wsvReadOnlyW			;@ 0x92 Noise LFSR value low
	.long wsvReadOnlyW			;@ 0x93 Noise LFSR value high
	.long wsvRegW				;@ 0x94 Sound voice control
	.long wsvImportantW			;@ 0x95 Sound Test
	.long wsvReadOnlyW			;@ 0x96 SND9697 SND_OUT_R (ch1-4) right output, 10bit.
	.long wsvReadOnlyW			;@ 0x97 SND9697
	.long wsvReadOnlyW			;@ 0x98 SND9899 SND_OUT_L (ch1-4) left output, 10bit.
	.long wsvReadOnlyW			;@ 0x99 SND9899
	.long wsvReadOnlyW			;@ 0x9A SND9A9B SND_OUT_M (ch1-4) mix output, 11bit.
	.long wsvReadOnlyW			;@ 0x9B SND9A9B
	.long wsvUnknownW			;@ 0x9C SND9C
	.long wsvUnknownW			;@ 0x9D SND9D
	.long wsvHWVolumeW			;@ 0x9E HW Volume
	.long wsvUnmappedW			;@ 0x9F ---

	.long wsvHWW				;@ 0xA0 Hardware type, SOC_ASWAN / SOC_SPHINX.
	.long wsvUnmappedW			;@ 0xA1 ---
	.long wsvTimerCtrlW			;@ 0xA2 Timer control
	.long wsvUnknownW			;@ 0xA3 ???
	.long wsvHTimerLowW			;@ 0xA4 HBlank timer low
	.long wsvHTimerHighW		;@ 0xA5 HBlank timer high
	.long wsvVTimerLowW			;@ 0xA6 VBlank timer low
	.long wsvVTimerHighW		;@ 0xA7 VBlank timer high
	.long wsvReadOnlyW			;@ 0xA8 HBlank counter low
	.long wsvReadOnlyW			;@ 0xA9 HBlank counter high
	.long wsvReadOnlyW			;@ 0xAA VBlank counter low
	.long wsvReadOnlyW			;@ 0xAB VBlank counter high
	.long wsv0xACW				;@ 0xAC Power Off???
	.long wsvUnmappedW			;@ 0xAD ---
	.long wsvUnmappedW			;@ 0xAE ---
	.long wsvUnmappedW			;@ 0xAF ---

	.long wsvInterruptBaseW		;@ 0xB0 Interrupt base
	.long wsvComByteW			;@ 0xB1 Serial data
	.long wsvIntEnableW			;@ 0xB2 Interrupt enable
	.long wsvSerialStatusW		;@ 0xB3 Serial status
	.long wsvReadOnlyW			;@ 0xB4 Interrupt status
	.long wsvRegW				;@ 0xB5 Input Controls
	.long wsvIntAckW			;@ 0xB6 Interrupt acknowledge
	.long wsvNMICtrlW			;@ 0xB7 NMI ctrl
	.long wsvUnmappedW			;@ 0xB8 ---
	.long wsvUnmappedW			;@ 0xB9 ---
	.long intEepromDataLowW		;@ 0xBA Internal eeprom data low
	.long intEepromDataHighW	;@ 0xBB Internal eeprom data high
	.long intEepromAdrLowW		;@ 0xBC Internal eeprom address low
	.long intEepromAdrHighW		;@ 0xBD Internal eeprom address high
	.long intEepromCommandW		;@ 0xBE Internal eeprom command
	.long wsvUnknownW			;@ 0xBF ???

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
	.align 2
CHR_DECODE:
	.space 0x400
DISP_BUFF:
	.space 160
SCROLL_BUFF:
	.space 160*4*2
WINDOW_BUFF:
	.space 160*4

#endif // #ifdef __arm__
