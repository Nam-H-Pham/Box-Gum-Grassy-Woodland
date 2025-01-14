import tkinter as tk
import json

import json

def draw_subdivided_squares(canvas, canvas_width, canvas_height, num_subdivisions, spacing_factor, output_file):
    """Draw square rings with smaller red subsquares and export their coordinates."""
    # Center of the canvas
    center_x = canvas_width / 2
    center_y = canvas_height / 2

    # Initial square dimensions (full canvas size)
    square_width = canvas_width
    square_height = canvas_height

    # Dictionary to store individual subsquares by unique keys (e.g., square1, square2)
    subsquares = {}

    square_counter = 1  # Initialize counter for individual square identifiers

    for i in range(num_subdivisions):
        # Calculate the outer square
        outer_top_left_x = center_x - square_width / 2
        outer_top_left_y = center_y - square_height / 2
        outer_bottom_right_x = center_x + square_width / 2
        outer_bottom_right_y = center_y + square_height / 2

        # Shrink the square for the next inner ring
        square_width /= 2
        square_height /= 2

        # Calculate the inner square
        inner_top_left_x = center_x - square_width / 2
        inner_top_left_y = center_y - square_height / 2
        inner_bottom_right_x = center_x + square_width / 2
        inner_bottom_right_y = center_y + square_height / 2

        # Draw the outer square if a canvas is provided
        if canvas is not None:
            canvas.create_rectangle(outer_top_left_x, outer_top_left_y, 
                                    outer_bottom_right_x, outer_bottom_right_y, 
                                    outline="black", width=2)

        # Fill the ring with red subsquares
        ring_width = (outer_bottom_right_x - outer_top_left_x) - (inner_bottom_right_x - inner_top_left_x)
        subsquare_size = ring_width / 2  # Change the divisor to control subsquare size

        scaling = 0.1  # Scaling factor to convert coordinates to meters

        y = outer_top_left_y
        while y < outer_bottom_right_y:
            x = outer_top_left_x
            while x < outer_bottom_right_x:
                # Check if the subsquare fits within the ring
                if (x + subsquare_size <= inner_top_left_x or x >= inner_bottom_right_x or
                        y + subsquare_size <= inner_top_left_y or y >= inner_bottom_right_y):
                    if canvas is not None:
                        canvas.create_rectangle(x, y, x + subsquare_size, y + subsquare_size, 
                                                outline="red", fill="lightgray")
                    # Add subsquare details with a unique key, including size, spacing, and origin
                    subsquares[f"square{square_counter}"] = {
                        "origin": [(x + subsquare_size / 2 - center_x) * scaling, 
                                   (y + subsquare_size / 2 - center_y) * scaling],  # Origin as midpoint
                        "size": subsquare_size * scaling,
                    }
                    square_counter += 1  # Increment counter for the next square
                x += subsquare_size
            y += subsquare_size

        # Draw the center square after certain number of subdivisions
        if i == num_subdivisions - 1:  # Only for the last subdivision
            # Break the center square into 4 smaller squares
            center_square_size = min(square_width, square_height)  # Size of the last square
            half_size = center_square_size / 2  # Half the size for splitting into 4 squares
            for row in range(2):  # 2 rows
                for col in range(2):  # 2 columns
                    center_top_left_x = center_x - center_square_size / 2 + col * half_size
                    center_top_left_y = center_y - center_square_size / 2 + row * half_size
                    center_bottom_right_x = center_top_left_x + half_size
                    center_bottom_right_y = center_top_left_y + half_size
                    if canvas is not None:
                        canvas.create_rectangle(center_top_left_x, center_top_left_y, 
                                                center_bottom_right_x, center_bottom_right_y, 
                                                outline="red", fill="lightgray")

                    # Add each of the 4 smaller squares to subsquares with a unique key
                    subsquares[f"square{square_counter}"] = {
                        "origin": [(center_top_left_x + half_size / 2 - center_x) * scaling, 
                                   (center_top_left_y + half_size / 2 - center_y) * scaling],  # Origin as midpoint
                        "size": half_size * scaling,
                    }
                    square_counter += 1  # Increment counter for the next square

    # Determine spacings based on the smallest subsquare size
    sizes = set([subsquare['size'] for subsquare in subsquares.values()])

    multiply_factor = spacing_factor / min(sizes)
    spacings = {}
    for size in sizes:
        spacings[size] = size * multiply_factor

    for key in subsquares:
        subsquares[key]["spacing"] = spacings[subsquares[key]["size"]]

    # Export the individual subsquare details to a JSON file
    with open(output_file, "w") as file:
        json.dump(subsquares, file, indent=4)

    # Print information about the subsquares
    sizes = sorted(set([subsquare['size'] for subsquare in subsquares.values()]))
    print(f"Subsquare sizes: {sizes}")
    print(f"Subsquare spacings: {sorted(spacings.values())}")


def create_tile_json(name="tile_data", spacing_factor=0.6, num_subdivisions=3, length_width_coverage=60, visualise=False):
    # Canvas dimensions
    canvas_width = length_width_coverage * 10  # convert meters to pixels
    canvas_height = length_width_coverage * 10

    # Output file for subsquare details
    output_file = f"{name}.json"

    if visualise:
        # Create the main window
        root = tk.Tk()
        root.title("Tile Visualisation")

        # Create a canvas
        canvas = tk.Canvas(root, width=canvas_width, height=canvas_height, bg="white")
        canvas.pack()

        # Draw the subdivided squares and export the data
        subsquares = draw_subdivided_squares(canvas, canvas_width, canvas_height, num_subdivisions, spacing_factor, output_file)

        # Start the Tkinter event loop
        root.mainloop()
    else:
        # Export the data without visualising
        subsquares = draw_subdivided_squares(None, canvas_width, canvas_height, num_subdivisions, spacing_factor, output_file)

    print(f"Data exported to {output_file}")

