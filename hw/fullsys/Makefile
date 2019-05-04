# Target executable
TARGET = simv

# Source files
SRC := $(wildcard ../include/*.vh) \
	   $(wildcard ../ppu/*.sv) \
	   $(wildcard ../cpu/*.sv) \
	   $(wildcard ../save_state/*.sv) \
	   $(wildcard *.sv) 

SRC := $(filter-out ../ppu/top.sv, $(SRC))
SRC := $(filter-out ../cpu/top.sv, $(SRC))

# Set the number of threads to use for parallel compilation (2 * cores)
CORES = $(shell getconf _NPROCESSORS_ONLN)
THREADS = $(shell echo $$((2 * $(CORES))))

# VCS flags
VCSFLAGS = -full64 -sverilog -debug_all +lint=all +warn=all -j$(THREADS) \
					 -timescale=1ns/1ps +v2k +define+NO_SYNTH=0
COMMON_FLAGS +=

# Simulator
SIM = vcs

# Copy common flags
VCSFLAGS += $(COMMON_FLAGS)

vdc: 
	$(SIM) $(VCSFLAGS) $(INC_V_FLAGS) $(INC_SV_FLAGS) -o $(TARGET) $(SRC)

clean :
	-rm -r csrc
	-rm -r DVEfiles
	-rm $(TARGET)
	-rm -r $(TARGET).daidir
	-rm ucli.key
	-rm inter.vpd
