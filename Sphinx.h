// Bandai WonderSwan SOC emulation

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
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

//wsvState:
//wsvRegs:					// 0-4
	u8 wsvDisplayControl;
	u8 wsvBGColor;
	u8 wsvCurrentLine;
	u8 wsvLineCompare;

	u8 wsvWinXPos;
	u8 wsvWinYPos;
	u8 wsvWinXSize;
	u8 wsvWinYSize;

	u8 wsvSprWinXPos;
	u8 wsvSprWinYPos;
	u8 wsvSprWinXSize;
	u8 wsvSprWinYSize;

	u8 wsvBGXScroll;
	u8 wsvBGYScroll;
	u8 wsvFGXScroll;
	u8 wsvFGYScroll;

	u8 kgeBGCol;
	u8 kgeBGPrio;
	u8 kgeLedEnable;
	u8 kgeLedBlink;
	u8 wsvVideoMode;

	u8 kgeLedOnOff;			// Bit 0, Led On/Off.
	u8 wsvModel;
	u8 koPadding1[2];

	u32 ledCounter;
	u32 windowData;

	void *irqFunction;

	u8 dirtyTiles[4];
	void *gfxRAM;
	void *paletteMonoRAM;
	void *paletteRAM;
	void *gfxRAMSwap;
	u32 *scrollBuff;

} Sphinx;

void wsVideoReset(void *irqFunction(), void *ram, int soc);

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
