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
read_autoclass_csv = function(bin, target_species = c()) {
  url = "https://ifcb.caloos.org/del-mar-mooring/"
  file_name = paste0(bin, "_class_scores.csv")
  bin_url = paste0(url, file_name)
  
  out <- tryCatch(
    {
      autoclass = read_csv(bin_url)
      
      # Filter to variables of interest
      if (!is_empty(target_species)) {
        autoclass = autoclass %>% select(all_of(c("pid", target_species)))
        return(autoclass)
      }
       else {
         message("target_species list must be provided")
         return(NA)
       }
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


#' Get detailed info for a IFCB bin
#' 
#' @param bin A string, the bin id.
#' @returns A list, the bin details.
#' @examples
#' get_bin_details("D20230326T150748_IFCB158")
get_bin_details = function(bin) {
  url = "https://ifcb.caloos.org/api/bin/"
  bin_url = paste0(url, bin)
  request = httr::GET(url = bin_url)
  
  if (request$status_code == 200) {
    content = content(request, as = "parsed")
    return(content)
  } else {
    message("Bin neighbors GET request failed with code: ", request$status_code)
    return(request$status_code)
  }
}
