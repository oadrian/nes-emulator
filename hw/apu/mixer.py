
#https://wiki.nesdev.com/w/index.php/APU_Mixer
#https://forums.nesdev.com/viewtopic.php?f=3&t=7870

def get_table_entry(n, f):
    if n == 0:
        return 0
    float_val = f(n)
    res = int(float_val * 65535)
    return res

def get_sv_array_str(lut):
    space = " " * 4
    res = "{\n" + space
    count = 0
    for entry in lut:
        count += 1
        res += "16'd%.5d, " % entry
        if count % 8 == 0:
            res += "\n" + space
    res = res.strip("\n ,") + "\n" + space + "};"
    return res

def generate_tables():
    pulse_fn = lambda n : 95.52/(8128.0/n + 100)
    tnd_fn = lambda n : 163.67/(24329.0/n + 100)
    pulse_table = [get_table_entry(n, pulse_fn) for n in range(0,31)]
    tnd_table = [get_table_entry(n, tnd_fn) for n in range(0,203)]
    pulse_table_sv = get_sv_array_str(pulse_table)
    tnd_table_sv = get_sv_array_str(tnd_table)
    print(pulse_table_sv)
    print(tnd_table_sv)

generate_tables()