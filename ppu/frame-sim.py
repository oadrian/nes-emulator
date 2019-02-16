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
PATTERN_TBL_0 = int("0", 16)
PATTERN_TBL_1 = int("1000", 16)
PATTERN_TBL_SZ = int("1000", 16)

NAMETABLE_0 = int("2000", 16)
NAMETABLE_1 = int("2400", 16)
NAMETABLE_2 = int("2800", 16)
NAMETABLE_3 = int("2C00", 16)
NAMETABLE_SZ = int("400", 16)

ATTRIBUTE_TBL_OFF = int("3C0", 16) #offset off nametable base address
ATTRIBUTE_TBL_SZ = int("40", 16) 

#Pallette ram offsets
BACKGROUND_PLT = int("0", 16)
SPRITE_PLT = int("10", 16)

#ATTRIBUTE LOCATION SHIFTS
TOPLEFT = 0 
TOPRIGHT = 2
BOTTOMLEFT = 4
BOTTOMRIGHT = 6

#NES Palettes
PALETTE = [
[(84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),     (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0), (0,0,0)],
[(152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32 ),  (120,60,0),    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0), (0,0,0)],
[(236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),  (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0), (0,0,0)],
[(236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144), (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0), (0,0,0)]
]
def parseMemoryFile(filename):
    with open(filename) as f:
        vram_raw = f.readline().strip().split(" ")
        palette_raw = f.readline().strip().split(" ")

        vram = list(map(lambda x: int(x, 16), vram_raw))
        palette = list(map(lambda x: int(x, 16), palette_raw))

        assert(len(vram) == 12288)
        assert(len(palette) == 32)


        return vram, palette

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

def createPixel(row, col, vram, palette_tbl, nametbl_off, patterntbl_off):
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
    attribute = 3 & (attribute_block >> shift)

    # Access Pattern table
    tile_lsb = vram[patterntbl_off + tile_idx*CHR_SIZE + tile_row]
    tile_msb = vram[patterntbl_off + tile_idx*CHR_SIZE + tile_row + CHR_SIZE//2]
    
    color = (getIthBit(TILE_W-tile_col, tile_msb)<<1) | getIthBit(TILE_W-tile_col, tile_lsb)

    bg_pallete_idx = (attribute<<2) | color
    palette_color = palette_tbl[BACKGROUND_PLT + bg_pallete_idx]

    palette_color_hi = (palette_color >> 4) & 15
    palette_color_lo = palette_color & 15
    return PALETTE[palette_color_hi][palette_color_lo]


def createBitmap(vram, palette, nametbl_off, patterntbl_off):
    bitmap = [[0 for j in range(WIDTH)] for i in range(HEIGHT)]

    for row in range(HEIGHT):
        for col in range(WIDTH):
            bitmap[row][col] = createPixel(row, col, vram, palette, nametbl_off, patterntbl_off)

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
    vram, palette_ram = parseMemoryFile(filename)
    bitmap = createBitmap(vram, palette_ram, NAMETABLE_0, PATTERN_TBL_1)
    createImage(bitmap)

if __name__ == '__main__':
    main()