# these two functions were taken from CMU 15-112 website
# https://www.cs.cmu.edu/~112/notes/notes-strings.html#basicFileIO
def readFile(path):
    with open(path, "rt") as f:
        return f.read()

def writeFile(path, contents):
    with open(path, "wt") as f:
        f.write(contents)

class Cpu_Log(object):
    def __str__(self):
        s = "%s %s A:%s X:%s Y:%s P:%s SP:%s CYC:%d" % (self.pc, self.opcode, self.a, self.x, self.y, self.status, self.sp, self.cycle)
        return s

    def __eq__(self, other):
        return str(self) == str(other)


class Output_Log(Cpu_Log):
    def __init__(self, line):
        # "c000 4c A:00 X:00 Y:00 P:24 SP:fd CYC:7"
        entries = line.split(" ")
        self.pc = entries[0].upper()
        self.opcode = entries[1].upper()
        self.a = entries[2][2:].upper()
        self.x = entries[3][2:].upper()
        self.y = entries[4][2:].upper()
        self.status = entries[5][2:].upper()
        self.sp = entries[6][3:].upper()
        self.cycle = int(entries[7][4:])

class Golden_Log(Cpu_Log):
    def __init__(self, line):
        #"C000  4C F5 C5  JMP $C5F5                       A:00 X:00 Y:00 P:24 SP:FD PPU:  0,  0 CYC:7"
        halves = line.split("A:")
        self.pc = halves[0][:4]
        self.opcode = halves[0][6:8]

        entries = halves[1].split(":")
        self.a = entries[0][:2]
        self.x = entries[1][:2]
        self.y = entries[2][:2]
        self.status = entries[3][:2]
        self.sp = entries[4][:2]
        self.cycle = int(entries[-1])

def find_first_dif(golden_contents, output_contents):
    
    matching_lines = []

    for (golden_line, output_line) in zip(golden_contents.splitlines(), output_contents.splitlines()):
        golden_log = Golden_Log(golden_line)
        #print(golden_log)
        output_log = Output_Log(output_line)
        #print(output_log)
        #return
        if golden_log == output_log:
            matching_lines.append(golden_log)
        else:
            for log in matching_lines[-5:]:
                print(log)
            print("expected: %s" % golden_log)
            print("got:      %s" % output_log)
            return

    print(len(golden_contents.splitlines()), len(output_contents.splitlines()))
    for log in matching_lines[-5:]:
        print(log)

    print("passed", len(matching_lines))


def main():
    golden_path = "logs/nestest.log.txt"
    output_path = "logs/cpu-out.log.txt"

    golden_contents = readFile(golden_path)
    output_contents = readFile(output_path)

    find_first_dif(golden_contents, output_contents)

main()
