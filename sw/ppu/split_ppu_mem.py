import sys
import trace_lib

# Takes a PPU memory trace 

PATTBL_FILE = "init/chr_rom_init.txt"
NAMETBL_FILE = "init/vram_init.txt"
PAL_FILE = "init/pal_init.txt"
OAM_FILE = "init/oam_init.txt"

def split(filename, pattbl_fl, nametbl_fl, pal_fl, oam_fl):
    pattbl, nametbl, pal, oam = trace_lib.parseMemoryFile(filename)
    vram = nametbl[0:0x800]  # only first two nametables

    trace_lib.dumpMemory(pattbl_fl, pattbl)
    trace_lib.dumpMemory(nametbl_fl, vram)
    trace_lib.dumpMemory(pal_fl, pal)
    trace_lib.dumpMemory(oam_fl, oam)

def main():
    filename = sys.argv[1]
    split(filename, PATTBL_FILE, NAMETBL_FILE, PAL_FILE, OAM_FILE)
    

if __name__ == '__main__':
    main()