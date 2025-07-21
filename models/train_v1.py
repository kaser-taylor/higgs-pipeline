import xgboost as xgb
from etl.data_cleaning import load_and_preprocess_data
import numpy as np

X_train, X_val, y_train, y_val = load_and_preprocess_data('data_sets/atlas-higgs-challenge-2014-v2.csv')

dtrain = xgb.DMatrix(X_train, label=y_train, missing=np.nan)
dval = xgb.DMatrix(X_val, label=y_val, missing=np.nan)

params = {
    'objective': 'binary:logistic',
    'eval_metric': 'auc',
    'max_depth': 3,
    'eta': 0.1,
    'subsample': 0.8,
    'colsample_bytree': 0.8,
    'seed': 42,
}

evallist = [(dtrain, 'train'), (dval, 'eval')]

bst = xgb.train(
    params,
    dtrain,
    num_boost_round=500,
    early_stopping_rounds=50,
    evals=evallist,
    verbose_eval=10
)