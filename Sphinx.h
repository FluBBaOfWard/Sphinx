//
//  Sphinx.h
//  Bandai WonderSwan SOC emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2025 Fredrik Ahlström. All rights reserved.
//

#ifndef SPHINX_HEADER
#define SPHINX_HEADER

#ifdef __cplusplus
extern "C" {
#endif

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

typedef struct {
//wsvState:
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	u32 unused0;
	/// Extra buffer for map/scroll registers
	u32 wsvBgScrollBak;
	u32 wsvFgScrollBak;
//wsvRegs:
	/// 0x00 Display control
	u8 dispCtrl;
	/// 0x01 Background color
	u8 bgColor;
	/// 0x02 Current scan line
	u8 currentLine;
	/// 0x03 Scan line compare for IRQ
	u8 lineCompare;

	/// 0x04 Sprite table address
	u8 sprTblAdr;
	/// 0x05 Sprite to start with
	u8 spriteFirst;
	/// 0x06 Sprite count
	u8 spriteCount;
	/// 0x07 Map table address
	u8 mapTblAdr;

	/// 0x08 Foreground window X-Position
	u8 fgWinXPos;
	/// 0x09 Foreground window Y-Position
	u8 fgWinYPos;
	/// 0x0A Foreground window X-End
	u8 fgWinXEnd;
	/// 0x0B Foreground window Y-End
	u8 fgWinYEnd;

	/// 0x0C Sprite window X-Position
	u8 sprWinXPos;
	/// 0x0D Sprite window Y-Position
	u8 sprWinYPos;
	/// 0x0E Sprite window X-Size
	u8 sprWinXSize;
	/// 0x0F Sprite window Y-Size
	u8 sprWinYSize;

	/// 0x10 Background X-Scroll
	u8 bgXScroll;
	/// 0x11 Background Y-Scroll
	u8 bgYScroll;
	/// 0x12 Foreground X-Scroll
	u8 fgXScroll;
	/// 0x13 Foreground Y-Scroll
	u8 fgYScroll;

	/// 0x14 LCD control (on/off, WSC contrast)
	u8 lcdControl;
	/// 0x15 LCD icons
	u8 lcdIcons;
	/// 0x16 Total scan lines
	u8 totalLines;
	/// 0x17 LCD_VSYNC
	u8 vSync;
	/// 0x18 Write current scan line
	u8 lineCounter;
	/// 0x19 No register
	u8 padding0[1];
	/// 0x1A LCD Cartridge & Volume icons
	u8 latchedIcons;
	/// 0x1B No register
	u8 padding1[1];

	/// 0x1C Color 0 & 1
	u8 color01;
	/// 0x1D Color 2 & 3
	u8 color23;
	/// 0x1E Color 4 & 5
	u8 color45;
	/// 0x1F Color 6 & 7
	u8 color67;

	/// 0x20/0x21 Palette 0
	u16 palette0;
	/// 0x22/0x23 Palette 1
	u16 palette1;
	/// 0x24/0x25 Palette 2
	u16 palette2;
	/// 0x26/0x27 Palette 3
	u16 palette3;
	/// 0x28/0x29 Palette 4
	u16 palette4;
	/// 0x2A/0x2B Palette 5
	u16 palette5;
	/// 0x2C/0x2D Palette 6
	u16 palette6;
	/// 0x2E/0x2F Palette 7
	u16 palette7;
	/// 0x30/0x31 Palette 8
	u16 palette8;
	/// 0x32/0x33 Palette 9
	u16 palette9;
	/// 0x34/0x35 Palette A
	u16 paletteA;
	/// 0x36/0x37 Palette B
	u16 paletteB;
	/// 0x38/0x39 Palette C
	u16 paletteC;
	/// 0x3A/0x3B Palette D
	u16 paletteD;
	/// 0x3C/0x3D Palette E
	u16 paletteE;
	/// 0x3E/0x3F Palette F
	u16 paletteF;

	/// 0x40-0x43 DMA source adr bits 19-0
	u32 dmaSource;
	/// 0x44/0x45 DMA destination adr bits 15-0
	u16 dmaDest;
	/// 0x46/0x47 DMA length bits 15-0
	u16 dmaLength;
	/// 0x48 DMA control, bit 7 start
	u8 dmaCtrl;
	/// 0x49 No register
	u8 padding2[1];

	/// 0x4A-0x4B Sound DMA source adr bits 15-0
	u16 sndDMASrcL;
	/// 0x4C-0x4D Sound DMA source adr bits 19-16
	u16 sndDMASrcH;
	/// 0x4E-0x4F Sound DMA length bits 15-0
	u16 sndDMALenL;
	/// 0x50-0x51 Sound DMA length bits 19-16
	u16 sndDMALenH;
	/// 0x52 Sound DMA control, bit 7 start
	u8 sndDMACtrl;

	/// 0x53 - 0x5F No registers
	u8 padding3[13];

	/// 0x60 Video rendering mode
	u8 videoMode;

	/// 0x61 No register
	u8 padding4[1];
	/// 0x62 WSC / SC, Power off
	u8 systemCtrl3;
	/// 0x63 No register
	u8 padding5;
	/// 0x64 HyperVoice Left channel (lower byte)
	u8 hyperVLL;
	/// 0x65 HyperVoice Left channel (upper byte)
	u8 hyperVLH;
	/// 0x66 HyperVoice Right channel (lower byte)
	u8 hyperVRL;
	/// 0x67 HyperVoice Right channel (upper byte)
	u8 hyperVRH;
	/// 0x68 HyperVoice Shadow (lower byte)
	u8 hyperVSL;
	/// 0x69 HyperVoice Shadow (upper byte)
	u8 hyperVSH;
	/// 0x6A HyperVoice control
	u8 hyperVCtrl;
	/// 0x6B HyperVoice channel control
	u8 hyperVChnCtrl;
	/// 0x6C - 0x6F No registers
	u8 padding5_1[4];

	/// 0x70 SC LCD control 0
	u8 scLCDCtrl0;
	/// 0x71 SC LCD control 1
	u8 scLCDCtrl1;
	/// 0x72 SC LCD control 2
	u8 scLCDCtrl2;
	/// 0x73 SC LCD control 3
	u8 scLCDCtrl3;
	/// 0x74 SC LCD control 4
	u8 scLCDCtrl4;
	/// 0x75 SC LCD control 5
	u8 scLCDCtrl5;
	/// 0x76 SC LCD control 6
	u8 scLCDCtrl6;
	/// 0x77 SC LCD control 7
	u8 scLCDCtrl7;
	/// 0x78 - 0x7F No registers
	u8 padding6[8];

	/// 0x80/0x81 Sound ch 1 pitch bits 10-0
	u16 sound1Freq;
	/// 0x82/0x83 Sound ch 2 pitch bits 10-0
	u16 sound2Freq;
	/// 0x84/0x85 Sound ch 3 pitch bits 10-0
	u16 sound3Freq;
	/// 0x86/0x87 Sound ch 4 pitch bits 10-0
	u16 sound4Freq;

	/// 0x88 Sound ch 1 volume
	u8 sound1Vol;
	/// 0x89 Sound ch 2 volume
	u8 sound2Vol;
	/// 0x8A Sound ch 3 volume
	u8 sound3Vol;
	/// 0x8B Sound ch 4 volume
	u8 sound4Vol;
	/// 0x8C Sweep value
	u8 sweepValue;
	/// 0x8D Sweep time
	u8 sweepTime;
	/// 0x8E Noise control
	u8 noiseCtrl;
	/// 0x8F Sound wave base
	u8 sampleBase;

	/// 0x90 Sound control
	u8 soundCtrl;
	/// 0x91 Sound output
	u8 soundOutput;
	/// 0x92/0x93 Noise Counter Shift Register (15 bits)
	u16 noiseCntr;
	/// 0x94 Ch2 Voice Volume
	u8 ch2VoiceVol;

	/// 0x95 Sound test
	u8 soundTest;
	/// 0x96/0x97 Sound out Right, 10  bits
	u16 soundOutR;
	/// 0x98/0x99 Sound out Left,  10  bits
	u16 soundOutL;
	/// 0x9A/0x9B Sound out Mixed, 11  bits
	u16 soundOutM;
	/// 0x9C - 0x9D No registers
	u8 padding7[2];
	/// 0x9E HW Volume (2 bit)
	u8 hwVolume;
	/// 0x9F No register
	u8 padding8;

	/// 0xA0 Hardware type, boot rom lock.
	u8 systemCtrl1;

	/// 0xA1 No register
	u8 padding9;

	/// 0xA2 Timer control
	u8 timerControl;
	/// 0xA3 No register
	u8 padding10;
	/// 0xA4/0xA5 HBlank Timer 'frequency'
	u16 hblTimerFreq;
	/// 0xA6/0xA7 VBlank Timer 'frequency'
	u16 vblTimerFreq;
	/// 0xA8/0xA9 HBlank Counter - 1/12000s
	u16 hblCounter;
	/// 0xAA/0xAB VBlank Counter - 1/75s
	u16 vblCounter;

	/// 0xAC Power off
	u8 powerOff;
	/// 0xAD - 0xAF No registers
	u8 padding11[3];

	/// 0xB0 Interrupt base
	u8 interruptBase;
	/// 0xB1 Serial Port byte
	u8 comByte;
	/// 0xB2 Interrupt enable
	u8 interruptEnable;
	/// 0xB3 Serial Port status
	u8 serialStatus;
	/// 0xB4 Interrupt status
	u8 interruptStatus;
	/// 0xB5 Input Controls
	u8 controls;
	/// 0xB6 Interrupt acknowledge
	u8 interruptAck;
	/// 0xB7 NMI Control
	u8 nmiControl;

	/// 0xB8 - 0xB9 No registers
	u8 padding12[2];

	/// 0xBA/0xBB Internal EEPROM data
	u16 intEEPROMData;
	///  0xBC/0xBD Internal EEPROM address
	u16 intEEPROMAdr;
	/// 0xBE Internal EEPROM command/status
	u16 intEEPROMCmd;

//-------- IO-Ports mapped to Cartridge ---------------
	/// 0xC0 ROM Bank Base Selector for segments 4-$F
	u8 bnk0Slct_;
	/// 0xC1 SRAM Bank selector
	u8 bnk1Slct_;
	/// 0xC2 BNK2SLCT - ROM Bank selector for segment 2
	u8 bnk2Slct_;
	/// 0xC3 BNK3SLCT - ROM Bank selector for segment 3
	u8 bnk3Slct_;
	/// 0xC4/0xC5 External EEPROM data
	u16 extEEPROMData;
	/// 0xC6/0xC7 External EEPROM address
	u16 extEEPROMAdr;
	/// 0xC8/0xC9 External EEPROM command/status
	u16 extEEPROMCmd;

	/// 0xCA RTC Command
	u8 rtcCommand;
	/// 0xCB RTC Data
	u8 rtcData;
	/// 0xCC GP IO Enable
	u8 gpIOEnable;
	/// 0xCD GP IO Data
	u8 gpIOData;
	/// 0xCE Map Flash/ROM to SRAM area
	u8 bank1Map;

	/// 0xCF ROM Bank Base Selector for segments 4-$F, mirros 0xC0.
	u8 bnk0SlctX;
	/// 0xD0/0xD1 SRAM Bank selector
	u16 bnk1SlctX;
	/// 0xD2/0xD3 BNK2SLCT - ROM Bank selector for segment 2
	u16 bnk2SlctX;
	/// 0xD4/0xD5 BNK3SLCT - ROM Bank selector for segment 3
	u16 bnk3SlctX;
	/// 0xD6 Cart Timer (Karnak)
	u8 cartTimer;
	/// 0xD7 No register
	u8 padding13[1];
	/// 0xD8 ADPCM Write (Karnak)
	u8 adpcmW;
	/// 0xD9 ADPCM Read (Karnak)
	u8 adpcmR;
	/// 0xDA - 0xFF No registers
	u8 padding14[38];
//--------- End of IO-Ports ---------------------

	/// Original Sound DMA source address
	u32 sndDmaSource;
	/// Original Sound DMA length
	u32 sndDmaLength;

	/// Ch1 Current addr
	u32 pcm1CurrentAddr;
	/// Ch2 Current addr
	u32 pcm2CurrentAddr;
	/// Ch3 Current addr
	u32 pcm3CurrentAddr;
	/// Ch4 Current addr
	u32 pcm4CurrentAddr;
	/// Ch4 noise Current addr
	u32 noise4CurrentAddr;
	/// Ch3 sweep Current addr
	u32 sweep3CurrentAddr;

	/// How many cycles to receive byte.
	u32 serialRXCounter;
	/// How many cycles to send byte.
	u32 serialTXCounter;

	/// Latched Sprite count
	u8 latchedSprCnt;
	u8 orientation;
	u8 lowBattery;
	u8 lowBatPin;
	u8 interruptPins;
	u8 byteReceived;
	u8 serialBufFull;
	u8 soundIconTimer;
	u8 cartIconTimer;
	u8 sleepMode__;
	u8 padding15[2];

	u32 enabledLCDIcons;
	/// Last line dispCtrl was updated.
	u32 dispLine;
	/// Last line window was updated.
	u32 windowLine;
	/// Last line scroll was updated.
	u32 scrollLine;
	u32 ledCounter;
	/// Internal sprite ram
	u8 wsvSpriteRAM[0x200];
	// End of Sphinx state

	//u32 sprWindowData;
	u8 cachedMaps[4];

	/// ASWAN, SPHINX or SPHINX2
	u8 soc;
	/// WonderSwan, WonderSwanColor, SwanCrystal or PocketChallengeV2
	u8 machine;
	u8 padding16[2];

	/// IRQ callback
	void (*irqFunction)(bool pin);
	/// Serial in empty function
	void (*rxFunction)(void);
	/// Serial out function
	void (*txFunction)(u8 val);

	void *gfxRAM;
	void *paletteRAM;
	u8 *dispBuff;
	u32 *windowBuff;
	u32 *scrollBuff;

} Sphinx;

void wsVideoReset(void *ram, int soc, void (*irqFunction)(bool pin));

/**
 * Saves the state of the chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The Sphinx chip to save.
 * @return The size of the state.
 */
int sphinxSaveState(void *destination, const Sphinx *chip);

/**
 * Loads the state of the chip from the source.
 * @param  *chip: The Sphinx chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int sphinxLoadState(Sphinx *chip, const void *source);

/**
 * Gets the state size of a Sphinx chip.
 * @return The size of the state.
 */
int sphinxGetStateSize(void);

void wsvDoScanline(void);
void wsvConvertTileMaps(void *destination);
void wsvConvertSprites(void *destination);
void wsvConvertTiles(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // SPHINX_HEADER
