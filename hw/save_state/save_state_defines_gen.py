

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

    # skip header line
    lines = text.splitlines()[1:]

    for line in lines:
        # should be [blank, num bits, signal_name, signal_area]
        entries = line.split(",")
        # for now don't do anything with the bit value
        signal_name = entries[2].upper()
        signal_area = entries[3].upper()
        index = len(signal_list)
        define_line = "`define %s_%s_%s %d" % (signal_header, signal_area, signal_name, index)
        signal_list.append(define_line)

    signal_defines = "\n".join(signal_list)
    num_indices = len(signal_list)

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