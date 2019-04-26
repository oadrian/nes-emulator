import sys
import trace_lib
import text2bin
import subprocess

# Takes a PPU memory trace 

# text files
PATTBL_FILE = "../init/chr_rom_init.txt"
NAMETBL_FILE = "../init/vram_init.txt"
PAL_FILE = "../init/pal_init.txt"
OAM_FILE = "../init/oam_init.txt"

# bin files
PATTBL_BIN = "../init-intel/chr_rom_init.bin"
NAMETBL_BIN = "../init-intel/vram_init.bin"
OAM_BIN = "../init-intel/oam_init.bin"

# hex files
PATTBL_HEX = "../init-intel/chr_rom_init.hex"
NAMETBL_HEX = "../init-intel/vram_init.hex"
OAM_HEX = "../init-intel/oam_init.hex"

def split(filename, pattbl_fl, nametbl_fl, pal_fl, oam_fl):
    pattbl, nametbl, pal, oam = trace_lib.parseMemoryFile(filename)
    vram = nametbl[0:0x800]  # only first two nametables

    trace_lib.dumpMemory(pattbl_fl, pattbl)
    trace_lib.dumpMemory(nametbl_fl, vram)
    trace_lib.dumpMemory(pal_fl, pal)
    trace_lib.dumpMemory(oam_fl, oam)

def split2hex(filename):
    pattbl_str = text2bin.text2bin(PATTBL_FILE)
    nametbl_str = text2bin.text2bin(NAMETBL_FILE)
    oam_str = text2bin.text2bin(OAM_FILE)

    text2bin.write2file(PATTBL_BIN, pattbl_str)
    text2bin.write2file(NAMETBL_BIN, nametbl_str)
    text2bin.write2file(OAM_BIN, oam_str)

    if(sys.platform == 'linux2'):
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", PATTBL_BIN, PATTBL_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", NAMETBL_BIN, NAMETBL_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", OAM_BIN, OAM_HEX])

        subprocess.call(["rm", PATTBL_BIN])
        subprocess.call(["rm", NAMETBL_BIN])
        subprocess.call(["rm", OAM_BIN])

    elif(sys.platform == 'win32'):
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", PATTBL_BIN, PATTBL_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", NAMETBL_BIN, NAMETBL_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", OAM_BIN, OAM_HEX])

        subprocess.call(["rm", PATTBL_BIN])
        subprocess.call(["rm", NAMETBL_BIN])
        subprocess.call(["rm", OAM_BIN])
    else:
        print("platform not recognized " + sys.platform)



def main():
    filename = sys.argv[1]
    split(filename, PATTBL_FILE, NAMETBL_FILE, PAL_FILE, OAM_FILE)
    split2hex(filename)
    

if __name__ == '__main__':
    main()