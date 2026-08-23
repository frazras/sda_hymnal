from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
BRAND = ROOT.parent / "brand"
FONTS = ROOT.parent / "fonts"

W, H = 1080, 1920
EMERALD = "#0D3F30"
ACCENT = "#176A50"
CREAM = "#FAFAF7"
GOLD = "#A87E2F"
INK = "#131714"
MUTED = "#6E7873"


def font(name: str, size: int):
    return ImageFont.truetype(str(FONTS / name), size=size)


def vertical_gradient(size, top, bottom):
    canvas = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(canvas)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        color = tuple(round(a * (1 - t) + b * t) for a, b in zip(top, bottom))
        draw.line((0, y, size[0], y), fill=color)
    return canvas


def rounded_screenshot(path: Path, target_h=1490):
    image = Image.open(path).convert("RGB")
    image = image.crop((0, 150, image.width, image.height - 105))
    target_w = round(image.width * target_h / image.height)
    image = image.resize((target_w, target_h), Image.Resampling.LANCZOS)
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width, image.height), radius=34, fill=255)
    result = Image.new("RGBA", image.size)
    result.paste(image, (0, 0), mask)
    return result


def make_store_shot(index, raw_name, title, subtitle, dark=False):
    if dark:
        background = vertical_gradient((W, H), (13, 63, 48), (6, 28, 22))
        title_color, subtitle_color = CREAM, "#B9C9C1"
    else:
        background = vertical_gradient((W, H), (250, 250, 247), (232, 241, 236))
        title_color, subtitle_color = INK, MUTED

    draw = ImageDraw.Draw(background)
    draw.rounded_rectangle((70, 64, 104, 76), radius=6, fill=GOLD)
    draw.text((70, 105), title, font=font("Literata-600.ttf", 60), fill=title_color)
    draw.text((72, 188), subtitle, font=font("InstrumentSans-500.ttf", 30), fill=subtitle_color)

    shot = rounded_screenshot(RAW / raw_name)
    x, y = (W - shot.width) // 2, 310
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x - 12, y + 16, x + shot.width + 12, y + shot.height + 44), radius=44, fill=(3, 24, 17, 72))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    background = Image.alpha_composite(background.convert("RGBA"), shadow)
    background.alpha_composite(shot, (x, y))
    background.convert("RGB").save(ROOT / f"phone-{index:02d}.png", optimize=True)


def make_feature_graphic():
    source = Image.open(RAW / "feature-background.png").convert("RGB")
    ratio = 1024 / 500
    crop_h = round(source.width / ratio)
    top = max(0, (source.height - crop_h) // 2)
    source = source.crop((0, top, source.width, top + crop_h)).resize((1024, 500), Image.Resampling.LANCZOS)

    overlay = Image.new("RGBA", source.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rounded_rectangle((54, 54, 640, 446), radius=28, fill=(8, 38, 29, 172))

    wordmark = Image.open(BRAND / "wordmark_dark.png").convert("RGBA")
    wordmark.thumbnail((500, 170), Image.Resampling.LANCZOS)
    overlay.alpha_composite(wordmark, (92, 88))
    draw.text((96, 280), "1,398 hymns. One beautiful app.", font=font("InstrumentSans-600.ttf", 31), fill=CREAM)
    draw.text((96, 332), "Search · Read · Listen · Save", font=font("InstrumentSans-500.ttf", 23), fill="#C8D8D0")
    draw.rounded_rectangle((96, 387, 294, 425), radius=19, fill=GOLD)
    draw.text((118, 395), "OLD & NEW", font=font("InstrumentSans-700.ttf", 17), fill=EMERALD)

    Image.alpha_composite(source.convert("RGBA"), overlay).convert("RGB").save(ROOT / "feature-graphic-1024x500.png", optimize=True)


if __name__ == "__main__":
    shots = [
        (1, "01-numbers.png", "Find any hymn", "Fast number entry for old and new hymnals", False),
        (2, "02-hymn-preview.png", "Preview instantly", "See both hymnals before you open a song", True),
        (3, "03-hymn-reader.png", "Read beautifully", "Clear lyrics, music controls and chord tools", False),
        (4, "04-search.png", "Search every word", "Find hymns by title, lyrics or number", True),
        (5, "05-settings.png", "Make it yours", "Themes, text size, sound and musician tools", False),
    ]
    for args in shots:
        make_store_shot(*args)
    make_feature_graphic()
