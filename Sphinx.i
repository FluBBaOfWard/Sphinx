;@ ASM header for the Bandai WonderSwan SOC emulator
;@

#define HW_AUTO              (0)
#define HW_WONDERSWAN        (1)
#define HW_WONDERSWANCOLOR   (2)
#define HW_SWANCRYSTAL       (3)
#define HW_POCKETCHALLENGEV2 (4)
#define HW_SELECT_END        (5)

#define SOC_ASWAN		(0)
#define SOC_SPHINX		(1)
#define SOC_SPHINX2		(2)

/** Game screen width in pixels */
#define GAME_WIDTH  (224)
/** Game screen height in pixels */
#define GAME_HEIGHT (144)

	geptr		.req r12
						;@ WSVideo.s
	.struct 0
scanline:			.long 0		;@ These 3 must be first in state.
nextLineChange:		.long 0
lineState:			.long 0

windowData:			.long 0
wsVideoState:					;@
wsvRegs:
wsvDispCtrl:		.byte 0		;@ 0x00 Display control
wsvBGColor:			.byte 0		;@ 0x01 Background color
wsvCurrentLine:		.byte 0		;@ 0x02 Current scan line
wsvLineCompare:		.byte 0		;@ 0x03 Scan line compare for IRQ
wsvSprTblAdr:		.byte 0		;@ 0x04 Sprite table address
wsvSpriteFirst:		.byte 0		;@ 0x05 Sprite to start with
wsvSpriteCount:		.byte 0		;@ 0x06 Sprite count
wsvMapTblAdr:		.byte 0		;@ 0x07 Map table address

wsvWinXPos:			.byte 0		;@ 0x08 Window X-Position
wsvWinYPos:			.byte 0		;@ 0x09 Window Y-Position
wsvWinXSize:		.byte 0		;@ 0x0A Window X-Size
wsvWinYSize:		.byte 0		;@ 0x0B Window Y-Size

wsvSprWinXPos:		.byte 0		;@ 0x0C Sprite window X-Position
wsvSprWinYPos:		.byte 0		;@ 0x0D Sprite window Y-Position
wsvSprWinXSize:		.byte 0		;@ 0x0E Sprite window X-Size
wsvSprWinYSize:		.byte 0		;@ 0x0F Sprite window Y-Size

wsvBGXScroll:		.byte 0		;@ 0x10 Background X-Scroll
wsvBGYScroll:		.byte 0		;@ 0x11 Background Y-Scroll
wsvFGXScroll:		.byte 0		;@ 0x12 Foreground X-Scroll
wsvFGYScroll:		.byte 0		;@ 0x13 Foreground Y-Scroll

wsvLCDControl:		.byte 0		;@ 0x14 LCD control (on/off?)
wsvLCDIcons:		.byte 0		;@ 0x15 LCD icons
wsvTotalLines:		.byte 0		;@ 0x16 Total scan lines
wsvPadding0:		.space 5	;@ 0x17 - 0x1B ???

wsvColor01:			.byte 0		;@ 0x1C Color 0 & 1
wsvColor23:			.byte 0		;@ 0x1D Color 2 & 3
wsvColor45:			.byte 0		;@ 0x1E Color 4 & 5
wsvColor67:			.byte 0		;@ 0x1F Color 6 & 7

wsvPalette00:		.byte 0		;@ 0x20 Palette 00
wsvPalette01:		.byte 0		;@ 0x21 Palette 01
wsvPalette10:		.byte 0		;@ 0x22 Palette 10
wsvPalette11:		.byte 0		;@ 0x23 Palette 11
wsvPalette20:		.byte 0		;@ 0x24 Palette 20
wsvPalette21:		.byte 0		;@ 0x25 Palette 21
wsvPalette30:		.byte 0		;@ 0x26 Palette 30
wsvPalette31:		.byte 0		;@ 0x27 Palette 31
wsvPalette40:		.byte 0		;@ 0x28 Palette 40
wsvPalette41:		.byte 0		;@ 0x29 Palette 41
wsvPalette50:		.byte 0		;@ 0x2A Palette 50
wsvPalette51:		.byte 0		;@ 0x2B Palette 51
wsvPalette60:		.byte 0		;@ 0x2C Palette 60
wsvPalette61:		.byte 0		;@ 0x2D Palette 61
wsvPalette70:		.byte 0		;@ 0x2E Palette 70
wsvPalette71:		.byte 0		;@ 0x2F Palette 71
wsvPalette80:		.byte 0		;@ 0x30 Palette 80
wsvPalette81:		.byte 0		;@ 0x31 Palette 81
wsvPalette90:		.byte 0		;@ 0x32 Palette 90
wsvPalette91:		.byte 0		;@ 0x33 Palette 91
wsvPaletteA0:		.byte 0		;@ 0x34 Palette A0
wsvPaletteA1:		.byte 0		;@ 0x35 Palette A1
wsvPaletteB0:		.byte 0		;@ 0x36 Palette B0
wsvPaletteB1:		.byte 0		;@ 0x37 Palette B1
wsvPaletteC0:		.byte 0		;@ 0x38 Palette C0
wsvPaletteC1:		.byte 0		;@ 0x39 Palette C1
wsvPaletteD0:		.byte 0		;@ 0x3A Palette D0
wsvPaletteD1:		.byte 0		;@ 0x3B Palette D1
wsvPaletteE0:		.byte 0		;@ 0x3C Palette E0
wsvPaletteE1:		.byte 0		;@ 0x3D Palette E1
wsvPaletteF0:		.byte 0		;@ 0x3E Palette F0
wsvPaletteF1:		.byte 0		;@ 0x3F Palette F1

wsvDMASource:		.short 0	;@ 0x40 DMA source adr bits 15-0
wsvDMASrcBnk:		.byte 0		;@ 0x42 DMA source adr bits 19-16
wsvDMAEmpty:		.byte 0		;@ 0x43 Nothing
wsvDMADest:			.short 0	;@ 0x44 DMA destination adr bits 15-0
wsvDMALength:		.short 0	;@ 0x46 DMA length bits 15-0
wsvDMAStart:		.byte 0		;@ 0x48 DMA control, bit 7 start

wsvPadding1:		.space 1	;@ 0x49 ???
wsvSndDMASrc0:		.byte 0		;@ 0x4A Sound DMA source adr bits 7-0
wsvSndDMASrc1:		.byte 0		;@ 0x4B Sound DMA source adr bits 15-8
wsvSndDMASrc2:		.byte 0		;@ 0x4C Sound DMA source adr bits 19-16
wsvPadding2:		.space 1	;@ 0x4D ???
wsvSndDMALen0:		.byte 0		;@ 0x4E Sound DMA length bits 7-0
wsvSndDMALen1:		.byte 0		;@ 0x4F Sound DMA length bits 15-8
wsvSndDMALen2:		.byte 0		;@ 0x4F Sound DMA length bits 23-16
wsvPadding3:		.space 1	;@ 0x51 ???
wsvSndDMAStart:		.byte 0		;@ 0x52 Sound DMA control, bit 7 start

wsvPadding4:		.space 13	;@ 0x53 - 0x5F ???

wsvVideoMode:		.byte 0		;@ 0x60 Video rendering mode

wsvPadding5:		.space 31	;@ 0x61 - 0x7F ???

wsvAudio1Freq0:		.byte 0		;@ 0x80 Audio 1 frequency bits 7-0
wsvAudio1Freq1:		.byte 0		;@ 0x81 Audio 1 frequency bits 15-8
wsvAudio2Freq0:		.byte 0		;@ 0x82 Audio 2 frequency bits 7-0
wsvAudio2Freq1:		.byte 0		;@ 0x83 Audio 2 frequency bits 15-8
wsvAudio3Freq0:		.byte 0		;@ 0x84 Audio 3 frequency bits 7-0
wsvAudio3Freq1:		.byte 0		;@ 0x85 Audio 3 frequency bits 15-8
wsvAudio4Freq0:		.byte 0		;@ 0x86 Audio 4 frequency bits 7-0
wsvAudio4Freq1:		.byte 0		;@ 0x87 Audio 4 frequency bits 15-8

wsvAudio1Vol:		.byte 0		;@ 0x88 Audio 1 volume
wsvAudio2Vol:		.byte 0		;@ 0x89 Audio 2 volume
wsvAudio3Vol:		.byte 0		;@ 0x8A Audio 3 volume
wsvAudio4Vol:		.byte 0		;@ 0x8B Audio 4 volume
wsvSweepValue:		.byte 0		;@ 0x8C Sweep value
wsvSweepStep:		.byte 0		;@ 0x8D Sweep step
wsvNoiseCtrl:		.byte 0		;@ 0x8E Noise control
wsvSampleLoc:		.byte 0		;@ 0x8F Sample location

wsvAudioCtrl:		.byte 0		;@ 0x90 Audio control
wsvAudioOutput:		.byte 0		;@ 0x91 Audio output
wsvNoiseCntr:		.short 0	;@ 0x92/0x93 Noise Counter Shift Register (15 bits)
wsvVolume:			.byte 0		;@ 0x94 Volume (4 bit)

wsvPadding6:		.space 11	;@ 0x95 - 0x9F ???

wsvHardwareType:	.byte 0		;@ 0xA0 Hardware type, boot rom lock.

wsvPadding7:		.space 1	;@ 0xA1 ???

wsvTimerControl:	.byte 0		;@ 0xA2 Timer control
wsvPadding8:		.space 1	;@ 0xA3 ???
wsvHBlTimerFreq:	.short 0	;@ 0xA4/0xA5 Hblank Timer 'frequency'
wsvVBlTimerFreq:	.short 0	;@ 0xA6/0xA7 Vblank Timer 'frequency'
wsvHBlCounter:		.short 0	;@ 0xA8/0xA9 Hblank Counter - 1/12000s
wsvVBlCounter:		.short 0	;@ 0xAA/0xAB Vblank Counter - 1/75s

wsvPadding9:		.space 4	;@ 0xAC - 0xAF ???

wsvInterruptBase:	.byte 0		;@ 0xB0 Interrupt base
wsvComByte:			.byte 0		;@ 0xB1 Communication byte
wsvInterruptEnable:	.byte 0		;@ 0xB2 Interrupt enable
wsvSerialStatus:	.byte 0		;@ 0xB3 Serial status
wsvInterruptStatus:	.byte 0		;@ 0xB4 Interrupt status
wsvControls:		.byte 0		;@ 0xB5 Input Controls
wsvInterruptAck:	.byte 0		;@ 0xB6 Interrupt acknowledge

wsvPadding11:		.space 3	;@ 0xB7 - 0xB9 ???

wsvIntEEPROMData:	.short 0	;@ 0xBA/0xBB Internal EEPROM data
wsvIntEEPROMAdr:	.short 0	;@ 0xBC/0xBD Internal EEPROM address
wsvIntEEPROMCmd:	.short 0	;@ 0xBE Internal EEPROM command/status

wsvBnk0Slct:		.byte 0		;@ 0xC0 ROM Bank Base Selector for segments 4-$F
wsvBnk1Slct:		.byte 0		;@ 0xC1 SRAM Bank selector
wsvBnk2Slct:		.byte 0		;@ 0xC2 BNK2SLCT - ROM Bank selector for segment 2
wsvBnk3Slct:		.byte 0		;@ 0xC3 BNK2SLCT - ROM Bank selector for segment 3
wsvExtEEPROMData:	.short 0	;@ 0xC4/0xC5 External EEPROM data
wsvExtEEPROMAdr:	.short 0	;@ 0xC6/0xC7 External EEPROM address
wsvExtEEPROMCmd:	.short 0	;@ 0xC8 External EEPROM command/status

wsvRTCCommand:		.byte 0		;@ 0xCA RTC Command
wsvRTCData:			.byte 0		;@ 0xCB RTC Data

wsvPadding14:		.space 52	;@ 0xCC - 0xFF ???

wsvSOC:				.byte 0		;@ ASWAN, SPHINX or SPHINX2
wsvLatchedSprCnt:	.byte 0		;@ Latched Sprite count
kgeLedEnable:		.byte 0
kgeLedBlink:		.byte 0
kgeLedOnOff:		.byte 0		;@ Bit 0, Led On/Off.
kgePadding1:		.space 3

scrollLine: 		.long 0		;@ Last line scroll was updated.
ledCounter:			.long 0
wsVideoStateEnd:

frameIrqFunc:		.long 0		;@ V-Blank Irq
periodicIrqFunc:	.long 0		;@ H-Blank Irq

dirtyTiles:			.space 4
gfxRAM:				.long 0		;@ 0x3000
paletteMonoRAM:		.long 0		;@ 0x0020
paletteRAM:			.long 0		;@ 0x0200
gfxRAMSwap:			.long 0		;@ 0x3000
scrollBuff:			.long 0
wsvSpriteRAM:		.space 0x200 ;@ Internal sprite ram

wsVideoSize:

;@----------------------------------------------------------------------------

