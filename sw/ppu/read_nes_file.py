import sys
import trace_lib as lib
import text2bin
import subprocess
import split_ppu_mem as splitter

PRGROM_TXT = "prg_rom_init.txt"
PRGROM_BIN = "prg_rom_init.bin"
PRGROM_HEX = "cpu/init-intel/prg_rom_init.hex"

CHRROM_TXT = "chr_rom_init.txt"
CHRROM_BIN = "chr_rom_init.bin"
CHRROM_HEX = "ppu/init-intel/chr_rom_init.hex"


def getIthBit(i, num):
    return (num>>i)&1

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

def writeTXT(filename, prgrom):
    mem = []
    for c in prgrom:
        to_hex = hex(ord(c))
        to_hex = to_hex[2:]
        if(len(to_hex) == 1):
            to_hex = "0"+to_hex
        mem.append(to_hex)
    lib.dumpMemory(filename, mem)

def readNES(filename):
    with open(filename, "rb") as f:
        header = f.read(16)
        prgrom_sz, chrrom_sz, vertical_mirror, bit_trainer = interpretHeader(header)
        if(bit_trainer):
            trainer =  f.read(512)
        prgrom = f.read(16384*prgrom_sz)
        chrrom = f.read(8192*chrrom_sz)

        writeTXT(PRGROM_TXT, prgrom)
        writeTXT(CHRROM_TXT, chrrom)

        if(sys.platform == 'linux2'):
            text2bin.write2file(PRGROM_BIN, prgrom)
            text2bin.write2file(CHRROM_BIN, chrrom)
            subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", PRGROM_BIN, PRGROM_HEX])
            subprocess.call(["objcopy", "--input-target=binary", "--output-target=ihex", CHRROM_BIN, CHRROM_HEX])

            subprocess.call(["rm", PRGROM_BIN])
            subprocess.call(["rm", CHRROM_BIN])
        elif(sys.platform == 'win32'):
            text2bin.write2file(PRGROM_BIN, prgrom)
            text2bin.write2file(CHRROM_BIN, chrrom)
            subprocess.call(["srec_cat", PRGROM_BIN, "-binary", "-output", PRGROM_HEX, "-Intel"])
            subprocess.call(["srec_cat", CHRROM_BIN, "-binary", "-output", CHRROM_HEX, "-Intel"])

            subprocess.call(["rm", PRGROM_BIN])
            subprocess.call(["rm", CHRROM_BIN])



            

def main():
    filename = sys.argv[1]

    readNES(filename)


if __name__ == '__main__':
    main()
