//
//  Sphinx.i
//  Bandai WonderSwan SOC emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2025 Fredrik Ahlström. All rights reserved.
//

#if !__ASSEMBLER__
	#error This header file is only for use in assembly files!
#endif

#define HW_AUTO              (0)
#define HW_WONDERSWAN        (1)
#define HW_WONDERSWANCOLOR   (2)
#define HW_SWANCRYSTAL       (3)
#define HW_POCKETCHALLENGEV2 (4)
#define HW_SELECT_END        (5)

#define SOC_ASWAN			(0)
#define SOC_SPHINX			(1)
#define SOC_SPHINX2			(2)

#define LCD_ICON_SLEEP		(1<<0)
#define LCD_ICON_VERT		(1<<1)
#define LCD_ICON_HORZ		(1<<2)
#define LCD_ICON_DOT1		(1<<3)
#define LCD_ICON_DOT2		(1<<4)
#define LCD_ICON_DOT3		(1<<5)
#define LCD_ICON_VOLU		(3<<6)
#define LCD_ICON_VOL1		(1<<6)
#define LCD_ICON_VOL2		(2<<6)
#define LCD_ICON_HEADPHONE	(1<<8)
#define LCD_ICON_BATTERY	(1<<9)
#define LCD_ICON_CARTRIDGE	(1<<10)
#define LCD_ICON_POWER		(1<<11)
/** Sound icons are on/off */
#define LCD_ICON_SOUND		(1<<12)

/** Time for latched icons (sound & cartridge) */
#define LCD_ICON_TIME_VALUE (128)

#define WS_KEY_START	(1<<1)
#define WS_KEY_A		(1<<2)
#define WS_KEY_B		(1<<3)
#define WS_KEY_X1		(1<<4)
#define WS_KEY_X2		(1<<5)
#define WS_KEY_X3		(1<<6)
#define WS_KEY_X4		(1<<7)
#define WS_KEY_Y1		(1<<8)
#define WS_KEY_Y2		(1<<9)
#define WS_KEY_Y3		(1<<10)
#define WS_KEY_Y4		(1<<11)
#define WS_KEY_SOUND	(1<<16)

#define PCV2_KEY_LEFT	(1<<0)
#define PCV2_KEY_DOWN	(1<<2)
#define PCV2_KEY_UP		(1<<3)
#define PCV2_KEY_VIEW	(1<<4)
#define PCV2_KEY_ESCAPE	(1<<6)
#define PCV2_KEY_RIGHT	(1<<7)
#define PCV2_KEY_CLEAR	(1<<8)
#define PCV2_KEY_CIRCLE	(1<<10)
#define PCV2_KEY_PASS	(1<<11)

/** Game screen width in pixels */
#define GAME_WIDTH  (224)
/** Game screen height in pixels */
#define GAME_HEIGHT (144)

;@----------------------------------------------------------------------------
;@ Internal IRQ flags
	.equ SERTX_IRQ_F,	0x01			;@ Serial Transmit IRQ flag
	.equ KEYPD_IRQ_F,	0x02			;@ Key press IRQ flag
	.equ EXTRN_IRQ_F,	0x04			;@ External (cart) IRQ flag
	.equ SERRX_IRQ_F,	0x08			;@ Serial Receive IRQ flag
	.equ LINE_IRQ_F,	0x10			;@ Drawing Line IRQ flag
	.equ VBLTM_IRQ_F,	0x20			;@ VBlank Timer IRQ flag
	.equ VBLST_IRQ_F,	0x40			;@ VBlank Start IRQ flag
	.equ HBLTM_IRQ_F,	0x80			;@ HBlank Timer IRQ flag
;@----------------------------------------------------------------------------

	spxptr		.req r12
						;@ WSVideo.s
	.struct 0
sphinxState:					;@
scanline:			.long 0		;@ These 3 must be first in state.
nextLineChange:		.long 0
lineState:			.long 0

unused0:			.long 0
wsvBgScrollBak:		.long 0		;@ Extra buff for scroll
wsvFgScrollBak:		.long 0

wsvRegs:
wsvDispCtrl:		.byte 0		;@ 0x00 Display control
wsvBgColor:			.byte 0		;@ 0x01 Background color
wsvCurrentLine:		.byte 0		;@ 0x02 Current scan line
wsvLineCompare:		.byte 0		;@ 0x03 Scan line compare for IRQ
wsvSprTblAdr:		.byte 0		;@ 0x04 Sprite table address
wsvSpriteFirst:		.byte 0		;@ 0x05 Sprite to start with
wsvSpriteCount:		.byte 0		;@ 0x06 Sprite count
wsvMapTblAdr:		.byte 0		;@ 0x07 Map table address

wsvFgWinXPos:		.byte 0		;@ 0x08 Foreground window X-Position
wsvFgWinYPos:		.byte 0		;@ 0x09 Foreground window Y-Position
wsvFgWinXEnd:		.byte 0		;@ 0x0A Foreground window X-End
wsvFgWinYEnd:		.byte 0		;@ 0x0B Foreground window Y-End

wsvSprWinXPos:		.byte 0		;@ 0x0C Sprite window X-Position
wsvSprWinYPos:		.byte 0		;@ 0x0D Sprite window Y-Position
wsvSprWinXSize:		.byte 0		;@ 0x0E Sprite window X-Size
wsvSprWinYSize:		.byte 0		;@ 0x0F Sprite window Y-Size

wsvBgXScroll:		.byte 0		;@ 0x10 Background X-Scroll
wsvBgYScroll:		.byte 0		;@ 0x11 Background Y-Scroll
wsvFgXScroll:		.byte 0		;@ 0x12 Foreground X-Scroll
wsvFgYScroll:		.byte 0		;@ 0x13 Foreground Y-Scroll

wsvLCDControl:		.byte 0		;@ 0x14 LCD control (sleep, WSC contrast)
wsvLCDIcons:		.byte 0		;@ 0x15 LCD icons
wsvTotalLines:		.byte 0		;@ 0x16 Total scan lines
wsvVSync:			.byte 0		;@ 0x17 LCD_VSYNC
wsvLineCounter:		.byte 0		;@ 0x18 Write current scan line.
wsvPadding0:		.space 1	;@ 0x19 ???
wsvLatchedIcons:	.byte 0		;@ 0x1A Latched LCD icons
wsvPadding1:		.space 1	;@ 0x1B ???

wsvColor01:			.byte 0		;@ 0x1C Color 0 & 1
wsvColor23:			.byte 0		;@ 0x1D Color 2 & 3
wsvColor45:			.byte 0		;@ 0x1E Color 4 & 5
wsvColor67:			.byte 0		;@ 0x1F Color 6 & 7

wsvPalette0:		.short 0	;@ 0x20/0x21 Palette 0
wsvPalette1:		.short 0	;@ 0x22/0x23 Palette 1
wsvPalette2:		.short 0	;@ 0x24/0x25 Palette 2
wsvPalette3:		.short 0	;@ 0x26/0x27 Palette 3
wsvPalette4:		.short 0	;@ 0x28/0x29 Palette 4
wsvPalette5:		.short 0	;@ 0x2A/0x2B Palette 5
wsvPalette6:		.short 0	;@ 0x2C/0x2D Palette 6
wsvPalette7:		.short 0	;@ 0x2E/0x2F Palette 7
wsvPalette8:		.short 0	;@ 0x30/0x31 Palette 8
wsvPalette9:		.short 0	;@ 0x32/0x33 Palette 9
wsvPaletteA:		.short 0	;@ 0x34/0x35 Palette A
wsvPaletteB:		.short 0	;@ 0x36/0x37 Palette B
wsvPaletteC:		.short 0	;@ 0x38/0x39 Palette C
wsvPaletteD:		.short 0	;@ 0x3A/0x3B Palette D
wsvPaletteE:		.short 0	;@ 0x3C/0x3D Palette E
wsvPaletteF:		.short 0	;@ 0x3E/0x3F Palette F

wsvDMASource:		.long 0		;@ 0x40-0x43 DMA source adr bits 19-0
wsvDMADest:			.short 0	;@ 0x44/0x45 DMA destination adr bits 15-0
wsvDMALength:		.short 0	;@ 0x46/0x47 DMA length bits 15-0
wsvDMACtrl:			.byte 0		;@ 0x48 DMA control, bit 7 start
wsvPadding2:		.space 1	;@ 0x49 ???

wsvSndDMASrcL:		.short 0	;@ 0x4A-0x4B Sound DMA source adr bits 15-0
wsvSndDMASrcH:		.short 0	;@ 0x4C-0x4D Sound DMA source adr bits 19-16
wsvSndDMALenL:		.short 0	;@ 0x4E-0x4F Sound DMA length bits 15-0
wsvSndDMALenH:		.short 0	;@ 0x50-0x51 Sound DMA length bits 19-16
wsvSndDMACtrl:		.byte 0		;@ 0x52 Sound DMA control, bit 7 start

wsvPadding3:		.space 13	;@ 0x53 - 0x5F ???

wsvVideoMode:		.byte 0		;@ 0x60 Video rendering mode
wsvPadding4:		.space 1	;@ 0x61 ???

wsvSystemCtrl3:		.byte 0		;@ 0x62 WSC / SC, Power off
wsvPadding5:		.space 1	;@ 0x63 ???

wsvHyperVL:			.short 0	;@ 0x64 HyperVoice Left channel
wsvHyperVR:			.short 0	;@ 0x66 HyperVoice Right channel
wsvHyperVSL:		.byte 0		;@ 0x68 HyperVoice Shadow (lower byte? left?)
wsvHyperVSH:		.byte 0		;@ 0x69 HyperVoice Shadow (upper byte? right?)
wsvHyperVCtrl:		.short 0	;@ 0x6A HyperVoice control
wsvPadding5_1:		.space 4	;@ 0x6C - 0x6F ???

wsvSCLCDCtrl0:		.byte 0		;@ 0x70 SC LCD control 0
wsvSCLCDCtrl1:		.byte 0		;@ 0x71 SC LCD control 1
wsvSCLCDCtrl2:		.byte 0		;@ 0x72 SC LCD control 2
wsvSCLCDCtrl3:		.byte 0		;@ 0x73 SC LCD control 3
wsvSCLCDCtrl4:		.byte 0		;@ 0x74 SC LCD control 4
wsvSCLCDCtrl5:		.byte 0		;@ 0x75 SC LCD control 5
wsvSCLCDCtrl6:		.byte 0		;@ 0x76 SC LCD control 6
wsvSCLCDCtrl7:		.byte 0		;@ 0x77 SC LCD control 7
wsvPadding6:		.space 8	;@ 0x78 - 0x7F ???

wsvSound1Freq:		.short 0	;@ 0x80/0x81 Sound ch 1 pitch bits 10-0
wsvSound2Freq:		.short 0	;@ 0x82/0x83 Sound ch 2 pitch bits 10-0
wsvSound3Freq:		.short 0	;@ 0x84/0x85 Sound ch 3 pitch bits 10-0
wsvSound4Freq:		.short 0	;@ 0x86/0x87 Sound ch 4 pitch bits 10-0

wsvSound1Vol:		.byte 0		;@ 0x88 Sound ch 1 volume
wsvSound2Vol:		.byte 0		;@ 0x89 Sound ch 2 volume
wsvSound3Vol:		.byte 0		;@ 0x8A Sound ch 3 volume
wsvSound4Vol:		.byte 0		;@ 0x8B Sound ch 4 volume
wsvSweepValue:		.byte 0		;@ 0x8C Sweep value
wsvSweepTime:		.byte 0		;@ 0x8D Sweep time
wsvNoiseCtrl:		.byte 0		;@ 0x8E Noise control
wsvSampleBase:		.byte 0		;@ 0x8F Sound wave base

wsvSoundCtrl:		.byte 0		;@ 0x90 Sound control
wsvSoundOutput:		.byte 0		;@ 0x91 Sound output
wsvNoiseCntr:		.short 0	;@ 0x92/0x93 Noise Counter Shift Register (15 bits)
wsvCh2VoiceVol:		.byte 0		;@ 0x94 Ch2 Voice Volume

wsvSoundTest:		.byte 0		;@ 0x95 Sound test
wsvSoundOutR:		.short 0	;@ 0x96/0x97 Sound out Right, 10  bits
wsvSoundOutL:		.short 0	;@ 0x98/0x99 Sound out Left,  10  bits
wsvSoundOutM:		.short 0	;@ 0x9A/0x9B Sound out Mixed, 11  bits
wsvPadding7:		.short 0	;@ 0x9C/0x9D ???
wsvHWVolume:		.byte 0		;@ 0x9E HW Volume (2 bit)
wsvPadding8:		.space 1	;@ 0x9F ???

wsvSystemCtrl1:		.byte 0		;@ 0xA0 Hardware type, boot rom lock.

wsvPadding9:		.space 1	;@ 0xA1 ???

wsvTimerControl:	.byte 0		;@ 0xA2 Timer control
wsvSystemTest:		.byte 0		;@ 0xA3 System Test
wsvHBlTimerFreq:	.short 0	;@ 0xA4/0xA5 HBlank Timer 'frequency'
wsvVBlTimerFreq:	.short 0	;@ 0xA6/0xA7 VBlank Timer 'frequency'
wsvHBlCounter:		.short 0	;@ 0xA8/0xA9 HBlank Counter - 1/12000s
wsvVBlCounter:		.short 0	;@ 0xAA/0xAB VBlank Counter - 1/75s

wsvPowerOff:		.byte 0		;@ 0xAC Power Off
wsvPadding11:		.space 3	;@ 0xAD - 0xAF ???

wsvInterruptBase:	.byte 0		;@ 0xB0 Interrupt base
wsvByteReceived:	.byte 0		;@ 0xB1 Serial Communication byte
wsvInterruptEnable:	.byte 0		;@ 0xB2 Interrupt enable
wsvSerialStatus:	.byte 0		;@ 0xB3 Serial status
wsvInterruptStatus:	.byte 0		;@ 0xB4 Interrupt status
wsvKeypad:			.byte 0		;@ 0xB5 Input Controls
wsvInterruptAck:	.byte 0		;@ 0xB6 Interrupt acknowledge
wsvNMIControl:		.byte 0		;@ 0xB7 NMI Control

wsvPadding12:		.space 2	;@ 0xB8 - 0xB9 ???

wsvIntEEPROMData:	.short 0	;@ 0xBA/0xBB Internal EEPROM data
wsvIntEEPROMAdr:	.short 0	;@ 0xBC/0xBD Internal EEPROM address
wsvIntEEPROMCmd:	.short 0	;@ 0xBE Internal EEPROM command/status

;@----------------------------------------------------------------------------
wsvBnk0Slct_:		.byte 0		;@ 0xC0 ROM Bank Base Selector for segments 4-$F
wsvBnk1Slct_:		.byte 0		;@ 0xC1 SRAM Bank selector
wsvBnk2Slct_:		.byte 0		;@ 0xC2 BNK2SLCT - ROM Bank selector for segment 2
wsvBnk3Slct_:		.byte 0		;@ 0xC3 BNK3SLCT - ROM Bank selector for segment 3
wsvExtEEPROMData:	.short 0	;@ 0xC4/0xC5 External EEPROM data
wsvExtEEPROMAdr:	.short 0	;@ 0xC6/0xC7 External EEPROM address
wsvExtEEPROMCmd:	.short 0	;@ 0xC8/0xC9 External EEPROM command/status

wsvRTCCommand:		.byte 0		;@ 0xCA RTC Command
wsvRTCData:			.byte 0		;@ 0xCB RTC Data
wsvGPIOEnable:		.byte 0		;@ 0xCC GP IO Enable/Direction
wsvGPIOData:		.byte 0		;@ 0xCD GP IO Data
wsvBank1Map:		.byte 0		;@ 0xCE Map Flash/ROM to SRAM area

wsvBnk0SlctX:		.byte 0		;@ 0xCF ROM Bank Base Selector for segments 4-$F
wsvBnk1SlctX:		.short 0	;@ 0xD0/0xD1 SRAM Bank selector
wsvBnk2SlctX:		.short 0	;@ 0xD2/0xD3 BNK2SLCT - ROM Bank selector for segment 2
wsvBnk3SlctX:		.short 0	;@ 0xD4/0xD5 BNK3SLCT - ROM Bank selector for segment 3
wsvCartTimer:		.byte 0		;@ 0xD6 Cart Timer
wsvPadding13:		.space 1	;@ 0xD7 ???
wsvADPCMW:			.byte 0		;@ 0xD8 ADPCM Write
wsvADPCMR:			.byte 0		;@ 0xD9 ADPCM Read
wsvPadding14:		.space 38	;@ 0xDA - 0xFF ???

;@----------------------------------------------------------------------------
sndDmaSource:		.long 0		;@ Sound DMA source address (current)
sndDmaLength:		.long 0		;@ Sound DMA length (current)

pcm1CurrentAddr:	.long 0		;@ Ch1 Current address
pcm2CurrentAddr:	.long 0		;@ Ch2 Current address
pcm3CurrentAddr:	.long 0		;@ Ch3 Current address
pcm4CurrentAddr:	.long 0		;@ Ch4 Current address
noise4CurrentAddr:	.long 0		;@ Ch4 noise Current address
sweep3CurrentAddr:	.long 0		;@ Ch3 sweep Current address
currentSampleValue: .long 0		;@ Hyper Voice sample
sampleBaseAddr:		.long 0		;@ Current sample base address

missingSamplesCnt:	.long 0		;@ Number of missing samples from last sound callback.

serialRXCounter:	.long 0		;@ How many cycles to receive byte.
serialTXCounter:	.long 0		;@ How many cycles to send byte.

wsvLatchedSprCnt:	.byte 0		;@ Latched Sprite count
wsvOrientation:		.byte 0
wsvLowBattery:		.byte 0
wsvLowBatPin:		.byte 0
wsvInterruptPins:	.byte 0
wsvComByte:			.byte 0
wsvSerialBufFull:	.byte 0
wsvOldKeypadReg:	.byte 0
wsvSoundIconTimer:	.byte 0
wsvCartIconTimer:	.byte 0
wsvRegMask14:		.byte 0
wsvPadding15:		.space 1

enabledLCDIcons:	.long 0
dispLine: 			.long 0		;@ Last line dispCtrl was updated.
windowLine:			.long 0		;@ Last line window was updated.
scrollLine: 		.long 0		;@ Last line scroll was updated.
ledCounter:			.long 0
wsvSpriteRAM:		.space 0x200 ;@ Internal sprite ram
sphinxStateEnd:

wsvDefaultBgCol:	.long 0		;@ LCD color when off
wsvJoyState:		.long 0		;@ Current Joypad state
cachedMaps:			.space 4

wsvSOC:				.byte 0		;@ ASwan, Sphinx or Sphinx2
wsvMachine:			.byte 0		;@ WonderSwan, WonderSwanColor, SwanCrystal or PocketChallengeV2
wsvPadding16:		.space 2

irqFunction:		.long 0		;@ IRQ function
rxFunction:			.long 0		;@ Serial in empty function
txFunction:			.long 0		;@ Serial out function

gfxRAM:				.long 0		;@ 0x4000/0x10000
paletteRAM:			.long 0		;@ 0x0200
dispBuff:			.long 0
windowBuff:			.long 0
scrollBuff:			.long 0

sphinxStateSize = sphinxStateEnd-sphinxState
sphinxSize:
	.previous

;@----------------------------------------------------------------------------

