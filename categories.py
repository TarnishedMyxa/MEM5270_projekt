import pandas as pd
import numpy as np

#chagne for prod data
ANDMED="data/testdata.csv"



# pandas print table params
pd.set_option('display.max_columns', None)
pd.set_option('display.expand_frame_repr', False)
pd.set_option('display.width', 1000)


dt=pd.read_csv(ANDMED)


# Split the 'category_code' column into three separate columns
split_categories = dt['category_code'].str.split('.', expand=True)
split_categories = split_categories.reindex(columns=[0, 1, 2])

# Assign the split columns to the original DataFrame
dt[['category1', 'category2', 'category3']] = split_categories.reindex(columns=[0, 1, 2])


# Create DataFrame with unique categories for category1, category2, and category3
unique_category1 = pd.DataFrame(dt['category1'].unique(), columns=['category'])
unique_category2 = pd.DataFrame(dt['category2'].unique(), columns=['category'])
unique_category3 = pd.DataFrame(dt['category3'].unique(), columns=['category'])

# Add prefix to each category indicating its level
unique_category1['category'] = '1_' + unique_category1['category'].astype(str)
unique_category2['category'] = '2_' + unique_category2['category'].astype(str)
unique_category3['category'] = '3_' + unique_category3['category'].astype(str)

# append all unique categories into one column
unique_categories = pd.concat([unique_category1, unique_category2, unique_category3], axis=0)

# save to excel
unique_categories.to_excel('unique_categories.xlsx', index=False)

