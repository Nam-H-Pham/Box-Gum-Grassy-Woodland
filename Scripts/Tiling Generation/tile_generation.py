import json
import os
import shutil
import time
from patch_generator import create_tile_patch  # Assuming the function is renamed accordingly

def generate_tiles(
    json_file='subsquare_coordinates.json',
    models_folder='models',
    model_folder_name='Rytidosperma caespitosum',
    output_folder='output',
    random_scale=(0.8, 1.2),
    spawn_chance=0.88
):
    """
    Generates tile patches based on subsquare coordinates and model configurations.

    Args:
        json_file (str): Path to the JSON file containing subsquare coordinates.
        models_folder (str): Folder containing the model data.
        model_folder_name (str): Name of the specific model folder.
        output_folder (str): Path to the output folder where tiles will be saved.
        random_scale (tuple): Range for random scaling of tiles.
        spawn_chance (float): Probability of spawning tiles.

    """
    # Read JSON file
    with open(json_file, 'r') as file:
        subsquares = json.load(file)

    # Get unique size and spacing values
    sizes = sorted(set([subsquare['size'] for subsquare in subsquares.values()]))
    spacings = sorted(set([subsquare['spacing'] for subsquare in subsquares.values()]))
    sizes_and_spacings = {size: spacing for size, spacing in zip(sizes, spacings)}

    model_folder_path = os.path.join(models_folder, model_folder_name)

    # Delete and recreate the output folder
    if os.path.exists(output_folder):
        shutil.rmtree(output_folder)
    time.sleep(0.1)
    os.makedirs(output_folder, exist_ok=True)

    # Copy models and JSON file to output folder
    shutil.copytree(models_folder, os.path.join(output_folder, models_folder))
    shutil.copy(json_file, os.path.join(output_folder, json_file))

    def get_model_names_paths(input_folder):
        """Get all model names and paths from the specified folder."""
        usdc_files = [f for f in os.listdir(input_folder) if f.endswith(".usdc")]
        return {usdc_file.split(".")[0]: os.path.join(input_folder, usdc_file) for usdc_file in usdc_files}

    # Identify LOD folders
    lod_folders = [f for f in os.listdir(model_folder_path) if f.startswith("LOD")]

    # Generate tile patches
    lod_level = 0
    for size, spacing in sizes_and_spacings.items():
        lod_level = min(lod_level, len(lod_folders) - 1)
        model_names_paths = get_model_names_paths(os.path.join(model_folder_path, f"LOD{lod_level}"))
        lod_level += 1

        print(f"Creating tiles with size {size} and spacing {spacing}")

        name = f"{size}_{spacing}.usda"
        patch_dimension = int(size // spacing)
        patch_spacing = spacing

        print(f"Creating tile patch {name}")
        print(f"Patch dimension: {patch_dimension}")
        print(f"Patch spacing: {patch_spacing}")

        create_tile_patch(
            os.path.join(output_folder, name),
            patch_dimension=patch_dimension,
            patch_spacing=patch_spacing,
            random_scale=random_scale,
            spawn_chance=spawn_chance,
            model_names_paths=model_names_paths
        )
