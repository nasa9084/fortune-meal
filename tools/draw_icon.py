import math, random
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # 4倍で描いて最後に縮小（アンチエイリアス）
def sc(v): return int(v * 4)
random.seed(7)

# 背景：暖かいグラデーション
bg = Image.new("RGB", (S, S))
top, bot = (255, 196, 120), (240, 128, 62)
px = bg.load()
for y in range(S):
    t = y / (S - 1)
    c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
    for x in range(S):
        px[x, y] = c
img = bg.convert("RGBA")

def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

# 湯気
steam = layer()
d = ImageDraw.Draw(steam)
for cx in (410, 512, 614):
    pts = []
    for i in range(60):
        t = i / 59
        y = 330 - t * 190
        x = cx + math.sin(t * math.pi * 2.2 + cx) * 26
        pts.append((sc(x), sc(y)))
    d.line(pts, fill=(255, 255, 255, 140), width=sc(18), joint="curve")
# 色は白のまま、透明度だけぼかす（縁が茶色くならないように）
a = steam.getchannel("A").filter(ImageFilter.GaussianBlur(sc(4)))
steam = Image.new("RGBA", (S, S), (255, 255, 255, 0)); steam.putalpha(a)
img = Image.alpha_composite(img, steam)

# ご飯の山（楕円の上半分が茶碗から盛り上がる）
mound_box = (sc(225), sc(355), sc(799), sc(740))
rice = layer()
d = ImageDraw.Draw(rice)
d.ellipse(mound_box, fill=(252, 250, 244, 255))
# 下側を少しだけ影に
shade = layer()
ds = ImageDraw.Draw(shade)
ds.ellipse((sc(250), sc(450), sc(774), sc(760)), fill=(225, 218, 205, 120))
shade = shade.filter(ImageFilter.GaussianBlur(sc(30)))
rice = Image.alpha_composite(rice, shade)

# 米粒
grains = layer()
for _ in range(900):
    while True:
        x = random.uniform(225, 799); y = random.uniform(355, 600)
        if ((x - 512) / 287) ** 2 + ((y - 547) / 192) ** 2 < 0.97:
            break
    w, h = 30, 15
    g = Image.new("RGBA", (sc(w) + 8, sc(h) + 8), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.ellipse((4, 4, sc(w) + 4, sc(h) + 4), fill=(255, 255, 255, 255),
               outline=(226, 220, 208, 255), width=sc(1.4))
    gd.ellipse((sc(6), sc(3), sc(16), sc(7)), fill=(255, 255, 255, 255))
    g = g.rotate(random.uniform(0, 180), expand=True, resample=Image.BICUBIC)
    grains.alpha_composite(g, (sc(x) - g.width // 2, sc(y) - g.height // 2))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse(mound_box, fill=255)
grains.putalpha(Image.composite(grains.getchannel("A"), Image.new("L", (S, S), 0), mask))
rice = Image.alpha_composite(rice, grains)
img = Image.alpha_composite(img, rice)

# 茶碗
bowl = layer()
d = ImageDraw.Draw(bowl)
rim_y = 600
d.pieslice((sc(170), sc(rim_y - 330), sc(854), sc(rim_y + 330)), 0, 180, fill=(178, 38, 46, 255))
# 高台
d.rounded_rectangle((sc(392), sc(rim_y + 310), sc(632), sc(rim_y + 352)), radius=sc(10), fill=(140, 26, 34, 255))
# 縁の帯
d.rounded_rectangle((sc(166), sc(rim_y - 14), sc(858), sc(rim_y + 16)), radius=sc(15), fill=(150, 28, 36, 255))
# 模様（白い波線）
pts = []
for i in range(200):
    t = i / 199
    x = 230 + t * 564
    y = rim_y + 110 + math.sin(t * math.pi * 6) * 16
    pts.append((sc(x), sc(y)))
d.line(pts, fill=(255, 236, 220, 230), width=sc(10), joint="curve")
for cx in (300, 420, 512, 604, 724):
    r = 9
    d.ellipse((sc(cx - r), sc(rim_y + 175 - r), sc(cx + r), sc(rim_y + 175 + r)), fill=(255, 236, 220, 230))
# 茶碗を形で切り抜く
bmask = Image.new("L", (S, S), 0)
bm = ImageDraw.Draw(bmask)
bm.pieslice((sc(170), sc(rim_y - 330), sc(854), sc(rim_y + 330)), 0, 180, fill=255)
bm.rounded_rectangle((sc(392), sc(rim_y + 310), sc(632), sc(rim_y + 352)), radius=sc(10), fill=255)
bm.rounded_rectangle((sc(166), sc(rim_y - 14), sc(858), sc(rim_y + 16)), radius=sc(15), fill=255)
bowl.putalpha(Image.composite(bowl.getchannel("A"), Image.new("L", (S, S), 0), bmask))
# ツヤ
gloss = layer()
ImageDraw.Draw(gloss).arc((sc(200), sc(rim_y - 260), sc(824), sc(rim_y + 290)), 120, 160, fill=(255, 255, 255, 90), width=sc(22))
gloss = gloss.filter(ImageFilter.GaussianBlur(sc(14)))
gloss.putalpha(Image.composite(gloss.getchannel("A"), Image.new("L", (S, S), 0), bmask))
bowl = Image.alpha_composite(bowl, gloss)
# 影
shadow = layer()
ImageDraw.Draw(shadow).ellipse((sc(300), sc(rim_y + 330), sc(724), sc(rim_y + 380)), fill=(120, 50, 20, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(sc(12)))
img = Image.alpha_composite(img, shadow)
img = Image.alpha_composite(img, bowl)

# 箸（茶碗の縁に渡す）
chop = layer()
d = ImageDraw.Draw(chop)
for (x1, y1, x2, y2) in ((150, 548, 880, 500), (160, 580, 890, 540)):
    d.line((sc(x1), sc(y1), sc(x2), sc(y2)), fill=(92, 58, 36, 255), width=sc(20))
    d.line((sc(x1), sc(y1) - sc(4), sc(x2), sc(y2) - sc(4)), fill=(130, 88, 58, 255), width=sc(6))
img = Image.alpha_composite(img, chop)

out = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
out.save("icon.png")
