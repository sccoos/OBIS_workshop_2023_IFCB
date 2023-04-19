# R script to interpret IFCB autoclass data
# TODO: more information about script
source("ifcb_rest_api.R")
library(worrms)

#' Get occurrences from bin based on taxon/thresholds
#' 
#' @param bin_id A string, the bin id.
#' @param target_labels A datadframe, of the provided taxon & thresholds.
#' @returns A dataframe, a summary of occurrences.
#' @examples
#' get_bin_occurrence_summary("D20230326T150748_IFCB158", target_labels)
get_bin_occurrence_summary = function(bin_id, target_labels = c()) {
  
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
  
  # Aggregate occurrence counts for each target taxon
  bin_reclass_summary = bin_autoclass_filtered %>%
    mutate(intended_worms_taxon = taxon_lookup[class]) %>%
    group_by(intended_worms_taxon) %>%
    summarize(occurrences = n())
  
  # Fill in absence
  bin_reclass_summary = bin_reclass_summary %>%
    complete(select(target_labels, intended_worms_taxon), fill = list(occurrences = 0))
  
  # Calculate occurrence per mL
  bin_reclass_summary = bin_reclass_summary %>% 
    mutate(occurrences_per_ml = occurrences/bin_ml_analyzed)
  
  # Add details to output table
  bin_reclass_summary = bin_reclass_summary %>%
    mutate(
      sampleTime = bin_details$timestamp_iso,
      lat = bin_details$lat,
      lng = bin_details$lng,
      binId = bin_id
    )
  
  
  return(bin_reclass_summary)
}

# Get worms
get_worms_taxonomy = function(taxons) {
  wm_records = list()
  for(i in 1:length(taxons)) {
    taxon = taxons[[i]]
    
    if(!exists(taxon, where = wm_records)) {
      record = worrms::wm_records_taxamatch(taxon, fuzzy = TRUE)[[1]]
      record = record %>% select(scientificname, lsid, rank, kingdom) %>% mutate(intended_worms_taxon = taxon)
      wm_records[taxon] = list(record)
    }
  }
  
  wm_df = bind_rows(wm_records)
  return(wm_df)
}
