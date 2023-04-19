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

#' Build summary table of occurrences
#' 
#' @param bin_details A list, the list of bin details.
#' @param occurrence_table A dataframe, the table of occurrences.
#' @param target_labels A datadframe, of the provided taxon & thresholds.
#' @returns A dataframe, a summary of occurrences.
#' @examples
#' get_bin_occurrence_summary(bin_details, occurrence_table, target_labels)
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
  
  get_labels_for_taxon = function(taxon) {
    filtered = target_labels %>% filter(intended_worms_taxon == taxon)
    return(str_c(filtered$label, collapse = " | "))
  }
  
  get_row_pids_for_taxon = function(bin_id, taxa) {
    filtered = occurrence_table %>% filter(str_detect(taxa, class)) %>%
      mutate(row_id = str_replace(pid, bin_id, ""))
  
    return(str_c(filtered$row_id, collapse = " | "))
  }
  
  # Add represented class labels
  bin_reclass_summary = bin_reclass_summary %>% rowwise() %>% 
    mutate(
      taxon_classes = get_labels_for_taxon(intended_worms_taxon),
      associated_rois = get_row_pids_for_taxon(bin_details$bin_id, taxon_classes)
    )
  
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
  
  return(bin_reclass_summary)
}

#' Perform worms lookup on taxa
#' 
#' @param taxa A list, the list of taxa.
#' @returns A dataframe, a table of worms records for the provided taxa.
#' @examples
#' get_worms_taxonomy(target_labels$intended_worms_taxon)
get_worms_taxonomy = function(taxa) {
  wm_records = list()
  for(i in 1:length(taxa)) {
    taxon = taxa[[i]]
    
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

#' Build Darwin core Event table
#' 
#' @param bin_details A list, the bin details.
#' @returns A dataframe, a table of darwin core events.
#' @examples
#' build_event_table(bin_details)
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
    maximumDepthInMeters = bin_details$depth,
    sampleSizeValue = as.double(str_extract(bin_details$ml_analyzed, "\\d+\\.+\\d+")),
    sampleSizeUnit = "milliliter"
  )
  
  return(as.tibble(event))
}

#' Build Darwin core Occurrence table
#' 
#' @param occurrences_summary A dataframe, the occurrences summary table.
#' @param bin_details A list, the bin details.
#' @returns A dataframe, a table of darwin core occurrences
#' @examples
#' build_occurrence_table(bin_details)
build_occurrence_table = function(occurrences_summary, bin_details) {
  occurrences = occurrences_summary %>% 
    transmute(
      eventID = bin_details$bin_id,
      occurrenceID = paste0(bin_details$bin_id, "_", AphiaID),
      basisOfRecord = "MachineObservation",
      identifiedBy = "",
      identificationVerificationStatus = "PredictedByMachine",
      identificationReferences = "Machine learning model (DOI for trained model) | Software to run the machine learning model (version) | Software to interpret autoclass scores (cite this notebook version)", #TODO git branch: system("git rev-parse HEAD", intern=TRUE),
      associatedMedia = str_replace_all(associated_rois, "_", paste0("https://ifcb.caloos.org/image?", "dataset=", bin_details$primary_dataset, "&bin=", bin_details$bin_id, "&image=")), #https://ifcb.caloos.org/image?image=00108&dataset=del-mar-mooring&bin=D20210926T181303_IFCB158
      verbatimIdentification = taxon_classes,
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
