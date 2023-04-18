# R script to interpret IFCB autoclass data
# TODO: more information about script
source("ifcb_rest_api.R")


# Get target class labels and associated thresholds for inferring species presence

target_labels = read_csv(here("data", "target_classification_labels.csv"))

# For a given bin:
bin_id = "D20210926T181303_IFCB158"


## documentation
get_bin_occurrence_summary = function(bin_id, target_labels = c()) {
  ## 1. Check if bin has autoclass
  ## 2. Get bin metadata/details
  ## 3. Download/read autoclass data
  ## 4. Apply thresholds
  
  # If autoclass file exists for bin
  if (!bin_has_autoclass(bin_id)) {
    message("No autoclass file found for bin: ", bin_id)
    return(NA)
  }
  
  # Lookup map for class -> threshold, class -> taxon
  threshold_lookup = target_labels$autoclass_threshold
  names(threshold_lookup) = target_labels$label
  
  # Lookup map for class -> threshold
  taxon_lookup = target_labels$intended_worms_taxon
  names(taxon_lookup) = target_labels$label
  
  # Get bin information
  bin_metadata = get_ifcb_metadata(bin_id)
  bin_details = get_bin_details(bin_id)
  bin_ml_analyzed = as.double(str_extract(bin_details$ml_analyzed, "\\d+\\.+\\d+")) # TODO what if ml_analzed not present?
  
  # Get bin autoclass file
  bin_autoclass = read_autoclass_csv(bin_id, target_labels$label)
  bin_autoclass_filtered = bin_autoclass %>%
    pivot_longer(!pid, names_to = "class", values_to = "score") %>%
    filter(score >= threshold_lookup[class]) %>%
    group_by(pid) %>%
    top_n(1, score)
  
  bin_reclass_summary = bin_autoclass_filtered %>%
    mutate(taxon = taxon_lookup[class]) %>%
    group_by(taxon) %>%
    summarize(occurrences = n()) %>% 
    mutate(occurrences_per_ml = occurrences/bin_ml_analyzed)
  
  
  ## TODO
  # worms lookup: scientificName 	scientificNameID 	taxonRank kingdom
  # add event metadata
  
  bin_reclass_summary = bin_reclass_summary %>%
    mutate(
      sampleTime = bin_details$timestamp_iso,
      lat = bin_details$lat,
      lng = bin_details$lng,
      binId = bin_id
    )
  
  
  return(bin_reclass_summary)
}
