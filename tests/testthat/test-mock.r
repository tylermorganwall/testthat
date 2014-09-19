context("Mock")

test_that("can make 3 = 5", {
  with_mock(
    compare = function(x, y, ...) list(equal = TRUE, message = "TRUE"),
    expect_equal(3, 5)
  )
  expect_that(5, not(equals(3)))
})

test_that("non-empty mock with return value", {
  expect_true(with_mock(
    compare = function(x, y, ...) list(equal = TRUE, message = "TRUE"),
    TRUE
  ))
})

test_that("multi-mock", {
  with_mock(
    gives_warning = throws_error,
    {
      expect_warning(stopifnot(compare(3, 5)$equal))
    }
  )
  expect_warning(warning("test"))
})

test_that("nested mock", {
  with_mock(
    all.equal = function(x, y, ...) TRUE,
    {
      with_mock(
        gives_warning = throws_error,
        {
          expect_warning(stopifnot(!compare(3, 5)$equal))
        }
      )
    },
    .env = asNamespace("base")
  )
  expect_false(isTRUE(all.equal(3, 5)))
  expect_warning(warning("test"))
})

test_that("qualified mock names", {
  with_mock(
    gives_warning = throws_error,
    `base::all.equal` = function(x, y, ...) TRUE,
    {
      expect_warning(stopifnot(!compare(3, 5)$equal))
    }
  )
  with_mock(
    `testthat::gives_warning` = throws_error,
    all.equal = function(x, y, ...) TRUE,
    {
      expect_warning(stopifnot(!compare(3, 5)$equal))
    },
    .env = asNamespace("base")
  )
  expect_false(isTRUE(all.equal(3, 5)))
  expect_warning(warning("test"))
})

test_that("can't mock non-existing", {
  expect_error(with_mock(`base::..bogus..` = identity, TRUE), "Function [.][.]bogus[.][.] not found in environment base")
  expect_error(with_mock(..bogus.. = identity, TRUE), "Function [.][.]bogus[.][.] not found in environment testthat")
})

test_that("can't mock non-function", {
  expect_error(with_mock(.bg_colours = FALSE, TRUE), "Function [.]bg_colours not found in environment testthat")
})

test_that("empty or no-op mock", {
  suppressWarnings({
    expect_that(with_mock(), equals(invisible(NULL)))
    expect_that(with_mock(TRUE), equals(TRUE))
    expect_that(with_mock(invisible(5)), equals(invisible(5)))
  })

  expect_that(with_mock(), gives_warning("Not mocking anything."))
  expect_that(with_mock(TRUE), gives_warning("Not mocking anything."))
  expect_that(with_mock(invisible(5)), gives_warning("Not mocking anything."))
})

test_that("multiple return values", {
  expect_true(with_mock(FALSE, TRUE, `base::identity` = identity))
  expect_equal(with_mock(3, `base::identity` = identity, 5), 5)
})

test_that("can access variables defined in function", {
  x <- 5
  suppressWarnings(expect_equal(with_mock(x), 5))
})

test_that("can mock both qualified and unqualified functions", {
  expect_identical(with_mock(`stats::acf` = identity, stats::acf), identity)
  expect_identical(with_mock(`stats::acf` = identity, acf), identity)
  expect_identical(with_mock(acf = identity, stats::acf, .env = "stats"), identity)
  expect_identical(with_mock(acf = identity, acf, .env = "stats"), identity)
})

test_that("can mock hidden functions", {
  expect_identical(with_mock(`stats:::add1.default` = identity, stats:::add1.default), identity)
})

test_that("can mock if package is not loaded", {
  expect_false("package:devtools" %in% search())
  expect_identical(with_mock(`devtools::add_path` = identity, devtools::add_path), identity)
})

test_that("changes to variables are preserved between calls and visible outside", {
  x <- 1
  with_mock(
    `base::identity` = identity,
    x <- 3,
    expect_equal(x, 3)
  )
  expect_equal(x, 3)
})

test_that("currently cannot mock function imported from other package", {
  expect_true("setRefClass" %in% getNamespaceImports("testthat")[["methods"]])
  expect_error(with_mock(`testthat::setRefClass` = identity, setRefClass))
})

test_that("mock extraction", {
  expect_equal(extract_mocks(list(identity = identity), asNamespace("base"))$identity$name, "identity")
  expect_error(extract_mocks(list(..bogus.. = identity), asNamespace("base")),
               "Function [.][.]bogus[.][.] not found in environment base")
  expect_equal(extract_mocks(list(`base::identity` = identity), NULL)[[1]]$name, "identity")
  expect_equal(extract_mocks(list(`base::identity` = identity), NULL)[[1]]$envs, list(asNamespace("base"), as.environment("package:base")))
  expect_equal(extract_mocks(list(identity = stop), "base")[[1]]$envs, list(asNamespace("base"), as.environment("package:base")))
  expect_equal(extract_mocks(list(identity = stop), asNamespace("base"))[[1]]$envs, list(asNamespace("base"), as.environment("package:base")))
  expect_equal(extract_mocks(list(`base::identity` = stop), NULL)[[1]]$orig_value, identity)
  expect_equal(extract_mocks(list(`base::identity` = stop), NULL)[[1]]$new_value, stop)
  expect_equal(extract_mocks(list(`base::identity` = stop), "stats")[[1]]$new_value, stop)
  expect_equal(extract_mocks(list(acf = identity), "stats")[[1]]$new_value, identity)
  expect_equal(length(extract_mocks(list(not = identity, `base::!` = identity), "testthat")), 2)
})