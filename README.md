# sharkDetectorR

This R package provides functions for shark detection and classification from videos and images. It includes functions to submit videos and images to a Flask API for processing, and to visualize performance metrics.

## Installation

You can install the package directly from GitHub using the `devtools` package:

```r
if (!requireNamespace("devtools", quietly = TRUE)) {
    install.packages("devtools")
}
devtools::install_github("JeremyFJ/sharkDetectorR")

## Usage
- Process video
```
library(sharkDetectorR)

result <- process_video("video.mp4", download = FALSE, crop = FALSE)
print(result)
```

- Process image
```
result_image <- process_image("image.jpg")
print(result_image)
```

- Plot performance metrics
```
performance()  # For all genera
performance("Alopias")  # For genus "Alopias"
```

- List available shark species
```
shark_metrics <- list_sharks()
print(shark_metrics)
```

