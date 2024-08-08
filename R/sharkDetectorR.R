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
#' @param threshold decimal from 0-1 to indicate the threshold value that the object detection program should discriminate shark subjects.
#' @return A data frame with the detected species, timestamps, detection probabilities, species probabilities, and image paths.
#' @examples
#' \dontrun{
#'   result <- process_video("path/to/video.mp4", download_images = TRUE, threshold = 0.95)
#'   print(result)
#' }
#' @export
process_video <- function(video_path, download_images = FALSE, threshold = 0.95) {
  video_name <- gsub(" ", "_", basename(video_path))
  save_path <- sub("\\..*$", "", video_name)
  cat("Processing:", video_name, "\n", "This may take a while...", "\n")
  
  res <- tryCatch(
    {
      httr::POST(
        url = "http://sp2.cs.vt.edu:5000/process_video",
        body = list(
          video = httr::upload_file(video_path),
          video_name = video_name,
          save_path = save_path,
          threshold = threshold
        ),
        encode = "multipart"
      )
    },
    error = function(e) {
      cat("Error in POST request:", conditionMessage(e), "\n")
      return(NULL)
    }
  )
  
  if (is.null(res)) {
    return(NULL)
  }
  
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
    species = sapply(results, function(x) x$species),
    timestamp = sapply(results, function(x) convert_timestamp(x$timestamp)),
    ymin = sapply(results, function(x) x$box_coordinates$ymin),
    xmin = sapply(results, function(x) x$box_coordinates$xmin),
    ymax = sapply(results, function(x) x$box_coordinates$ymax),
    xmax = sapply(results, function(x) x$box_coordinates$xmax),
    detection_probability = sapply(results, function(x) x$detection_prob),
    species_probability = sapply(results, function(x) x$class_prob),
    img_name = sapply(results, function(x) x$image_path),
    parent_image = sapply(results, function(x) x$parent_image)
  )

  if (download_images) {
    base_url <- "https://sp2.cs.vt.edu/shiny/sharkdetector/output/"

    # Create the save_path directory if it doesn't exist
    if (!dir.exists(save_path)) {
      dir.create(save_path, recursive = TRUE)
    }

    for (i in 1:nrow(results_df)) {
      tryCatch(
        {
          img_url <- paste0(base_url, save_path, "/", results_df$img_name[i])
          download.file(img_url, destfile = file.path(save_path, results_df$img_name[i]))
        },
        error = function(e) {
          cat("Error downloading image:", results_df$img_name[i], "-", conditionMessage(e), "\n")
        }
      )
    }

    unique_parent <- unique(results_df$parent_image)

    for (i in unique_parent) {
      tryCatch(
        {
          img_url <- paste0(base_url, save_path, "/", i)
          download.file(img_url, destfile = file.path(save_path, i))
        },
        error = function(e) {
          cat("Error downloading parent image:", i, "-", conditionMessage(e), "\n")
        }
      )
    }
  }

  # Write the combined results to a CSV file
  csv_path <- file.path(paste0("./",save_path, ".csv"))
  write.csv(results_df, csv_path, row.names = FALSE)
  cat("Results saved to:", csv_path, "\n")

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
    select(Species = X, Precision = precision, Recall = recall, `F1 Score` = f1.score)
  
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
#' @param download_images Logical, whether to download the processed images. Default is FALSE.
#' @param threshold decimal from 0-1 to indicate the threshold value that the object detection program should discriminate shark subjects.
#' @return A list with the detected species, detection probability, species probability, and image path.
#' @examples
#' \dontrun{
#'   result <- process_image("path/to/image.jpg", download_image = FALSE, threshold = 0.95)
#'   print(result)
#' }
#' @export
process_image <- function(image_path, download_images = FALSE, threshold = 0.95) {
  image_name <- gsub(" ", "_", basename(image_path))
  save_path <- sub("\\..*$", "", image_name)
  
  res <- tryCatch(
    {
      httr::POST(
        url = "http://sp2.cs.vt.edu:5000/process_image",
        body = list(
          image = httr::upload_file(image_path),
          image_name = image_name,
          threshold = threshold
        ),
        encode = "multipart"
      )
    },
    error = function(e) {
      cat("Error in POST request:", conditionMessage(e), "\n")
      return(NULL)
    }
  )
  
  if (is.null(res)) {
    return(NULL)
  }
  
  results <- httr::content(res, as = "parsed")

  results_df <- data.frame(
    species = sapply(results, function(x) x$species),
    ymin = sapply(results, function(x) x$box_coordinates$ymin),
    xmin = sapply(results, function(x) x$box_coordinates$xmin),
    ymax = sapply(results, function(x) x$box_coordinates$ymax),
    xmax = sapply(results, function(x) x$box_coordinates$xmax),
    detection_probability = sapply(results, function(x) x$detection_prob),
    species_probability = sapply(results, function(x) x$class_prob),
    img_name = sapply(results, function(x) x$image_path),
    parent_image = sapply(results, function(x) x$parent_image)
  )
  
  if (download_images) {
    base_url <- "https://sp2.cs.vt.edu/shiny/sharkdetector/output/images/"
    
    # Create the save_path directory if it doesn't exist
    if (!dir.exists(save_path)) {
      dir.create(save_path, recursive = TRUE)
    }

    for (i in 1:nrow(results_df)) {
      tryCatch(
        {
          img_url <- paste0(base_url, results_df$img_name[i]) 
          download.file(img_url, destfile = file.path(save_path, results_df$img_name[i]))
        },
        error = function(e) {
          cat("Error downloading image:", results_df$img_name[i], "-", conditionMessage(e), "\n")
        }
      )
    }
  }

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
           Genus = ifelse(Class == 'Species', sub('_.*', '', X), X),
           X = gsub('_', ' ', X))  # Replace underscores with spaces
  
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
      scale_fill_manual(values = c("skyblue", "lightgreen", "coral")) +  # Custom color palette
      labs(title = paste("Performance Metrics by", ifelse(genus == "all", "Genus", paste("Genus", genus))),
           x = ifelse(genus == "all", "Genus", "Species")) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 12, face = "bold"),
        axis.text.y = element_text(size = 12, face = "bold"),
        axis.title.y = element_blank(),
        panel.background = element_rect(fill = "white"),
        panel.grid = element_blank(),
        axis.line = element_line(color = "black"),
        axis.ticks = element_line(color = "black"),
        axis.ticks.length = unit(0.25, "cm"),
        plot.margin = unit(c(1, 1, 0.5, 1), "cm")
      ) +
      coord_cartesian(ylim = c(0, max(data$Value) * 1.1))  # Adjust y-axis to remove gap
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
#' @param download_images Logical, whether to download the processed images. Default is FALSE.
#' @param threshold decimal from 0-1 to indicate the threshold value that the object detection program should discriminate shark subjects.
#' @examples
#' \dontrun{
#'   process_directory("path/to/images, download_images = FALSE, threshold = 0.95")
#' }
#' @export
process_directory <- function(directory_path = "./images", download_images = FALSE, threshold = 0.95) {
  # Get the list of all image files in the directory
  image_files <- list.files(directory_path, pattern = "\\.(jpg|jpeg|png)$", full.names = TRUE, ignore.case = TRUE)
  save_path <- paste0("detected_", basename(directory_path))
  # Initialize an empty data frame to store results
  all_results <- data.frame()
  
  # Loop through each image file and process it
  for (image_file in image_files) {
    cat("Processing:", basename(image_file), "\n")
    result_df <- tryCatch(
      {
        process_image(image_file, threshold = threshold)
      },
      error = function(e) {
        cat("Error processing image:", basename(image_file), "-", conditionMessage(e), "\n")
        NULL  # Return NULL in case of error
      }
    )
    if (!is.null(result_df)) {
      all_results <- dplyr::bind_rows(all_results, result_df)
    }
  }
  
  if (download_images) {
    base_url <- "https://sp2.cs.vt.edu/shiny/sharkdetector/output/images/"
    # Create the save_path directory if it doesn't exist
    if (!dir.exists(save_path)) {
      dir.create(save_path, recursive = TRUE)
    }

    for (i in 1:nrow(all_results)) {
      tryCatch(
        {
          img_url <- paste0(base_url, all_results$img_name[i])
          download.file(img_url, destfile = file.path(save_path, all_results$img_name[i]))
        },
        error = function(e) {
          cat("Error downloading image:", all_results$img_name[i], "-", conditionMessage(e), "\n")
        }
      )
    }
  }
  name = paste0(save_path, "/",basename(directory_path), ".csv")
  # Write the combined results to a CSV file
  csv_path <- file.path(save_path)
  write.csv(all_results, csv_path, row.names = FALSE)
  cat("Results saved to:", name, "\n")
  
  return(all_results) 
}
