# Deletes random rows from a CSV file until N rows remain helper function

import csv
import random

def delete_random_rows(csv_file, n):
    # Read the CSV file and store its contents
    with open(csv_file, 'r') as file:
        reader = csv.reader(file)
        rows = list(reader)

    # Ensure the number of rows to delete is not greater than the total number of rows
    if n >= len(rows) - 1:  # Subtracting 1 for the header row
        print("Number of rows to keep is greater than or equal to total number of rows (excluding header).")
        return

    # Extract the header row and store it
    header = rows[0]

    # Delete random rows until only n rows remain (excluding header)
    remaining_rows = [header]  # Initialize with header row
    while len(remaining_rows) < n + 1:  # Adding 1 for the header row
        # Choose a random row index to delete
        index_to_delete = random.randint(1, len(rows) - 1)  # Start from index 1 to exclude header row
        # Append the randomly chosen row to remaining_rows before deleting it
        remaining_rows.append(rows.pop(index_to_delete))

    # Write the remaining rows back to the CSV file
    with open(csv_file, 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerows(remaining_rows)

    print(f"{n} rows remaining after deletion.")

# Example usage:
csv_file = "/Users/joelsmith/Documents/MATLAB/radiomic_table_validation.csv"  # Replace with your CSV file path
N = 100  # Number of rows to keep
delete_random_rows(csv_file, N)
