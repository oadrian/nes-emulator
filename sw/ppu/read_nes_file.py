import sys
import os
import trace_lib as lib
import text2bin
import subprocess
import split_ppu_mem as splitter

PRGROM_TXT = "init/prg_rom_init.txt"
PRGROM_BIN = "prg_rom_init.bin"
PRGROM_HEX = "init-intel/prg_rom_init.hex"

CHRROM_TXT = "init/chr_rom_init.txt"
CHRROM_BIN = "chr_rom_init.bin"
CHRROM_HEX = "init-intel/chr_rom_init.hex"

HEADER_TXT = "init/header_init.txt"
HEADER_BIN = "header_init.bin"
HEADER_HEX = "init-intel/header_init.hex"


SRAM_HEX = "init/sram_init.hex"
SRAM_GAME_ORDER_TXT = "init/game_order.txt"

SRAM_SIZE = 2097152  # 2 MB
SRAM_GAME_SECTION_SIZE = 65536 # 64 KB
SRAM_HEADER_SIZE = 32  # 32 B
SRAM_PRG_SIZE = 32768  # 32 KB
SRAM_CHR_SIZE = 8192   # 8 KB
SRAM_MAX_GAMES = SRAM_SIZE / SRAM_GAME_SECTION_SIZE


def getIthBit(i, num):
    return (num>>i)&1

def getRoms(roms_folder):
    roms = []
    for rom in os.listdir(roms_folder):
        if(rom.endswith(".nes")):
            roms.append(rom)
    return roms

def interpretHeader(header):
    nes = header[0:4]
    print(nes)
    prgrom_sz = ord(header[4])
    print("size of prg-rom: " + str(prgrom_sz) + "x 16KB")
    chrrom_sz = ord(header[5])
    print("size of chr-rom: " + str(chrrom_sz) + "x 8KB")
    flags_6 = ord(header[6])

    vertical_mirror = False
    if(getIthBit(0, flags_6)):
        print("vertical mirroring")
        vertical_mirror = True
    else:
        print("horizontal mirroring")
        vertical_mirror = False


    if(getIthBit(1, flags_6)):
        print("Cartridge contains battery-backed PRG RAM")
    else:
        print("Cartridge does not contain battery-backed PRG RAM")

    bit_trainer = False
    if(getIthBit(2, flags_6)):
        print("512-byte trainer")
        bit_trainer = True
    else:
        print("no 512-byte trainer")
        bit_trainer = False

    ignore_mc = False
    if(getIthBit(3, flags_6)):
        print("Ignore mirror control")
        ignore_mc = True
    else:
        print("Don't ignore mirror control")
        ignore_mc = False

    flags_7 = ord(header[7])
    flags_8 = ord(header[8])
    flags_9 = ord(header[9])
    flags_10 = ord(header[10])

    return prgrom_sz, chrrom_sz, vertical_mirror, bit_trainer

def writeTXT(filename, prgrom, endchr= "\n"):
    mem = []
    for c in prgrom:
        to_hex = hex(ord(c))
        to_hex = to_hex[2:]
        if(len(to_hex) == 1):
            to_hex = "0"+to_hex
        mem.append(to_hex)
    lib.dumpMemory(filename, mem, endchr)

def getSections(filename):
    with open(filename, "rb") as f:
        header = ""
        prgrom = ""
        chrrom = ""

        # GET HEADER
        header = 2*f.read(16)

        # Interpret HEADER
        prgrom_sz, chrrom_sz, vertical_mirror, bit_trainer = interpretHeader(header)

        if(bit_trainer):
            trainer =  f.read(512)
        
        # GET PRG ROM
        if(prgrom_sz == 1):
            # 16 KB - pad lower 16kb with ff
            prgrom = 2*f.read(16384*prgrom_sz)
        else:
            # 32 KB
            prgrom = f.read(16384*prgrom_sz)

        # GET CHR ROM
        if(chrrom_sz == 0):
            chrrom = '\x00'*8192
        else:   
            chrrom = f.read(8192*chrrom_sz)

        return header, prgrom, chrrom

def singleGame(filename):
    header, prgrom, chrrom = getSections(filename)

        
    writeTXT(HEADER_TXT, header)
    writeTXT(PRGROM_TXT, prgrom)
    writeTXT(CHRROM_TXT, chrrom)

    if(sys.platform == 'linux2'):
        text2bin.write2file(PRGROM_BIN, prgrom)
        text2bin.write2file(CHRROM_BIN, chrrom)
        text2bin.write2file(HEADER_BIN, header)
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", PRGROM_BIN, PRGROM_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", CHRROM_BIN, CHRROM_HEX])
        subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", HEADER_BIN, HEADER_HEX])
    elif(sys.platform == 'win32'):
        text2bin.write2file(PRGROM_BIN, prgrom)
        text2bin.write2file(CHRROM_BIN, chrrom)
        text2bin.write2file(HEADER_BIN, header)
        subprocess.call(["srec_cat", PRGROM_BIN, "-binary", "-output", PRGROM_HEX, "-Intel"])
        subprocess.call(["srec_cat", CHRROM_BIN, "-binary", "-output", CHRROM_HEX, "-Intel"])
        subprocess.call(["srec_cat", HEADER_BIN, "-binary", "-output", HEADER_HEX, "-Intel"])


def multipleGames(folder):
    roms =  getRoms(folder)
    if(len(roms) > SRAM_MAX_GAMES):
        roms = roms[:SRAM_MAX_GAMES]
    roms = roms[16:]
    sram_init = ""
    game_order = ""
    i = 0
    for rom in roms:
        game_order += str(i) + ".- "+ rom[:-4] + "\n"
        filename = folder + "/" + rom
        header, prgrom, chrrom = getSections(filename)
        assert(len(header) == SRAM_HEADER_SIZE)
        assert(len(prgrom) == SRAM_PRG_SIZE)
        assert(len(chrrom) == SRAM_CHR_SIZE)

        padding = SRAM_GAME_SECTION_SIZE - SRAM_HEADER_SIZE - SRAM_PRG_SIZE - SRAM_CHR_SIZE
        rom_init = header + prgrom + chrrom + padding*'\x00'

        assert(len(rom_init) == SRAM_GAME_SECTION_SIZE)

        sram_init += rom_init

        i+=1

    writeTXT(SRAM_HEX, sram_init, endchr = "")
    with open(SRAM_GAME_ORDER_TXT, "w") as f:
        f.write(game_order)

            

def main():
    path = sys.argv[1]
    sram_init = (sys.argv[2] == "-sram_init")

    if(sram_init):
        multipleGames(path)
    else:
        singleGame(path)


if __name__ == '__main__':
    main()
