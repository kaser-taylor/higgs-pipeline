# Introduction:
This folder contains the dataset 

# Prepping the data: 

I obtained the data from the CERN Open data portal at this link https://opendata.cern.ch/record/328 

the data is downloaded in a .csv.gz package and needs to be unpacked properly. Finder on my mac struggled with this so here is the terminal command I used gunzip yourfile.csv.gz

# Extracting and inspecting the data:

So it looks like I need to look for missing values and this is known something as the missing value sentinel and looks like a -999.000 GPT says xgboost can handle these internally but its best to convert them to a np nan

import pandas as pd

<!-- # A pandas datafram is a pandas version of a table -->
df = pd.read_csv('atlas-higgs-challenge-2014-v2.csv')

print(df.shape)
print(df.head())
print(df.info())

# Cleaning the data

First we need to convert the missing values to np nans

import pandas as pd
import numpy as np

<!-- # A pandas dataframe is a pandas version of a table -->
df = pd.read_csv('atlas-higgs-challenge-2014-v2.csv')

print(df.shape)
print(df.head())
print(df.info())

<!-- # the parameters mean replace all -999.0 with a np nan inplace in the dataframe so it does not return a copy -->
df.replace(-999.0, np.nan, inplace=True)

<!-- # sums up, sorts the data beforehand, and reports the top 10 columns with missing numbers -->
print(df.isna().sum().sort_values(ascending=False).head(10))

I am choosing not to impute the data because missing feature data can still be predictive in this case scenario 

Next we need to encode the target value.

<!-- so this creates a new column called target and sets it equal to the dataframe value from label. If 's' is true then it sets target to one -->
df['target'] = (df['Label'] == 's').astype(int)

# Splitting the training and test sets

<!-- so this creates a dataframe for training if the original dataframe column value kaggle set is == to t for train. The df['KaggleSet'] == 't' spits out a boolean series of values and then df of that snags all the df values where that is true. This is called pandas row filtering boolean mask-->
train_df = df[df['KaggleSet'] == 't'].copy()

<!--Now we need to setup our features and target. This sets two values equal to to dataframes corresponding to the input fetures and the target answer -->

X = train_df.drop(columns=['EventId', 'Label', 'target', 'KaggleSet', 'KaggleWeight'])

y = train_df['target']

# Data Cleaning for model train_v2.py

# train_v2.py CHANGES AND EXPLANATIONS

So a problem I ran into a problem where the real data set I identified uses the PHYS_LITE format. This format does not contain the DER_mass_MMC and the PRI_tau_pt features that the simulated ATLAS DATA has. The option that I believe is most within my skill set is to attempt dropping those features from the simulated data and retraining the model.

# Cleaning Root Files

1. Read the file keys
2. Our features are stored in CollectionTree;1
3. There are so many keys

