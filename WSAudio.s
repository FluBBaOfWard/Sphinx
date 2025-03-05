//
//  WSAudio.s
//  Bandai WonderSwan Sound emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2025 Fredrik Ahlström. All rights reserved.
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
	.global setSoundOutput
	.global setTotalVolume
	.global vol2_L

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
	ldr r0,[spxptr,#gfxRAM]
	str r0,[spxptr,#sampleBaseAddr]

;@----------------------------------------------------------------------------
setAllChVolume:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r0,[spxptr,#wsvSound1Vol]
	bl setCh1Volume
	ldrb r0,[spxptr,#wsvSound2Vol]
	bl setCh2Volume
	ldrb r0,[spxptr,#wsvSound3Vol]
	bl setCh3Volume
	ldrb r0,[spxptr,#wsvSound4Vol]
	bl setCh4Volume
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
setCh1Volume:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundCtrl]
	tst r1,#1					;@ Ch 1 on?
	moveq r0,#0
	ldr r1,=vol1_L
	and r2,r0,#0xF
	mov r0,r0,lsr#4
	strb r0,[r1,#vol1_L-vol1_L]
	strb r2,[r1,#vol1_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setCh2Volume:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundCtrl]
	tst r1,#0x20				;@ Ch 2 voice on?
	bne doCh2Voice
	tst r1,#2					;@ Ch 2 on?
	moveq r0,#0
	ldr r2,=vol2_L
	and r1,r0,#0xF
	mov r0,r0,lsr#4
	strb r0,[r2]
	strb r1,[r2,#4]
	bx lr
doCh2Voice:
	ldrb r2,[spxptr,#wsvCh2VoiceVol]
	movs r1,r2,lsl#29			;@ Left vol
	movcs r1,r0,lsr#1			;@ 50%
	movmi r1,r0					;@ 100%
	movs r2,r2,lsl#31			;@ Right vol
	movcs r2,r0,lsr#1			;@ 50%
	movmi r2,r0					;@ 100%

	ldr r0,=vol2_L
	strb r1,[r0]
	strb r2,[r0,#4]
	bx lr

;@----------------------------------------------------------------------------
setCh3Volume:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundCtrl]
	tst r1,#4					;@ Ch 3 on?
	moveq r0,#0
	ldr r1,=vol1_L
	and r2,r0,#0xF
	mov r0,r0,lsr#4
	strb r0,[r1,#vol3_L-vol1_L]
	strb r2,[r1,#vol3_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setCh4Volume:
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvSoundCtrl]
	tst r1,#8					;@ Ch 4 on?
	moveq r0,#0
	ldr r1,=vol1_L
	and r2,r0,#0xF
	mov r0,r0,lsr#4
	strb r0,[r1,#vol4_L-vol1_L]
	strb r2,[r1,#vol4_R-vol1_L]
	bx lr
;@----------------------------------------------------------------------------
setHyperVoiceValue:
;@----------------------------------------------------------------------------
	ldrh r1,[spxptr,#wsvHyperVCtrl]
	ldrb r2,[spxptr,#wsvSoundOutput]
	tst r1,#0x80				;@ HyperV Enabled
	tstne r2,#0x80				;@ HeadPhones Enabled
	bxeq lr

	movs r0,r0,lsl#24
	orrmi r0,r0,#7
	ands r2,r1,#0x0C
	biceq r0,r0,#7
	cmpne r2,#0x08				;@ Sign extend?
	orrmi r0,r0,#7				;@ Unsigned negated
	bichi r1,r1,#0x03			;@ Ignore shift
	and r2,r1,#0x03				;@ Mask shift amount
	mov r0,r0,ror r2
	mov r0,r0,lsr#16			;@ Left
	ands r2,r1,#0x6000			;@ Mode, 0=stereo, 1=left, 2=right, 3=mono both.
	cmp r2,#0x4000
	moveq r0,r0,lsl#16			;@ Right
	cmp r2,#0x6000
	orreq r0,r0,r0,lsl#16		;@ Mono
	str r0,[spxptr,#currentSampleValue]
	bx lr
;@----------------------------------------------------------------------------
setSoundOutput:				;@ r0 = wsvSoundOutput (from 0x91)
;@----------------------------------------------------------------------------
	and r1,r0,#0x6
	tst r0,#0x80				;@ Headphones?
	biceq r0,r0,#0x08			;@ Disable headphones out if not connected.
	bicne r0,r0,#0x01			;@ Disable internal speaker if connected.
	movne r1,#8					;@ Headphones
	tst r0,#0x9					;@ Is any output enabled?
	moveq r1,#10				;@ No sound
	adr r2,mixerVolumes
	ldr r1,[r2,r1,lsl#1]
	ldr r0,=vol1_L
	str r1,[r0,#totalVolume-vol1_L]
	bx lr
mixerVolumes:
	mov r2,r2,lsl#8
	mov r2,r2,lsl#7
	mov r2,r2,lsl#6
	mov r2,r2,lsl#5
	add r2,r9,r2,lsl#5			;@ Headphones
	mov r2,r2,lsr#32			;@ No sound

;@----------------------------------------------------------------------------
setTotalVolume:
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvHWVolume]
	ldrb r1,[spxptr,#wsvSOC]
	adr r2,hw1Volumes
	cmp r1,#SOC_ASWAN
	adrne r2,hw2Volumes
	ldr r0,[r2,r0,lsl#2]
	ldr r1,=mix8Vol
	str r0,[r1]
	bx lr
hw1Volumes:
	mov r2,r2,lsr#32
	mov r2,r2,lsr#1
	mov r2,r2,lsr#0
	mov r2,r2,lsr#0
hw2Volumes:
	mov r2,r2,lsr#32
	mov r2,r2,lsr#2
	mov r2,r2,lsr#1
	mov r2,r2,lsr#0

;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2

#ifdef GBA
#define PSG_DIVIDE 24
#else
#define PSG_DIVIDE 16
#endif
#define PSG_ADDITION 0x00008000*PSG_DIVIDE
#define PSG_SWEEP_ADD 0x00010000*PSG_DIVIDE

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
;@ r9  = HyperVoice sample.
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
mixLoop:
	mov r11,r3,lsl#20			;@ Pre-load r11 & lr with frequency.
	mov lr,r4,lsl#20
innerMixLoop:
	add r3,r3,#PSG_ADDITION
	tst r3,r3,lsl#6
	addcs r3,r3,r11,lsr#5

	add r4,r4,#PSG_ADDITION
	tst r4,r4,lsl#6
	addcs r4,r4,lr,lsr#5

	add r5,r5,#PSG_ADDITION
	tst r5,r5,lsl#6
	mov r2,r5,lsl#20
	addcs r5,r5,r2,lsr#5

	add r6,r6,#PSG_ADDITION
	tst r6,r6,lsl#6
	mov r2,r6,lsl#20
	addcs r6,r6,r2,lsr#5

	movscs r2,r7,lsr#16			;@ Mask LFSR and check noise calc enable.
	addcs r7,r7,r2,lsl#16
	ands r2,r7,r7,lsl#21
	eorsne r2,r2,r7,lsl#21
	orreq r7,r7,#0x00010000

	subs r0,r0,#0x10000000
	bmi innerMixLoop
	bic r0,r0,#0xF0000000
;@----------------------------------------------------------------------------

	ldrb r11,[r10,r3,lsr#28]	;@ Channel 1
	tst r3,#0x08000000
	movne r11,r11,lsr#4
	and r11,r11,#0xF
vol1_L:
	mov lr,#0x00				;@ Volume left
vol1_R:
	orr lr,lr,#0xFF0000			;@ Volume right
	mul r2,lr,r11

	orrs r11,r10,r4,lsr#28
	ldrb r11,[r11,#0x10]		;@ Channel 2
	movcs r11,r11,lsr#4
	ands r11,r11,#0xF
vol2_L:
	mov lr,#0x00				;@ Volume left
vol2_R:
	orr lr,lr,#0xFF0000			;@ Volume right
	mlane r2,lr,r11,r2			;@ This is changed in wsvSoundCtrlW

	orrs r11,r10,r5,lsr#28
	ldrb r11,[r11,#0x20]		;@ Channel 3
	movcs r11,r11,lsr#4
	ands r11,r11,#0xF
vol3_L:
	mov lr,#0x00				;@ Volume left
vol3_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	movs r11,r7,lsl#17			;@ Channel 4 Noise enabled? (#0x4000)
	orrspl r11,r10,r6,lsr#28
	ldrbpl r11,[r11,#0x30]		;@ Channel 4 PCM
	movcs r11,r11,lsr#4
	movsmi r11,r7,lsl#15
	movmi r11,#0x0F
	ands r11,r11,#0xF
vol4_L:
	mov lr,#0x00				;@ Volume left
vol4_R:
	orrsne lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r11,r2

	tst r8,r8,lsr#9				;@ Ch3 Sweep?
	bcc noSweep
	addscs r8,r8,#PSG_SWEEP_ADD
	bcc noSweep
	subcs r8,r8,r8,lsl#26
	ldrsb lr,[spxptr,#wsvSweepValue]
	mov r5,r5,ror#11
	add r5,r5,lr,lsl#21
	mov r5,r5,ror#21
noSweep:
totalVolume:
	add r2,r9,r2,lsl#5			;@ This is updated by setSoundOutput
	subs r0,r0,#1
#ifdef GBA
	add r2,r2,r2,lsr#16
	mov r2,r2,lsr#9
	strbpl r2,[r1],#1
#else
	strpl r2,[r1],#4
#endif
	bhi mixLoop					;@ ?? cycles according to No$gba

	mov r2,r7,lsr#17
	strh r2,[spxptr,#wsvNoiseCntr]	;@ Update Reg 0x92 for "rnd".
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
	bhi mixLoop					;@ ?? cycles according to No$gba

	mov r2,r7,lsr#17
	strh r2,[spxptr,#wsvNoiseCntr]
	b pcmMixReturn
;@----------------------------------------------------------------------------
#endif


#endif // #ifdef __arm__
