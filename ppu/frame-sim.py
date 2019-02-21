import sys
import random
from PIL import Image
import numpy as np

#FRAME dimensions
WIDTH = 256
HEIGHT = 240

#TILE dimensions
TILE_W = 8 #pixels
TILE_H = 8 #pixels

#BLOCK dimesions
BLOCK_W = 4*TILE_W
BLOCK_H = 4*TILE_H

#CHR size
CHR_SIZE = 16 #pixel representation of chr takes 16 bytes

#NAMETABLE dimensions
NAMETABLE_W = WIDTH//TILE_W    # TILES
NAMETABLE_H = HEIGHT//TILE_H   # TILES

#ATTRIBUTE TABLE dimesions
ATTRIBUTE_TBL_W = 8             # BLOCKS
ATTRIBUTE_TBL_H = 8             # BLOCKS

#VRAM offsets
PATTERN_TBL_0 = 0x0
PATTERN_TBL_1 = 0x1000
PATTERN_TBL_SZ = 0x1000

NAMETABLE_0 = 0x2000
NAMETABLE_1 = 0x2400
NAMETABLE_2 = 0x2800
NAMETABLE_3 = 0x2C00
NAMETABLE_SZ = 0x400

ATTRIBUTE_TBL_OFF = 0x3C0 #offset off nametable base address
ATTRIBUTE_TBL_SZ = 0x40  

#Pallette ram offsets
BACKGROUND_PLT = 0x0 
SPRITE_PLT = 0x10 

#ATTRIBUTE LOCATION SHIFTS
TOPLEFT = 0 
TOPRIGHT = 2
BOTTOMLEFT = 4
BOTTOMRIGHT = 6

# Number of sprite info in OAM
OAM_SPRITES = 64
Y_OFF = 0
TILE_IDX_OFF = 1
ATTR_OFF = 2
X_OFF = 3

OAM_PRIO = 5
OAM_FLIP_HOR = 6
OAM_FLIP_VER = 7

BYTES_PER_SPRITE = 4

SECOND_OAM_LEN = 8


# Enable Sprites
SPRITES_EN = False


#NES Palettes
PALETTE = [
[(84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),     (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0), (0,0,0)],
[(152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32 ),  (120,60,0),    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0), (0,0,0)],
[(236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),  (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0), (0,0,0)],
[(236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144), (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0), (0,0,0)]
]
def parseMemoryFile(filename):
    global SPRITES_EN
    with open(filename) as f:
        vram_raw = f.readline().strip().split(" ")
        palette_raw = f.readline().strip().split(" ")
        oam_raw = f.readline().strip().split(" ")

        vram = list(map(lambda x: int(x, 16), vram_raw))
        palette = list(map(lambda x: int(x, 16), palette_raw))
        oam = []
        if(len(oam_raw) == 256):
            oam = list(map(lambda x: int(x, 16), oam_raw))
            SPRITES_EN = True

        assert(len(vram) == 12288)
        assert(len(palette) == 32)


        return vram, palette, oam

def getIthBit(i, num):
    return (num>>i)&1

def getAttributeShift(row, col):
    if row < BLOCK_H//2 and col < BLOCK_W//2:
        return TOPLEFT
    elif row < BLOCK_H//2 and col >= BLOCK_W//2:
        return TOPRIGHT
    elif row >= BLOCK_H//2 and col < BLOCK_W//2:
        return BOTTOMLEFT
    elif row >= BLOCK_H//2 and col >= BLOCK_W//2:
        return BOTTOMRIGHT

def getTileColor(tile_idx, tile_row, tile_col, vram, patterntbl_off, flip_ver, flip_hor):
    if(flip_ver):
        tile_row = TILE_H - 1 - tile_row
    if(flip_hor):
        tile_col = TILE_W - 1 - tile_col

    # Access Pattern table
    tile_lsb = vram[patterntbl_off + tile_idx*CHR_SIZE + tile_row]
    tile_msb = vram[patterntbl_off + tile_idx*CHR_SIZE + tile_row + CHR_SIZE//2]
    
    color = (getIthBit(TILE_W-tile_col-1, tile_msb)<<1) | getIthBit(TILE_W-tile_col-1, tile_lsb)

    return color

def getPaletteColor(palette_ram, palette_idx):
    palette_color = palette_ram[palette_idx]

    palette_color_hi = (palette_color >> 4) & 0xf
    palette_color_lo = palette_color & 0xf
    return PALETTE[palette_color_hi][palette_color_lo]

def createBackgroundPixel(row, col, vram, palette_ram, nametbl_off, patterntbl_off):
    nametbl_row = row // TILE_H
    nametbl_col = col // TILE_W
    attrtbl_row = row // BLOCK_H
    attrtbl_col = col // BLOCK_W

    tile_row = row % TILE_H
    tile_col = col % TILE_W
    block_row = row % BLOCK_H
    block_col = col % BLOCK_W

    # Access Nametable
    nametbl_idx = NAMETABLE_W*nametbl_row + nametbl_col
    tile_idx = vram[nametbl_off + nametbl_idx]

    # Access Attribute table
    attrtbl_idx = ATTRIBUTE_TBL_W*attrtbl_row + attrtbl_col
    attribute_block = vram[nametbl_off + ATTRIBUTE_TBL_OFF + attrtbl_idx]
    shift = getAttributeShift(block_row, block_col)
    palette_idx = 0x3 & (attribute_block >> shift)

    # Access Pattern table
    color_idx = getTileColor(tile_idx, tile_row, tile_col, vram, patterntbl_off, False, False)

    bg_color_idx = (palette_idx<<2) | color_idx
    if (bg_color_idx == 0x04 or bg_color_idx == 0x08 or bg_color_idx == 0x0c):
        bg_color_idx = 0x00

    color = getPaletteColor(palette_ram, BACKGROUND_PLT + bg_color_idx)
    return color, color_idx
    

def createSpritePixel(row, col, vram, palette_ram, oam, sprite_idxs, patterntbl_off):
    for i in sprite_idxs:
        sprite_y = oam[i + Y_OFF]
        tile_idx = oam[i + TILE_IDX_OFF]
        attr = oam[i + ATTR_OFF]
        sprite_x = oam[i + X_OFF]

        palette_idx = (attr & 0x3)
        priority = ((attr >> OAM_PRIO) & 0x1)
        flip_hor = ((attr >> OAM_FLIP_HOR) & 0x1) == 1
        flip_ver = ((attr >> OAM_FLIP_VER) & 0x1) == 1 

        if(sprite_x <= col and col < sprite_x + TILE_W):
            tile_row = row - sprite_y
            tile_col = col - sprite_x

            color_idx = getTileColor(tile_idx, tile_row, tile_col, vram, patterntbl_off, flip_ver, flip_hor)

            sp_color_idx = (palette_idx << 2) | color_idx
            
            color = getPaletteColor(palette_ram, SPRITE_PLT + sp_color_idx)

            return color, color_idx, priority
    return 0,0,0

# return indexes of active sprites on next scanline
def getSpritesInLine(row, oam):
    idxs = []
    for i in range(0, BYTES_PER_SPRITE*OAM_SPRITES, BYTES_PER_SPRITE):
        sprite_y = oam[i + Y_OFF]
        if(len(idxs) < SECOND_OAM_LEN and (sprite_y <= row and row < sprite_y + TILE_H)):
            idxs.append(i)
    return idxs

def mergeBackgroundSprites(bg_color, bg_color_idx, sp_color, sp_color_idx, sp_prio):
    if(bg_color_idx == 0 and sp_color_idx == 0):
        return bg_color
    elif(bg_color_idx == 0 and sp_color_idx > 0):
        return sp_color
    elif(bg_color_idx > 0 and sp_color_idx == 0):
        return bg_color
    elif(bg_color_idx > 0 and sp_color_idx > 0 and sp_prio == 0):
        return sp_color
    elif(bg_color_idx > 0 and sp_color_idx > 0 and sp_prio == 1):
        return bg_color



def createBitmap(vram, palette_ram, oam):
    bitmap = [[0 for j in range(WIDTH)] for i in range(HEIGHT)]

    for row in range(HEIGHT):
        sprite_idxs = []
        if SPRITES_EN:
            sprite_idxs = getSpritesInLine(row, oam)
        for col in range(WIDTH):
            if SPRITES_EN:
                bg_color, bg_color_idx = createBackgroundPixel(row, col, vram, palette_ram, NAMETABLE_0, PATTERN_TBL_1)
                sp_color, sp_color_idx, sp_prio = createSpritePixel(row, col, vram, palette_ram, oam, sprite_idxs, PATTERN_TBL_0)
                bitmap[row][col] = mergeBackgroundSprites(bg_color, bg_color_idx, sp_color, sp_color_idx, sp_prio)
            else:
                bg_color, bg_color_idx = createBackgroundPixel(row, col, vram, palette_ram, NAMETABLE_0, PATTERN_TBL_1)
                bitmap[row][col] = bg_color
    return bitmap

def createImage(bitmap):
    w, h = len(bitmap[0]), len(bitmap)
    data = np.zeros((h, w, 3), dtype=np.uint8)
    for row in range(h):
        for col in range(w):
            data[row][col] = bitmap[row][col]
    img = Image.fromarray(data, 'RGB')
    img.save('my.png')

def main():
    filename = sys.argv[1]
    vram, palette_ram, oam = parseMemoryFile(filename)
    bitmap = createBitmap(vram, palette_ram, oam)
    createImage(bitmap)

if __name__ == '__main__':
    main()