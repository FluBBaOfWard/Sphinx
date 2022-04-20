// Bandai WonderSwan Sound emulation

#ifdef __arm__
#include "Sphinx.i"

	.global wsAudioReset
	.global wsAudioMixer

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
wsAudioReset:				;@ spxptr=r12=pointer to struct
;@----------------------------------------------------------------------------
	mov r0,#0x00000800
	str r0,[spxptr,#pcm1CurrentAddr]
	str r0,[spxptr,#pcm2CurrentAddr]
	str r0,[spxptr,#pcm3CurrentAddr]
	str r0,[spxptr,#pcm4CurrentAddr]
	mov r0,#0x80000000
	str r0,[spxptr,#noise4CurrentAddr]
	bx lr

;@----------------------------------------------------------------------------
wsAudioMixer:				;@ r0=len, r1=dest, r12=spxptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r4-r11,lr}
;@--------------------------
	ldr r10,=vol1_L

	ldrb r4,[spxptr,#wsvHWVolume]
	add r5,r4,#1
	rsb r4,r4,#3
	cmp r4,#3
	mov r6,#0xF0
	moveq r6,#0
	mov r6,r6,lsr r4
	ldrb r9,[spxptr,#wsvSoundCtrl]

	ands r3,r9,#1					;@ Ch 1 on?
	movne r3,r6
	ldrb r1,[spxptr,#wsvSound1Vol]
	and r2,r3,r1,lsl r5
	and r1,r3,r1,lsr r4
	strb r1,[r10,#vol1_L-vol1_L]
	strb r2,[r10,#vol1_R-vol1_L]

	ands r3,r9,#2					;@ Ch 2 on?
	movne r3,r6
	ldrb r1,[spxptr,#wsvSound2Vol]
	and r2,r3,r1,lsl r5
	and r1,r3,r1,lsr r4
	strb r1,[r10,#vol2_L-vol1_L]
	strb r2,[r10,#vol2_R-vol1_L]

	ands r3,r9,#4					;@ Ch 3 on?
	movne r3,r6
	ldrb r1,[spxptr,#wsvSound3Vol]
	and r2,r3,r1,lsl r5
	and r1,r3,r1,lsr r4
	strb r1,[r10,#vol3_L-vol1_L]
	strb r2,[r10,#vol3_R-vol1_L]

	ands r3,r9,#8					;@ Ch 4 on?
	movne r3,r6
	ldrb r1,[spxptr,#wsvSound4Vol]
	and r2,r3,r1,lsl r5
	and r1,r3,r1,lsr r4
	strb r1,[r10,#vol4_L-vol1_L]
	strb r2,[r10,#vol4_R-vol1_L]

	add r0,spxptr,#pcm1CurrentAddr
	ldmia r0,{r3-r8}
;@--------------------------
	ldrh r1,[spxptr,#wsvSound1Freq]
	mov r3,r3,lsr#11
	orr r3,r1,r3,lsl#11
;@--------------------------
	ldrh r1,[spxptr,#wsvSound2Freq]
	mov r4,r4,lsr#11
	orr r4,r1,r4,lsl#11
;@--------------------------
	ldrh r1,[spxptr,#wsvSound3Freq]
	mov r5,r5,lsr#11
	orr r5,r1,r5,lsl#11

	ldrb r1,[spxptr,#wsvSweepTime]
	add r1,r1,#1
	orr r8,r1,r8,lsl#6
	mov r8,r8,ror#6
;@--------------------------
	ands r0,r9,#0x80			;@ Ch 4 noise on?
	bic r7,r7,#0x80
	orr r7,r7,r0
	and r0,r9,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[spxptr,#wsvSound4Freq]
	mov r6,r6,lsr#11
	orreq r6,r1,r6,lsl#11
	orrne r6,r6,r0,ror#5
	movne r6,r6,ror#21
;@--------------------------

	ldr r10,[spxptr,#gfxRAM]
	ldrb r2,[spxptr,#wsvSampleBase]
	add r10,r10,r2,lsl#6
	ldmfd sp,{r11,lr}			;@ r11=len, lr=dest buffer
	mov r11,r11,lsl#2
;@	mov r11,r11					;@ no$gba break
	b pcmMix
pcmMixReturn:
;@	mov r11,r11					;@ no$gba break
	add r0,spxptr,#pcm1CurrentAddr	;@ Counters
	stmia r0,{r3-r8}

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2

#define PSGDIVIDE 16
#define PSGADDITION 0x00008000*PSGDIVIDE
#define PSGSWEEPADD 0x00002000*4*PSGDIVIDE
#define PSGNOISEFEED 0x00050001

;@----------------------------------------------------------------------------
;@ r0  =
;@ r1  =
;@ r2  = Mixer register
;@ r3  = Channel 1
;@ r4  = Channel 2
;@ r5  = Channel 3
;@ r6  = Channel 4
;@ r10 = Sample pointer
;@ r11 = Length
;@----------------------------------------------------------------------------
pcmMix:				;@ r0=len, r1=dest, r12=snptr
// IIIIIVCCCCCCCCCCC0001FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
mixLoop:
	mov r2,#0x80000000
innerMixLoop:
	add r3,r3,#PSGADDITION
	movs r9,r3,lsr#27
	mov r1,r3,lsl#20
	addcs r3,r3,r1,lsr#5
vol1_L:
	mov r1,#0x00				;@ Volume left
vol1_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrb r0,[r10,r9,lsr#1]		;@ Channel 1
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
	mla r2,r1,r0,r2

	add r4,r4,#PSGADDITION
	movs r9,r4,lsr#27
	add r9,r9,#0x20
	mov r1,r4,lsl#20
	addcs r4,r4,r1,lsr#5
vol2_L:
	mov r1,#0x00				;@ Volume left
vol2_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrb r0,[r10,r9,lsr#1]		;@ Channel 2
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
	mla r2,r1,r0,r2

	add r5,r5,#PSGADDITION
	movs r9,r5,lsr#27
	add r9,r9,#0x40
	mov r1,r5,lsl#20
	addcs r5,r5,r1,lsr#5
vol3_L:
	mov r1,#0x00				;@ Volume left
vol3_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrb r0,[r10,r9,lsr#1]		;@ Channel 3
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
	mla r2,r1,r0,r2

	add r6,r6,#PSGADDITION
	movs r9,r6,lsr#27
	add r9,r9,#0x60
	mov r1,r6,lsl#20
	addcs r6,r6,r1,lsr#5

	movcs r1,r7,lsr#16
	addscs r7,r7,r1,lsl#16
	ldrcs r1,=PSGNOISEFEED
	eorcs r7,r7,r1
	tst r7,#0x80				;@ Noise 4 enabled?
	ldrbeq r0,[r10,r9,lsr#1]	;@ Channel 4
	andsne r0,r7,#0x00000001
	movne r0,#0xFF
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
vol4_L:
	mov r1,#0x00				;@ Volume left
vol4_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	mla r2,r1,r0,r2

	sub r11,r11,#1
	tst r11,#3
	bne innerMixLoop

//	subs r8,r8,#PSGSWEEPADD
//	bhi noSweep
//	ldrb r1,[spxptr,#wsvSweepTime]
//	add r1,r1,#1
//	add r8,r8,r1,lsl#26
//	ldrsb r1,[spxptr,#wsvSweepValue]
//	mov r5,r5,ror#11
//	adds r5,r5,r1,lsl#21
//	mov r5,r5,ror#21
noSweep:
	eor r2,#0x00008000
	cmp r11,#0
	strpl r2,[lr],#4
	bhi mixLoop				;@ ?? cycles according to No$gba

	mov r1,r7,lsr#17
	strh r1,[spxptr,#wsvNoiseCntr]
	b pcmMixReturn
;@----------------------------------------------------------------------------


#endif // #ifdef __arm__
