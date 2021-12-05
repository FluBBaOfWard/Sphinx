// Bandai WonderSwan Sound emulation

#ifdef __arm__
#include "Sphinx.i"

#define PSGDIVIDE 20*4
#define PSGADDITION 0x00004000*PSGDIVIDE
#define PSGNOISEFEED 0x8600C001

	.global WSAudioReset
	.global WSAudioMixer
	psgptr		.req r12

	.syntax unified
	.arm

	.section .itcm
	.align 2
;@----------------------------------------------------------------------------
;@ r0 = length.
;@ r1 = destination.
;@----------------------------------------------------------------------------
pcmMix:				;@ r0=len, r1=dest, r12=snptr
// IIIIIVCCCCCCCCCCC0010FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
pcmMixLoop:
	add r3,r3,#PSGADDITION
	movs r0,r3,lsr#27
	mov r1,r3,lsl#18
	subcs r3,r3,r1,asr#4
vol0_L:
	mov r2,#0x00				;@ Volume left
vol0_R:
	orrs r1,r2,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 0
	mulne r2,r1,r0

	add r4,r4,#PSGADDITION
	movs r0,r4,lsr#27
	add r0,r0,#0x20
	mov r1,r4,lsl#18
	subcs r4,r4,r1,asr#4
vol1_L:
	mov r1,#0x00				;@ Volume left
vol1_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 1
	mlane r2,r1,r0,r2

	add r5,r5,#PSGADDITION
	movs r0,r5,lsr#27
	add r0,r0,#0x40
	mov r1,r5,lsl#18
	subcs r5,r5,r1,asr#4
vol2_L:
	mov r1,#0x00				;@ Volume left
vol2_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 2
	mlane r2,r1,r0,r2

	add r6,r6,#PSGADDITION
	movs r0,r6,lsr#27
	add r0,r0,#0x80
	mov r1,r6,lsl#18
	subcs r6,r6,r1,asr#4

	movcs r1,r9,lsr#14
	addscs r9,r9,r1,lsl#14
	ldrcs r1,=PSGNOISEFEED
	eorcs r9,r9,r1
	tst r9,#0x80				;@ Noise 4 enabled?
	ldrsbeq r0,[r12,r0]			;@ Channel 4
	andsne r0,r9,#0x00000001
	movne r0,#0x1F
vol3_L:
	mov r1,#0x00				;@ Volume left
vol3_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	mlane r2,r1,r0,r2


	subs r11,r11,#1
	strpl r2,[lr],#4
	bhi pcmMixLoop				;@ ?? cycles according to No$gba

	b pcmMixReturn
;@----------------------------------------------------------------------------


	.section .text
	.align 2
;@----------------------------------------------------------------------------
WSAudioReset:				;@ psgptr=r12=pointer to struct
;@----------------------------------------------------------------------------
	bx lr

;@----------------------------------------------------------------------------
WSAudioMixer:				;@ r0=len, r1=dest, r12=psgptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r4-r11,lr}
;@--------------------------
	ldr r10,=vol0_L

//	ldrb r1,[psgptr,#ch0balance]
//	ldrb r0,[psgptr,#ch0control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3 & r4.
	strb r1,[r10],#vol0_R-vol0_L
	strb r2,[r10],#vol1_L-vol0_R

//	ldrb r1,[psgptr,#ch1balance]
//	ldrb r0,[psgptr,#ch1control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3 & r4.
	strb r1,[r10],#vol1_R-vol1_L
	strb r2,[r10],#vol2_L-vol1_R

//	ldrb r1,[psgptr,#ch2balance]
//	ldrb r0,[psgptr,#ch2control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3 & r4.
	strb r1,[r10],#vol2_R-vol2_L
	strb r2,[r10],#vol3_L-vol2_R

//	ldrb r1,[psgptr,#ch3balance]
//	ldrb r0,[psgptr,#ch3control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3 & r4.
	strb r1,[r10],#vol3_R-vol3_L
	strb r2,[r10]

//	add r0,psgptr,#ch0freq		;@ Original freq
	ldmia r0,{r3-r8}
;@--------------------------
//	ldrh r1,[psgptr,#pcm0currentaddr]
	and r1,r1,#0xF000
	orr r1,r1,r3
//	strh r1,[psgptr,#pcm0currentaddr]
;@--------------------------
//	ldrh r1,[psgptr,#pcm1currentaddr]
	and r1,r1,#0xF000
	orr r1,r1,r4
//	strh r1,[psgptr,#pcm1currentaddr]
;@--------------------------
//	ldrh r1,[psgptr,#pcm2currentaddr]
	and r1,r1,#0xF000
	orr r1,r1,r5
//	strh r1,[psgptr,#pcm2currentaddr]
;@--------------------------
//	ldrh r1,[psgptr,#pcm3currentaddr]
	and r1,r1,#0xF000
	orr r1,r1,r6
//	strh r1,[psgptr,#pcm3currentaddr]
;@--------------------------

//	add r0,psgptr,#pcm0currentaddr
	ldmia r0,{r3-r10}

//	add psgptr,psgptr,#ch0waveform	;@ r12 = PCE wavebuffer
	ldmfd sp,{r11,lr}			;@ r11=len, lr=dest buffer
;@	mov r11,r11					;@ no$gba break
	b pcmMix
pcmMixReturn:
;@	mov r11,r11					;@ no$gba break
//	sub psgptr,psgptr,#ch0waveform	;@ Get correct psgptr
//	add r0,psgptr,#pcm0currentaddr	;@ Counters
	stmia r0,{r3-r10}

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------
getVolumeDS:
;@----------------------------------------------------------------------------
	and r2,r0,#0xc0
	cmp r2,#0x80				;@ Should channel be played?

	and r0,r0,#0x1f				;@ Channel master
;@	mov r3,#103					;@ Maybe boost?
	mov r3,#126					;@ Boost.
	movne r3,#0
	mul r0,r3,r0
//	ldrb r3,[psgptr,#globalBalance]

	and r2,r1,#0xf				;@ Channel right
	and r4,r3,#0xf				;@ Main right
	mul r2,r4,r2
	mul r2,r0,r2

	mov r1,r1,lsr#4				;@ Channel left
	mov r3,r3,lsr#4				;@ Main left
	mul r4,r3,r1
	mul r1,r0,r4

	mov r1,r1,lsr#12			;@ 0 <= r1 <= 0xAF
	mov r2,r2,lsr#12			;@ 0 <= r2 <= 0xAF
	bx lr
;@----------------------------------------------------------------------------

#endif // #ifdef __arm__
