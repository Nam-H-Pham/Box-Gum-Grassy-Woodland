import configparser
from tile_json import create_tile_json
from tile_generation import generate_tiles

# Create a ConfigParser object
config = configparser.ConfigParser()

# Read the configuration file
config.read('config.ini')

# Access the values
name = config['Settings']['Json Name']
spacing_factor = float(config['Settings']['Spacing Factor'])
num_subdivisions = int(config['Settings']['Subdivisions'])
length_width_coverage = int(config['Settings']['Length/Width Coverage'])

models_root_folder = config['Settings']['Models Root Folder']
model_subfolder = config['Settings']['Model Subfolder']
random_scale = tuple(map(float, config['Settings']['Random Scale'].split(',')))
spawn_chance = float(config['Settings']['Spawn Chance'])

# Print the values
print(f"Name: {name}")
print(f"Spacing Factor: {spacing_factor}")
print(f"Subdivisions: {num_subdivisions}")
print(f"Length/Width Coverage: {length_width_coverage}")
print(f"Models Root Folder: {models_root_folder}")
print(f"Model Subfolder: {model_subfolder}")
print(f"Random Scale: {random_scale}")
print(f"Spawn Chance: {spawn_chance}")
print()

print("Creating tile JSON file...")
create_tile_json(name, spacing_factor, 
                 num_subdivisions, 
                 length_width_coverage, 
                 visualise=False
                 )

print("Generating tiles...")
generate_tiles(json_file=f"{name}.json",
               models_folder=models_root_folder,
               model_folder_name=model_subfolder,
               output_folder="output",
               random_scale=random_scale,
               spawn_chance=spawn_chance
               )