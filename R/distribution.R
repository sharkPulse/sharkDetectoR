#' @name sharkDetectoR-package
#' @aliases sharkDetectoR
#' @docType package
#' @title IUCN and Aquamaps Distribution List
#' @description Provides functions to identify Elasmobranch distributions given a sampling coordinate.
#' @details The package allows users to submit a sampling coordinate and receive a list of Elasmobranch species with overlapping distribution shape files.
#' @keywords package
NULL

#' Find species at a given coordinate with a specified radius
#'
#' This function sends a request to the Flask API, which forwards it to the Plumber API,
#' to retrieve species data at the specified location and radius.
#'
#' @param lon Numeric, the longitude of the location.
#' @param lat Numeric, the latitude of the location.
#' @param radius_km Numeric, the radius in kilometers (default is 60).
#' @return A data frame of species present at the location with conditions and probabilities.
#' @examples
#' iucn_list(43, -70)
#' 
#' @export
iucn_list <- function(lat, lon, radius_km = 60) {
  # Construct the URL for the Flask API endpoint
  api_url <- "http://sp2.cs.vt.edu:5000/find_species"
  
  # Define query parameters
  params <- list(
    lon = lon,
    lat = lat,
    radius_km = radius_km
  )
  
  # Submit the GET request
  response <- httr::GET(api_url, query = params)
  
  # Check for errors in the response
  if (httr::status_code(response) != 200) {
    stop("API request failed with status code: ", httr::status_code(response))
  }
  
  # Parse the JSON response and flatten it
  data <- httr::content(response, as = "text", encoding = "UTF-8")
  data <- jsonlite::fromJSON(data, flatten = TRUE)
  
  # Convert to a data frame, ensuring no duplicate columns
  data <- as.data.frame(data)
  
  # Remove duplicated columns (if any)
  data <- data[ , !duplicated(names(data))]

  # Sort the data frame alphabetically by 'species'
  data <- data %>% arrange(species)

  # Move the 'species' column to the first position and sort alphabetically
  if ("species" %in% colnames(data)) {
    data <- data[order(data$species), c("species", setdiff(names(data), "species"))]
  }

  return(data)
}

