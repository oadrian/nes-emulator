import sys

def text2bin(infile):
    with open(infile, "r") as f:
        wr_str = ""
        for line in f:
            byte = line.strip()
            wr_str += chr(int(byte, 16))
        return wr_str

def write2file(outfile, wr_str):
    with open(outfile, "wb") as f:
        f.write(wr_str)

def main():
    infile = sys.argv[1]
    outfile = sys.argv[2]
    wr_str = text2bin(infile)
    write2file(outfile, wr_str)

if __name__ == '__main__':
    main()