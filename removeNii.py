# helper function to remove all ".nii" files in a directory


import os

def remove_nii_files(directory):
    # List all files in the directory
    files = os.listdir(directory)
    
    # Filter out files with the ".nii" extension
    nii_files = [file for file in files if file.endswith('.nii')]
    
    # Remove each ".nii" file
    for nii_file in nii_files:
        file_path = os.path.join(directory, nii_file)
        os.remove(file_path)
        print(f"Removed: {file_path}")

# Example usage
directory_path = '/Users/joelsmith/Documents/MATLAB/archive/BraTS2020_training_data/content/data/volume_1'
remove_nii_files(directory_path)
