# Wrapper for messages, spotted in googlesheets3
spf <- function(...) stop(sprintf(...), call. = FALSE)

# This helper function makes a single call, given the full API endpoint URL
# Used as the workhorse function inside .fetch_results() below
.quick_fetch <- function(api_url,
                         url_full = NULL,
                         api_key = NULL, # deprecated, unused, can't swallow this in `...`
                         event_status = NULL,
                         offset = 0,
                         ...) {

  url <- api_url %||% url_full

  # list of parameters
  parameters <- list(
    status = event_status, # you need to add the status
    # otherwise it will get only the upcoming event
    offset = offset,
    ... # other parameters
  )

  # Only need API keys if OAuth is disabled...
  if (!getOption("meetupr.use_oauth")) {
    parameters <- append(parameters, list(key = get_api_key()))
  }

  req <- httr::GET(
    url = url, # the endpoint or full url
    query = parameters,
    config = meetup_token()
  )

  if (req$status_code == 400) {
    stop(paste0(
      "HTTP 400 Bad Request error encountered for: ",
      api_url, ".\n As of June 30, 2020, this may be ",
      "because a presumed bug with the Meetup API ",
      "causes this error for a future event. Please ",
      "confirm the event has ended."
    ),
    call. = FALSE
    )
  }

  httr::stop_for_status(req)
  reslist <- httr::content(req, "parsed")

  if (length(reslist) == 0) {
    stop("Zero records match your filter. Nothing to return.\n",
      call. = FALSE
    )
  }

  return(list(result = reslist, headers = req$headers))
}

.fetch_events <- function(api_method, api_key = NULL, event_status = NULL, n_offsets = 10, ...) {
  # Build the API endpoint URL
  meetup_api_prefix <- "https://api.meetup.com/"
  api_url <- paste0(meetup_api_prefix, api_method)

  o <- 0

  # Fetch first set of results (limited to 200 records each call)
  raw <- .quick_fetch(
    api_url = api_url,
    api_key = api_key,
    event_status = event_status,
    offset = o,
    ...
  )

  if (length(raw$result$events) == 0) {
    return(tibble::tibble())
  }

  out <-
    raw$result$events %>%
    purrr::map(.wrangle_event) %>%
    dplyr::bind_rows() %>%
    dplyr::mutate(offset = o)

  more_content <- TRUE

  while (more_content && o < n_offsets) {
    o %<>% `+`(1)

    raw <-
      .quick_fetch(
        api_url = NULL,
        url_full = raw$headers$link %>% gsub(";.*", "", .) %>% gsub("[<>]", "", .),
        api_key = api_key,
        event_status = event_status,
        offset = o,
        ...
      )

    if (length(raw$result$events) > 0) {
      this <-
        raw$result$events %>%
        purrr::map(.wrangle_event) %>%
        dplyr::bind_rows() %>%
        dplyr::mutate(offset = o)
    } else {
      this <- tibble::tibble()
      more_content <- FALSE
    }

    out %<>% dplyr::bind_rows(this)
  }

  out
}

# Fetch all the results of a query given an API Method
# Will make multiple calls to the API if needed
# API Methods listed here: https://www.meetup.com/meetup_api/docs/
.fetch_results <- function(api_method, api_key = NULL, event_status = NULL, ...) {

  # Build the API endpoint URL
  meetup_api_prefix <- "https://api.meetup.com/"
  api_url <- paste0(meetup_api_prefix, api_method)

  # Fetch first set of results (limited to 200 records each call)

  res <- .quick_fetch(
    api_url = api_url,
    api_key = api_key,
    event_status = event_status,
    offset = 0,
    ...
  )

  # Total number of records matching the query
  total_records <- as.integer(res$headers$`x-total-count`)
  if (length(total_records) == 0) total_records <- 1L
  records <- res$result
  cat(paste("Downloading", total_records, "record(s)..."))

  if ((length(records) < total_records) & !is.null(res$headers$link)) {

    # calculate number of offsets for records above 200
    offsetn <- ceiling(total_records / length(records))
    all_records <- list(records)

    for (i in 1:(offsetn - 1)) {
      res <- .quick_fetch(
        api_url = api_url,
        api_key = api_key,
        event_status = event_status,
        offset = i,
        ...
      )

      next_url <- strsplit(strsplit(res$headers$link, split = "<")[[1]][2], split = ">")[[1]][1]
      res <- .quick_fetch(next_url, event_status)

      all_records[[i + 1]] <- res$result
    }
    records <- unlist(all_records, recursive = FALSE)
  }

  return(records)
}


# helper function to convert a vector of milliseconds since epoch into POSIXct
.date_helper <- function(time) {
  if (is.character(time)) {
    # if date is character string, try to convert to numeric
    time <- tryCatch(
      expr = as.numeric(time),
      error = warning("One or more dates could not be converted properly")
    )
  }
  if (is.numeric(time)) {
    # divide milliseconds by 1000 to get seconds; convert to POSIXct
    seconds <- time / 1000
    out <- as.POSIXct(seconds, origin = "1970-01-01")
  } else {
    # if no conversion can be done, then return NA
    warning("One or more dates could not be converted properly")
    out <- rep(NA, length(time))
  }
  return(out)
}

# Turn a datetime into format Meetup wants
.fix_dt <- function(x) {
  x %>% gsub(" ", "T", .)
}

.wrangle_event <- function(x) {

  # These contain their own sub-lists
  fee_idx <- which(names(x) == "fee")
  venue_idx <- which(names(x) == "venue")
  group_idx <- which(names(x) == "group")

  event <-
    x[-c(fee_idx, venue_idx, group_idx)] %>%
    tibble::as_tibble() %>%
    dplyr::rename_all(
      ~ paste0("event_", .)
    )

  fee <-
    x$fee %>%
    tibble::as_tibble() %>%
    dplyr::rename_all(
      ~ paste0("fee_", .)
    )

  venue <-
    x$venue %>%
    tibble::as_tibble() %>%
    dplyr::rename_all(
      ~ paste0("venue_", .)
    )

  group <-
    x$venue %>%
    tibble::as_tibble() %>%
    dplyr::rename_all(
      ~ paste0("group_", .)
    )

  event %>%
    dplyr::bind_cols(venue) %>%
    dplyr::bind_cols(group)
}

.wrangle_topic <- function(x) {
  photo_idx <- which(names(x) == "photo")

  x[-photo_idx] %>%
    tibble::as_tibble() %>%
    tidyr::unnest(category_ids)
}
