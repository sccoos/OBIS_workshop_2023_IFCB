# Load packages
library(tidyverse)
library(httr)
library(jsonlite)
library(here)

# test vars
ifcb_dataset = "del-mar-mooring"
ifcb_bin = "D20210926T181303_IFCB158"
autoclass_vars = c("pid", "Alexandrium catenella", "Pseudo-nitzschia", "pennate Pseudo-nitzschia")


#' Get metadata for a IFCB bin
#' 
#' @param bin A string, the bin id.
#' @returns A list, JSON response
#' @examples
#' get_ifcb_metadata("D20230326T150748_IFCB158")
get_ifcb_metadata = function(bin) {
  url = "https://ifcb.caloos.org/api/metadata/"
  bin_url = paste0(url, bin)
  request = httr::GET(url = bin_url)
  
  if (request$status_code == 200) {
    content = content(request, as = "parsed")
    return(content$metadata)
  } else {
    message("Metadata GET request failed with code: ", request$status_code)
    return(request$status_code)
  }
}


#' Check if bin has autoclass file available
#' 
#' @param bin A string, the bin id.
#' @returns A boolean.
#' @examples
#' bin_has_autoclass("D20230326T150748_IFCB158")
bin_has_autoclass = function(bin) {
  url = "https://ifcb.caloos.org/api/has_products/"
  bin_url = paste0(url, bin)
  request = httr::GET(url = bin_url)
  
  if (request$status_code == 200) {
    content = content(request, as = "parsed")
    return(content$has_class_scores)
  } else {
    message("Autoclass GET request failed with code:", request$status_code)
    return(request$status_code)
  }
}


#' Check if bin has autoclass file available
#' 
#' @param bin A string, the bin id.
#' @param bin A character vector, the variables to select from csv.
#' @returns A data frame.
#' @examples
#' read_autoclass_csv("D20230326T150748_IFCB158", c("pid", "Alexandrium catenella")
read_autoclass_csv = function(bin, filter_vars = c()) {
  url = "https://ifcb.caloos.org/del-mar-mooring/"
  file_name = paste0(bin, "_class_scores.csv")
  bin_url = paste0(url, file_name)
  
  out <- tryCatch(
    {
      autoclass = read_csv(bin_url)
      
      # Filter to variables of interest
      if (!is_empty(filter_vars)) {
        autoclass = autoclass %>% select(all_of(filter_vars))
      }
      
      return(autoclass)
    },
    error=function(cond) {
      message("Failed to read autoclass csv for bin ", bin)
      message("Error:")
      message(cond)
      return(NA)
    }
  )
  
  return(out)
}


#' Get metadata for a IFCB bin
#' 
#' @param bin A string, the bin id.
#' @returns A list, elements for linked bin ids.
#' @examples
#' get_bin_neighbors("D20230326T150748_IFCB158")
get_bin_neighbors = function(bin) {
  url = "https://ifcb.caloos.org/api/bin/"
  bin_url = paste0(url, bin)
  request = httr::GET(url = bin_url)
  
  if (request$status_code == 200) {
    content = content(request, as = "parsed")
    return(list("previous_bin" = content$previous_bin_id, "next_bin" = content$next_bin_id))
  } else {
    message("Bin neighbors GET request failed with code: ", request$status_code)
    return(request$status_code)
  }
}