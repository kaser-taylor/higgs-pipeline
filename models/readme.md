# Introduction
I am very new to ml and XGBoost has been recommended to me as a framework for this particular use case. As I get more into training this part of the read me will be filled out more

I am going to use the XGBoost framework. I am new to machine learning so this readme will contain my notes and decision making process. I choose the XGBoost framework because of this conversation with GPT 4o https://chatgpt.com/share/687b2540-9938-8003-859a-f8e87a72adf8 

The summary of the conversation is that XGBoost is a classifier framework that is good for beginners and requires little configuration.

Learning XGBoost:

A short GPT class can be found on XGBoost in this convo: https://chatgpt.com/share/687b28d9-da10-8003-b77d-cfe7592c5ea7

# Important Notes

## Validation

For this project, a single train/validation split was used to keep the pipeline simple and reproducible. In a production scenario, cross validation should be implemented. The scope of this project is to produce a data pipeline on AWS. I do believe since the data set is large this split and set of hyperparameters provides a model for this use case.

# Line by Line code explanation train_v1.py

## 6

<!-- This line sets the training and evaluation features (X) and the evaluation and training targets (y) to the output of the data cleaning file found at etl/data_cleaning.py. -->

X_train, X_val, y_train, y_val = load_and_preprocess_data('data_sets/atlas-higgs-challenge-2014-v2.csv')

## 8-9

<!-- We need to convert the output of the data cleaning file which is a dataframe into something called a DMatrix which is XGBoost's preferred format -->

dtrain = xgb.DMatrix(X_train, label=y_train, missing=np.nan)
dval = xgb.DMatrix(X_val, label=y_val, missing=np.nan)

## 11 - 19 

<!-- This sets the parameters for the model.  

objective: binary classification (logistic regression)

eval_metric: AUC (Area Under Curve)

max_depth: tree depth (controls overfitting)

eta: learning rate (how fast to learn)

subsample: row sampling per tree (for regularization)

colsample_bytree: column sampling per tree (for regularization)

seed: reproducibility

-->

<!-- Parameters I needed to learn

subsample: controls what fraction of the rows that XGBoost randomly picks for each new tree it builds. This is done so it gets a new sample of data at each tree level ensuring some level of random data. If it is too random it can be hard to learn so it is best to keep it between 0.7 and 0.9

colsample_bytree: this is similar to subsample but it picks a fraction of the features to train on. this prevents overfitting by ensuring one feature doesn't dominate prediction. .8 is the default starting point
 -->

params = {
    'objective': 'binary:logistic',
    'eval_metric': 'auc',
    'max_depth': 3,
    'eta': 0.1,
    'subsample': 0.8,
    'colsample_bytree': 0.8,
    'seed': 42,
}

## 21

<!-- This created a variable called evallist that is a list containing two touples that track the training and eval data as it trains -->

<!-- XGboost only trains on the training set and then after each round it predicts based on the training set and the evaluation set to gather information like AUC and loss -->

evallist = [(dtrain, 'train'), (dval, 'eval')]

## 23

<!-- This assigns a dictionary to results so we can plot our auc -->

results = {}

## 25-33

<!-- This calls the training function from the XGBoost framework pulling in the parameters, the DMatrix Values, sets the number of training rounds, how many rounds to stop if improvement stagnates, sets train and evaluation sets, and how many rounds to print the metrics  -->

bst = xgb.train(
    params,
    dtrain,
    num_boost_round=1000,
    early_stopping_rounds=50,
    evals=evallist,
    evals_result=results,
    verbose_eval=10
)

## 35 - 41

<!-- GPT generated auc pyplot -->

eval_auc = results['eval']['auc']
plt.plot(eval_auc)
plt.title("Eval AUC Over Training")
plt.xlabel("Boosting Round")
plt.ylabel("AUC")
plt.grid(True)
plt.show()


## 43

<!-- Saves the model into the model_weights folder -->

bst.save_model('/model_weights/xgb_higgs_v1.json')
