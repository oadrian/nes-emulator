

# parses ppu memory returns arrays corresponding to :
# Pattern table 0x0-0x1fff
# Nametable 0x2000-0x27ff
# Palette ram 0x3f00-0x3f1f

PATTBL_STR = 0x0
PATTBL_END = 0x2000 

NAMETBL_STR = 0x2000
NAMETBL_END = 0x2800

PAL_STR = 0x3f00
PAL_END = 0x3f20


def parseMemoryFile(filename):
	with open(filename, "r") as f:
        ppu_mem = f.readline().strip().split(" ")

        return ppu_mem[PATTBL_STR:PATTBL_END], ppu_mem[NAMETBL_STR:NAMETBL_END], ppu_mem[PAL_STR:PAL_END]



def dumpMemory(filename, mem):
    with open(filename, "w") as f:
        for i in range(len(mem)):
            f.write(mem[i] + "\n")

