"""
    prep_img.py

    This Python script reads in an image, resizes it to 128 x 128 
    (maintains aspect ratio, pads black) and generates the hex file for 
    input to Verilog $readmemh(). 

    Author: Mahesh Venkitachalam

"""

from PIL import Image
import sys

if len(sys.argv) != 2:
    print("usage:\npython prep_img.py input.png")
    exit(0)

im = Image.open(sys.argv[1])

pixels = im.load() 
width, height = im.size

WIDTH, HEIGHT = 128, 128 

if (width, height) != (WIDTH, HEIGHT):
    print("resizing...")
    aspect = 128 / float(im.size[0])
    im_new = Image.new("RGB", (128, 128), (0, 0, 0))
    h = im.size[1] * (WIDTH / float(width))
    im = im.resize((WIDTH, int(h)), Image.Resampling.LANCZOS)
    y = (HEIGHT - int(h)) // 2
    im_new.paste(im, (0, y))
    im_new.save('out.png')

ofile = open("img.mem", 'w')

pixels = im_new.load()
width, height = im_new.size
for x in range(height):
    for y in range(width):
        pixel = pixels[y, x]
        # write out BGR in 12-bit format. eg. abc ce0 ...
        ofile.write("%x%x%x " % (pixel[2] >> 4, pixel[1] >> 4, pixel[0] >> 4))
    ofile.write('\n')
ofile.close()

print('output written to img.mem.')
