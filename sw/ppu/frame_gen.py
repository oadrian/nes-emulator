import sys
from PIL import Image
import numpy as np

# creates a png from a frame data in a text file

#NES Palettes
PALETTE = [
[(84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),     (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0), (0,0,0)],
[(152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32 ),  (120,60,0),    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0), (0,0,0)],
[(236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),  (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0), (0,0,0)],
[(236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144), (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0), (0,0,0)]
]

def getPaletteColor(palette_color):
	palette_color_hi = (palette_color >> 4) & 0xf
	palette_color_lo = palette_color & 0xf
	return PALETTE[palette_color_hi][palette_color_lo]

def parseMemoryFile(filename):
	with open(filename, "r") as f:
		bitmap = []
		for line in f:
			scanline_raw = line.strip().split(" ")

			sl_rgb = list(map(lambda x: getPaletteColor(int(x)), scanline_raw))
		
			bitmap.append(sl_rgb)
		return bitmap
		
            
def createImage(filename, bitmap):
    w, h = len(bitmap[0]), len(bitmap)
    data = np.zeros((h, w, 3), dtype=np.uint8)
    for row in range(h):
        for col in range(w):
            data[row][col] = bitmap[row][col]
    img = Image.fromarray(data, 'RGB')
    img.save(filename)


def main():
    data_file = sys.argv[1]
    pic_file = sys.argv[2]
    
    bitmap = parseMemoryFile(data_file)
    
    createImage(pic_file, bitmap)
    
    

if __name__ == '__main__':
    main()
