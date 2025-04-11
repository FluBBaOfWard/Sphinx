//
//  WSVideo.s
//  Bandai WonderSwan Video emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2025 Fredrik Ahlström. All rights reserved.
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
	.global wsvSetCartOk
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
	.global spxGetIOPortRaw
	.global wsvCopyScrollValues
	.global wsvConvertTileMaps
	.global wsvConvertSprites
	.global wsvRefW
	.global wsvGetInterruptVector
	.global wsvSetInterruptExternal
	.global wsvPushVolumeButton
	.global wsvGetHeadphones
	.global wsvSetHeadphones
	.global wsvSetLowBattery
	.global wsvSetJoyState
	.global wsvSetSerialByteIn
	.global wsvSetPowerOff
	.global wsvHandleHalt

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
wsVideoReset:				;@ r0=ram+LUTs, r1=machine, r2=IrqFunc
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r2,lr}

	mov r0,spxptr
	ldr r1,=sphinxSize/4
	bl memclr_					;@ Clear Sphinx state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#1
	stmia spxptr,{r0-r2}		;@ Reset scanline, nextChange & lineState
	mov r0,#-1
	str r0,[spxptr,#serialRXCounter]
	str r0,[spxptr,#serialTXCounter]

	ldmfd sp!,{r0-r2}

	str r0,[spxptr,#gfxRAM]
	add r0,r0,#0xFE00
	str r0,[spxptr,#paletteRAM]
	ldr r0,=DISP_BUFF
	str r0,[spxptr,#dispBuff]
	ldr r0,=WINDOW_BUFF
	str r0,[spxptr,#windowBuff]
	ldr r0,=SCROLL_BUFF
	str r0,[spxptr,#scrollBuff]

	strb r1,[spxptr,#wsvMachine]
	cmp r1,#HW_WONDERSWAN
	cmpne r1,#HW_POCKETCHALLENGEV2
	moveq r0,#SOC_ASWAN
	movne r0,#SOC_SPHINX2
	subs r3,r1,#HW_WONDERSWANCOLOR
	ldrne r3,=0xFFF
	moveq r0,#SOC_SPHINX
	strb r0,[spxptr,#wsvSOC]
	str r3,[spxptr,#wsvDefaultBgCol]

	cmp r2,#0
	adreq r2,dummyIrqFunc
	str r2,[spxptr,#irqFunction]
	adr r3,dummyIrqFunc
	str r3,[spxptr,#rxFunction]
	str r3,[spxptr,#txFunction]

	;@ r0=SOC
	bl initIOMap

	ldmfd sp!,{lr}
	b resetRegisters

dummyIrqFunc:
	bx lr
;@----------------------------------------------------------------------------
wsvHandleHalt:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSystemCtrl3]
	tst r0,#1
	bxeq lr
;@----------------------------------------------------------------------------
wsvSetPowerOff:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0
	ldr r1,=powerIsOn
	strb r0,[r1]

	ldrb r0,[spxptr,#wsvPowerOff]
	orr r0,r0,#1
	strb r0,[spxptr,#wsvPowerOff]
	mov r0,#143
	str r0,[spxptr,#scanline]
	bl setMuteSoundChip
	bl setupEmuBgrShutDown
	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
initIOMap:					;@ r0=SOC
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

	ldr r1,=wsvUnmappedR
	ldr r2,=wsvUnmappedW
	cmp r0,#SOC_SPHINX2
	streq r1,[r3,#0x17<<2]		;@ Back porch not on SPHINX2
	streq r2,[r4,#0x17<<2]
	ldmfdeq sp!,{r4,r5,pc}
	cmp r0,#SOC_ASWAN
	streq r1,[r3,#0x9E<<2]		;@ HW Volume not on ASWAN
	streq r2,[r4,#0x9E<<2]
	streq r1,[r3,#0xAC<<2]		;@ Power Off not on ASWAN
	streq r2,[r4,#0xAC<<2]
	moveq r5,#0x40
	movne r5,#0x70				;@ SPHINX
ioASLoop:
	str r1,[r3,r5,lsl#2]
	str r2,[r4,r5,lsl#2]
	add r5,r5,#1
	cmp r5,#0x78
	bne ioASLoop
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------
setIOMode:					;@ r0=color mode, 0=mono !0=color.
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
	cmp r5,#0x60
	bne ioMode1Loop
	ldmfd sp!,{r4,r5,pc}

modeMono:
	ldr r1,=wsvUnmappedR
	ldr r2,=wsvUnmappedW
ioMode0Loop:
	str r1,[r3,r5,lsl#2]
	str r2,[r4,r5,lsl#2]
	add r5,r5,#1
	cmp r5,#0x60
	bne ioMode0Loop
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------
wsvSetCartMap:				;@ r0=inTable, r1=outTable, r2=length, r3=defaultIn
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r6,lr}
	ldr r4,=cartInTable
	ldr r5,=cartOutTable
	rsb r6,r2,#0x40
cartTblLoop:
	subs r2,r2,#1
	ldr lr,[r0],#4
	str lr,[r4],#4
	ldr lr,[r1],#4
	str lr,[r5],#4
	bhi cartTblLoop

	ldr lr,=wsvUnmappedW
cartTblLoop2:
	subs r6,r6,#1
	str r3,[r4],#4
	str lr,[r5],#4
	bhi cartTblLoop2

	ldmfd sp!,{r4-r6,lr}
	bx lr
;@----------------------------------------------------------------------------
wsvSetIOPortOut:			;@ r0=port, r1=function
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
handleSerialOutW:
;@----------------------------------------------------------------------------
	ldr r3,[spxptr,#txFunction]
	bx r3
;@----------------------------------------------------------------------------
callSerialInEmpty:
;@----------------------------------------------------------------------------
	stmfd sp!,{spxptr,lr}
	ldr r3,[spxptr,#rxFunction]
	mov lr,pc
	bx r3
	ldmfd sp!,{spxptr,pc}
;@----------------------------------------------------------------------------
memCopy:
;@----------------------------------------------------------------------------
	ldr r3,=memcpy
;@----------------------------------------------------------------------------
thumbCallR3:
;@----------------------------------------------------------------------------
	bx r3
;@----------------------------------------------------------------------------
wsvSetCartOk:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSystemCtrl1]
	cmp r0,#0
	orrne r1,r1,#0x80
	strb r1,[spxptr,#wsvSystemCtrl1]
	movne r0,#LCD_ICON_TIME_VALUE
	strb r0,[spxptr,#wsvCartIconTimer]
	bx lr
;@----------------------------------------------------------------------------
resetRegisters:				;@ in r0=SOC
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,spxptr,lr}
	adr r1,AswanIODefault
	cmp r0,#SOC_SPHINX
	adreq r1,SphinxIODefault
	adrhi r1,Sphinx2IODefault
	mov r2,#0xC0
	add r0,spxptr,#wsvRegs
	bl memCopy
	ldmfd sp!,{r1,spxptr}
	mov r2,#0xF1				;@ 0x14 default mask
	cmp r1,#SOC_SPHINX2
	moveq r2,#0x01				;@ 0x14 spx2 mask
	moveq r0,#0x80
	strbeq r0,[spxptr,#wsvSystemCtrl3]
	strb r2,[spxptr,#wsvRegMask14]
	cmp r1,#SOC_ASWAN
	mov r0,#0x02				;@ Color mode
	strbne r0,[spxptr,#wsvSystemCtrl1]
	bleq wsvHWVolumeW
	ldmfd sp!,{lr}

	ldrb r0,[spxptr,#wsvTotalLines]
	b wsvRefW

;@----------------------------------------------------------------------------
AswanIODefault:
	.byte 0x00, 0x00, 0x01, 0x40, 0x00, 0x00, 0x00, 0x12	;@ 0x00
	.byte 0x10, 0x60, 0x00, 0x00, 0x8a, 0x00, 0x10, 0x04	;@ 0x08
	.byte 0x01, 0xce, 0x81, 0x20, 0x00, 0x00, 0x9c, 0x92	;@ 0x10
	.byte 0x00, 0x00, 0x00, 0x00, 0x80, 0x04, 0x22, 0x70	;@ 0x18
	.byte 0x60, 0x01, 0x00, 0x42, 0x02, 0x40, 0x00, 0x65	;@ 0x20
	.byte 0x10, 0x21, 0x10, 0x14, 0x30, 0x10, 0x20, 0x03	;@ 0x28
	.byte 0x02, 0x50, 0x04, 0x52, 0x01, 0x20, 0x21, 0x02	;@ 0x30
	.byte 0x00, 0x04, 0x60, 0x00, 0x00, 0x00, 0x20, 0x00	;@ 0x38
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x40
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x48
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x50
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x58
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x60
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x68
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x70
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x78
	.byte 0x00, 0x00, 0x00, 0x04, 0x25, 0x07, 0x00, 0x01	;@ 0x80
	.byte 0x00, 0x88, 0x00, 0x84, 0x00, 0x19, 0x00, 0x1a	;@ 0x88
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x90
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x98
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0xa0, 0x50, 0x44	;@ 0xA0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xA8
	.byte 0x00, 0xa4, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB8

SphinxIODefault:
	.byte 0x00, 0x00, 0x01, 0xb9, 0x00, 0x00, 0x00, 0xbf	;@ 0x00
	.byte 0x8e, 0xff, 0x88, 0xff, 0xd1, 0xfb, 0xae, 0xb7	;@ 0x08
	.byte 0xbc, 0xef, 0x2f, 0x07, 0x00, 0x00, 0x9e, 0x9b	;@ 0x10
	.byte 0x00, 0x00, 0x00, 0x00, 0x81, 0xe9, 0x77, 0xdf	;@ 0x18
	.byte 0x73, 0x70, 0x77, 0x34, 0x67, 0x55, 0x56, 0x63	;@ 0x20
	.byte 0x70, 0x70, 0x00, 0x43, 0x20, 0x57, 0x10, 0x77	;@ 0x28
	.byte 0x47, 0x77, 0x43, 0x76, 0x32, 0x66, 0x43, 0x72	;@ 0x30
	.byte 0x50, 0x36, 0x40, 0x75, 0x30, 0x56, 0x30, 0x53	;@ 0x38
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x40
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x48
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x50
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x58
	.byte 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x60
	.byte 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00	;@ 0x68
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x70
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x78
	.byte 0x2d, 0x07, 0x13, 0x07, 0x20, 0x07, 0x7f, 0x05	;@ 0x80
	.byte 0xf7, 0xef, 0xcf, 0xf6, 0xfb, 0x0c, 0x00, 0xbb	;@ 0x88
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x90
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x98
	.byte 0x00, 0x00, 0x00, 0x00, 0xec, 0xbc, 0x7f, 0xf0	;@ 0xA0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xA8
	.byte 0x00, 0xa5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB8

Sphinx2IODefault:
	.byte 0x00, 0x00, 0x01, 0x1a, 0x00, 0x00, 0x00, 0x18	;@ 0x00
	.byte 0x91, 0x07, 0xe0, 0xe6, 0x01, 0x81, 0x5a, 0x16	;@ 0x08
	.byte 0x6b, 0x06, 0x74, 0x30, 0x00, 0x00, 0x9e, 0x00	;@ 0x10
	.byte 0x00, 0x00, 0x20, 0x00, 0x00, 0xd4, 0x93, 0x28	;@ 0x18
	.byte 0x32, 0x27, 0x51, 0x14, 0x10, 0x40, 0x00, 0x00	;@ 0x20
	.byte 0x00, 0x20, 0x20, 0x04, 0x40, 0x10, 0x10, 0x34	;@ 0x28
	.byte 0x43, 0x04, 0x06, 0x43, 0x05, 0x40, 0x50, 0x41	;@ 0x30
	.byte 0x40, 0x03, 0x50, 0x65, 0x50, 0x04, 0x60, 0x45	;@ 0x38
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x40
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x48
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x50
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x58
	.byte 0x0a, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x60
	.byte 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00	;@ 0x68
	.byte 0xd0, 0x77, 0xf7, 0x06, 0xe2, 0x0a, 0xea, 0xee	;@ 0x70
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x78
	.byte 0xba, 0x00, 0xd0, 0x04, 0xe0, 0x02, 0x8a, 0x02	;@ 0x80
	.byte 0x89, 0x60, 0x41, 0x64, 0x28, 0x13, 0x00, 0x10	;@ 0x88
	.byte 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00	;@ 0x90
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0x98
	.byte 0x00, 0x00, 0x00, 0x00, 0x09, 0x18, 0x80, 0x94	;@ 0xA0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xA8
	.byte 0x00, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB0
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	;@ 0xB8

;@----------------------------------------------------------------------------
sphinxSaveState:			;@ In r0=dest, r1=spxptr. Out r0=state size.
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
sphinxLoadState:			;@ In r0=spxptr, r1=source. Out r0=state size.
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
sphinxGetStateSize:			;@ Out r0=state size.
	.type sphinxGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#sphinxStateSize
	bx lr

;@----------------------------------------------------------------------------
spxGetIOPortRaw:			;@ r0=Sphinx, r1=port
	.type spxGetIOPortRaw STT_FUNC
;@----------------------------------------------------------------------------
	and r1,r1,#0xFF
	add r0,r0,#wsvRegs
	ldrb r0,[r0,r1]
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
	ldrcc pc,[pc,r0,lsl#2]
	b wsvReadHigh
ioInTable:
	.space 0xC0*4
;@----------------------------------------------------------------------------
;@Cartridge					;@ I/O read cart (0xC0-0xFF)
;@----------------------------------------------------------------------------
cartInTable:
	.space 0x40*4

;@----------------------------------------------------------------------------
wsvWriteOnlyR:
wsvUnmappedR:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	ldrb r1,[spxptr,#wsvSOC]
	cmp r1,#SOC_ASWAN			;@ Mono model?
	moveq r1,#0x90
	movne r1,#0x00
	stmfd sp!,{r1,spxptr,lr}
	bl _debugIOUnmappedR
	ldmfd sp!,{r0,spxptr,lr}
	bx lr
;@----------------------------------------------------------------------------
wsvZeroR:
;@----------------------------------------------------------------------------
	mov r1,#0x00
	stmfd sp!,{r1,spxptr,lr}
	bl _debugIOUnmappedR
	ldmfd sp!,{r0,spxptr,lr}
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
wsvVCountR:					;@ 0x02
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#scanline]
	bx lr
;@----------------------------------------------------------------------------
wsvLatchedIconsR:			;@ 0x1A
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvLatchedIcons]
	ldrb r1,[spxptr,#wsvCartIconTimer]
	ldrb r2,[spxptr,#wsvSoundIconTimer]
	and r0,r0,#1				;@ LCD block disabled?
	cmp r1,#0					;@ Cart icon?
	orrne r0,r0,#0x20
	cmp r2,#0					;@ Sound icons?
	bxeq lr
	ldrb r1,[spxptr,#wsvSoundOutput]
	ands r1,r1,#0x80			;@ Headphones?
	orrne r0,r0,#0x02
	orreq r0,r0,#0x10			;@ Speaker
	ldrbeq r1,[spxptr,#wsvHWVolume]
	movs r1,r1,lsl#31
	orrmi r0,r0,#0x08
	orrcs r0,r0,#0x04
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
wsvNoiseCntrLR:				;@ 0x92
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#noise4CurrentAddr+2]
	bx lr
;@----------------------------------------------------------------------------
wsvNoiseCntrHR:				;@ 0x93
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#noise4CurrentAddr+3]
	and r0,r0,#0x7F
	bx lr
;@----------------------------------------------------------------------------
wsvGetInterruptVector:		;@ return vector in r0
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
wsvInterruptBaseR:			;@ 0xB0
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvInterruptStatus]
#ifdef GBA
	mov r1,#7
	mov r0,r0,lsl#24
intVecLoop:
	movs r0,r0,lsl#1
	bcs intFound
	subs r1,r1,#1
	bne intVecLoop
intFound:
#else
	clz r1,r0
	rsbs r1,r1,#31
	movmi r1,#0
#endif
	ldrb r0,[spxptr,#wsvInterruptBase]
	orr r0,r0,r1
	bx lr
;@----------------------------------------------------------------------------
wsvComByteR:				;@ 0xB1
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#SERRX_IRQ_F			;@ #3 = Serial receive
	bl clearInterruptPins
	bl callSerialInEmpty
	mov r0,#0
	strb r0,[spxptr,#wsvSerialBufFull]
	ldrb r0,[spxptr,#wsvByteReceived]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
wsvSerialStatusR:			;@ 0xB3
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSerialStatus]
	ldr r1,[spxptr,#serialTXCounter]
	cmp r1,#0					;@ Send complete?
	orrmi r0,r0,#4
	ldrb r1,[spxptr,#wsvSerialBufFull]
	cmp r1,#0					;@ Receive buffer full?
	orrne r0,r0,#1
	tst r0,#0x80
	andeq r0,r0,#0x40
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
	ldrcc pc,[pc,r1,lsl#2]
	b wsvWriteHigh
ioOutTable:
	.space 0xC0*4
;@----------------------------------------------------------------------------
;@Cartridge					;@ I/O write cart (0xC0-0xFF)
;@----------------------------------------------------------------------------
cartOutTable:
	.space 0x40*4

;@----------------------------------------------------------------------------
wsvZeroW:
;@----------------------------------------------------------------------------
	cmp r0,#0
	bxeq lr
;@----------------------------------------------------------------------------
wsvReadOnlyW:
;@----------------------------------------------------------------------------
wsvUnmappedW:
;@----------------------------------------------------------------------------
	stmfd sp!,{spxptr,lr}
	bl _debugIOUnmappedW
	ldmfd sp!,{spxptr,pc}
;@----------------------------------------------------------------------------
wsvUnknownW:
;@----------------------------------------------------------------------------
	ldr r2,=0x826EBAD0
;@----------------------------------------------------------------------------
wsvImportantW:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	stmfd sp!,{r0,r1,spxptr,lr}
	bl debugIOUnimplW
	ldmfd sp!,{r0,r1,spxptr,lr}
;@----------------------------------------------------------------------------
wsvRegW:
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
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
wsvBgColorW:				;@ 0x01, Background Color
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvVideoMode]
	tst r1,#0x80				;@ Color mode?
	andeq r0,r0,#0x07
	strb r0,[spxptr,#wsvBgColor]
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
wsvMapAdrW:					;@ 0x07, Map table address
;@----------------------------------------------------------------------------
#ifdef __ARM_ARCH_5TE__
	ldrd r2,r3,[spxptr,#wsvBgScrollBak]
#else
	ldr r2,[spxptr,#wsvBgScrollBak]
	ldr r3,[spxptr,#wsvFgScrollBak]
#endif
	ldrb r1,[spxptr,#wsvVideoMode]
	tst r1,#0x80				;@ Color mode?
	andeq r0,r0,#0x77
	strb r0,[spxptr,#wsvMapTblAdr]
	strb r0,[spxptr,#wsvBgScrollBak+1]
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
	ldrd r2,r3,[spxptr,#wsvBgScrollBak]
#else
	ldr r2,[spxptr,#wsvBgScrollBak]
	ldr r3,[spxptr,#wsvFgScrollBak]
#endif
	add r1,r1,#wsvRegs
	strb r0,[spxptr,r1]
	add r1,r1,#(wsvBgScrollBak/2) - wsvBgXScroll
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
wsvLCDControlW:				;@ 0x14, Sleep, WSC contrast.
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvRegMask14]
	and r0,r0,r1
	strb r0,[spxptr,#wsvLCDControl]
	mov r0,r0,lsl#7				;@ Enable default color if LCD sleep.
	strb r0,[spxptr,#wsvDefaultBgCol+3]
	bx lr
;@----------------------------------------------------------------------------
wsvLCDIconW:				;@ 0x15, Enable/disable LCD icons
;@----------------------------------------------------------------------------
	and r0,r0,#0x3F
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
	cmp r0,#0x9C
	movmi r0,#0x9C
	cmp r0,#0xC8
	movpl r0,#0xC8
	add r0,r0,#1
	str r0,lineStateLastLine
	b setScreenRefresh
;@----------------------------------------------------------------------------
wsvLatchedIconsW:			;@ 0x1A
;@----------------------------------------------------------------------------
	ands r1,r0,#1
	strb r1,[spxptr,#wsvLatchedIcons]
	bxeq lr
	mov r1,#LCD_ICON_TIME_VALUE
	movs r0,r0,lsl#27			;@ Cart & Sound icons?
	strbcs r1,[spxptr,#wsvCartIconTimer]
	strbmi r1,[spxptr,#wsvSoundIconTimer]
	bx lr
;@----------------------------------------------------------------------------
wsvPaletteTrW:				;@ 0x28,0x2A,0x2C,0x2E,0x38,0x3A,0x3C,0x3E
;@----------------------------------------------------------------------------
	and r0,r0,#0x70
;@----------------------------------------------------------------------------
wsvPaletteW:				;@ 0x20-0x3F
;@----------------------------------------------------------------------------
	and r0,r0,#0x77
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
wsvDMASourceW:				;@ 0x40, only Color.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMASource]
	bx lr
;@----------------------------------------------------------------------------
wsvDMASourceHW:				;@ 0x42, only Color.
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvDMASource+2]
	bx lr
;@----------------------------------------------------------------------------
wsvDMADestW:				;@ 0x44, only Color.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMADest]
	bx lr
;@----------------------------------------------------------------------------
wsvDMALengthW:				;@ 0x46, only Color.
;@----------------------------------------------------------------------------
	bic r0,r0,#0x01
	strb r0,[spxptr,#wsvDMALength]
	bx lr
;@----------------------------------------------------------------------------
wsvDMACtrlW:				;@ 0x48, only Color, word transfer. steals 5+2*word cycles.
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
	and r0,r0,#0x40				;@ Only keep Inc/dec
	movs r6,r5,lsr#16			;@ r6=length
	beq dmaEnd
	mov r4,r4,lsl#12
	mov r5,r5,lsl#16
	sub v30cyc,v30cyc,#5*CYCLE
	sub v30cyc,v30cyc,r6,lsl#CYC_SHIFT

	rsb r7,r0,#0x20				;@ Inc/dec
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

	rsb r0,r7,#0x20
dmaEnd:
	strb r0,[spxptr,#wsvDMACtrl]
	ldmfd sp!,{r4-r8,pc}
;@----------------------------------------------------------------------------
wsvSndDMASrc0W:				;@ 0x4A, only Color.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcL]
	strb r0,[spxptr,#sndDmaSource]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc1W:				;@ 0x4B, only Color.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcL+1]
	strb r0,[spxptr,#sndDmaSource+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMASrc2W:				;@ 0x4C, only Color.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMASrcH]
	strb r0,[spxptr,#sndDmaSource+2]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen0W:				;@ 0x4E, only Color.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMALenL]
	strb r0,[spxptr,#sndDmaLength]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen1W:				;@ 0x4F, only Color.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSndDMALenL+1]
	strb r0,[spxptr,#sndDmaLength+1]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMALen2W:				;@ 0x50, only Color.
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvSndDMALenH]
	strb r0,[spxptr,#sndDmaLength+2]
	bx lr
;@----------------------------------------------------------------------------
wsvSndDMACtrlW:				;@ 0x52, only Color mode. steals 6+n cycles.
;@----------------------------------------------------------------------------
	ldr r1,[spxptr,#sndDmaLength]
	and r0,r0,#0xDF
	cmp r1,#0
	biceq r0,r0,#0x80
	strb r0,[spxptr,#wsvSndDMACtrl]
	bx lr
;@----------------------------------------------------------------------------
wsvVideoModeW:				;@ 0x60, Video mode, only Color.
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvVideoMode]
	strb r0,[spxptr,#wsvVideoMode]
	eor r1,r1,r0
	tst r1,#0x80				;@ Color mode changed?
	bxeq lr
	and r0,r0,#0x80
	stmfd sp!,{lr}
	bl setIOMode
	ldmfd sp!,{lr}
	b intEepromSetSize
;@----------------------------------------------------------------------------
wsvSysCtrl3W:				;@ 0x62, only Color.
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSystemCtrl3]
	and r0,r0,#1				;@ Power Off bit.
	and r1,r1,#0x80
	orr r0,r0,r1				;@ OR SwanCrystal flag (bit 7).
	strb r0,[spxptr,#wsvSystemCtrl3]
	bx lr
;@----------------------------------------------------------------------------
wsvHyperCtrlW:				;@ 0x6A, only Color
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHyperVCtrl]
	bx lr
;@----------------------------------------------------------------------------
wsvHyperChanCtrlW:			;@ 0x6B, only Color
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHyperVCtrl+1]
	tst r0,#0x10				;@ Reset Left/Right?
	bx lr
;@----------------------------------------------------------------------------
wsvFreqLW:					;@ 0x80,0x82,0x84,0x86, Sound frequency low
;@----------------------------------------------------------------------------
	add r2,spxptr,#wsvRegs
	strb r0,[r2,r1]
	and r1,r1,#6
	add r2,spxptr,#pcm1CurrentAddr
	strb r0,[r2,r1,lsl#1]
	bx lr
;@----------------------------------------------------------------------------
wsvFreqHW:					;@ 0x81,0x83,0x85,0x87, Sound frequency high
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
wsvCh1VolumeW:				;@ 0x88, Sound Channel 1 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound1Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound1Vol]	;@ Each nibble is L & R
	b wsaSetCh1Volume
;@----------------------------------------------------------------------------
wsvCh2VolumeW:				;@ 0x89, Sound Channel 2 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound2Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound2Vol]	;@ Each nibble is L & R
	b wsaSetCh2Volume
;@----------------------------------------------------------------------------
wsvCh3VolumeW:				;@ 0x8A, Sound Channel 3 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound3Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound3Vol]	;@ Each nibble is L & R
	b wsaSetCh3Volume
;@----------------------------------------------------------------------------
wsvCh4VolumeW:				;@ 0x8B, Sound Channel 4 Volume
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSound4Vol]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSound4Vol]	;@ Each nibble is L & R
	b wsaSetCh4Volume
;@----------------------------------------------------------------------------
wsvSweepTimeW:				;@ 0x8D, Sound sweep time
;@----------------------------------------------------------------------------
	and r0,r0,#0x1F				;@ Only low 5 bits
	strb r0,[spxptr,#wsvSweepTime]
	ldr r1,[spxptr,#sweep3CurrentAddr]
	add r0,r0,#1
	sub r0,r0,r0,lsl#26
	and r1,r1,#0x100			;@ Keep sweep enabled.
	orr r0,r0,r1
	str r0,[spxptr,#sweep3CurrentAddr]
	bx lr
;@----------------------------------------------------------------------------
wsvNoiseCtrlW:				;@ 0x8E, Noise Control
;@----------------------------------------------------------------------------
	and r1,r0,#0x17				;@ Only save enable & tap bits
	strb r1,[spxptr,#wsvNoiseCtrl]
	ldr r1,[spxptr,#noise4CurrentAddr]
	mov r1,r1,lsr#12			;@ Clear taps
	tst r0,#0x10				;@ Enable Noise calculation?
	biceq r1,r1,#0x8
	orrne r1,r1,#0x8
	movs r0,r0,lsl#29			;@ Mask taps, Reset to carry
	andcs r1,r1,#0xC			;@ Keep Ch4 noise/calculation on/off
	adr r2,noiseTaps
	ldr r0,[r2,r0,lsr#29-2]
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
wsvSampleBaseW:				;@ 0x8F, Sample Base
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvSampleBase]
	ldr r1,[spxptr,#gfxRAM]
	add r1,r1,r0,lsl#6
	str r1,[spxptr,#sampleBaseAddr]
	bx lr
;@----------------------------------------------------------------------------
wsvSoundCtrlW:				;@ 0x90, Sound Control
;@----------------------------------------------------------------------------
	and r0,r0,#0xEF
	ldrb r1,[spxptr,#wsvSoundCtrl]
	teq r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvSoundCtrl]
	b wsaSetAllChVolume
;@----------------------------------------------------------------------------
wsvSoundOutputW:			;@ 0x91, Sound ouput
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundOutput]
	and r0,r0,#0x0F				;@ Only low 4 bits
	and r1,r1,#0x80				;@ Keep Headphones bit
	orr r0,r0,r1
	strb r0,[spxptr,#wsvSoundOutput]
	b wsaSetSoundOutput
;@----------------------------------------------------------------------------
wsvCh2VoiceVolW:			;@ 0x94, Sound Channel 2 Voice Volume
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F				;@ Only low 4 bits
	strb r0,[spxptr,#wsvCh2VoiceVol]
	bx lr
;@----------------------------------------------------------------------------
wsvPushVolumeButton:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundOutput]
	ldrb r0,[spxptr,#wsvHWVolume]
	tst r1,#0x80				;@ Headphones?
	subeq r0,r0,#1
;@----------------------------------------------------------------------------
wsvHWVolumeW:				;@ 0x9E, HW Volume?
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
	b wsaSetTotalVolume
;@----------------------------------------------------------------------------
wsvHWW:						;@ 0xA0, Color/Mono, boot rom lock
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSystemCtrl1]
	and r0,r0,#0x0D				;@ Only these bits can be set.
	and r1,r1,#0x83				;@ These can't be cleared once set.
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
wsvTimerCtrlW:				;@ 0xA2, Timer control
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,[spxptr,#wsvTimerControl]
	bx lr
;@----------------------------------------------------------------------------
wsvSystemTestW:				;@ 0xA3, System Test
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F				;@ Only low 4 bits
	strb r0,[spxptr,#wsvSystemTest]
	bx lr
;@----------------------------------------------------------------------------
wsvHTimerLowW:				;@ 0xA4, HBlank timer low
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHBlTimerFreq]
	strb r0,[spxptr,#wsvHBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvHTimerHighW:				;@ 0xA5, HBlank timer high
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvHBlTimerFreq+1]
	strb r0,[spxptr,#wsvHBlCounter+1]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerLowW:				;@ 0xA6, VBlank timer low
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvVBlTimerFreq]
	strb r0,[spxptr,#wsvVBlCounter]
	bx lr
;@----------------------------------------------------------------------------
wsvVTimerHighW:				;@ 0xA7, VBlank timer high
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvVBlTimerFreq+1]
	strb r0,[spxptr,#wsvVBlCounter+1]
	bx lr

;@----------------------------------------------------------------------------
wsvPowerOffW:				;@ 0xAC
;@----------------------------------------------------------------------------
	ands r0,r0,#1				;@ Power Off bit
	strb r0,[spxptr,#wsvPowerOff]
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
	ldrb r1,[spxptr,#wsvSerialStatus]
	tst r1,#0x80					;@ Serial enabled?
	bxeq lr
	strb r0,[spxptr,#wsvComByte]
	tst r1,#0x40					;@ 0 = 9600, 1 = 38400 bps
	moveq r2,#2560					;@ 3072000/(9600/8)
	movne r2,#640					;@ 3072000/(38400/8)
	str r2,[spxptr,#serialTXCounter]
	mov r0,#SERTX_IRQ_F				;@ #0 = Serial transmit
	b clearInterruptPins
;@----------------------------------------------------------------------------
wsvIntEnableW:				;@ 0xB2
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptPins]
	strb r0,[spxptr,#wsvInterruptEnable]
	and r0,r0,r1
	and r0,r0,#0x0D				;@ RX/TX/Extrn are level interrupts
	b setInterruptPins
;@----------------------------------------------------------------------------
wsvSerialStatusW:			;@ 0xB3
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSerialStatus]
	and r0,r0,#0xC0				;@ Mask out writeable bits. 0x20 is reset Overrun.
	strb r0,[spxptr,#wsvSerialStatus]
	eor r1,r1,r0
	tst r1,#0x80				;@ Serial enable changed?
	bxeq lr
	mov r1,#-1
	str r1,[spxptr,#serialTXCounter]
	str r1,[spxptr,#serialRXCounter]
	tst r0,#0x80				;@ Serial enable now?
	mov r0,#SERTX_IRQ_F|SERRX_IRQ_F		;@ #0 = Serial transmit, 3 = receive
	beq clearInterruptPins
	stmfd sp!,{lr}
	bl callSerialInEmpty
	ldmfd sp!,{lr}
	mov r0,#SERTX_IRQ_F			;@ #0 = Serial transmit buffer empty
	b setInterruptPins
;@----------------------------------------------------------------------------
wsvSetJoyState:				;@ r0 = joy state
;@----------------------------------------------------------------------------
	ldr r1,[spxptr,#wsvJoyState]
	str r0,[spxptr,#wsvJoyState]
	eor r1,r0,r1
	ands r1,r1,r0
	bxeq lr
	tst r1,#0x10000
	bne wsvPushVolumeButton
	ldrb r0,[spxptr,#wsvKeypad]
;@----------------------------------------------------------------------------
wsvKeypadW:					;@ 0xB5
;@----------------------------------------------------------------------------
	and r0,r0,#0x70
	ldr r1,[spxptr,#wsvJoyState]
	tst r0,#0x10				;@ Y keys enabled?
	biceq r1,r1,#0xF00
	teq r0,r0,lsl#26			;@ X keys / Buttons enabled?
	bicpl r1,r1,#0x0F0
	biccc r1,r1,#0x00F
	orr r1,r1,r1,lsr#8
	orr r1,r1,r1,lsr#4
	and r1,r1,#0x0F
	orr r0,r0,r1
	strb r0,[spxptr,#wsvKeypad]

	bx lr
;@----------------------------------------------------------------------------
wsvIntAckW:					;@ 0xB6
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvInterruptStatus]
	bic r0,r1,r0
	ldrb r1,[spxptr,#wsvInterruptEnable]
	ldrb r2,[spxptr,#wsvInterruptPins]
	and r2,r2,r1
	and r2,r2,#0x0D				;@ RX/TX/Extrn are level interrupts
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
	ldrb r1,[spxptr,#wsvNMIControl]
	strb r0,[spxptr,#wsvLowBattery]
	and r0,r0,r1
	ldrb r1,[spxptr,#wsvLowBatPin]
	strb r0,[spxptr,#wsvLowBatPin]
	cmp r0,r1
	bne V30SetNMIPin
	bx lr
;@----------------------------------------------------------------------------
wsvGetHeadphones:			;@ out r0 = on/off
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundOutput]
	ands r0,r0,#0x80
	movne r0,#1
	bx lr
;@----------------------------------------------------------------------------
wsvSetHeadphones:			;@ in r0 = on/off
;@----------------------------------------------------------------------------
	cmp r0,#0
	ldrb r1,[spxptr,#wsvSoundOutput]
	biceq r0,r1,#0x80
	orrne r0,r1,#0x80
	strb r0,[spxptr,#wsvSoundOutput]
	eor r1,r1,r0
	ands r1,r1,#0x80
	movne r1,#LCD_ICON_TIME_VALUE
	strbne r1,[spxptr,#wsvSoundIconTimer]
	b wsaSetSoundOutput
;@----------------------------------------------------------------------------
wsvSetSerialByteIn:			;@ r0=byte in, Needs spxptr
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSerialStatus]
	tst r1,#0x80					;@ Serial enabled?
	bxeq lr
	strb r0,[spxptr,#wsvByteReceived]
	tst r1,#0x40					;@ 0 = 9600, 1 = 38400 bps
	moveq r2,#2560					;@ 3072000/(9600/8)
	movne r2,#640					;@ 3072000/(38400/8)
	str r2,[spxptr,#serialRXCounter]
	bx lr

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
endFrame:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r2,[spxptr,#wsvLCDControl]
	ands r2,r2,#1					;@ LCD on?
	streq r2,[spxptr,#dispLine]
	ldrbne r2,[spxptr,#wsvDispCtrl]
	bl dispCnt
	ldr r2,[spxptr,#wsvFgWinXPos]
	bl windowCnt
#ifdef __ARM_ARCH_5TE__
	ldrd r2,r3,[spxptr,#wsvBgScrollBak]
#else
	ldr r2,[spxptr,#wsvBgScrollBak]
	ldr r3,[spxptr,#wsvFgScrollBak]
#endif
	bl scrollCnt
	bl gfxEndFrame
	bl dmaSprites
	ldmfd sp!,{lr}

	ldrb r0,[spxptr,#wsvKeypad]
	ldrb r1,[spxptr,#wsvOldKeypadReg]
	strb r0,[spxptr,#wsvOldKeypadReg]
	eor r1,r1,r0
	and r1,r1,r0
	ands r0,r1,#0xF
	movne r0,#KEYPD_IRQ_F		;@ #2 = Key pressed

	ldrh r1,[spxptr,#wsvVBlCounter]
	orr r0,r0,#VBLST_IRQ_F		;@ #6 = VBlank Start
	subs r1,r1,#1
	bmi setInterruptPins
	ldrb r2,[spxptr,#wsvTimerControl]
	bne noVBlIrq
	orreq r0,r0,#VBLTM_IRQ_F	;@ #5 = VBlank timer
	tst r2,#0x8					;@ Repeat?
	ldrhne r1,[spxptr,#wsvVBlTimerFreq]
noVBlIrq:
	tst r2,#0x4					;@ VBlank timer enabled?
	strhne r1,[spxptr,#wsvVBlCounter]
	b setInterruptPins

;@----------------------------------------------------------------------------
drawFrameGfx:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldrb r0,[spxptr,#wsvVideoMode]
	adr lr,transRet
	and r1,r0,#0xC0
	cmp r1,#0xC0
	bne transferVRAM4Planar
	tst r0,#0x20
	bne transferVRAM16Packed
	b transferVRAM16Planar
transRet:
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
	moveq r0,#LINE_IRQ_F		;@ #4 = Line compare

	ldrb r1,[spxptr,#wsvSerialStatus]
	tst r1,#0x80
	blne checkSerialRxTx

	ldrh r1,[spxptr,#wsvHBlCounter]
	subs r1,r1,#1
	bmi noTimerHBlIrq
	ldrb r2,[spxptr,#wsvTimerControl]
	bne noHBlIrq
	orreq r0,r0,#HBLTM_IRQ_F	;@ #7 = HBlank timer
	tst r2,#0x2					;@ Repeat?
	ldrhne r1,[spxptr,#wsvHBlTimerFreq]
noHBlIrq:
	tst r2,#0x1					;@ HBlank timer enabled?
	strhne r1,[spxptr,#wsvHBlCounter]
noTimerHBlIrq:
	bl setInterruptPins

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
checkSerialRxTx:
;@----------------------------------------------------------------------------
	ldr r2,[spxptr,#serialRXCounter]
	cmp r2,#0
	subspl r2,r2,#256			;@ Cycles per scanline
	str r2,[spxptr,#serialRXCounter]
	orrcc r0,r0,#SERRX_IRQ_F	;@ #3 = Serial receive
	strbcc r0,[spxptr,#wsvSerialBufFull]

	ldr r2,[spxptr,#serialTXCounter]
	cmp r2,#0
	subspl r2,r2,#256			;@ Cycles per scanline
	str r2,[spxptr,#serialTXCounter]
	bxcs lr
	orrcc r0,r0,#SERTX_IRQ_F	;@ #0 = Serial transmit
	stmfd sp!,{r0,spxptr,lr}
	ldrb r0,[spxptr,#wsvComByte]
	bl handleSerialOutW
	ldmfd sp!,{r0,spxptr,pc}

;@----------------------------------------------------------------------------
wsvSetInterruptExternal:	;@ r0 = irq pin state
;@----------------------------------------------------------------------------
	cmp r0,#0
	mov r0,#EXTRN_IRQ_F			;@ External interrupt is bit/number 2.
	beq clearInterruptPins
;@----------------------------------------------------------------------------
setInterruptPins:			;@ r0 = interrupt pins to set
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
clearInterruptPins:			;@ In r0 = interrupt pins to clear
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
	b wsaSetHyperVoiceValue
sdmaHold:
	ands r0,r0,#0x10			;@ Ch2Vol/HyperVoice
	beq wsvCh2VolumeW
	mov r0,#0
	b wsaSetHyperVoiceValue
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
tData:
	.long DIRTYTILES+0x200
	.long wsRAM+0x4000
	.long CHR_DECODE
	.long BG_GFX+0x08000		;@ BGR tiles
	.long SPRITE_GFX			;@ SPR tiles
;@----------------------------------------------------------------------------
transferVRAM16Packed:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r10,lr}
	adr r0,tData
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
transferVRAM16Planar:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r10,lr}
	adr r0,tData
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
t4Data:
	.long DIRTYTILES+0x100
	.long wsRAM+0x2000
	.long CHR_DECODE
	.long BG_GFX+0x08000		;@ BGR tiles
	.long BG_GFX+0x0C000		;@ BGR tiles 2
	.long SPRITE_GFX			;@ SPR tiles
	.long SPRITE_GFX+0x4000		;@ SPR tiles 2
	.long 0x44444444			;@ Extra bitplane, undirty mark
;@----------------------------------------------------------------------------
transferVRAM4Planar:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r12,lr}
	adr r0,t4Data
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
wsvCopyScrollValues:		;@ r0 = destination
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
dmaSprites:
;@----------------------------------------------------------------------------
	stmfd sp!,{spxptr,lr}

	add r0,spxptr,#wsvSpriteRAM			;@ Destination
	ldr r1,[spxptr,#gfxRAM]
	ldrb r2,[spxptr,#wsvSprTblAdr]
	add r1,r1,r2,lsl#9
	ldrb r2,[spxptr,#wsvSpriteFirst]	;@ First sprite
	ldrb r3,[spxptr,#wsvSpriteCount]	;@ Sprite count
	add r1,r1,r2,lsl#2
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
	orreq r3,r3,#PRIORITY*2		;@ Prio GBA/NDS
	orrne r3,r3,#PRIORITY		;@ Prio GBA/NDS
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
	ldrb r2,[spxptr,#wsvLatchedIcons]
	mov r0,#LCD_ICON_POWER
	tst r2,#1					;@ LCD block disabled?
	ldrbeq r2,[spxptr,#wsvPowerOff]
	tsteq r2,#1
	movne r0,#0
	bne setEnabledIcons
	ldrb r2,[spxptr,#wsvLCDIcons]
	and r2,r2,#0x3F
	orr r0,r0,r2
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
	orrhi r0,r0,#LCD_ICON_SOUND
	ble setEnabledIcons
	ldrb r2,[spxptr,#wsvSoundOutput]
	ands r2,r2,#0x80			;@ Headphones?
	orrne r0,r0,#LCD_ICON_HEADPHONE
	ldrbeq r2,[spxptr,#wsvHWVolume]
	and r2,r2,#3
	orr r0,r0,r2,lsl#6
setEnabledIcons:
	eors r1,r1,r0
	bxeq lr
	str r0,[spxptr,#enabledLCDIcons]
;@----------------------------------------------------------------------------
wsvRedrawLCDIcons:			;@ In r0=enabledLCDIcons
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

	tst r0,#LCD_ICON_SOUND
	tstne r0,#LCD_ICON_HEADPHONE	;@ HeadPhones
	moveq r3,r4
	ldrhne r3,[r1,#26]
	strh r3,[r2],#0x40
	ldrhne r3,[r1,#28]
	strh r3,[r2],#0x40

	bne clrVoluIcon
	tst r0,#LCD_ICON_SOUND
	bne chkVoluIcon
clrVoluIcon:
	strh r4,[r2],#0x40			;@ No Volume when headphones
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

	tst r0,#LCD_ICON_SOUND
	tstne r0,#LCD_ICON_HEADPHONE	;@ HeadPhones
	moveq r3,r4
	ldrhne r3,[r1,#0x24]
	strh r3,[r2,#0x26]

	bne clrVoluIconMono
	tst r0,#LCD_ICON_SOUND
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
	.long wsvRegR				;@ 0x14 LCD control (sleep, WSC contrast)
	.long wsvRegR				;@ 0x15 LCD icons
	.long wsvRegR				;@ 0x16 Total scan lines
	.long wsvRegR				;@ 0x17 Vsync line
	.long wsvWriteOnlyR			;@ 0x18 Write current scan line.
	.long wsvUnmappedR			;@ 0x19 ---
	.long wsvLatchedIconsR		;@ 0x1A Cartridge & Volume Icons
	.long wsvZeroR				;@ 0x1B ???
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
			;@ DMA registers, only Color
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

	.long wsvImportantR			;@ 0x70 SC LCD control 0
	.long wsvImportantR			;@ 0x71 SC LCD control 1
	.long wsvImportantR			;@ 0x72 SC LCD control 2
	.long wsvImportantR			;@ 0x73 SC LCD control 3
	.long wsvImportantR			;@ 0x74 SC LCD control 4
	.long wsvImportantR			;@ 0x75 SC LCD control 5
	.long wsvImportantR			;@ 0x76 SC LCD control 6
	.long wsvImportantR			;@ 0x77 SC LCD control 7
	.long wsvUnmappedR			;@ 0x78 ---
	.long wsvUnmappedR			;@ 0x79 ---
	.long wsvUnmappedR			;@ 0x7A ---
	.long wsvUnmappedR			;@ 0x7B ---
	.long wsvUnmappedR			;@ 0x7C ---
	.long wsvUnmappedR			;@ 0x7D ---
	.long wsvUnmappedR			;@ 0x7E ---
	.long wsvUnmappedR			;@ 0x7F ---

	.long wsvRegR				;@ 0x80 Sound Ch1 Pitch Low
	.long wsvRegR				;@ 0x81 Sound Ch1 Pitch High
	.long wsvRegR				;@ 0x82 Sound Ch2 Pitch Low
	.long wsvRegR				;@ 0x83 Sound Ch2 Pitch High
	.long wsvRegR				;@ 0x84 Sound Ch3 Pitch Low
	.long wsvRegR				;@ 0x85 Sound Ch3 Pitch High
	.long wsvRegR				;@ 0x86 Sound Ch4 Pitch Low
	.long wsvRegR				;@ 0x87 Sound Ch4 Pitch High
	.long wsvRegR				;@ 0x88 Sound Ch1 Volume
	.long wsvRegR				;@ 0x89 Sound Ch2 Volume
	.long wsvRegR				;@ 0x8A Sound Ch3 Volume
	.long wsvRegR				;@ 0x8B Sound Ch4 Volume
	.long wsvRegR				;@ 0x8C Sweeep Amount
	.long wsvRegR				;@ 0x8D Sweep Time
	.long wsvRegR				;@ 0x8E Noise Control
	.long wsvRegR				;@ 0x8F Wave Base

	.long wsvRegR				;@ 0x90 Sound Control
	.long wsvRegR				;@ 0x91 Sound Output
	.long wsvNoiseCntrLR		;@ 0x92 Noise LFSR value low
	.long wsvNoiseCntrHR		;@ 0x93 Noise LFSR value high
	.long wsvRegR				;@ 0x94 Sound Ch2 Voice Volume
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
	.long wsvImportantR			;@ 0xA3 System Test
	.long wsvRegR				;@ 0xA4 HBlankTimer low
	.long wsvRegR				;@ 0xA5 HBlankTimer high
	.long wsvRegR				;@ 0xA6 VBlankTimer low
	.long wsvRegR				;@ 0xA7 VBlankTimer high
	.long wsvRegR				;@ 0xA8 HBlankTimer counter low
	.long wsvRegR				;@ 0xA9 HBlankTimer counter high
	.long wsvRegR				;@ 0xAA VBlankTimer counter low
	.long wsvRegR				;@ 0xAB VBlankTimer counter high
	.long wsvUnknownR			;@ 0xAC PowerOff
	.long wsvUnmappedR			;@ 0xAD ---
	.long wsvUnmappedR			;@ 0xAE ---
	.long wsvUnmappedR			;@ 0xAF ---

	.long wsvInterruptBaseR		;@ 0xB0 Interrupt base
	.long wsvComByteR			;@ 0xB1 Serial data
	.long wsvRegR				;@ 0xB2 Interrupt enable
	.long wsvSerialStatusR		;@ 0xB3 Serial status
	.long wsvRegR				;@ 0xB4 Interrupt status
	.long wsvRegR				;@ 0xB5 keypad
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
	.long wsvBgColorW			;@ 0x01 Background color
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
	.long wsvLCDControlW		;@ 0x14 LCD control (sleep, WSC contrast)
	.long wsvLCDIconW			;@ 0x15 LCD icons
	.long wsvRefW				;@ 0x16 Total scan lines
	.long wsvRegW				;@ 0x17 Vsync line
	.long wsvImportantW			;@ 0x18 Write current scan line.
	.long wsvUnmappedW			;@ 0x19 ---
	.long wsvLatchedIconsW		;@ 0x1A Cartridge & Volume Icons, LCD disable
	.long wsvUnmappedW			;@ 0x1B ---
	.long wsvRegW				;@ 0x1C Pal mono pool 0
	.long wsvRegW				;@ 0x1D Pal mono pool 1
	.long wsvRegW				;@ 0x1E Pal mono pool 2
	.long wsvRegW				;@ 0x1F Pal mono pool 3

	.long wsvPaletteW			;@ 0x20 Pal mono 0 low
	.long wsvPaletteW			;@ 0x21 Pal mono 0 high
	.long wsvPaletteW			;@ 0x22 Pal mono 1 low
	.long wsvPaletteW			;@ 0x23 Pal mono 1 high
	.long wsvPaletteW			;@ 0x24 Pal mono 2 low
	.long wsvPaletteW			;@ 0x25 Pal mono 2 high
	.long wsvPaletteW			;@ 0x26 Pal mono 3 low
	.long wsvPaletteW			;@ 0x27 Pal mono 3 high
	.long wsvPaletteTrW			;@ 0x28 Pal mono 4 low
	.long wsvPaletteW			;@ 0x29 Pal mono 4 high
	.long wsvPaletteTrW			;@ 0x2A Pal mono 5 low
	.long wsvPaletteW			;@ 0x2B Pal mono 5 high
	.long wsvPaletteTrW			;@ 0x2C Pal mono 6 low
	.long wsvPaletteW			;@ 0x2D Pal mono 6 high
	.long wsvPaletteTrW			;@ 0x2E Pal mono 7 low
	.long wsvPaletteW			;@ 0x2F Pal mono 7 high

	.long wsvPaletteW			;@ 0x30 Pal mono 8 low
	.long wsvPaletteW			;@ 0x31 Pal mono 8 high
	.long wsvPaletteW			;@ 0x32 Pal mono 9 low
	.long wsvPaletteW			;@ 0x33 Pal mono 9 high
	.long wsvPaletteW			;@ 0x34 Pal mono A low
	.long wsvPaletteW			;@ 0x35 Pal mono A high
	.long wsvPaletteW			;@ 0x36 Pal mono B low
	.long wsvPaletteW			;@ 0x37 Pal mono B high
	.long wsvPaletteTrW			;@ 0x38 Pal mono C low
	.long wsvPaletteW			;@ 0x39 Pal mono C high
	.long wsvPaletteTrW			;@ 0x3A Pal mono D low
	.long wsvPaletteW			;@ 0x3B Pal mono D high
	.long wsvPaletteTrW			;@ 0x3C Pal mono E low
	.long wsvPaletteW			;@ 0x3D Pal mono E high
	.long wsvPaletteTrW			;@ 0x3E Pal mono F low
	.long wsvPaletteW			;@ 0x3F Pal mono F high
			;@ DMA registers, only Color
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
	.long wsvHyperCtrlW			;@ 0x6A Hyper Voice control
	.long wsvHyperChanCtrlW		;@ 0x6B Hyper Chan control
	.long wsvUnmappedW			;@ 0x6C ---
	.long wsvUnmappedW			;@ 0x6D ---
	.long wsvUnmappedW			;@ 0x6E ---
	.long wsvUnmappedW			;@ 0x6F ---

	.long wsvImportantW			;@ 0x70 SC LCD control 0
	.long wsvImportantW			;@ 0x71 SC LCD control 1
	.long wsvImportantW			;@ 0x72 SC LCD control 2
	.long wsvImportantW			;@ 0x73 SC LCD control 3
	.long wsvImportantW			;@ 0x74 SC LCD control 4
	.long wsvImportantW			;@ 0x75 SC LCD control 5
	.long wsvImportantW			;@ 0x76 SC LCD control 6
	.long wsvImportantW			;@ 0x77 SC LCD control 7
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
	.long wsvCh2VoiceVolW		;@ 0x94 Sound voice volume
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

	.long wsvHWW				;@ 0xA0 Hardware Type, SOC_ASWAN / SOC_SPHINX.
	.long wsvUnmappedW			;@ 0xA1 ---
	.long wsvTimerCtrlW			;@ 0xA2 Timer Control
	.long wsvSystemTestW		;@ 0xA3 System Test
	.long wsvHTimerLowW			;@ 0xA4 HBlank Timer Low
	.long wsvHTimerHighW		;@ 0xA5 HBlank Timer High
	.long wsvVTimerLowW			;@ 0xA6 VBlank Timer Low
	.long wsvVTimerHighW		;@ 0xA7 VBlank Timer High
	.long wsvReadOnlyW			;@ 0xA8 HBlank Counter Low
	.long wsvReadOnlyW			;@ 0xA9 HBlank Counter High
	.long wsvReadOnlyW			;@ 0xAA VBlank Counter Low
	.long wsvReadOnlyW			;@ 0xAB VBlank Counter High
	.long wsvPowerOffW			;@ 0xAC Power Off
	.long wsvUnmappedW			;@ 0xAD ---
	.long wsvUnmappedW			;@ 0xAE ---
	.long wsvUnmappedW			;@ 0xAF ---

	.long wsvInterruptBaseW		;@ 0xB0 Interrupt Base
	.long wsvComByteW			;@ 0xB1 Serial Data
	.long wsvIntEnableW			;@ 0xB2 Interrupt Enable
	.long wsvSerialStatusW		;@ 0xB3 Serial Status
	.long wsvReadOnlyW			;@ 0xB4 Interrupt Status
	.long wsvKeypadW			;@ 0xB5 Input Controls
	.long wsvIntAckW			;@ 0xB6 Interrupt Acknowledge
	.long wsvNMICtrlW			;@ 0xB7 NMI Ctrl
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
