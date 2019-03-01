from PIL import Image
import numpy as np

## library with useful functions for rendering frames

# parses ppu memory returns arrays corresponding to :
# Pattern table 0x0-0x1fff
# Nametable 0x2000-0x27ff
# Palette ram 0x3f00-0x3f1f

PATTBL_STR = 0x0
PATTBL_END = 0x2000 

NAMETBL_STR = 0x2000
NAMETBL_END = 0x3000

PAL_STR = 0x3f00
PAL_END = 0x3f20

#NES Palettes
PALETTE = [
[(84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),     (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0), (0,0,0)],
[(152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32 ),  (120,60,0),    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0), (0,0,0)],
[(236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),  (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0), (0,0,0)],
[(236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144), (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0), (0,0,0)]
]

## palette functions

def getPaletteRGB(pal_color_idx):
    palette_color_hi = (pal_color_idx >> 4) & 0xf
    palette_color_lo = pal_color_idx & 0xf
    return PALETTE[palette_color_hi][palette_color_lo]



### memory functions 

# assumes filename is structured as follows:
# line 1 - entire ppu memory (one line)
# line 2 - palette ram
# line 3 - oam 
# assumes spaces between memory entries
# returns  pattern_table (0x0000-0x1fff)
#          nametable (0x2000-0x2fff)
#          pal_ram (0x3f00-0x3f1f)
#          oam
# entries in return lists are strings.
def parseMemoryFile(filename):
    with open(filename, "r") as f:
        ppu_mem = f.readline().strip().split(" ")
        pal = f.readline().strip().split(" ")
        oam = f.readline().strip().split(" ")

        return ppu_mem[PATTBL_STR:PATTBL_END], ppu_mem[NAMETBL_STR:NAMETBL_END], pal, oam


# follows format needed for .hex files, however can change layout with end_chr
def dumpMemory(filename, mem, end_chr = "\n"):
    with open(filename, "w") as f:
        for i in range(len(mem)):
            f.write(mem[i] + end_chr)


## image functions

def createImage(filename, bitmap):
    w, h = len(bitmap[0]), len(bitmap)
    data = np.zeros((h, w, 3), dtype=np.uint8)
    for row in range(h):
        for col in range(w):
            data[row][col] = bitmap[row][col]
    img = Image.fromarray(data, 'RGB')
    img.save(filename)

