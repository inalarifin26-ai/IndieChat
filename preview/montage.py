import sys
from PIL import Image, ImageDraw
d, names, out, cols = sys.argv[1], sys.argv[2].split(','), sys.argv[3], int(sys.argv[4])
ims = [Image.open(f'{d}/{n}.png').convert('RGB') for n in names]
w, h = ims[0].size; s = 0.62; tw, th = int(w*s), int(h*s)
rows = (len(ims)+cols-1)//cols; sheet = Image.new('RGB', (cols*tw+(cols+1)*10, rows*(th+22)+10), '#C9CFE0')
dr = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(zip(names, ims)):
    x, y = 10+(i%cols)*(tw+10), 10+(i//cols)*(th+22); sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y+16)); dr.text((x, y), n, fill='#222')
sheet.save(out)
