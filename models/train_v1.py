import matplotlib.pyplot as plt
import numpy as np
import xgboost as xgb

from etl.data_cleaning_simulated_data import load_and_preprocess_data

X_train, X_val, y_train, y_val = load_and_preprocess_data(
    "data_sets/atlas-higgs-challenge-2014-v2.csv"
)

dtrain = xgb.DMatrix(X_train, label=y_train, missing=np.nan)
dval = xgb.DMatrix(X_val, label=y_val, missing=np.nan)

params = {
    "objective": "binary:logistic",
    "eval_metric": "auc",
    "max_depth": 3,
    "eta": 0.1,
    "subsample": 0.8,
    "colsample_bytree": 0.8,
    "seed": 42,
}

evallist = [(dtrain, "train"), (dval, "eval")]

results = {}

bst = xgb.train(
    params,
    dtrain,
    num_boost_round=10000,
    early_stopping_rounds=50,
    evals=evallist,
    evals_result=results,
    verbose_eval=10,
)

eval_auc = results["eval"]["auc"]
plt.plot(eval_auc)
plt.title("Eval AUC Over Training")
plt.xlabel("Boosting Round")
plt.ylabel("AUC")
plt.grid(True)
plt.show()

# bst.save_model('model_weights/xgb_higgs_v1.json')
