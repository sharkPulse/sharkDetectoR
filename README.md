# sharkDetectoR <a href="http://seaql.org/wp-content/uploads/2022/06/SD.pdf"><img src="man/figures/sd.png" align="right" height="132" /></a>

This R package provides functions for shark detection and classification from videos and images. It includes functions to submit videos and images to a Flask API for processing, and to visualize performance metrics. For increased customization, retraining, and faster processing speeds, please see the [Shark Detector version repository](https://github.com/sharkPulse/Shark-Detector). Version 4.0.0 can classify 69 species of sharks with an average accuracy of 82%.  

The Shark Detector is an AI application for detecting and taxonomically classifying shark species in visual media. Videos and images are processed stepwise, beginning with 1) extracting frames, 2) detecting any shark subjects, 3) cropping shark subjects to remove background noise, and taxonomically classifying to the genus and then species level, and finally 4) producing annotations.

[sharkPulse](https://sp2.cs.vt.edu) is an advanced cyber infrastructure designed to crowdsource global sightings and generate conservation knowledge with multiple computer vision, machine learning, and data science workflows. The Shark Detector functions as the main work engine to automate shark detection and species classification, and ingest new information to continuously improve itself. By demonstrating this AI platform in Hawaii, we show how easy and effective it is to boost the Shark Detector and advance new baselines of classification performance.   

We rely on crowdsourcing efforts to increase AI performance, so if you have footage of sharks that you want to contribute, please reach to the contacts below!

## Installation

You can install the package directly from GitHub using the `devtools` package:

```r
devtools::install_github("sharkPulse/sharkDetectoR")
```

## Usage
To use `sharkDetectoR`, process a video, an image, or a batch of images with these functions. Additionally, generate the most up-to-date performance reports and print the current list of classifiable shark genera and species and their corresponding accuracy. Media can be processed to return shark detections, bounding box coordinates, species classifications, prediction probability, and the name of the cropped and original (parent) image. Multiple detection boxes can be drawn per image.

- Process a video
```r
result <- process_video("video.mp4", download_images = TRUE, threshold = 0.95)
colnames(result)
 [1] "species"               "timestamp"             "ymin"                 
 [4] "xmin"                  "ymax"                  "xmax"                 
 [7] "detection_probability" "species_probability"   "img_name"             
[10] "parent_image"
```

For the graphical interface of this function, please visit sharkPulse for the [video processor](http://sharkpulse.org/video-processor).

<p align="left">
  <img src="man/figures/figure5.PNG" alt="processor" width="700"/>
</p>

- Process an image 
```r
result_image = process_image("whiteshark.jpg", download_images = TRUE, threshold = 0.95)
colnames(result_image)
 [1] "species"               "timestamp"             "ymin"                 
 [4] "xmin"                  "ymax"                  "xmax"                 
 [7] "detection_probability" "species_probability"   "img_name"             
[10] "parent_image"
```

- Process a batch of images
```r
> results = process_directory("./images/", download_images = TRUE, threshold = 0.95)
Processing: carcharhinus.jpg 
Processing: hammerhead.jpg 
Processing: whiteshark.jpg 
Processing: whiteshark2.jpg 
Results saved to: detected_images/images.csv
```

## `iucn_list` Function

The `iucn_list` function allows you to query the IUCN and Aquamaps species distribution for any given geographical location and radius. By scanning potential survey locations for assessment-driven species distributions, this function systematically informs data-boosting efforts.

### Function Parameters

- `lon`: Numeric. The longitude of the target location.
- `lat`: Numeric. The latitude of the target location.
- `radius_km`: Numeric. The radius (in kilometers) around the specified location within which to search for species occurrences. Defaults to 60 km.

### Return Value

The function returns a data frame containing the following columns:

- **`species`**: The scientific name of each species present within the specified radius.
- **`aquamaps2020_prob`**: The average probability of occurrence from Aquamaps data within the specified radius. If no data is available, this value will be `NA`.
- **`category`**: The IUCN Red List conservation category for each species (e.g., `VU` for Vulnerable, `LC` for Least Concern).
- **`class`**: Classification as `shark` or `ray`.
- **`condition`**: Species presence condition, indicating if the species is known to be `Extant` (confirmed) or `Possibly Extant` in the specified area.

### Example

Here’s an example of how to use the `iucn_list` function:

```r
# Sample usage
result <- iucn_list(lon = -70.0, lat = 43.0, radius_km = 60)
head(result[1:5])
                  species aquamaps2020_prob category class condition
1   Alopias superciliosus                NA       VU shark    Extant
2        Alopias vulpinus              0.65       VU shark    Extant
3       Amblyraja jenseni              0.06       LC   ray    Extant
4       Amblyraja radiata              0.86       VU   ray    Extant
5    Bathyraja spinicauda              0.73       NT   ray    Extant
6 Carcharhinus longimanus              0.01       CR shark    Extant
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

The Shark Detector has the most diverse dataset of shark species in the world, describing over 300 species and 69 classifiable species. To see a summary of the full training dataset, see the [Taxonomy Table](https://sp2.cs.vt.edu/dynamic/queryTax1.php). As we continue to crowdsource global observations, the performance and taxonomic range of the Shark Detector will increase!

## Contact
Author: Jeremy F. Jenrette
- Email: jjeremy1@vt.edu
