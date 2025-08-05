import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split


def load_and_preprocess_data(csv_path):

    # A pandas datafram is a pandas version of a table
    df = pd.read_csv(csv_path)

    print(df.shape)
    print(df.head())
    print(df.info())

    # the parameters mean replace all -999.0 with a np nan inplace in the dataframe so it does not return a copy
    df.replace(-999.0, np.nan, inplace=True)

    # sums up, sorts the data beforehand, and reports the top 10 columns with missing numbers
    print(df.isna().sum().sort_values(ascending=False).head(10))

    #encodes the target

    df['target'] = (df['Label'] == 's').astype(int)

    #filter out training rows
    train_df = df[df['KaggleSet'] == 't'].copy()

    # set our features and target data

    X = train_df.drop(columns=['EventId', 'Label', 'target', 'KaggleSet', 'KaggleWeight', 'Weight', 'DER_mass_MMC', 'DER_met_phi_centrality', 'PRI_tau_pt', 'PRI_tau_eta', 'PRI_tau_phi', 'PRI_met_sumet'])

    y = train_df['target']

    #Sci-kit learn split 

    return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

def print_col():
    df = pd.read_csv('data_sets/atlas-higgs-challenge-2014-v2.csv')

    print(df.columns)

