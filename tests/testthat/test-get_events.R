test_that("get_events() success case", {
  withr::local_options(list(meetupr.use_oauth = FALSE))
  set_api_key("yay")

  meetup_events <- with_mock(
    `httr::GET` = function(url, query, ...) {
      load(test_path("testdata/httr_get_get_events.rda"))
      return(req)
    },
    meetup_events <- get_events(
      api_key = "yay",
      urlname = "<3",
      event_status = "upcoming"
    )
  )

  expect_equal(nrow(meetup_events), 1, label = "check get_events() returns one result")
  expect_equal(meetup_events$status, "upcoming", label = "check get_events() content (status)")
})

# TODO: multiple statuses

# TODO: event type is not allowed

# TODO: "urlname is missing"
