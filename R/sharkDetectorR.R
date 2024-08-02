#' @name sharkDetectorR-package
#' @aliases sharkDetectorR
#' @docType package
#' @title Shark Detection and Classification Package
#' @description Provides functions to submit videos and images to a Flask API for shark detection and classification.
#' @details The package allows users to submit visual media to a backend API, which processes the media with object-detection and image classification models to detect and classify shark species.
#' @keywords package
NULL


#' Process a Video for Shark Detection and Classification
#'
#' Submits a video file to the Flask API for processing. The API returns
#' detected shark species, timestamps, detection probabilities, and
#' classified species probabilities along with cropped images.
#'
#' @param video_path The path to the video file to be processed.
#' @param download_images Logical, whether to download the processed images. Default is FALSE.
#' @param crop Logical, whether to download cropped detected sharks instead of the entire frame.
#' @return A data frame with the detected species, timestamps, detection probabilities, species probabilities, and image paths.
#' @examples
#' \dontrun{
#'   result <- process_video("path/to/video.mp4", download_images = TRUE)
#'   print(result)
#' }
#' @export
process_video <- function(video_path, download_images = FALSE, crop = FALSE) {
  video_name <- gsub(" ", "_", basename(video_path))
  save_path = sub("\\..*$", "", video_name)
  res <- httr::POST(
    url = "http://sp2.cs.vt.edu:5000/process_video",
    body = list(
      video = httr::upload_file(video_path),
      video_name = video_name,
      save_path = save_path
    ),
    encode = "multipart"
  )
  
  results <- httr::content(res, as = "parsed")

  # Convert timestamp from 'h0m0s18' format to 'HH:MM:SS'
  convert_timestamp <- function(timestamp_str) {
    hours <- as.numeric(gsub("h(\\d+)m\\d+s\\d+", "\\1", timestamp_str))
    minutes <- as.numeric(gsub("h\\d+m(\\d+)s\\d+", "\\1", timestamp_str))
    seconds <- as.numeric(gsub("h\\d+m\\d+s(\\d+)", "\\1", timestamp_str))
    time <- sprintf("%02d:%02d:%02d", hours, minutes, seconds)
    return(time)
  }

  results_df <- data.frame(
    species = sapply(results, `[[`, "species"),
    timestamp = sapply(results, function(x) convert_timestamp(x$timestamp)),
    detection_probability = sapply(results, `[[`, "detection_prob"),
    species_probability = sapply(results, `[[`, "class_prob"),
    img_name = sapply(results, `[[`, "image_path")
  )
  
  if (download_images) {
    base_url <- "https://sp2.cs.vt.edu/shiny/sharkdetector/output/"

    # Create the save_path directory if it doesn't exist
    if (!dir.exists(save_path)) {
      dir.create(save_path, recursive = TRUE)
    }

    for (i in 1:nrow(results_df)) {
      if (crop) {
        img_url <- paste0(base_url, save_path, "/", "crop_", results_df$img_name[i])
      }
      else {img_url <- paste0(base_url, save_path, "/", results_df$img_name[i])}
      download.file(img_url, destfile = file.path(save_path, results_df$img_name[i]))
    }
  }

  return(results_df)
}

#' List Shark Species and Their Performance Metrics
#'
#' This function reads the CSV file containing classification performance metrics
#' and lists all shark species along with their precision, recall, and F1 score.
#'
#' @return A data frame with shark species and their performance metrics.
#' @export
list_sharks <- function() {
  library(dplyr)
  # Read the CSV file
  url <- 'https://sp2.cs.vt.edu/shiny/sharkdetector/combined_report.csv'
  performance_data <- read.csv(url)
  
  # Identify species
  species_data <- performance_data %>%
    filter(grepl('_', X)) %>%
    select(Species = X, Precision = precision, Recall = recall, `F1 Score` = f1.score)
  
  # Print the data frame
  print(species_data)
  
  return(species_data)
}

# Example usage
# list_sharks()


#' Process an Image for Shark Detection and Classification
#'
#' Submits an image file to the Flask API for processing. The API returns
#' detected shark species, detection probabilities, and
#' classified species probabilities along with the processed image path.
#' Optionally, the function can download the processed image.
#'
#' @param image_path The path to the image file to be processed.
#' @return A list with the detected species, detection probability, species probability, and image path.
#' @examples
#' \dontrun{
#'   result <- process_image("path/to/image.jpg", download_image = FALSE, crop = FALSE)
#'   print(result)
#' }
#' @export
process_image <- function(image_path) {
  image_name <- gsub(" ", "_", basename(image_path))
  res <- httr::POST(
    url = "http://sp2.cs.vt.edu:5000/process_image",
    body = list(
      image = httr::upload_file(image_path),
      image_name = image_name
    ),
    encode = "multipart"
  )
  
  results <- httr::content(res, as = "parsed")

  results_df <- data.frame(
    species = sapply(results, `[[`, "species"),
    detection_probability = sapply(results, `[[`, "detection_prob"),
    species_probability = sapply(results, `[[`, "class_prob"),
    img_name = sapply(results, `[[`, "image_path")
  )
  
  return(results_df)
}

#' Plot Performance Metrics for Genus and Species Classification
#'
#' This function reads the CSV file containing classification performance metrics
#' and generates bar graphs of precision, recall, and F1 score for genus and species.
#' When 'genus' is "all", it generates graphs for all genera. When a specific genus is
#' provided, it generates graphs for that genus and its corresponding species.
#'
#' @param genus A character string indicating the genus to plot ("all" or a specific genus).
#' @export
performance <- function(genus = "all") {
  library(ggplot2)
  library(dplyr)
  # Read the CSV file
  url <- 'https://sp2.cs.vt.edu/shiny/sharkdetector/combined_report.csv'
  performance_data <- read.csv(url)
  
  # Identify genus and species
  performance_data <- performance_data %>%
    mutate(Class = ifelse(grepl('_', X), 'Species', 'Genus'),
           Genus = ifelse(Class == 'Species', sub('_.*', '', X), X))
  
  # Filter data based on the genus argument
  if (genus != "all") {
    performance_data <- performance_data %>% filter(Genus == genus)
  } else {
    performance_data <- performance_data %>% filter(Class == 'Genus')
  }
  
  # Reshape data for plotting
  performance_long <- performance_data %>%
    select(X, precision, recall, f1.score) %>%
    tidyr::pivot_longer(cols = c(precision, recall, f1.score), names_to = "Metric", values_to = "Value")
  
  # Plot precision, recall, and f1.score
  plot_metrics <- function(data) {
    ggplot(data, aes(x = reorder(X, -Value), y = Value, fill = Metric)) +
      geom_bar(stat = 'identity', position = 'dodge') +
      labs(title = paste("Performance Metrics by", ifelse(genus == "all", "Genus", paste("Genus", genus))),
           x = ifelse(genus == "all", "Genus", "Species"),
           y = "Value") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  }
  
  # Plot and display the graph
  performance_plot <- plot_metrics(performance_long)
  
  print(performance_plot)
}

#' Process a Directory of Images for Shark Detection and Classification
#'
#' Processes all images in a specified directory using the Flask API for shark detection and classification.
#' The API returns detected shark species, detection probabilities, and classified species probabilities for each image.
#' The results are saved to a CSV file.
#'
#' @param directory_path The path to the directory containing the image files to be processed.
#' @examples
#' \dontrun{
#'   process_directory("path/to/images")
#' }
#' @export
process_directory <- function(directory_path = "./images") {
  # Get the list of all image files in the directory
  image_files <- list.files(directory_path, pattern = "\\.(jpg|jpeg|png)$", full.names = TRUE, ignore.case = TRUE)
  
  # Initialize an empty data frame to store results
  all_results <- data.frame()
  
  # Loop through each image file and process it
  for (image_file in image_files) {
    cat("Processing:", basename(image_file), "\n")
    result_df <- process_image(image_file)
    all_results <- dplyr::bind_rows(all_results, result_df)
  }
  
  # Write the combined results to a CSV file
  write.csv(all_results, "./results.csv", row.names = FALSE)
  cat("Results saved to:", "results.csv", "\n")
  return(all_results) 
}