import pandas as pd
import os
import gc

# Change for prod data
ANDMED = "data/2019-Nov.csv"
OUTPUT_DIR = "data/users/"
START_INDEX = 304  # Change this to the desired starting number for the file names
CATEGORY_FILE = "data/unique_category_codes.csv"

# Ensure the output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Pandas print table params
pd.set_option('display.max_columns', None)
pd.set_option('display.expand_frame_repr', False)
pd.set_option('display.width', 1000)

# Load data
dt = pd.read_csv(ANDMED, parse_dates=['event_time'])
print("Data read successfully.")

dt = dt[dt.event_type.isin(['view', 'purchase'])]

unique_categories = dt['category_code'].dropna().unique()
unique_categories_df = pd.DataFrame(unique_categories, columns=['category_code'])
unique_categories_df.to_csv(CATEGORY_FILE, index=False)
print(f"Unique category codes saved to {CATEGORY_FILE}")

# Free memory used for categories
del unique_categories, unique_categories_df
gc.collect()
print("Memory used for category codes freed.")


# Initialize counters
batch_size = 10000
batch_counter = 0
user_counter = 0
user_data_list = []
total_users = dt['user_id'].nunique()
total_batches = (total_users + batch_size - 1) // batch_size

# Group data by 'user_id' and process in batches
for user_counter, (user_id, user_data) in enumerate(dt.groupby('user_id'), start=1):
    user_data_list.append(user_data)
    
    # When batch reaches size, write it to a file
    if user_counter % batch_size == 0 or user_counter == total_users:
        batch_counter += 1
        file_number = START_INDEX + batch_counter - 1
        batch_file = os.path.join(OUTPUT_DIR, f"batch_{file_number}.csv")
        pd.concat(user_data_list).to_csv(batch_file, index=False)
        print(f"Batch {batch_counter} out of {total_batches} with {len(user_data_list)} users saved to {batch_file}")
        user_data_list = []  # Clear the batch

print(f"Processing completed. Total users processed: {user_counter} in {batch_counter} batches.")
