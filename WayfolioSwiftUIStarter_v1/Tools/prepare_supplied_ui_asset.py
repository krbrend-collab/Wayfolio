#!/usr/bin/env python3
"""Convert a supplied white-backed UI JPEG to an exact transparent PNG."""

import sys
from PIL import Image, ImageOps

source, destination, mode = sys.argv[1:4]
image = Image.open(source).convert("RGB")
alpha = ImageOps.invert(ImageOps.grayscale(image))
rgb = Image.new("RGB", image.size, "white") if mode == "mask" else image
red, green, blue = rgb.split()
Image.merge("RGBA", (red, green, blue, alpha)).save(destination, "PNG")
