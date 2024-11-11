#' @name sharkDetectoR-package
#' @aliases sharkDetectoR
#' @docType package
#' @title IUCN and Aquamaps Distribution List
#' @description Provides functions to identify Elasmobranch distributions given a sampling coordinate.
#' @details The package allows users to submit a sampling coordinate and receive a list of Elasmobranch species with overlapping distribution shape files.
#' @keywords package
NULL

#' Find species within a specified bounding box
#'
#' This function sends a request to the Flask API, which forwards it to the Plumber API,
#' to retrieve species data within the specified bounding box.
#'
#' @param xmin Numeric, minimum longitude of the bounding box.
#' @param ymin Numeric, minimum latitude of the bounding box.
#' @param xmax Numeric, maximum longitude of the bounding box.
#' @param ymax Numeric, maximum latitude of the bounding box.
#' @return A data frame of species present within the bounding box with conditions and probabilities.
#' @examples
#' result = iucn_list(-70, 40, -69, 41)
#' 
#' @export
iucn_list <- function(xmin, ymin, xmax, ymax) {
  # Construct the URL for the Flask API endpoint
  api_url <- "http://sp2.cs.vt.edu:5000/find_species"
  
  # Define query parameters
  params <- list(
    xmin = xmin,
    ymin = ymin,
    xmax = xmax,
    ymax = ymax
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

  # Move the 'species' column to the first position and sort alphabetically
  if ("species" %in% colnames(data)) {
    data <- data[order(data$species), c("species", setdiff(names(data), "species"))]
  }

  # Remove row names by setting them to NULL
  row.names(data) <- NULL

  return(data)
}

