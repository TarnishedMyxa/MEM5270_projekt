import pandas as pd
import numpy as np

# Change for prod data
ANDMED = "data/2019-Oct.csv"
analysis_category = 2053013555631882655  # for now only category, TODO: add product to be analyzed

# Pandas print table params
pd.set_option('display.max_columns', None)
pd.set_option('display.expand_frame_repr', False)
pd.set_option('display.width', 1000)

# Load data
dt = pd.read_csv(ANDMED, parse_dates=['event_time'])
dt['event_time'] = pd.to_datetime(dt['event_time'], utc=True)
print("data read")


# Drop rows for all event types except 'view' and 'purchase'
dt = dt[dt.event_type.isin(['view', 'purchase'])]

# Split the 'category_code' column into three separate columns
split_categories = dt['category_code'].str.split('.', expand=True)
split_categories = split_categories.reindex(columns=[0, 1, 2])

# Assign the split columns to the original DataFrame
dt[['category1', 'category2', 'category3']] = split_categories.reindex(columns=[0, 1, 2])

# Replace NaN categories with 'None'
dt[['category1', 'category2', 'category3']] = dt[['category1', 'category2', 'category3']].fillna('None')


print("categories split")


# Get unique sessions
unique_sessions = dt['user_session'].unique()

# Get the buy rows of the analysis category
buy_rows = dt[(dt.event_type == 'purchase') & (dt.category_id == analysis_category)]

# Get the unique sessions of the buy rows
unique_sessions_buy = buy_rows['user_session'].unique()

# Add bought column to the main data
maindt = pd.DataFrame(unique_sessions, columns=['user_session'])
maindt['bought'] = np.where(maindt['user_session'].isin(unique_sessions_buy), 1, 0)

# Add user_id to the main data
maindt = maindt.merge(dt[['user_session', 'user_id']], on='user_session', how='left')

# Add first time to main data
first_time = dt.groupby('user_session')['event_time'].min()
maindt['session_start'] = maindt['user_session'].map(first_time)

# add column day_phase to main data (morning, afternoon, evening, night)
# Extract the hour from the 'session_start' column
maindt['hour'] = maindt['session_start'].dt.hour

print("main data created")

# Add 'day_phase' column based on the hour using pd.cut()
maindt['day_phase'] = pd.cut(maindt['hour'], bins=[-1, 6, 12, 18, 24], labels=['night', 'morning', 'afternoon', 'evening'], right=True)

# create 3 numeric dummy columns for day_phase
maindt = pd.get_dummies(maindt, columns=['day_phase'], drop_first=True)

print("day_phase added")


# Add 'day_of_week' column to main data
maindt['day_of_week'] = maindt['session_start'].dt.day_name()

# Create dummy columns for 'day_of_week'
maindt = pd.get_dummies(maindt, columns=['day_of_week'], drop_first=True)

print("day_of_week added")

# Create DataFrame with unique categories for category1, category2, and category3
unique_category1 = pd.DataFrame(dt['category1'].unique(), columns=['category'])
unique_category2 = pd.DataFrame(dt['category2'].unique(), columns=['category'])
unique_category3 = pd.DataFrame(dt['category3'].unique(), columns=['category'])

# Add prefix to each category indicating its level
unique_category1['category'] = '1_' + unique_category1['category'].astype(str)
unique_category2['category'] = '2_' + unique_category2['category'].astype(str)
unique_category3['category'] = '3_' + unique_category3['category'].astype(str)

# Append all unique categories into one column
unique_categories = pd.concat([unique_category1, unique_category2, unique_category3], axis=0)
unique_categories['category'] = unique_categories['category'].fillna('None')

print("categories done")

# Create DataFrame with unique categories for category1, category2, and category3
unique_category1 = pd.DataFrame(dt['category1'].unique(), columns=['category'])
unique_category2 = pd.DataFrame(dt['category2'].unique(), columns=['category'])
unique_category3 = pd.DataFrame(dt['category3'].unique(), columns=['category'])

# Add prefix to each category indicating its level
unique_category1['category'] = '1_' + unique_category1['category'].astype(str)
unique_category2['category'] = '2_' + unique_category2['category'].astype(str)
unique_category3['category'] = '3_' + unique_category3['category'].astype(str)

# Append all unique categories into one column
unique_categories = pd.concat([unique_category1, unique_category2, unique_category3], axis=0)
unique_categories['category'] = unique_categories['category'].fillna('None')


print("new columns added")

# Add suffixes to category levels to make them unique
viewed_counts1 = dt[dt.event_type == 'view'].groupby(['user_id', 'category1']).size().unstack(fill_value=0)
viewed_counts1 = viewed_counts1.add_suffix('_cat1')

print("1/6")

bought_counts1 = dt[dt.event_type == 'purchase'].groupby(['user_id', 'category1']).size().unstack(fill_value=0)
bought_counts1 = bought_counts1.add_suffix('_cat1')

print("2/6")

viewed_counts2 = dt[dt.event_type == 'view'].groupby(['user_id', 'category2']).size().unstack(fill_value=0)
viewed_counts2 = viewed_counts2.add_suffix('_cat2')

print("3/6")

bought_counts2 = dt[dt.event_type == 'purchase'].groupby(['user_id', 'category2']).size().unstack(fill_value=0)
bought_counts2 = bought_counts2.add_suffix('_cat2')

print("4/6")

viewed_counts3 = dt[dt.event_type == 'view'].groupby(['user_id', 'category3']).size().unstack(fill_value=0)
viewed_counts3 = viewed_counts3.add_suffix('_cat3')

print("5/6")

bought_counts3 = dt[dt.event_type == 'purchase'].groupby(['user_id', 'category3']).size().unstack(fill_value=0)
bought_counts3 = bought_counts3.add_suffix('_cat3')

print("6/6")

# Combine all counts into single DataFrames for viewed and bought
viewed_counts = pd.concat([viewed_counts1, viewed_counts2, viewed_counts3], axis=1, copy=False)
bought_counts = pd.concat([bought_counts1, bought_counts2, bought_counts3], axis=1, copy=False)

print("counts added")

maindt = maindt.drop_duplicates()

# Now, you can map the actual counts for each category in a more optimized way
for category in unique_categories['category']:
    cat = category[2:]  # Remove the prefix if needed (adjust this if necessary)

    # Initialize 'viewed' column
    maindt[category + '_viewed'] = 0

    # Handle viewed counts
    for i in range(1, 4):  # Check for category1, category2, category3
        if f"{cat}_cat{i}" in viewed_counts.columns:
            maindt[category + '_viewed'] += maindt['user_id'].map(viewed_counts[f"{cat}_cat{i}"]).fillna(0).astype(int)

    # Initialize 'bought' column
    maindt[category + '_bought'] = 0

    # Handle bought counts
    for i in range(1, 4):  # Check for category1, category2, category3
        if f"{cat}_cat{i}" in bought_counts.columns:
            maindt[category + '_bought'] += maindt['user_id'].map(bought_counts[f"{cat}_cat{i}"]).fillna(0).astype(int)

print("counts mapped")


# Checking results
print(maindt.head())

#drop the event_time column
#maindt = maindt.drop(columns=['session_start', 'hour', 'user_id'])


print(maindt.shape)

# Save the main data to an Excel file
#maindt.to_excel('data/maindt.xlsx', index=False)

# save to csv
maindt.to_csv('data/maindt.csv', index=False)


print("ready")
