import sys
import trace_lib

# Takes a PPU memory trace 

PATTBL_FILE = "init/chr_rom_init.hex"
NAMETBL_FILE = "init/vram_init.hex"
PAL_FILE = "init/pal_init.hex"
OAM_FILE = "init/oam_init.hex"

def main():
    filename = sys.argv[1]
    pattbl, nametbl, pal, oam = trace_lib.parseMemoryFile(filename)
    vram = nametbl[0:0x800]  # only first two nametables

    trace_lib.dumpMemory(PATTBL_FILE, pattbl)
    trace_lib.dumpMemory(NAMETBL_FILE, vram)
    trace_lib.dumpMemory(PAL_FILE, pal)
    trace_lib.dumpMemory(OAM_FILE, oam)

if __name__ == '__main__':
    main()