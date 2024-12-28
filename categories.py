import pandas as pd

#read two csv files and append  them then save only unique values
def combine_csv_files(file1, file2, output_file):
    # Read the csv files
    df1 = pd.read_csv(file1)
    df2 = pd.read_csv(file2)

    # Concatenate the dataframes
    df = pd.concat([df1, df2])

    # Save only unique values
    df.drop_duplicates().to_csv(output_file, index=False)
    print(f"Combined data saved to {output_file}")

combine_csv_files("data/unique_category_codes.csv", "data/unique_category_codes1.csv", "data/unique_category_codes_combined.csv")