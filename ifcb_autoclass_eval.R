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
get_bin_occurrences = function(bin_id, target_labels = c()) {
  
  # If autoclass file exists for bin
  if (!bin_has_autoclass(bin_id)) {
    message("No autoclass file found for bin: ", bin_id)
    return(NA)
  }
  
  # Lookup map for class -> threshold, class -> taxon
  threshold_lookup = target_labels$autoclass_threshold
  names(threshold_lookup) = target_labels$label
  
  # Get bin autoclass file
  bin_autoclass = read_autoclass_csv(bin_id, target_labels$label)
  bin_autoclass_filtered = bin_autoclass %>%
    pivot_longer(!pid, names_to = "class", values_to = "score") %>%
    filter(score >= threshold_lookup[class]) %>%
    group_by(pid) %>%
    top_n(1, score)
  
  return(bin_autoclass_filtered)
}

summarize_bin_occurrences = function(bin_details, occurrence_table, target_labels) {
  
  # Lookup map for class -> threshold
  taxon_lookup = target_labels$intended_worms_taxon
  names(taxon_lookup) = target_labels$label
  
  # Get bin information
  bin_ml_analyzed = as.double(str_extract(bin_details$ml_analyzed, "\\d+\\.+\\d+")) # TODO what if ml_analzed not present?
  
  # Aggregate occurrence counts for each target taxon
  bin_reclass_summary = occurrence_table %>%
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
      bin_id = bin_details$bin_id
    )
  
  # TODO: Add column providing verbatim class labels used to inform occurences
  
  return(bin_reclass_summary)
}

# Get worms
get_worms_taxonomy = function(taxons) {
  wm_records = list()
  for(i in 1:length(taxons)) {
    taxon = taxons[[i]]
    
    if(!exists(taxon, where = wm_records)) {
      #TODO: wrap in try catch for failed lookups/no match
      record = worrms::wm_records_taxamatch(taxon, fuzzy = TRUE)[[1]]
      if(record$status == "accepted") {
        record = record %>% select(AphiaID, scientificname, lsid, rank, kingdom) %>% mutate(intended_worms_taxon = taxon)
        wm_records[taxon] = list(record)
      } else {
        message("Found record does not have status 'accepted'")
      }
    }
  }
  
  wm_df = bind_rows(wm_records)
  return(wm_df)
}

build_event_table = function(bin_details) {
  event = list(
    datasetName = bin_details$primary_dataset,
    eventId = bin_details$bin_id,
    eventDate = bin_details$timestamp_iso,
    decimalLongitude = bin_details$lng,
    decimalLatitude = bin_details$lat,
    countryCode = 'US',
    geodeticDatum = 'WGS84',
    minimumDepthInMeters = bin_details$depth,
    maximumDepthInMeters = bin_details$depth
  )
  
  return(as.tibble(event))
}

build_occurrence_table = function(occurrences_summary, bin_details) {
  occurrences = occurrences_summary %>% 
    transmute(
      eventID = bin_id,
      occurrenceID = paste0(bin_id, "_", AphiaID),
      basisOfRecord = "MachineObservation",
      identifiedBy = "",
      identificationVerificationStatus = "PredictedByMachine",
      identificationReferences = "Machine learning model (here is where we will recommend DOI for trained model) | Software to run the machine learning model (cite version) | Software to interpret autoclass scores (cite this notebook version)", #TODO git branch: system("git rev-parse HEAD", intern=TRUE),
      associatedMedia = paste0("https://ifcb.caloos.org/timeline?", "dataset=", bin_details$primary_dataset, "&bin=", bin_id),
      verbatimIdentification = "", #TODO gather class labels used for this occurrence
      scientificName = scientificname,
      scientificNameID = lsid,
      taxonRank = rank,
      kingdom = kingdom,
      occurrenceStatus = ifelse(occurrences > 0, "present", "absent"),
      organismQuantity = occurrences_per_ml,
      organismQuantityType = "counts per milliliter",
      institutionCode = "AxiomROR"
    )
  
  return(occurrences)
}
