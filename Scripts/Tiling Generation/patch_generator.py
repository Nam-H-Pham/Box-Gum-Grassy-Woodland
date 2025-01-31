from pxr import Usd, UsdGeom, Gf
import random
import os

def create_tile_patch(output_usd_path, patch_dimension=10, patch_spacing=0.5, random_scale=(0.8, 1.2), spawn_chance=0.88, model_names_paths=None):
    if model_names_paths is None:
        model_names_paths = {
            "Themeda_triandra_0": "Themeda_triandra_0.usdc",
            "Themeda_triandra_1": "Themeda_triandra_1.usdc",
            "Themeda_triandra_2": "Themeda_triandra_2.usdc",
            "Themeda_triandra_3": "Themeda_triandra_3.usdc",
            "Themeda_triandra_4": "Themeda_triandra_4.usdc"
        }
    
    # Create a new USD stage
    stage = Usd.Stage.CreateNew(output_usd_path)

    # Define the root Xform
    world = UsdGeom.Xform.Define(stage, "/World")

    # Define the Assets Xform under World
    assets = UsdGeom.Xform.Define(stage, "/World/Assets")

    def define_grass_model(stage, grass_model_path, name="Themeda_triandra_1", rotate_90=True):
        # Define the Themeda_triandra_1 Xform under Assets
        grass_model = UsdGeom.Xform.Define(stage, f"/World/Assets/{name}")
        grass_model.GetPrim().SetMetadata("kind", "component")
        grass_model.GetPrim().GetReferences().AddReference(grass_model_path)

        # Grass is strange sometimes, so we need to rotate it 90 degrees around the X-axis
        if rotate_90:
            rotation_90 = Gf.Matrix4d(1.0, 0.0, 0.0, 0.0, 
                                    0.0, 0.0, 1.0, 0.0, 
                                    0.0, 1.0, 0.0, 0.0, 
                                    0.0, 0.0, 0.0, 1.0)
            grass_model.AddTransformOp().Set(rotation_90)

        UsdGeom.Imageable(grass_model.GetPrim()).MakeInvisible()

    # Define the grass models
    for name, path in model_names_paths.items():
        define_grass_model(stage, path, name)

    # Define the grass patch
    for i in range(patch_dimension):
        for j in range(patch_dimension):
            if random.random() > spawn_chance:
                continue

            # Position in a grid
            random_offset = random.uniform(-patch_spacing / 2, patch_spacing / 2)
            translation = (Gf.Vec3f(i*patch_spacing - patch_dimension/2 * patch_spacing + random_offset, 0, j*patch_spacing - patch_dimension/2 * patch_spacing + random_offset))

            # Rotate 90 degrees around Y-axis
            rotation = Gf.Vec3f(0, 90, 90)

            # Random scale
            scale_factor = random.uniform(random_scale[0], random_scale[1])
            scales = (Gf.Vec3f(scale_factor, scale_factor, scale_factor))

            # Create the instance
            # Randomly choose a grass model
            grass_model_name = random.choice(list(model_names_paths.keys()))
            instance = UsdGeom.Xform.Define(stage, f"/World/Instance_{i}_{j}_{grass_model_name}")
            instance.GetPrim().SetInstanceable(True)
            instance.GetPrim().GetReferences().AddInternalReference(f"/World/Assets/{grass_model_name}")
            instance.AddTranslateOp().Set(translation)
            instance.AddRotateXYZOp().Set(rotation)
            instance.AddScaleOp().Set(scales)
            instance.GetXformOpOrderAttr().Set([
                "xformOp:translate",
                "xformOp:rotateXYZ",
                "xformOp:scale"
            ])

            # Explicitly set the instance's visibility to "inherited"
            UsdGeom.Imageable(instance.GetPrim()).MakeVisible()

    # Save the stage
    stage.GetRootLayer().Save()
    print(f"USD file created at: {output_usd_path}")

    # replace all backslashes with forward slashes in the USD file
    with open(output_usd_path, "r") as f:
        contents = f.read()
    contents = contents.replace("\\", "/")
    with open(output_usd_path, "w") as f:
        f.write(contents)
        

# Example usage
if __name__ == "__main__":
    create_tile_patch("grass_patch.usda", patch_dimension=60, patch_spacing=0.5, random_scale=(0.8, 1.2), spawn_chance=0.88)