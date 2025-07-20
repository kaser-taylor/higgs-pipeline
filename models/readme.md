I am going to use the XGboost framework. I am new to machine learning so this readme will contain my notes and decision making process. I choose the XGboost framework because of this conversation with GPT 4o https://chatgpt.com/share/687b2540-9938-8003-859a-f8e87a72adf8 

The summary of the conversation is that XGboost is a classifier framework that is good for beginners and requires little configuration.

# ENV SET UP:
1. python3 -m venv .venv
2. source .venv/bin/activate (deactivate to exit)
3. pip install xgboost pandas scikit-learn


# Prepping the data: 

I obtained the data from the CERN Open data portal at this link https://opendata.cern.ch/record/328 

I have chosen to do the etl in a .gitignore file so I'm not pushing it all to github

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

<!-- left off on step 4 with the validation set scikit learn stuff Data prep for xgboost chat
-->

Learning XGboost:

A short GPT class can be found on XGboost in this convo: https://chatgpt.com/share/687b28d9-da10-8003-b77d-cfe7592c5ea7


Left off on step 3: https://chatgpt.com/g/g-p-686cc80afa788191ada3c976fab120f8-data-pipeline/c/687b2a1d-61c4-8003-80a9-4f77524dbaf5 