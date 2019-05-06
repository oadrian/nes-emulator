import math

# from 15-112 website lol
def readFile(path):
    with open(path, "rt") as f:
        return f.read()

def writeFile(path, contents):
    with open(path, "wt") as f:
        f.write(contents)

csv_path = "save_state_bits.csv"
vh_path = "../include/save_state_defines.vh"

def get_signal_defines(text):
    signal_header = "SAVE_STATE"
    signal_list = []

    index = 0

    # skip header line
    lines = text.splitlines()[1:]

    for line in lines:
        # should be [blank, num bits, num addrs, signal_name, signal_area]
        entries = line.split(",")
        
        num_addrs = int(entries[2])
        fix_text = lambda s : s.upper().replace("-", "_")
        signal_name = fix_text(entries[3])
        signal_area = fix_text(entries[4])
        if num_addrs == 1:
            define_line = "`define %s_%s_%s %d" % (signal_header, signal_area, signal_name, index)
            signal_list.append(define_line)
        else:
            # values that are more than 16 bits are likely memory
            start_line = "`define %s_%s_%s_LO %d" % (signal_header, signal_area, signal_name, index)
            signal_list.append(start_line)
            index = index + num_addrs - 1
            end_line = "`define %s_%s_%s_HI %d" % (signal_header, signal_area, signal_name, index)
            signal_list.append(end_line)
        index += 1

    signal_defines = "\n".join(signal_list)
    num_indices = index

    return signal_defines, num_indices


def main():
    csv_text = readFile(csv_path)
    signal_defines, num_indices = get_signal_defines(csv_text)

    last_address = num_indices - 1
    last_address_define = "`define SAVE_STATE_LAST_ADDRESS %d" % last_address
    num_bits_define = "`define SAVE_STATE_BITS ($clog2(%d))" % last_address

    vh_text = "\n%s\n\n%s\n\n%s\n" % (num_bits_define, last_address_define, signal_defines)

    writeFile(vh_path, vh_text)

main()