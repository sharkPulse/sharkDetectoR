#' Find Elasmobranch Species Within a Bounding Box
#'
#' Calls the Flask API endpoint `/find_species` at \code{http://sharkpulse.cnre.vt.edu}
#' and returns a data.frame of all shark species whose ranges intersect the given bbox,
#' along with IUCN status, Aquamaps probability, FishBase depth, etc.
#'
#' @param xmin Numeric: minimum longitude of bounding box.
#' @param ymin Numeric: minimum latitude of bounding box.
#' @param xmax Numeric: maximum longitude of bounding box.
#' @param ymax Numeric: maximum latitude of bounding box.
#' @return A data.frame with columns:
#'   \itemize{
#'     \item \code{species} (character)
#'     \item \code{iucn_condition} ("Extant" or "Possibly Extant")
#'     \item \code{aquamaps2020_prob} (numeric or NA)
#'     \item \code{category} (IUCN category)
#'     \item \code{DepthRangeComShallow}, \code{DepthRangeComDeep} (numeric or NA)
#'     \item \code{bbox} (list column containing a numeric vector of length 4: xmin, ymin, xmax, ymax)
#'   }
#' @examples
#' \dontrun{
#'   df <- find_species(-98, 18, -80, 30)
#'   print(df)
#' }
#' @export
find_species <- function(xmin, ymin, xmax, ymax) {
  # 1. Input validation
  if (!is.numeric(xmin) || !is.numeric(ymin) ||
      !is.numeric(xmax) || !is.numeric(ymax)) {
    stop("All bbox coordinates (xmin, ymin, xmax, ymax) must be numeric.")
  }
  # 2. Perform GET request
  url <- "http://sharkpulse.cnre.vt.edu/find_species"
  res <- httr::GET(url, query = list(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax))
  if (httr::status_code(res) >= 400) {
    stop("Server error: ", httr::content(res, "text", encoding = "UTF-8"))
  }
  # 3. Parse JSON text via jsonlite::fromJSON to get a data.frame or list
  json_txt <- httr::content(res, as = "text", encoding = "UTF-8")
  parsed <- tryCatch({
    jsonlite::fromJSON(json_txt, simplifyVector = TRUE)
  }, error = function(e) {
    stop("Failed to parse JSON from /find_species: ", conditionMessage(e))
  })
  # 4. If result is empty, return empty data.frame with correct columns
  if (length(parsed) == 0) {
    empty_df <- data.frame(
      species              = character(0),
      iucn_condition       = character(0),
      aquamaps2020_prob    = numeric(0),
      class                = character(0),
      category             = character(0),
      DepthRangeComShallow = numeric(0),
      DepthRangeComDeep    = numeric(0),
      bbox                 = I(list()),
      stringsAsFactors = FALSE
    )
    return(empty_df)
  }
  # 5. If parsed is a data.frame, ensure bbox is a list-column
  if (is.data.frame(parsed)) {
    df <- parsed
    # jsonlite::fromJSON will turn "bbox":[xmin,ymin,xmax,ymax] into a list-column or a matrix.
    # Ensure it's a list of numeric vectors
    if ("bbox" %in% names(df)) {
      # If bbox is a matrix or data.frame with four columns, convert to list column
      if (is.matrix(df$bbox) || is.data.frame(df$bbox)) {
        df$bbox <- lapply(seq_len(nrow(df$bbox)), function(i) as.numeric(df$bbox[i, ]))
      } else if (!is.list(df$bbox)) {
        # If somehow atomic, wrap it
        df$bbox <- lapply(seq_along(df$bbox), function(i) as.numeric(unlist(df$bbox[i])))
      }
    } else {
      # If no bbox column, create a list of the same bbox
      df$bbox <- rep(list(c(xmin, ymin, xmax, ymax)), nrow(df))
    }
    return(df)
  }
  # 6. Otherwise, parsed is likely a list-of-lists; convert to data.frame manually
  if (is.list(parsed) && all(vapply(parsed, is.list, logical(1)))) {
    rows <- lapply(parsed, function(x) {
      # For each element x (a named list), extract fields, making missing -> NA
      species             <- if (!is.null(x$species)) x$species else NA_character_
      iucn_condition      <- if (!is.null(x$iucn_condition)) x$iucn_condition else NA_character_
      aquamaps2020_prob   <- if (!is.null(x$aquamaps2020_prob)) x$aquamaps2020_prob else NA_real_
      class_label         <- if (!is.null(x$class)) x$class else NA_character_
      category            <- if (!is.null(x$category)) x$category else NA_character_
      shallow             <- if (!is.null(x$DepthRangeComShallow)) x$DepthRangeComShallow else NA_real_
      deep                <- if (!is.null(x$DepthRangeComDeep)) x$DepthRangeComDeep else NA_real_
      bbox_vec            <- if (!is.null(x$bbox)) as.numeric(x$bbox) else c(NA_real_, NA_real_, NA_real_, NA_real_)
      data.frame(
        species              = species,
        iucn_condition       = iucn_condition,
        aquamaps2020_prob    = aquamaps2020_prob,
        # class                = class_label,
        category             = category,
        DepthRangeComShallow = shallow,
        DepthRangeComDeep    = deep,
        stringsAsFactors     = FALSE
      ) -> df_row
      df_row$bbox <- list(bbox_vec)
      df_row
    })
    final_df <- do.call(rbind, rows)
    return(final_df)
  }
  stop("Unexpected return type from /find_species endpoint.")
}
