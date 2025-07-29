#' Submit a single image for shark detection (YOLO) only
#'
#' Calls the Flask API endpoint `/detect_image` at \code{http://sharkpulse.cnre.vt.edu}.
#' Returns a data frame of all detected bounding boxes (xmin, ymin, xmax, ymax), detection score,
#' and class label (character: "shark" when label == 0). Optionally downloads annotated and/or
#' cropped images into \code{save_dir}/images. The returned filenames are base names only.
#'
#' @param image_path    Path to a local image file (JPEG/PNG).
#' @param threshold     Numeric in [0,1] controlling YOLO‐confidence threshold. Default = 0.25.
#' @param draw_boxes    Logical; if TRUE, the server will draw boxes and return an annotated image path.
#'                      If set, this function will also download that annotated image (base name only).
#' @param crop          Logical; if TRUE, the server will return all cropped shark patches;
#'                      if set, this function downloads each patch (base names only).
#' @param save_dir      Character; directory where downloaded images are saved. Default = `"./"`.
#'                      A subfolder `"images"` will be created under it if it does not already exist.
#' @return A data frame with columns:
#'   \itemize{
#'     \item \code{xmin, ymin, xmax, ymax} – bounding‐box coordinates (numeric).
#'     \item \code{score}           – detection confidence (numeric).
#'     \item \code{label}           – character: `"shark"` for label==0.
#'     \item \code{annotated_image} – base name of downloaded annotated image, or NA.
#'     \item \code{cropped_images}  – list‐column of base names of downloaded cropped patches, or an empty character vector.
#'   }
#' @examples
#' \dontrun{
#'   df <- detect_image(
#'     image_path = "shark.jpg",
#'     threshold  = 0.5,
#'     draw_boxes = TRUE,
#'     crop       = TRUE,
#'     save_dir   = "./results/"
#'   )
#'   print(df)
#' }
#' @export
detect_image <- function(image_path,
                          threshold = 0.25,
                          draw_boxes = FALSE,
                          crop = FALSE,
                          save_dir = "./") {
  # 1. Input checks
  if (!file.exists(image_path)) {
    stop("`image_path` does not exist: ", image_path)
  }
  if (!is.numeric(threshold) || threshold < 0 || threshold > 1) {
    stop("`threshold` must be a number in [0,1].")
  }
  if (!is.logical(draw_boxes) || !is.logical(crop)) {
    stop("`draw_boxes` and `crop` must be TRUE or FALSE.")
  }

  # 2. Ensure save_dir exists
  if (!dir.exists(save_dir)) {
    dir.create(save_dir, recursive = TRUE)
  }
  img_dir <- file.path(save_dir)
  if (!dir.exists(img_dir)) {
    dir.create(img_dir, recursive = TRUE)
  }

  # 3. POST to /detect_image
  res <- tryCatch({
    httr::POST(
      url = "http://sharkpulse.cnre.vt.edu/detect_image",
      encode = "multipart",
      body = list(
        image      = httr::upload_file(image_path),
        threshold  = as.character(threshold),
        draw_boxes = tolower(as.character(draw_boxes)),
        crop       = tolower(as.character(crop))
      )
    )
  }, error = function(e) {
    stop("HTTP error during POST: ", conditionMessage(e))
  })

  if (httr::status_code(res) >= 400) {
    stop("Server returned HTTP ", httr::status_code(res),
         "\nMessage: ", httr::content(res, "text", encoding = "UTF-8"))
  }

  # 4. Parse JSON response (keep nested lists)
  json_resp <- httr::content(res, as = "parsed", simplifyVector = FALSE)
  dets      <- json_resp[["detections"]]

  # If no detections, return empty data.frame
  if (!is.list(dets) || length(dets) == 0) {
    df_empty <- data.frame(
      xmin            = numeric(0),
      ymin            = numeric(0),
      xmax            = numeric(0),
      ymax            = numeric(0),
      score           = numeric(0),
      label           = character(0),
      annotated_image = character(0),
      cropped_images  = I(list())
    )
    return(df_empty)
  }

  # 5. Build a data.frame from dets
  nrow_det <- length(dets)
  xmin_vec <- numeric(nrow_det)
  ymin_vec <- numeric(nrow_det)
  xmax_vec <- numeric(nrow_det)
  ymax_vec <- numeric(nrow_det)
  score_vec <- numeric(nrow_det)
  label_chr <- character(nrow_det)

  for (i in seq_len(nrow_det)) {
    det <- dets[[i]]
    coords <- unlist(det$box)
    if (!(is.numeric(coords) && length(coords) == 4)) {
      stop("Unexpected `box` format in detection ", i)
    }
    xmin_vec[i] <- coords[1]
    ymin_vec[i] <- coords[2]
    xmax_vec[i] <- coords[3]
    ymax_vec[i] <- coords[4]
    score_vec[i] <- det$score
    lab <- det$label
    label_chr[i] <- if (is.numeric(lab) && lab == 0) "shark" else as.character(lab)
  }

  result_df <- data.frame(
    xmin    = xmin_vec,
    ymin    = ymin_vec,
    xmax    = xmax_vec,
    ymax    = ymax_vec,
    score   = score_vec,
    label   = label_chr,
    stringsAsFactors = FALSE
  )
  result_df$annotated_image <- NA_character_
  result_df$cropped_images  <- I(vector("list", nrow_det))

  # 6. Download annotated image (base name only)
  if (draw_boxes && !is.null(json_resp$annotated_image_path)) {
    remote_annot <- basename(json_resp$annotated_image_path)
    local_annot  <- file.path(img_dir, remote_annot)
    download_url <- paste0("http://sharkpulse.cnre.vt.edu/static/images/", remote_annot)
    tryCatch({
      utils::download.file(download_url, local_annot, mode = "wb", quiet = TRUE)
      result_df$annotated_image <- remote_annot
    }, error = function(e) {
      warning("Failed to download annotated image: ", remote_annot, "\n  ", conditionMessage(e))
    })
  }

  # 7. Download cropped images (base names only)
  if (crop && !is.null(json_resp$cropped_images)) {
    remote_crops <- json_resp$cropped_images
    if (!is.list(remote_crops) || length(remote_crops) == 0) {
      warning("`cropped_images` field was empty or invalid.")
    } else {
      local_crops <- character(length(remote_crops))
      for (i in seq_along(remote_crops)) {
        rem <- basename(remote_crops[[i]])
        loc <- file.path(img_dir, rem)
        url <- paste0("http://sharkpulse.cnre.vt.edu/static/images/", rem)
        tryCatch({
          utils::download.file(url, loc, mode = "wb", quiet = TRUE)
          local_crops[i] <- rem
        }, error = function(e) {
          warning("Failed to download cropped image: ", rem, "\n  ", conditionMessage(e))
          local_crops[i] <- NA_character_
        })
      }
      result_df$cropped_images <- list(local_crops)
    }
  }

  return(result_df)
}




#' Submit a single image for combined detection + hierarchical classification (client-side)
#'
#' Calls the Flask API endpoint `/detect_and_classify` at \code{http://sharkpulse.cnre.vt.edu}.
#' Optionally downloads any annotated / cropped images into `save_dir/images/`.
#' Returns a data frame with one row per detected bounding‐box and per taxonomy candidate.
#'
#' @param image_path    Path to a local image file (JPEG/PNG).
#' @param threshold     Numeric in [0,1] controlling YOLO‐confidence threshold. Default = 0.25.
#' @param draw_boxes    Logical; if TRUE, an annotated image with drawn boxes is downloaded.
#' @param crop          Logical; if TRUE, each detected shark patch (cropped) is downloaded.
#' @param topk          Integer ≥ 1: how many taxonomy candidates to return per detection. Default = 1.
#' @param save_dir      Character; directory where downloaded images are saved. Default = `"./"`.
#'                      A subfolder `"images"` will be created if it does not exist.
#' @return A data.frame with one row per detection × per candidate, with columns:
#'   \itemize{
#'     \item \code{xmin, ymin, xmax, ymax} – bounding‐box coordinates (numeric)
#'     \item \code{score}   – detection confidence (numeric)
#'     \item \code{label}   – `"shark"` (character) or integer label otherwise
#'     \item \code{order, family, genus, species} (character)
#'     \item \code{p_order, p_family, p_genus, p_species, joint_score} (numeric)
#'     \item \code{annotated_image} – local filename of the annotated image (if \code{draw_boxes=TRUE}), or NA
#'     \item \code{cropped_image} – local filename of the cropped patch (if \code{crop=TRUE}), or NA
#'   }
#' @examples
#' \dontrun{
#'   # topk = 1: one row per detection, download annotated box
#'   df1 <- detect_and_classify(
#'     image_path = "shark.jpg",
#'     threshold  = 0.3,
#'     draw_boxes = TRUE,
#'     crop       = FALSE,
#'     topk       = 1,
#'     save_dir   = "./results"
#'   )
#'   print(df1)
#'
#'   # topk = 3: three rows per detection, download crops
#'   df3 <- detect_and_classify(
#'     image_path = "shark.jpg",
#'     threshold  = 0.3,
#'     draw_boxes = FALSE,
#'     crop       = TRUE,
#'     topk       = 3,
#'     save_dir   = "./results"
#'   )
#'   print(df3)
#' }
#' @export
detect_and_classify <- function(image_path,
                                threshold  = 0.25,
                                draw_boxes = FALSE,
                                crop       = FALSE,
                                topk       = 1,
                                save_dir   = "./") {
  # 1. Input checks
  if (!file.exists(image_path)) {
    stop("`image_path` does not exist: ", image_path)
  }
  if (!is.numeric(threshold) || threshold < 0 || threshold > 1) {
    stop("`threshold` must be a number in [0,1].")
  }
  if (!is.logical(draw_boxes) || !is.logical(crop)) {
    stop("`draw_boxes` and `crop` must be TRUE or FALSE.")
  }
  if (!is.numeric(topk) || topk < 1) {
    stop("`topk` must be an integer ≥ 1.")
  }

  # 2. Ensure save_dir exists
  if (!dir.exists(save_dir)) {
    dir.create(save_dir, recursive = TRUE)
  }
  # 3. Create (or confirm) the "images" subfolder
  img_dir <- file.path(save_dir)
  if (!dir.exists(img_dir)) {
    dir.create(img_dir, recursive = TRUE)
  }

  # 4. POST to /detect_and_classify endpoint
  res <- tryCatch({
    httr::POST(
      url = "http://sharkpulse.cnre.vt.edu/detect_and_classify",
      encode = "multipart",
      body = list(
        image      = httr::upload_file(image_path),
        threshold  = as.character(threshold),
        draw_boxes = tolower(as.character(draw_boxes)),
        crop       = tolower(as.character(crop)),
        topk       = as.character(topk)
      )
    )
  }, error = function(e) {
    stop("HTTP error during POST: ", conditionMessage(e))
  })

  if (httr::status_code(res) >= 400) {
    stop(
      "Server returned HTTP ", httr::status_code(res),
      "\nMessage: ", httr::content(res, "text", encoding = "UTF-8")
    )
  }

  # 5. Parse JSON response without simplifying nested lists
  json_resp <- httr::content(res, as = "parsed", simplifyVector = FALSE)
  raw_results <- json_resp$results

  # 6. If no detections, return an empty data.frame
  if (!is.list(raw_results) || length(raw_results) == 0) {
    base_cols  <- c("xmin","ymin","xmax","ymax","score","label")
    class_cols <- c(
      "order","family","genus","species",
      "p_order","p_family","p_genus","p_species","joint_score"
    )
    extra_cols <- c("annotated_image","cropped_image")
    all_cols   <- c(base_cols, class_cols, extra_cols)
    return(data.frame(matrix(ncol = length(all_cols), nrow = 0,
                             dimnames = list(NULL, all_cols))))
  }

  # 7. Determine where to fetch static images from
  #    (make sure your Flask app serves these under /static/images/<filename>)
  base_url <- "http://sharkpulse.cnre.vt.edu/static/images/"

  # 8. Extract “annotated_image_path” and download if requested
  #    json_resp$annotated_image_path is assumed to be something like
  #    "…/static/images/annotated_20250606T162211Z_mako.jpg"
  annotated_base <- NA_character_
  if (draw_boxes && !is.null(json_resp$annotated_image_path)) {
    annotated_base <- basename(json_resp$annotated_image_path)
    # Local path to write:
    local_annotated_file <- file.path(img_dir, annotated_base)
    # Only download if not already on disk:
    if (!file.exists(local_annotated_file)) {
      full_url <- paste0(base_url, annotated_base)
      resp_img <- httr::GET(full_url)
      if (httr::status_code(resp_img) == 200) {
        writeBin(httr::content(resp_img, "raw"), local_annotated_file)
      } else {
        warning("Failed to download annotated image from ", full_url)
      }
    }
  }

  # 9. Extract “cropped_images” list and download each if requested
  cropped_list <- rep(NA_character_, length(raw_results))
  if (crop && !is.null(json_resp$cropped_images)) {
    # json_resp$cropped_images is a list of full URLs or paths,
    # so we take the basename of each and download:
    fmts <- vapply(json_resp$cropped_images, basename, FUN.VALUE = "")
    for (i in seq_along(fmts)) {
      fname <- fmts[i]
      local_crop_path <- file.path(img_dir, fname)
      # download if not already present:
      if (!file.exists(local_crop_path)) {
        full_url <- paste0(base_url, fname)
        resp_img <- httr::GET(full_url)
        if (httr::status_code(resp_img) == 200) {
          writeBin(httr::content(resp_img, "raw"), local_crop_path)
        } else {
          warning("Failed to download cropped image from ", full_url)
        }
      }
      cropped_list[i] <- fname
    }
  }

  # 10. Build a data.frame per detection (+ per topk candidate)
  per_det_dfs <- lapply(seq_along(raw_results), function(i) {
    item <- raw_results[[i]]
    det  <- item$detection
    cls  <- item$classification

    # Unpack bounding box
    coords <- unlist(det$box)
    if (!(is.numeric(coords) && length(coords) == 4)) {
      stop("Unexpected `box` format in detection ", i)
    }
    xmin  <- coords[1]; ymin <- coords[2]
    xmax  <- coords[3]; ymax <- coords[4]
    score <- det$score
    label <- if (is.numeric(det$label) && det$label == 0) "shark" else as.character(det$label)

    if (topk == 1) {
      # Expect cls to have order/family/genus/species + probabilities
      req_names <- c("order","p_order","family","p_family","genus","p_genus","species","p_species")
      if (!is.list(cls) || !all(req_names %in% names(cls))) {
        stop("Unexpected structure in classification for detection ", i)
      }
      joint <- cls$p_order * cls$p_family * cls$p_genus * cls$p_species
      dfi <- data.frame(
        xmin            = xmin,
        ymin            = ymin,
        xmax            = xmax,
        ymax            = ymax,
        score           = score,
        label           = label,
        order           = cls$order,
        family          = cls$family,
        genus           = cls$genus,
        species         = cls$species,
        p_order         = cls$p_order,
        p_family        = cls$p_family,
        p_genus         = cls$p_genus,
        p_species       = cls$p_species,
        joint_score     = joint,
        annotated_image = if (draw_boxes) annotated_base else NA_character_,
        cropped_image   = if (crop) cropped_list[i] else NA_character_,
        stringsAsFactors = FALSE
      )
      # Reorder columns
      dfi <- dfi[, c(
        "xmin","ymin","xmax","ymax","score","label",
        "order","family","genus","species",
        "p_order","p_family","p_genus","p_species","joint_score",
        "annotated_image","cropped_image"
      )]
      return(dfi)

    } else {
      # topk > 1: cls$topk is a list-of-lists, each with order/family/etc + joint_score
      if (!is.list(cls$topk) || length(cls$topk) != topk) {
        stop("Unexpected or missing `topk` entries in classification for detection ", i)
      }
      df_list <- lapply(cls$topk, function(pr) {
        req_names2 <- c(
          "order","p_order","family","p_family","genus","p_genus","species","p_species","joint_score"
        )
        if (!all(req_names2 %in% names(pr))) {
          stop("Unexpected fields in topk candidate for detection ", i)
        }
        data.frame(
          xmin            = xmin,
          ymin            = ymin,
          xmax            = xmax,
          ymax            = ymax,
          score           = score,
          label           = label,
          order           = pr$order,
          family          = pr$family,
          genus           = pr$genus,
          species         = pr$species,
          p_order         = pr$p_order,
          p_family        = pr$p_family,
          p_genus         = pr$p_genus,
          p_species       = pr$p_species,
          joint_score     = pr$joint_score,
          annotated_image = if (draw_boxes) annotated_base else NA_character_,
          cropped_image   = if (crop) cropped_list[i] else NA_character_,
          stringsAsFactors = FALSE
        )
      })
      dfi <- do.call(rbind, df_list)
      dfi <- dfi[, c(
        "xmin","ymin","xmax","ymax","score","label",
        "order","family","genus","species",
        "p_order","p_family","p_genus","p_species","joint_score",
        "annotated_image","cropped_image"
      )]
      return(dfi)
    }
  })

  # 11. Combine everything into one data.frame
  final_df <- do.call(rbind, per_det_dfs)
  rownames(final_df) <- NULL
  return(final_df)
}


#' Score a single image for shark presence (binary classification)
#'
#' Calls the Flask API endpoint `/classify_binary` at \code{http://sharkpulse.cnre.vt.edu}.
#' Returns a single-row data frame with columns `image_path` and `shark_confidence`,
#' where `shark_confidence` is a probability score [0,1] indicating shark presence.
#'
#' @param image_path Path to a local image file (JPEG/PNG).
#' @return A single-row data.frame with columns:
#'   \itemize{
#'     \item \code{image_path} – input image path.
#'     \item \code{shark_confidence} – predicted probability of shark presence.
#'   }
#' @examples
#' \dontrun{
#'   df <- is_shark("shark.jpg")
#'   print(df)
#' }
#' @export
is_shark <- function(image_path) {
  # 1. Input checks
  if (!file.exists(image_path)) {
    stop("`image_path` does not exist: ", image_path)
  }

  # 2. POST to /classify_binary endpoint
  res <- tryCatch({
    httr::POST(
      url = "http://sharkpulse.cnre.vt.edu/classify_binary",
      encode = "multipart",
      body = list(
        image = httr::upload_file(image_path)
      )
    )
  }, error = function(e) {
    stop("HTTP error during POST: ", conditionMessage(e))
  })

  if (httr::status_code(res) >= 400) {
    stop(
      "Server returned HTTP ", httr::status_code(res),
      "\nMessage: ", httr::content(res, "text", encoding = "UTF-8")
    )
  }

  # 3. Parse JSON response
  json_resp <- httr::content(res, as = "parsed", simplifyVector = TRUE)

  if (!"shark_confidence" %in% names(json_resp)) {
    stop("Unexpected JSON structure: missing `shark_confidence` field.")
  }

  # 4. Build a single-row data.frame
  df <- data.frame(
    image_path       = normalizePath(image_path),
    shark_confidence = json_resp$shark_confidence,
    stringsAsFactors = FALSE
  )

  return(df)
}



#' Submit a single image for classification (hierarchical taxonomy)
#'
#' Calls the Flask API endpoint `/classify` at \code{http://sharkpulse.cnre.vt.edu}.
#' Returns a data frame of the predicted taxonomy. If \code{topk = 1}, it returns a single-row
#' data frame with columns in the order:
#' \code{order, family, genus, species, p_order, p_family, p_genus, p_species, joint_score}.
#' If \code{topk > 1}, it returns a data frame of size \code{topk} with columns
#' \code{order, family, genus, species, p_order, p_family, p_genus, p_species, joint_score},
#' in that column order.
#'
#' @param image_path    Path to a local image file (JPEG/PNG).
#' @param topk          Integer ≥ 1: how many taxonomy candidates to return. Default = 1.
#' @return If \code{topk = 1}, a single-row data frame with columns:
#'   \code{order, family, genus, species, p_order, p_family, p_genus, p_species, joint_score}.  
#'   If \code{topk > 1}, a data frame of size \code{topk} with those same columns.
#' @examples
#' \dontrun{
#'   df1 <- classify_image("shark.jpg", topk = 1)
#'   print(df1)
#'
#'   df3 <- classify_image("shark.jpg", topk = 3)
#'   print(df3)  # Already sorted in desired column order
#' }
#' @export
classify_image <- function(image_path, topk = 1) {
  # 1. Input checks
  if (!file.exists(image_path)) {
    stop("`image_path` does not exist: ", image_path)
  }
  if (!is.numeric(topk) || topk < 1) {
    stop("`topk` must be an integer >= 1.")
  }

  # 2. POST to /classify
  res <- tryCatch({
    httr::POST(
      url = "http://sharkpulse.cnre.vt.edu/classify",
      encode = "multipart",
      body = list(
        image = httr::upload_file(image_path),
        topk  = as.character(topk)
      )
    )
  }, error = function(e) {
    stop("HTTP error during POST: ", conditionMessage(e))
  })

  if (httr::status_code(res) >= 400) {
    stop(
      "Server returned HTTP ", httr::status_code(res),
      "\nMessage: ", httr::content(res, "text", encoding = "UTF-8")
    )
  }

  # 3. Parse JSON response with simplifyVector = TRUE
  json_resp <- httr::content(res, as = "parsed", simplifyVector = TRUE)

  # 4. Handle topk = 1 vs > 1
  if (topk == 1) {
    pred <- json_resp$prediction
    req_cols <- c(
      "order","p_order",
      "family","p_family",
      "genus","p_genus",
      "species","p_species"
    )
    if (!is.list(pred) || !all(req_cols %in% names(pred))) {
      stop("Unexpected JSON structure from /classify endpoint.")
    }
    # Build data.frame, then compute joint_score
    df <- data.frame(
      order     = pred[["order"]],
      family    = pred[["family"]],
      genus     = pred[["genus"]],
      species   = pred[["species"]],
      p_order   = pred[["p_order"]],
      p_family  = pred[["p_family"]],
      p_genus   = pred[["p_genus"]],
      p_species = pred[["p_species"]],
      stringsAsFactors = FALSE
    )
    df$joint_score <- with(df, p_order * p_family * p_genus * p_species)

    # Reorder columns: order, family, genus, species, p_order, p_family, p_genus, p_species, joint_score
    df <- df[, c(
      "order",
      "family",
      "genus",
      "species",
      "p_order",
      "p_family",
      "p_genus",
      "p_species",
      "joint_score"
    )]
    return(df)

  } else {
    preds <- json_resp$predictions
    if (!is.list(preds) || length(preds) == 0) {
      stop("Unexpected or empty `predictions` from /classify endpoint.")
    }

    # Build a data.frame of size topk
    if (is.data.frame(preds)) {
      topk_df <- preds
    } else {
      topk_df <- do.call(rbind, lapply(preds, function(pr) {
        data.frame(
          order       = pr[["order"]],
          family      = pr[["family"]],
          genus       = pr[["genus"]],
          species     = pr[["species"]],
          p_order     = pr[["p_order"]],
          p_family    = pr[["p_family"]],
          p_genus     = pr[["p_genus"]],
          p_species   = pr[["p_species"]],
          joint_score = pr[["joint_score"]],
          stringsAsFactors = FALSE
        )
      }))
    }

    # Reorder columns: order, family, genus, species, p_order, p_family, p_genus, p_species, joint_score
    desired_cols <- c(
      "order",
      "family",
      "genus",
      "species",
      "p_order",
      "p_family",
      "p_genus",
      "p_species",
      "joint_score"
    )
    missing_cols <- setdiff(desired_cols, names(topk_df))
    if (length(missing_cols) > 0) {
      stop("Missing expected columns in `predictions`: ", paste(missing_cols, collapse = ", "))
    }
    topk_df <- topk_df[, desired_cols]

    return(topk_df)
  }
}

#' Fetch the entire taxonomy3 table from the API
#'
#' @return A data.frame with all rows/columns from taxonomy3.
#' @export
get_taxonomy <- function() {
  library(httr)
  library(jsonlite)
  base_url = "http://sharkpulse.cnre.vt.edu"
  url <- paste0(base_url, "/taxonomy3")
  resp <- GET(url)

  # throw an error if we didn’t get 200
  stop_for_status(resp)

  # parse JSON into a list of named lists
  parsed <- content(resp, as = "text", encoding = "UTF-8")
  dat_list <- fromJSON(parsed, simplifyDataFrame = TRUE)

  # ensure it’s a data.frame
  df <- as.data.frame(dat_list, stringsAsFactors = FALSE) 
  df <- df[,!(colnames(df) %in% c("order_name.x", "order_name.y"))]
  return(df)
}


#' Retrieve classification performance metrics (order/family/genus/species)
#'
#' Reads the `cond_metrics` (conditional shark classifier metrics) file hosted at
#' \url{http://sharkpulse.cnre.vt.edu/static/cond_metrics.csv} into a data frame.
#' Columns are: \code{level, class, precision, recall, f1score, n_train, n_val, n_test}.
#'
#' @return A data.frame with one row per taxon at each level.
#' @examples
#' \dontrun{
#'   metrics_df <- get_metrics()
#'   head(metrics_df)
#' }
#' @export
get_metrics <- function() {
  url <- "http://sharkpulse.cnre.vt.edu/static/cond_metrics.csv"
  tryCatch({
    df <- utils::read.csv(url, stringsAsFactors = FALSE)
    return(df)
  }, error = function(e) {
    stop("Failed to read metrics CSV from server: ", conditionMessage(e))
  })
}
