import os
from PIL import Image

current_dir = os.path.dirname(os.path.realpath(__file__))

print("Current directory:", current_dir)

for filename in os.listdir(current_dir):
    if filename.endswith(".png"):
    
        img = Image.open(os.path.join(current_dir, filename)).convert("RGBA")

        alpha = img.split()[3]

        mask = Image.new("L", img.size, color=0)

        mask.paste(255, mask=alpha)

        new_filename = f"{os.path.splitext(filename)[0]}-alpha.png"
        mask.save(os.path.join(current_dir, new_filename))

        print(f"Alpha mask created for {filename}")

print("Alpha masks created for all PNG images in the current directory.")
