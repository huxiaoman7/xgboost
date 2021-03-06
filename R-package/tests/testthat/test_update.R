require(xgboost)

context("update trees in an existing model")

data(agaricus.train, package = 'xgboost')
data(agaricus.test, package = 'xgboost')
dtrain <- xgb.DMatrix(agaricus.train$data, label = agaricus.train$label)
dtest <- xgb.DMatrix(agaricus.test$data, label = agaricus.test$label)

test_that("updating the model works", {
  watchlist = list(train = dtrain, test = dtest)
  cb = list(cb.evaluation.log()) # to run silent, but store eval. log
  
  # no-subsampling
  p1 <- list(objective = "binary:logistic", max_depth = 2, eta = 0.05, nthread = 2)
  set.seed(11)
  bst1 <- xgb.train(p1, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb)
  tr1 <- xgb.model.dt.tree(model = bst1)
  
  # with subsampling
  p2 <- modifyList(p1, list(subsample = 0.1))
  set.seed(11)
  bst2 <- xgb.train(p2, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb)
  tr2 <- xgb.model.dt.tree(model = bst2)
  
  # the same no-subsampling boosting with an extra 'refresh' updater:
  p1r <- modifyList(p1, list(updater = 'grow_colmaker,prune,refresh', refresh_leaf = FALSE))
  set.seed(11)
  bst1r <- xgb.train(p1r, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb)
  tr1r <- xgb.model.dt.tree(model = bst1r)
  # all should be the same when no subsampling
  expect_equal(bst1$evaluation_log, bst1r$evaluation_log)
  expect_equal(tr1, tr1r, tolerance = 0.00001, check.attributes = FALSE)

  # the same boosting with subsampling with an extra 'refresh' updater:
  p2r <- modifyList(p2, list(updater = 'grow_colmaker,prune,refresh', refresh_leaf = FALSE))
  set.seed(11)
  bst2r <- xgb.train(p2r, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb)
  tr2r <- xgb.model.dt.tree(model = bst2r)
  # should be the same evaluation but different gains and larger cover
  expect_equal(bst2$evaluation_log, bst2r$evaluation_log)
  expect_equal(tr2[Feature == 'Leaf']$Quality, tr2r[Feature == 'Leaf']$Quality)
  expect_gt(sum(abs(tr2[Feature != 'Leaf']$Quality - tr2r[Feature != 'Leaf']$Quality)), 100)
  expect_gt(sum(tr2r$Cover) / sum(tr2$Cover), 1.5)

  # process type 'update' for no-subsampling model, refreshing the tree stats AND leaves from training data:
  p1u <- modifyList(p1, list(process_type = 'update', updater = 'refresh', refresh_leaf = TRUE))
  bst1u <- xgb.train(p1u, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb, xgb_model = bst1)
  tr1u <- xgb.model.dt.tree(model = bst1u)
  # all should be the same when no subsampling
  expect_equal(bst1$evaluation_log, bst1u$evaluation_log)
  expect_equal(tr1, tr1u, tolerance = 0.00001, check.attributes = FALSE)
  
  # process type 'update' for model with subsampling, refreshing only the tree stats from training data:
  p2u <- modifyList(p2, list(process_type = 'update', updater = 'refresh', refresh_leaf = FALSE))
  bst2u <- xgb.train(p2u, dtrain, nrounds = 10, watchlist, verbose = 0, callbacks = cb, xgb_model = bst2)
  tr2u <- xgb.model.dt.tree(model = bst2u)
  # should be the same evaluation but different gains and larger cover
  expect_equal(bst2$evaluation_log, bst2u$evaluation_log)
  expect_equal(tr2[Feature == 'Leaf']$Quality, tr2u[Feature == 'Leaf']$Quality)
  expect_gt(sum(abs(tr2[Feature != 'Leaf']$Quality - tr2u[Feature != 'Leaf']$Quality)), 100)
  expect_gt(sum(tr2u$Cover) / sum(tr2$Cover), 1.5)
  # the results should be the same as for the model with an extra 'refresh' updater
  expect_equal(bst2r$evaluation_log, bst2u$evaluation_log)
  expect_equal(tr2r, tr2u, tolerance = 0.00001, check.attributes = FALSE)
  
  # process type 'update' for no-subsampling model, refreshing only the tree stats from TEST data:
  p1ut <- modifyList(p1, list(process_type = 'update', updater = 'refresh', refresh_leaf = FALSE))
  bst1ut <- xgb.train(p1ut, dtest, nrounds = 10, watchlist, verbose = 0, callbacks = cb, xgb_model = bst1)
  tr1ut <- xgb.model.dt.tree(model = bst1ut)
  # should be the same evaluations but different gains and smaller cover (test data is smaller)
  expect_equal(bst1$evaluation_log, bst1ut$evaluation_log)
  expect_equal(tr1[Feature == 'Leaf']$Quality, tr1ut[Feature == 'Leaf']$Quality)
  expect_gt(sum(abs(tr1[Feature != 'Leaf']$Quality - tr1ut[Feature != 'Leaf']$Quality)), 100)
  expect_lt(sum(tr1ut$Cover) / sum(tr1$Cover), 0.5)
})
