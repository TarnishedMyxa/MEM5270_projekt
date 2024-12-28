import pandas as pd
import numpy as np
import os
import gc

# Directory for batch files
BATCH_DIR = "data/users/"  # Directory where batches are stored
CATEGORY_FILE = "data/unique_category_codes_combined.csv"  # Unique categories file
analysis_category = 2053013555631882655  # Category to analyze

# Pandas print table params
pd.set_option('display.max_columns', None)
pd.set_option('display.expand_frame_repr', False)
pd.set_option('display.width', 1000)

# Load unique categories from the combined CSV
unique_categories = pd.read_csv(CATEGORY_FILE)['category'].unique()


# Split the categories into category1, category2, and category3
split_categories = pd.DataFrame(unique_categories, columns=['category'])
split_categories = split_categories['category'].str.split('.', expand=True)
split_categories = split_categories.reindex(columns=[0, 1, 2])
split_categories.columns = ['category1', 'category2', 'category3']

# Add prefix to each category level
split_categories['category1'] = '1_' + split_categories['category1'].astype(str)
split_categories['category2'] = '2_' + split_categories['category2'].astype(str)
split_categories['category3'] = '3_' + split_categories['category3'].astype(str)

# Append all unique categories into one column
unique_categories_combined = pd.concat([split_categories['category1'],
                                        split_categories['category2'],
                                        split_categories['category3']], axis=0)

# Fill NaN values with 'None' for categories
unique_categories_combined = unique_categories_combined.fillna('None')

# Process each batch
batch_files = sorted([f for f in os.listdir(BATCH_DIR) if f.endswith('.csv')])

for batch_file in batch_files:
    # Read data for the current batch
    batch_data = pd.read_csv(os.path.join(BATCH_DIR, batch_file), parse_dates=['event_time'])
    batch_data['event_time'] = pd.to_datetime(batch_data['event_time'], utc=True)

    print(f"Batch {batch_file} loaded.")

    # Filter batch data for event types 'view' and 'purchase'
    batch_data = batch_data[batch_data['event_type'].isin(['view', 'purchase'])]

    # Split 'category_code' into three separate columns
    split_categories = batch_data['category_code'].str.split('.', expand=True)
    split_categories = split_categories.reindex(columns=[0, 1, 2])

    # Assign the split columns to the batch data
    batch_data[['category1', 'category2', 'category3']] = split_categories.fillna('None')

    print("categories split")

    # Get unique sessions
    unique_sessions = batch_data['user_session'].unique()

    # Get the buy rows of the analysis category
    buy_rows = batch_data[(batch_data.event_type == 'purchase') & (batch_data.category_id == analysis_category)]

    # Get the unique sessions of the buy rows
    unique_sessions_buy = buy_rows['user_session'].unique()

    # Add bought column to the main data
    maindt = pd.DataFrame(unique_sessions, columns=['user_session'])
    maindt['bought'] = np.where(maindt['user_session'].isin(unique_sessions_buy), 1, 0)

    del(unique_sessions_buy)
    gc.collect()

    # Add user_id to the main data
    maindt = maindt.merge(batch_data[['user_session', 'user_id']], on='user_session', how='left')

    # Add first time to main data
    first_time = batch_data.groupby('user_session')['event_time'].min()
    maindt['session_start'] = maindt['user_session'].map(first_time)

    # Add column day_phase to main data (morning, afternoon, evening, night)
    maindt['hour'] = maindt['session_start'].dt.hour
    maindt['day_phase'] = pd.cut(maindt['hour'], bins=[-1, 6, 12, 18, 24], labels=['night', 'morning', 'afternoon', 'evening'], right=True)

    # Create 3 numeric dummy columns for day_phase
    maindt = pd.get_dummies(maindt, columns=['day_phase'], drop_first=True)

    print("day_phase added")

    unique_categories = unique_categories_combined

    print("categories done")

    # Generate counts for 'view' and 'purchase' events
    viewed_counts1 = batch_data[batch_data.event_type == 'view'].groupby(['user_id', 'category1']).size().unstack(fill_value=0)
    viewed_counts1 = viewed_counts1.add_suffix('_cat1')

    bought_counts1 = batch_data[batch_data.event_type == 'purchase'].groupby(['user_id', 'category1']).size().unstack(fill_value=0)
    bought_counts1 = bought_counts1.add_suffix('_cat1')

    viewed_counts2 = batch_data[batch_data.event_type == 'view'].groupby(['user_id', 'category2']).size().unstack(fill_value=0)
    viewed_counts2 = viewed_counts2.add_suffix('_cat2')

    bought_counts2 = batch_data[batch_data.event_type == 'purchase'].groupby(['user_id', 'category2']).size().unstack(fill_value=0)
    bought_counts2 = bought_counts2.add_suffix('_cat2')

    # Generate counts for 'view' and 'purchase' events for category3
    viewed_counts3 = batch_data[batch_data.event_type == 'view'].groupby(['user_id', 'category3']).size().unstack(
        fill_value=0)
    viewed_counts3 = viewed_counts3.add_suffix('_cat3')

    bought_counts3 = batch_data[batch_data.event_type == 'purchase'].groupby(['user_id', 'category3']).size().unstack(
        fill_value=0)
    bought_counts3 = bought_counts3.add_suffix('_cat3')

    print("viewed and bought counts for categories 1, 2, and 3 calculated")

    # Combine all counts into single DataFrames for viewed and bought
    viewed_counts = pd.concat([viewed_counts1, viewed_counts2, viewed_counts3], axis=1, copy=False)
    bought_counts = pd.concat([bought_counts1, bought_counts2, bought_counts3], axis=1, copy=False)

    # Merge the counts with the main data
    maindt = maindt.drop_duplicates()

    for category in unique_categories_combined:
        cat = category[2:]  # Remove the prefix if needed (adjust this if necessary)

        # Initialize 'viewed' column
        maindt[category + '_viewed'] = 0

        # Handle viewed counts
        for i in range(1, 4):  # Check for category1, category2, category3
            if f"{cat}_cat{i}" in viewed_counts.columns:
                maindt[category + '_viewed'] += maindt['user_id'].map(viewed_counts[f"{cat}_cat{i}"]).fillna(0).astype(
                    int)

        # Initialize 'bought' column
        maindt[category + '_bought'] = 0

        # Handle bought counts
        for i in range(1, 4):  # Check for category1, category2, category3
            if f"{cat}_cat{i}" in bought_counts.columns:
                maindt[category + '_bought'] += maindt['user_id'].map(bought_counts[f"{cat}_cat{i}"]).fillna(0).astype(
                    int)

    print(f"counts mapped for {batch_file}")

    # Checking results
    print(maindt.head())

    # Optionally drop columns to reduce memory usage
    maindt = maindt.drop(columns=['hour', 'session_start', 'user_id'])

    # Save the processed data for the current batch to a CSV
    output_file = os.path.join('data/processed_batches', f"processed_{batch_file}")
    maindt.to_csv(output_file, index=False)

    print(f"Processed data saved for {batch_file}")

    # Cleanup memory
    del batch_data, maindt, viewed_counts, bought_counts
    gc.collect()

print("All batches processed.")
