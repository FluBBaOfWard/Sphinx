//
//  WSAudio.s
//  Bandai WonderSwan Sound emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2023 Fredrik Ahlström. All rights reserved.
//

#ifdef __arm__
#include "Sphinx.i"

	.global wsAudioReset
	.global wsAudioMixer
	.global setAllChVolume
	.global setCh1Volume
	.global setCh2Volume
	.global setCh3Volume
	.global setCh4Volume
	.global setHyperVoiceValue
	.global setTotalVolume

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
	str r0,[spxptr,#sweep3CurrentAddr]
	ldr r0,=0x00000408
	str r0,[spxptr,#noise4CurrentAddr]

;@----------------------------------------------------------------------------
setAllChVolume:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r1,[spxptr,#wsvSound1Vol]
	bl setCh1Volume
	ldrb r1,[spxptr,#wsvSound2Vol]
	bl setCh2Volume
	ldrb r1,[spxptr,#wsvSound3Vol]
	bl setCh3Volume
	ldrb r1,[spxptr,#wsvSound4Vol]
	bl setCh4Volume
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
setCh1Volume:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundCtrl]
	tst r0,#1					;@ Ch 1 on?
	moveq r1,#0
	ldr r0,=vol1_L
	and r2,r1,#0xF
	mov r1,r1,lsr#4
	strb r1,[r0,#vol1_L-vol1_L]
	strb r2,[r0,#vol1_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setCh2Volume:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundCtrl]
	ands r2,r0,#0x20			;@ Ch 2 voice on?
	orrne r2,r1,r1,lsl#16
	strne r2,[spxptr,#currentSampleValue]
	movne r1,#0					;@ Silence for now
	tst r0,#2					;@ Ch 2 on?
	moveq r1,#0
	ldr r0,=vol1_L
	and r2,r1,#0xF
	mov r1,r1,lsr#4
	strb r1,[r0,#vol2_L-vol1_L]
	strb r2,[r0,#vol2_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setCh3Volume:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundCtrl]
	tst r0,#4					;@ Ch 3 on?
	moveq r1,#0
	ldr r0,=vol1_L
	and r2,r1,#0xF
	mov r1,r1,lsr#4
	strb r1,[r0,#vol3_L-vol1_L]
	strb r2,[r0,#vol3_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setCh4Volume:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvSoundCtrl]
	tst r0,#8					;@ Ch 4 on?
	moveq r1,#0
	ldr r0,=vol1_L
	and r2,r1,#0xF
	mov r1,r1,lsr#4
	strb r1,[r0,#vol4_L-vol1_L]
	strb r2,[r0,#vol4_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setHyperVoiceValue:
;@----------------------------------------------------------------------------
	ldrh r0,[spxptr,#wsvHyperVCtrl]
	ldrb r2,[spxptr,#wsvSoundOutput]
	tst r0,#0x80				;@ HyperV Enabled
	tstne r2,#0x80				;@ HeadPhones Enabled
	bxeq lr
//	and r2,r0,#0x6000			;@ Mode, 0=stereo, 1=left, 2=right, 3=mono both.
	tst r0,#8					;@ Signed value?
	eorne r1,r1,#0x80
//	ands r2,r0,#3				;@ Shift amount
//	movne r1,r1,lsr r2
	orr r1,r1,r1,lsl#16
	str r1,[spxptr,#currentSampleValue]
	bx lr
;@----------------------------------------------------------------------------
setTotalVolume:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvHWVolume]
	ldrb r0,[spxptr,#wsvSoundOutput]
	tst r0,#0x80				;@ Headphones?
	movne r1,#3
	ldr r0,=vol1_L
	adr r2,hwVolumes
	ldr r1,[r2,r1,lsl#2]
	str r1,[r0,#totalVolume-vol1_L]
	bx lr
hwVolumes:
	mov r2,#0x80000000
	mov r2,r2,lsl#4
	mov r2,r2,lsl#5
	mov r2,r2,lsl#6

;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2

#define PSG_DIVIDE 16
#define PSG_ADDITION 0x00008000*PSG_DIVIDE
#define PSG_SWEEP_ADD 0x00020000*PSG_DIVIDE

;@----------------------------------------------------------------------------
#ifdef WSAUDIO_LOW
;@----------------------------------------------------------------------------
;@ r0  = Length
;@ r1  = Destination
;@ r2  = Mixer register
;@ r3  = Channel 1
;@ r4  = Channel 2
;@ r5  = Channel 3
;@ r6  = Channel 4
;@ r7  = Noise LFSR
;@ r8  = Ch3 Sweep
;@ r9  = Ch2/HyperVoice sample.
;@ r10 = Sample pointer
;@ r11 = Current sample
;@ lr  = Current volume
;@----------------------------------------------------------------------------
wsAudioMixer:		;@ r0=len, r1=dest, r12=spxptr
// IIIIIVCCCCCCCCCCC0001FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}
	add r2,spxptr,#pcm1CurrentAddr
	ldmia r2,{r3-r10}
	mov r0,r0,lsl#3
mixLoop:
innerMixLoop:
	add r3,r3,#PSG_ADDITION
	tst r3,r3,lsl#6
	mov r2,r3,lsl#20
	addcs r3,r3,r2,lsr#5

	add r4,r4,#PSG_ADDITION
	tst r4,r4,lsl#6
	mov r2,r4,lsl#20
	addcs r4,r4,r2,lsr#5

	add r5,r5,#PSG_ADDITION
	tst r5,r5,lsl#6
	mov r2,r5,lsl#20
	addcs r5,r5,r2,lsr#5

	add r6,r6,#PSG_ADDITION
	tst r6,r6,lsl#6
	mov r2,r6,lsl#20
	addcs r6,r6,r2,lsr#5

	movscs r2,r7,lsr#16
	addcs r7,r7,r2,lsl#16
	ands r2,r7,r7,lsl#21
	eorsne r2,r2,r7,lsl#21
	orreq r7,r7,#0x00010000

	sub r0,r0,#1
	tst r0,#7
	bne innerMixLoop
;@----------------------------------------------------------------------------

	mov r2,#0xFE000000
	ldrb r11,[r10,r3,lsr#28]	;@ Channel 1
	add r10,r10,#0x10
	tst r3,#0x08000000
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol1_L:
	mov lr,#0x00				;@ Volume left
vol1_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	ldrb r11,[r10,r4,lsr#28]	;@ Channel 2
	add r10,r10,#0x10
	tst r4,#0x08000000
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol2_L:
	mov lr,#0x00				;@ Volume left
vol2_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2
	add r2,r2,r9

	ldrb r11,[r10,r5,lsr#28]	;@ Channel 3
	add r10,r10,#0x10
	tst r5,#0x08000000
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol3_L:
	mov lr,#0x00				;@ Volume left
vol3_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	tst r7,#0x4000				;@ Channel 4 Noise enabled?
	ldrbeq r11,[r10,r6,lsr#28]	;@ Channel 4 PCM
	sub r10,r10,#0x30
	andsne r11,r7,#0x00010000
	movne r11,#0xFF
	tst r6,#0x08000000
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol4_L:
	mov lr,#0x00				;@ Volume left
vol4_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	tst r8,#0x100				;@ Ch3 Sweep?
	beq noSweep
	adds r8,r8,#PSG_SWEEP_ADD
	bcc noSweep
	sub r8,r8,r8,lsl#26
	ldrsb lr,[spxptr,#wsvSweepValue]
	mov r5,r5,ror#11
	adds r5,r5,lr,lsl#21
	mov r5,r5,ror#21
noSweep:
totalVolume:
	mov r2,r2,lsl#6
	eor r2,r2,#0x00008000
	cmp r0,#0
	strpl r2,[r1],#4
	bhi mixLoop				;@ ?? cycles according to No$gba

	mov r2,r7,lsr#17
	strh r2,[spxptr,#wsvNoiseCntr]
	add r0,spxptr,#pcm1CurrentAddr	;@ Counters
	stmia r0,{r3-r8}
	ldmfd sp!,{r4-r11,pc}
#else
;@----------------------------------------------------------------------------
;@ r0  = Length
;@ r1  = Destination
;@ r2  = Mixer register
;@ r3  = Channel 1
;@ r4  = Channel 2
;@ r5  = Channel 3
;@ r6  = Channel 4
;@ r10 = Sample pointer
;@ r11 =
;@----------------------------------------------------------------------------
pcmMix:				;@ r0=len, r1=dest, r12=snptr
// IIIIIVCCCCCCCCCCC0001FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
mixLoop:
	mov r2,#0x80000000
innerMixLoop:
	add r3,r3,#PSG_ADDITION
	movs r9,r3,lsr#27
	mov lr,r3,lsl#20
	addcs r3,r3,lr,lsr#5
	ldrb r11,[r10,r3,lsr#1]		;@ Channel 1
	tst r9,#1
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol1_L:
	mov lr,#0x00				;@ Volume left
vol1_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	add r4,r4,#PSG_ADDITION
	movs r9,r4,lsr#27
	add r9,r9,#0x20
	mov lr,r4,lsl#20
	addcs r4,r4,lr,lsr#5
	ldrb r11,[r10,r9,lsr#1]		;@ Channel 2
	tst r9,#1
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol2_L:
	mov lr,#0x00				;@ Volume left
vol2_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	add r5,r5,#PSG_ADDITION
	movs r9,r5,lsr#27
	add r9,r9,#0x40
	mov lr,r5,lsl#20
	addcs r5,r5,lr,lsr#5
	ldrb r11,[r10,r9,lsr#1]		;@ Channel 3
	tst r9,#1
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol3_L:
	mov lr,#0x00				;@ Volume left
vol3_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	add r6,r6,#PSG_ADDITION
	movs r9,r6,lsr#27
	add r9,r9,#0x60
	mov lr,r6,lsl#20
	addcs r6,r6,lr,lsr#5

	movcs lr,r7,lsr#16
	addscs r7,r7,lr,lsl#16
	ldrcs lr,=PSG_NOISE_FEED
	eorcs r7,r7,lr
	tst r7,#0x80				;@ Noise 4 enabled?
	ldrbeq r11,[r10,r9,lsr#1]	;@ Channel 4
	andsne r11,r7,#0x00000001
	movne r11,#0xFF
	tst r9,#1
	moveq r11,r11,lsr#4
	ands r11,r11,#0xF
vol4_L:
	mov lr,#0x00				;@ Volume left
vol4_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	sub r0,r0,#1
	tst r0,#3
	bne innerMixLoop

//	subs r8,r8,#PSG_SWEEP_ADD
//	bhi noSweep
//	ldrb lr,[spxptr,#wsvSweepTime]
//	add lr,lr,#1
//	add r8,r8,lr,lsl#26
//	ldrsb lr,[spxptr,#wsvSweepValue]
//	mov r5,r5,ror#11
//	adds r5,r5,lr,lsl#21
//	mov r5,r5,ror#21
noSweep:
	eor r2,r2,#0x00008000
	cmp r0,#0
	strpl r2,[r1],#4
	bhi mixLoop				;@ ?? cycles according to No$gba

	mov r2,r7,lsr#17
	strh r2,[spxptr,#wsvNoiseCntr]
	b pcmMixReturn
;@----------------------------------------------------------------------------
#endif


#endif // #ifdef __arm__
