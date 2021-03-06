% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/find_events.R
\name{find_events}
\alias{find_events}
\title{Find events by meetup groups}
\usage{
find_events(
  query = NULL,
  n_offsets = 10,
  topic_category = NULL,
  lat = NULL,
  lon = NULL,
  radius = NULL,
  start_date_range = NULL,
  end_date_range = NULL,
  fields = NULL,
  excluded_groups = NULL,
  order = NULL,
  api_key = NULL
)
}
\arguments{
\item{query}{Character. Raw full text search query.}

\item{n_offsets}{Numeric. Number of offsets to ask for from the API.}

\item{topic_category}{Character vector}

\item{lat}{Approximate target latitude}

\item{lon}{Approximate target longitude}

\item{radius}{Radius (in miles) to search from the center of \code{lat, lon}}

\item{start_date_range}{Character. Start date range for events to return (format: YYYY-MM-DDTHH:MM:SS)}

\item{end_date_range}{Character. End date range for events to return (format: YYYY-MM-DDTHH:MM:SS)}

\item{fields}{Extra optional fields to populate in the response}

\item{excluded_groups}{IDs for groups to exclude from the returned events}

\item{order}{One of "best" or "time". The sort order of returned events. "best" orders events by recommendation score, while "time" orders events by the by the event's start time in increasing order. Defaults to "best."}

\item{api_key}{Character. Your api key. Defaults to checking your environment
for a parameter called "MEETUP_KEY" via \code{Sys.getenv("MEETUP_KEY")}. This key can be
obtained from \url{https://secure.meetup.com/meetup_api/key/}. To set the environment variable
run \code{Sys.setenv(MEETUP_KEY = "PASTE YOUR MEETUP KEY HERE")}.}
}
\value{
A tibble with columns prefixed with \code{event_}, \code{venue_}, and \code{group}
}
\description{
Provide a search query, a latitude + longitude combination, and/or \code{topic_category} values to find events
}
\examples{
\dontrun{
ll <- get_locations("New York City")
find_events(lat = ll$lat, lon = ll$lon, radius = 10, query = "ultimate frisbee")

topics <- get_topics()
mvmt_ids <- topics \%>\%
  dplyr::filter(name == "Movements") \%>\%
  dplyr::pull(category_ids)

find_events(lat = ll$lat, lon = ll$lon, radius = 10, topic_category = mvmt_ids)
}
}
