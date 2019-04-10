import trace_lib


def main():
    for row in range(len(trace_lib.PALETTE)):
        for col in range(len(trace_lib.PALETTE[0])):
            (r,g,b) = trace_lib.PALETTE[row][col]
            row_h = hex(row)[2:]
            col_h = hex(col)[2:]

            print("6'h"+row_h+col_h+":   rgb = { 8'd"+str(r)+", 8'd"+str(g)+", 8'd"+str(b)+" };")
        print()


if __name__ == '__main__':
    main()