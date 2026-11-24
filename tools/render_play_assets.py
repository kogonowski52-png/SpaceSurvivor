#!/usr/bin/env python3
"""Compose Play listing artwork from the project's hulls and unmodified Godot captures."""
import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / "release" / "google-play" / "assets"
DISPLAY = PROJECT / "assets" / "fonts" / "Oxanium.ttf"
CAPTIONS = (
    ("01-combat", "Przebij się przez szyk", "Break through the formation", "#72dfef"),
    ("02-weapons", "Rozwiń siłę ognia", "Build your firepower", "#ac92f5"),
    ("03-asterion", "Starcie z Asterionem", "Face Asterion", "#efa976"),
    ("04-vesperon", "Przełam obronę Vesperona", "Breach Vesperon’s defence", "#e3bb8b"),
    ("05-nadir", "Finał z Nadirem", "Take on Nadir", "#a1eee0"),
    ("06-hangar", "Wybierz swój statek", "Choose your starfighter", "#72dfef"),
    ("07-campaign", "Odkryj szlak Helionu", "Chart the Helion route", "#72dfef"),
    ("08-upgrades", "Rozbuduj swój statek", "Upgrade your ship", "#efa976"),
)
SUBTITLES = {"pl-PL": "PRÓG HELIONU", "en-US": "THE HELION GATE"}


def font(size, weight):
    face = ImageFont.truetype(str(DISPLAY), size)
    face.set_variation_by_axes([weight])
    return face


def fleet_art(path, width, angle=0):
    with Image.open(PROJECT / "assets" / "art" / path) as image:
        ship = image.convert("RGBA")
    height = round(ship.height * width / ship.width)
    ship = ship.resize((width, height), Image.Resampling.LANCZOS)
    return ship.rotate(angle, Image.Resampling.BICUBIC, expand=True) if angle else ship


def place(canvas, ship, center, opacity=165):
    corner = (center[0] - ship.width // 2, center[1] - ship.height // 2)
    shadow = Image.new("RGBA", canvas.size)
    mask = ship.getchannel("A").point(lambda alpha: alpha * opacity // 255)
    shadow.paste((0, 1, 8, 255), (corner[0] - 3, corner[1] + 11, corner[0] + ship.width - 3,
                                    corner[1] + ship.height + 11), mask)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(15)))
    canvas.alpha_composite(ship, corner)


def feature(directory, subtitle):
    with Image.open(OUTPUT / "source" / "feature-backdrop.webp") as background:
        canvas = ImageOps.fit(background.convert("RGBA"), (1024, 500), Image.Resampling.LANCZOS)
    scrim = Image.new("RGBA", canvas.size)
    gradient = ImageDraw.Draw(scrim)
    for x in range(canvas.width):
        shade = round(72 * max(0.0, min(1.0, (680 - x) / 250)))
        gradient.line((x, 0, x, 500), fill=(3, 10, 22, shade))
    canvas.alpha_composite(scrim)
    place(canvas, fleet_art("chapter_one/enemies/nadir.webp", 463, 8), (758, 170))
    place(canvas, fleet_art("premium/hulls/peregrine.webp", 174, -32), (730, 318))
    lettering = ImageDraw.Draw(canvas)
    heading = font(91, 800)
    lettering.text((70, 128), "GALAXY", font=heading, fill="#edf7ff", stroke_width=1, stroke_fill="#0c1b29")
    lettering.text((70, 214), "STRIKE", font=heading, fill="#a3efff", stroke_width=1, stroke_fill="#0c1b29")
    lettering.rectangle((75, 333, 111, 335), fill="#e2b981")
    lettering.text((126, 318), subtitle, font=font(28, 640), fill="#fae3c1")
    canvas.convert("RGB").save(directory / "feature-1024x500.jpg", quality=95, optimize=True, subsampling=0)


def listing_photo(source, target, caption, accent):
    with Image.open(source) as original:
        if original.size != (1080, 1920):
            raise ValueError(f"Use a complete 1080×1920 Godot capture: {source}")
        frame = ImageOps.contain(original.convert("RGB"), (1008, 1792), Image.Resampling.LANCZOS)
    photo = Image.new("RGB", (1080, 1920), "#091525")
    drawing = ImageDraw.Draw(photo)
    drawing.rectangle((36, 103, 1043, 106), fill=accent)
    drawing.text((36, 30), caption, font=font(49, 690), fill="#ebf5ff")
    photo.paste(frame, ((photo.width - frame.width) // 2, 109))
    photo.save(target, quality=94, optimize=True, subsampling=0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", type=Path, help="Directory of original 1080×1920 PNGs")
    args = parser.parse_args()
    proof = []
    for key, *_ in CAPTIONS:
        path = args.captures / f"1080x1920-{key}.png"
        proof.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
    equipment = args.captures / "1080x1920-09-equipment.png"
    proof.append(f"{hashlib.sha256(equipment.read_bytes()).hexdigest()}  {equipment.name}")
    (OUTPUT / "raw-frames.sha256").write_text("\n".join(proof) + "\n", encoding="ascii")
    with Image.open(PROJECT / "assets" / "launcher.png") as icon:
        assert icon.size == (512, 512)
        icon.convert("RGBA").save(OUTPUT / "icon-512.png", optimize=True)
    assert (OUTPUT / "icon-512.png").stat().st_size <= 1_048_576
    for locale, subtitle in SUBTITLES.items():
        folder = OUTPUT / locale
        screens = folder / "screenshots"
        screens.mkdir(parents=True, exist_ok=True)
        feature(folder, subtitle)
        for key, polish, english, accent in CAPTIONS:
            listing_photo(args.captures / f"1080x1920-{key}.png", screens / f"{key}.jpg",
                          polish if locale == "pl-PL" else english, accent)
        alternatives = folder / "alternatives"
        alternatives.mkdir(exist_ok=True)
        listing_photo(equipment, alternatives / "09-equipment.jpg",
                      "Dobierz wyposażenie" if locale == "pl-PL" else "Fit your loadout", "#ac92f5")


if __name__ == "__main__":
    main()
