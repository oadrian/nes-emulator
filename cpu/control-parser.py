'''
    This tool will help produce important files for the c and sv
    implementations of our 6502 processor.

    Nikolai Lenney

'''

csv_dir = "control-csv"
instr_ctrl_signals_file = "instr_ctrl_signals.csv"
addr_mode_ucode_file = "addr_mode_ucode.csv"
opcode_mapping_file = "opcode_mappings.csv"
instr_mem_type_file = "instr_mem_type.csv"
decode_ctrl_signals_files = "decode_ctrl_signals.csv"

instr_ctrl_signals_struct_name = "instr_ctrl_signals"
addr_mode_ucode_struct_name = "ucode_ctrl_signals"

template_dir = "templates"

c_template_file = "ucode_ctrl_template.txt"

c_target_file = "ucode_ctrl.c"


#ALUOUTDST,ALU1SRC,ALU2SRC,ALU2INV,ALUCINSRC,ALUOP,ZEROSRC,NEGSRC,CARSRC,OVRSRC,INTSRC,BRKSRC,DECSRC,BRANCHBIT,BRANCHINV,STORE
class instr_ctrl_vector(object):
    def __init__(self, row):
        self.init_alu_signals(row[:6])
        self.init_status_signals(row[6:13])
        self.init_misc_signals(row[13:])

    def init_alu_signals(self, alu_row):
        if alu_row[0] == "":
            self.alu_out_dst = "none"
        else:
            self.alu_out_dst = alu_row[0]
        if alu_row[1] == "":
            self.alu_src1 = "A"
        else:
            self.alu_src1 = alu_row[1]
        if alu_row[2] == "":
            self.alu_src2 = "0"
        else:
            self.alu_src2 = alu_row[2]
        if alu_row[3] == "":
            self.invert_src2 = "0"
        else:
            self.invert_src2 = alu_row[3]
        if alu_row[4] == "":
            self.alu_c_in = "0"
        else:
            self.alu_c_in = alu_row[4]
        if alu_row[5] == "":
            self.alu_op = "hold"
        else:
            self.alu_op = alu_ops_to_str(alu_row[5])

    def init_status_signals(self, flag_row):
        if flag_row[0] == "":
            self.zero_src = "none"
        else:
            self.zero_src = flag_row[0]
        if flag_row[1] == "":
            self.negative_src = "none"
        else:
            self.negative_src = flag_row[1]
        if flag_row[2] == "":
            self.carry_src = "none"
        else:
            self.carry_src = flag_row[2]
        if flag_row[3] == "":
            self.overflow_src = "none"
        else:
            self.overflow_src = flag_row[3]
        if flag_row[4] == "":
            self.interrupt_src = "none"
        else:
            self.interrupt_src = flag_row[4]
        if flag_row[5] == "":
            self.break_src = "none"
        else:
            self.break_src = flag_row[5]
        if flag_row[6] == "":
            self.decimal_src = "none"
        else:
            self.decimal_src = flag_row[6]

    def init_misc_signals(self, misc_row):
        if misc_row[0] == "":
            self.branch_bit = "C"
        else:
            self.branch_bit = misc_row[0]
        if misc_row[1] == "":
            self.branch_inv = "0"
        else:
            self.branch_inv = misc_row[1]
        if misc_row[2] == "":
            self.store_tgt = "A"
        else:
            self.store_tgt = misc_row[2]

    def get_flags(self):
        return [self.negative_src, self.overflow_src, self.break_src,
                self.decimal_src, self.interrupt_src, self.zero_src,
                self.carry_src]

    def vector_to_c_struct(self):
        res = "{"
        res += "ALUOP_%s, " % self.alu_op
        res += "ALUDST_%s, " % self.alu_out_dst
        res += "SRC1_%s, " % self.alu_src1
        res += "SRC2_%s, " % self.alu_src2
        res += "Invert_%s, " % self.invert_src2
        res += "ALUC_%s, " % self.alu_c_in
        for flag_str in self.get_flags():
            res += "flag_%s, " % flag_str
        res += "Branch_%s, " % self.branch_bit
        res += "Invert_%s, " % self.branch_inv
        res += "Store_%s" %  self.store_tgt
        return res + "}"

    def __repr__(self):
        return self.vector_to_c_struct()

# ADDRLOSRC,ADDRHISRC,R/W,WMEMSRC,   ALU1SRC,ALU2SRC,ALU2INV,ALUCINSRC,ALUOP,   SPSRC,PCLOSRC,PCHISRC,Status,   INCPC,OPCODECTRL,STARTFETCH,STARTDECODE,CSKIP,Stop uCode
class ucode_vector(object):
    def __init__(self, fields):
        self.init_mem_signals(fields[:4])
        self.init_alu_signals(fields[4:9])
        self.init_write_reg_signals(fields[9:13])
        self.init_cpu_ctrl_signals(fields[13:])

    def init_mem_signals(self, mem_row):
        if mem_row[0] == "":
            self.addr_lo = "hold"
        else:
            self.addr_lo = mem_row[0]
        if mem_row[1] == "":
            self.addr_hi = "hold"
        else:
            self.addr_hi = mem_row[1]
        if mem_row[2] == "":
            self.read_en = "none"
        else:
            self.read_en = mem_row[2]
        if mem_row[3] == "":
            self.wmem_src = "PCHI"
        else:
            self.wmem_src = mem_row[3]

    def init_alu_signals(self, alu_row):
        if alu_row[0] == "":
            self.alu_src1 = "A"
        else:
            self.alu_src1 = alu_row[0]
        if alu_row[1] == "":
            self.alu_src2 = "0"
        else:
            self.alu_src2 = alu_row[1]
        if alu_row[2] == "":
            self.invert_src2 = "0"
        else:
            self.invert_src2 = alu_row[2]
        if alu_row[3] == "":
            self.alu_c_in = "0"
        else:
            self.alu_c_in = alu_row[3]
        if alu_row[4] == "":
            self.alu_op = "hold"
        else:
            self.alu_op = alu_ops_to_str(alu_row[4])

    def init_write_reg_signals(self, write_reg_row):
        if write_reg_row[0] == "":
            self.write_sp = "none"
        else:
            self.write_sp = write_reg_row[0]
        if write_reg_row[1] == "":
            self.write_pclo = "none"
        else:
            self.write_pclo = write_reg_row[1]
        if write_reg_row[2] == "":
            self.write_pchi = "none"
        else:
            self.write_pchi = write_reg_row[2]
        if write_reg_row[3] == "":
            self.write_status = "none"
        else:
            self.write_status = write_reg_row[3]

    def init_cpu_ctrl_signals(self, cpu_ctrl_row):
        if cpu_ctrl_row[0] == "":
            self.inc_pc = "0"
        else:
            self.inc_pc = cpu_ctrl_row[0]
        if cpu_ctrl_row[1] == "":
            self.instr_ctrl = "0"
        else:
            self.instr_ctrl = cpu_ctrl_row[1]
        if cpu_ctrl_row[2] == "":
            self.start_fetch = "0"
        else:
            self.start_fetch = cpu_ctrl_row[2]
        if cpu_ctrl_row[3] == "":
            self.start_decode = "0"
        else:
            self.start_decode = cpu_ctrl_row[3]
        if cpu_ctrl_row[4] == "":
            self.carry_skip = "0"
        else:
            self.carry_skip = cpu_ctrl_row[4]
        if cpu_ctrl_row[5] == "":
            self.stop_ucode = "0"
        else:
            self.stop_ucode = cpu_ctrl_row[5]

    def vector_to_c_struct(self):
        res = "{"
        res += "ADDRLO_%s, " % self.addr_lo
        res += "ADDRHI_%s, " % self.addr_hi
        res += "ReadEn_%s, " % self.read_en
        res += "WMEMSRC_%s, " % self.wmem_src
        res += "SRC1_%s, " % self.alu_src1
        res += "SRC2_%s, " % self.alu_src2
        res += "Invert_%s, " % self.invert_src2
        res += "ALUC_%s, " % self.alu_c_in
        res += "ALUOP_%s, " % self.alu_op
        res += "SPSRC_%s, " % self.write_sp
        res += "PCLO_%s, " % self.write_pclo
        res += "PCHI_%s, " % self.write_pchi
        res += "Status_SRC_%s, " % self.write_status
        res += "Branch_Depend_%s, " % self.inc_pc
        res += "INSTR_CTRL_%s, " % self.instr_ctrl
        res += "Enable_%s, " % self.start_fetch
        res += "Branch_Depend_%s, " % self.start_decode
        res += "Enable_%s, " % self.carry_skip
        res += "Branch_Depend_%s" % self.stop_ucode
        return res + "}"

    def __repr__(self):
        return self.vector_to_c_struct()

class decode_ctrl_signal_vector(object):
    def __init__(self, row):
        if row[0] == "":
            self.inc_pc = "0"
        else:
            self.inc_pc = row[0]
        if row[1] == "":
            self.start_fetch = "0"
        else:
            self.start_fetch = row[1]

    def to_packed_int(self):
        res = 0
        # lowest bit is inc_pc
        res += 1 * int(self.inc_pc)
        # next lowest bit is begin fetch
        res += 2 * int(self.start_fetch)
        return res


default_instr_ctrl_vector = instr_ctrl_vector([""]*16)

default_ucode_vector = ucode_vector([""]*18+["1"])

default_decode_ctrl_signal_vector = decode_ctrl_signal_vector([""]*2)

def alu_ops_to_str(op):
    alu_op_dict = {"+" : "add", "^" : "xor", "&" : "and", "|" : "or",
                   ">>" : "right_shift", "<<" : "left_shift"}
    return alu_op_dict[op]

# these two functions were taken from CMU 15-112 website
# https://www.cs.cmu.edu/~112/notes/notes-strings.html#basicFileIO
def readFile(path):
    with open(path, "rt") as f:
        return f.read()

def writeFile(path, contents):
    with open(path, "wt") as f:
        f.write(contents)

# takes in a string which is the raw output of reading a csv
def csv_to_2d_list(contents):
    res = []
    for line in contents.splitlines():
        row = line.split(',')
        res.append(row)
    return res

def pp_2d_list(L):
    print("[")
    for row in L:
        print(row, end=",\n")
    print("]")

def get_instr_ctrl_signals():
    path = "%s/%s" % (csv_dir, instr_ctrl_signals_file)
    contents = readFile(path)
    instr_ctrl_signals_list = csv_to_2d_list(contents)
    # remove the header row
    instr_ctrl_signals_list.pop(0)
    
    instr_indices = dict()
    instr_ctrl_signals = [default_instr_ctrl_vector]
    for row in instr_ctrl_signals_list:
        instr = row[0]
        # skip the second field sinse it is just describes the instr
        fields = row[2:]
        instr_indices[instr] = len(instr_ctrl_signals)
        instr_ctrl_signals.append(instr_ctrl_vector(fields))

    return instr_indices, instr_ctrl_signals


def get_ucode():
    path = "%s/%s" % (csv_dir, addr_mode_ucode_file)
    contents = readFile(path)
    ucode_csv_list = csv_to_2d_list(contents)
    # remove the header row
    ucode_csv_list.pop(0)

    ucode_indices = dict()
    ucode_rom = [default_ucode_vector]

    for row in ucode_csv_list:
        addr_mode = row[0]
        if addr_mode != "":
            ucode_indices[addr_mode] = len(ucode_rom)
        fields = row[1:]
        ucode_rom.append(ucode_vector(fields))

    return ucode_indices, ucode_rom


def get_instr_to_mem_type_dict():
    path = "%s/%s" % (csv_dir, instr_mem_type_file)
    contents = readFile(path)
    instr_mem_type_list = csv_to_2d_list(contents)
    instr_mem_type_list.pop(0)

    res = dict()

    for row in instr_mem_type_list:
        res[row[0]] = row[1]

    return res

def get_opcode_dicts():
    instr_mem_type_dict = get_instr_to_mem_type_dict()
    path = "%s/%s" % (csv_dir, opcode_mapping_file)
    contents = readFile(path)
    opcode_mappings = csv_to_2d_list(contents)
    opcode_mappings.pop(0)

    instr_dict = dict()
    addr_mode_dict = dict()

    for row in opcode_mappings:
        opcode = row[2]
        instr = row[0]
        if row[1] != "IMM" and instr in instr_mem_type_dict:
            addr_mode = row[1] + instr_mem_type_dict[instr]
        else:
            addr_mode = row[1]

        instr_dict[opcode] = instr
        addr_mode_dict[opcode] = addr_mode

    return instr_dict, addr_mode_dict

def get_opcode_to_decode_ctrl_signals(opcode_to_addr_mode):
    path = "%s/%s" % (csv_dir, decode_ctrl_signals_files)
    contents = readFile(path)
    decode_ctrl_signals_list = csv_to_2d_list(contents)
    decode_ctrl_signals_list.pop(0)

    addr_mode_to_decode_ctrl_signals_dict = dict()
    for row in decode_ctrl_signals_list:
        addr_mode = row[0]
        decode_ctrl_signals = decode_ctrl_signal_vector(row[1:])
        addr_mode_to_decode_ctrl_signals_dict[addr_mode] = decode_ctrl_signals

    opcode_to_decode_ctrl_signals = dict()
    for opcode in opcode_to_addr_mode:
        addr_mode = opcode_to_addr_mode[opcode]
        decode_ctrl_signals = addr_mode_to_decode_ctrl_signals_dict[addr_mode]
        opcode_to_decode_ctrl_signals[opcode] = decode_ctrl_signals

    return opcode_to_decode_ctrl_signals

def get_c_struct_array(struct_name, vector_list):
    res = "%s %s_rom[] = {\n" % (struct_name, struct_name)
    for vector in vector_list:
        res += "  %s,\n" % str(vector)
    return res + "}\n"

def get_hex_byte(i):
    hex_chrs = "0123456789ABCDEF"
    i %= 256
    upper_nibble, lower_nibble = i//16, i % 16
    return "0x%s%s" % (hex_chrs[upper_nibble], hex_chrs[lower_nibble])

def get_c_indices_array(struct_name, opcode_dict, index_dict):
    res = "uint8_t %s_indices[] = {\n  " % (struct_name)
    ct = 0

    for i in range(256):
        hex_i = get_hex_byte(i)
        if hex_i in opcode_dict:
            target_value = opcode_dict[hex_i]
            if target_value in index_dict:
                index = index_dict[target_value]
            else:
                index = 0
        else:
            index = 0

        if ct == 15:
            res += "%3d,\n  " % index
            ct = 0
        else:
            res += "%3d, " % index
            ct += 1

    return res + "}\n"

def get_c_decode_ctrl_signals_array(opcode_to_decode_ctrl_signals):
    res = "uint8_t decode_ctrl_signals_rom[] = {\n  "
    ct = 0

    for i in range(256):
        hex_i = get_hex_byte(i)
        if hex_i in opcode_to_decode_ctrl_signals:
            decode_ctrl_signals_byte = opcode_to_decode_ctrl_signals[hex_i].to_packed_int()
        else:
            decode_ctrl_signals_byte = default_decode_ctrl_signal_vector.to_packed_int()

        if ct == 15:
            res += "%d,\n  " % decode_ctrl_signals_byte
            ct = 0
        else:
            res += "%d, " % decode_ctrl_signals_byte
            ct += 1

    return res + "}\n"

def write_c_code(new_c_code):
    read_path = "%s/%s" % (template_dir, c_template_file)
    read_contents = readFile(read_path)
    write_contents = read_contents + new_c_code

    write_path = c_target_file
    writeFile(write_path, write_contents)


def main():
    instr_indices, instr_ctrl_signals = get_instr_ctrl_signals()
    #print(instr_ctrl_signals)
    ucode_indices, ucode_rom = get_ucode()
    opcode_to_instr, opcode_to_addr_mode = get_opcode_dicts()
    opcode_to_decode_ctrl_signals = get_opcode_to_decode_ctrl_signals(opcode_to_addr_mode)

    instr_ctrl_signals_vector_array = get_c_struct_array(instr_ctrl_signals_struct_name, instr_ctrl_signals)
    ucode_vector_array = get_c_struct_array(addr_mode_ucode_struct_name, ucode_rom)

    instr_ctrl_signals_indices_array = get_c_indices_array(instr_ctrl_signals_struct_name, opcode_to_instr, instr_indices)
    ucode_indices_array = get_c_indices_array(addr_mode_ucode_struct_name, opcode_to_addr_mode, ucode_indices)
    decode_ctrl_signals_array = get_c_decode_ctrl_signals_array(opcode_to_decode_ctrl_signals)

    # how to write to another file? will need to put the structs and enums in their own file?
    new_c_code = "\n\n%s\n%s\n%s\n%s\n%s" % (instr_ctrl_signals_indices_array, instr_ctrl_signals_vector_array, 
                                           ucode_indices_array, ucode_vector_array, 
                                           decode_ctrl_signals_array)
    write_c_code(new_c_code)

main()