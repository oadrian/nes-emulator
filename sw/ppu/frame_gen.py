import sys
import trace_lib

# creates a png from a frame data in a text file


def createBitmap(filename):
	with open(filename, "r") as f:
		bitmap = []
		for line in f:
			scanline_raw = line.strip().split(" ")

			sl_rgb = list(map(lambda x: trace_lib.getPaletteRGB(int(x, 16)), scanline_raw))
		
			bitmap.append(sl_rgb)
		return bitmap

def main():
    data_file = sys.argv[1]
    pic_file = sys.argv[2]
    bitmap = createBitmap(data_file)
    trace_lib.createImage(pic_file, bitmap)
    
    

if __name__ == '__main__':
    main()
