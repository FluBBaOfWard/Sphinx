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

	mov r3,#0xF0
	ldrb r1,[spxptr,#wsvSound1Vol]
	and r2,r3,r1,lsl#4
	and r1,r3,r1
	strb r1,[r10],#vol1_R-vol1_L
	strb r2,[r10],#vol2_L-vol1_R

	ldrb r1,[spxptr,#wsvSound2Vol]
	and r2,r3,r1,lsl#4
	and r1,r3,r1
	strb r1,[r10],#vol2_R-vol2_L
	strb r2,[r10],#vol3_L-vol2_R

	ldrb r1,[spxptr,#wsvSound3Vol]
	and r2,r3,r1,lsl#4
	and r1,r3,r1
	strb r1,[r10],#vol3_R-vol3_L
	strb r2,[r10],#vol4_L-vol3_R

	ldrb r1,[spxptr,#wsvSound4Vol]
	and r2,r3,r1,lsl#4
	and r1,r3,r1
	strb r1,[r10],#vol4_R-vol4_L
	strb r2,[r10]

	add r0,spxptr,#pcm1CurrentAddr
	ldmia r0,{r3-r7}
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
;@--------------------------
	ldrb r2,[spxptr,#wsvSoundCtrl]
	ands r0,r2,#0x80			;@ Noise on?
	bic r7,r7,#0x80
	orr r7,r7,r0
	and r0,r2,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[spxptr,#wsvSound4Freq]
	mov r6,r6,lsr#11
	orreq r6,r1,r6,lsl#11
	orrne r6,r6,r0,ror#5
	movne r6,r6,ror#21
;@--------------------------

	ldr r8,=wsSRAM
	ldrb r2,[spxptr,#wsvSampleBase]
	add r8,r8,r2,lsl#6
	ldmfd sp,{r11,lr}			;@ r11=len, lr=dest buffer
;@	mov r11,r11					;@ no$gba break
	b pcmMix
pcmMixReturn:
;@	mov r11,r11					;@ no$gba break
	add r0,spxptr,#pcm1CurrentAddr	;@ Counters
	stmia r0,{r3-r7}

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2

#define PSGDIVIDE 32
#define PSGADDITION 0x00008000*PSGDIVIDE
#define PSGNOISEFEED 0x8600C001

;@----------------------------------------------------------------------------
;@ r0 = length.
;@ r1 = destination.
;@----------------------------------------------------------------------------
pcmMix:				;@ r0=len, r1=dest, r12=snptr
// IIIIIVCCCCCCCCCCC0001FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
pcmMixLoop:
	add r3,r3,#PSGADDITION
	movs r9,r3,lsr#27
	mov r1,r3,lsl#20
	addcs r3,r3,r1,lsr#5
vol1_L:
	mov r2,#0x00				;@ Volume left
vol1_R:
	orrs r1,r2,#0xFF0000		;@ Volume right
	ldrb r0,[r8,r9,lsr#1]		;@ Channel 1
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
	mul r2,r1,r0

	add r4,r4,#PSGADDITION
	movs r9,r4,lsr#27
	add r9,r9,#0x20
	mov r1,r4,lsl#20
	addcs r4,r4,r1,lsr#5
vol2_L:
	mov r1,#0x00				;@ Volume left
vol2_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrb r0,[r8,r9,lsr#1]		;@ Channel 2
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
	ldrb r0,[r8,r9,lsr#1]		;@ Channel 3
	tst r9,#1
	moveq r0,r0,lsr#4
	andne r0,r0,#0xF
	mla r2,r1,r0,r2

	add r6,r6,#PSGADDITION
	movs r9,r6,lsr#27
	add r9,r9,#0x60
	mov r1,r6,lsl#20
	addcs r6,r6,r1,lsr#5

	movcs r1,r7,lsr#14
	addscs r7,r7,r1,lsl#14
	ldrcs r1,=PSGNOISEFEED
	eorcs r7,r7,r1
	tst r7,#0x80				;@ Noise 4 enabled?
	ldrbeq r0,[r8,r9,lsr#1]		;@ Channel 4
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

	subs r11,r11,#1
	strpl r2,[lr],#4
	bhi pcmMixLoop				;@ ?? cycles according to No$gba

	b pcmMixReturn
;@----------------------------------------------------------------------------


#endif // #ifdef __arm__
