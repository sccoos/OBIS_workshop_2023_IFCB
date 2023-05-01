# R script holding helper functions for Darwin Core mapping
library(worrms)


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
    eventID = bin_details$bin_id,
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
  
  return(as_tibble(event))
}

#' Build Darwin core Occurrence table
#' 
#' @param occurrences_summary A dataframe, the occurrences summary table.
#' @param bin_details A list, the bin details.
#' @returns A dataframe, a table of darwin core occurrences
#' @examples
#' build_occurrence_table(bin_details)
build_occurrence_table = function(occurrences_summary, bin_details) {
  curr_branch = system("git rev-parse HEAD", intern=TRUE)
  
  occurrences = occurrences_summary %>% 
    transmute(
      eventID = bin_details$bin_id,
      occurrenceID = paste0(bin_details$bin_id, "_", AphiaID),
      basisOfRecord = "MachineObservation",
      identifiedBy = "",
      identificationVerificationStatus = "PredictedByMachine",
      identificationReferences = paste0(
        "Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | ",
        "Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | ",
        "Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/",curr_branch,"/ifcb_autoclass_eval.R | ",
        "Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/",curr_branch,"/data/target_classification_labels.csv"
      ),
      identificationRemarks = "Arbitrary threshold used for both presence and absence without testing for false positives.",
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