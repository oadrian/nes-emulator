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

#NES Palette (FROM NES Wiki) 
# PALETTE = [
# [(84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),     (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0), (0,0,0)],
# [(152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32 ),  (120,60,0),    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0), (0,0,0)],
# [(236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),  (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0), (0,0,0)],
# [(236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144), (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0), (0,0,0)]
# ]

#NES Palette (FROM Mesen Emulator)
PALETTE = [
[(102,102,102),    (0,42,136),    (20,18,167),    (59,0,164),    (92,0,126),    (100,0,64),     (108,6,0),      (86,29,0),     (51,53,0),     (11,72,0),      (0,82,0),      (0,79,8),      (0,64,77),     (0,0,0),       (0,0,0), (0,0,0)],
[(173,173,173),    (21,95,217),   (66,64,255),    (117,39,254),  (160,26,204),  (183,30,123),   (181,49,32 ),   (153,78,0),    (107,109,0),   (56,135,0),     (12,147,0),    (0,143,50),    (0,124,141),   (0,0,0),       (0,0,0), (0,0,0)],
[(255,254,255),    (100,176,255), (146,144,255),  (198,118,255), (243,106,255), (254,110,204),  (254,129,112),  (234,158,34),  (188,190,0),   (136,216,0),    (92,228,48),   (69,224,130),  (72,205,222),  (79,79,79),    (0,0,0), (0,0,0)],
[(255,254,255),    (192,223,255), (211,210,255),  (232,200,255), (251,194,255), (254,196,234),  (254,204,197),  (247,216,165), (228,229,148), (207,239,150),  (189,244,171), (179,243,204), (181,235,242), (184,184,184), (0,0,0), (0,0,0)]
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

