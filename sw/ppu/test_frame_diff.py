from __future__ import division
import sys
import os
import subprocess
import frame_sim as sw_sim 
import trace_lib as lib 
import split_ppu_mem as splitter
import frame_gen as hw_gen

def getTraceNames(trace_folder):
    traces = []
    for filename in os.listdir(trace_folder):
        if(filename.endswith(".txt")):
            trace = filename[:-4]
            traces.append(trace)
    return traces

def testSW(traces, trace_folder):
    for trace in traces:
        print("testing trace: " + trace)
        txt_path = trace_folder+ "/" + trace+".txt"
        png_path = trace_folder+ "/" + trace+".png"
        vram, palette_ram, oam = sw_sim.parseMemory(txt_path)
        bitmap0 = sw_sim.createBitmap(vram, palette_ram, oam)
        bitmap1 = lib.image2Bitmap(png_path)
        good, total = lib.compareBitmaps(bitmap0, bitmap1)
        print("Matched: "+str(100*good/total)+"% (" + str(good) + "/" + str(total) + ") of pixels\n\n")

def testHW(traces, trace_folder):
    pattbl_fl = "init/chr_rom_init.txt"
    nametbl_fl = "init/vram_init.txt"
    pal_fl = "init/pal_init.txt"
    oam_fl = "init/oam_init.txt"
    for trace in traces:
        print("testing trace: " + trace)
        txt_path = trace_folder+ "/" + trace+".txt"
        png_path = trace_folder+ "/" + trace+".png"

        # split ppu mem to init/ folder for hw simulation
        splitter.split(txt_path, pattbl_fl, nametbl_fl, pal_fl, oam_fl)

        # run ./simv 
        FNULL = open(os.devnull, 'w')
        subprocess.call(["./simv"], stdout=FNULL, stderr=FNULL)

        # convert generated frame data to bitmap
        bitmap0 = hw_gen.createBitmap("my_frame.txt")
        bitmap1 = lib.image2Bitmap(png_path)
        good, total = lib.compareBitmaps(bitmap0, bitmap1)
        print("Matched: "+str(100*good/total)+"% (" + str(good) + "/" + str(total) + ") of pixels\n\n")

def testALL(traces, trace_folder):
    pattbl_fl = "init/chr_rom_init.txt"
    nametbl_fl = "init/vram_init.txt"
    pal_fl = "init/pal_init.txt"
    oam_fl = "init/oam_init.txt"
    for trace in traces:
        print("testing trace: " + trace)
        txt_path = trace_folder+ "/" + trace+".txt"
        png_path = trace_folder+ "/" + trace+".png"

        # split ppu mem to init/ folder for hw simulation
        splitter.split(txt_path, pattbl_fl, nametbl_fl, pal_fl, oam_fl)

        # run ./simv 
        FNULL = open(os.devnull, 'w')
        subprocess.call(["./simv", "+FRAMETEST"], stdout=FNULL, stderr=FNULL)

        # convert generated frame data to bitmap
        bitmap_hw = hw_gen.createBitmap("my_frame.txt")
        bitmap1 = lib.image2Bitmap(png_path)
        good, total = lib.compareBitmaps(bitmap_hw, bitmap1)
        print("HW - Matched: "+str(100*good/total)+"% (" + str(good) + "/" + str(total) + ") of pixels")

        vram, palette_ram, oam = sw_sim.parseMemory(txt_path)
        bitmap_sw = sw_sim.createBitmap(vram, palette_ram, oam)
        good, total = lib.compareBitmaps(bitmap_sw, bitmap1)
        print("SW - Matched: "+str(100*good/total)+"% (" + str(good) + "/" + str(total) + ") of pixels\n\n")


def main():
    target = sys.argv[1]
    trace_folder = sys.argv[2]
    traces = getTraceNames(trace_folder)
    if(target == "sw"):
        print("----Testing Software Script----\n\n")
        testSW(traces, trace_folder)
    elif(target == "hw"):
        testHW(traces, trace_folder)
    elif(target == "all"):
        print("----Testing ALL----\n\n")
        print("----Testing Software Script----\n\n")
        testALL(traces, trace_folder)
    else:
        print("Did not recognized target "+target)
        exit(1)

if __name__ == '__main__':
    main()