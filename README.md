# sharkDetectorR <a href="http://seaql.org/wp-content/uploads/2022/06/SD.pdf"><img src="man/figures/sd.png" align="right" height="132" /></a>

This R package provides functions for shark detection and classification from videos and images. It includes functions to submit videos and images to a Flask API for processing, and to visualize performance metrics.

The Shark Detector is an AI application for detecting and taxonomically classifying shark species in visual media. Videos and images are processed stepwise, beginning with 1) extracting frames, 2) detecting any shark subjects, 3) cropping shark subjects to remove background noise, and 4) taxonomically classifying to the genus and then species level.

sharkPulse is an advanced cyber infrastructure designed to crowdsource global sightings and generate conservation knowledge with multiple computer vision, machine learning, and data science workflows. The Shark Detector functions as the main work engine to automate shark detection and species classification, and ingest new information to continuously improve itself. By demonstrating this AI platform in Hawaii, we show how easy and effective it is to boost the Shark Detector and advance new baselines of classification performance.   

We rely on crowdsourcing efforts to increase AI performance, so if you have footage of sharks that you want to contribute, please reach to the contacts below!

<a href="https://github.com/sharkPulse/Shark-Detector"><img src="man/figures/figure1.png" align="center" height="300" /></a>

## Installation

You can install the package directly from GitHub using the `devtools` package:

```r
devtools::install_github("JeremyFJ/sharkDetectorR")
```

## Usage
- Process video
```r
library(sharkDetectorR)

result <- process_video("video.mp4", download = FALSE, crop = FALSE)
print(result)
```

- Process image
```r
result_image <- process_image("image.jpg")
print(result_image)
```

- Plot performance metrics
```r
performance()  # For all genera
performance("Alopias")  # For genus "Alopias"
```

- List available shark species
```r
shark_metrics <- list_sharks()
print(shark_metrics)
```

