# groups the volume foles in the folder path by volume number


import os
import re
import shutil

# Function to create directories and move files
def group_files_by_volume(folder_path):
    # List all files in the folder
    files = os.listdir(folder_path)
    
    # Create a regex pattern to extract volume numbers
    pattern = re.compile(r'volume_(\d+)_slice_\d+\.h5')

    # Create a dictionary to store file paths by volume number
    volume_files = {}

    # Group files by volume number
    for file in files:
        match = pattern.match(file)
        if match:
            volume_number = match.group(1)
            if volume_number not in volume_files:
                volume_files[volume_number] = []
            volume_files[volume_number].append(file)

    # Create directories and move files
    for volume_number, files in volume_files.items():
        volume_folder = os.path.join(folder_path, f"volume_{volume_number}")
        os.makedirs(volume_folder, exist_ok=True)
        for file in files:
            source = os.path.join(folder_path, file)
            destination = os.path.join(volume_folder, file)
            shutil.move(source, destination)

# Usage example
folder_path = "/Users/joelsmith/Downloads/archive/BraTS2020_training_data/content/data"
group_files_by_volume(folder_path)
