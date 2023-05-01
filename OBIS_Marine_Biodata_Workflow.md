---
title: "OBIS Marine Biodata Workshop"
author: "Stace Beaulieu, Ian Brunjes"
date: "2023-04-18"
output: 
  html_document:
    keep_md: true
---



# Overview

Notebook developed with R version 4.2.2

## Use Case

- Interoperable IFCB data product for the CA HAB Bulletin
- IFCB Dashboard to OBIS use case with automated classification
- Event core with Occurrence extension

## Authors

Ian Brunjes (SCCOOS), Stace Beaulieu (WHOI)
Prepared for OBIS IOOS Marine Biological Data Mobilization Workshop April 2023

**This is a prototype for testing purposes only.**
**A protocol is being developed to determine if and when appropriate to submit products from automated classification to OBIS.**

Sponsored by NOAA PCMHAB20 project “Harmful Algal Bloom Community Technology Accelerator”

# Workflow

Main steps in the workflow can be related to the [IFCB workflow diagram](https://raw.githubusercontent.com/hsosik/ifcb-analysis/master/Development/IFCB%20workflow%20chart.png) in the [ifcb-analysis wiki on GitHub](https://github.com/hsosik/ifcb-analysis/wiki)

Step: Classification
- Interpretation for the autoclass scores / transform automated classification into presence/absence

Step: Matching class labels to scientific names and IDs
- Match the class labels to scientific names in the World Register of Marine Species (WoRMS) taxonomic database.

Step: Summarization
- Calculate concentration as number of ROIs classified to a taxon divided by volume analyzed

Next step (not shown / would extend the diagram): Transforming to Darwin Core
- Map resulting data table into Darwin Core table(s)

## Target data product to standardize to Darwin Core:
Concentration of 2 genera of HAB taxa from an IFCB sample(s) (e.g., [here is a sample with autoclass available in HABDAC at Del Mar Mooring](https://ifcb.caloos.org/timeline?dataset=del-mar-mooring&bin=D20210620T221255_IFCB158)

Preconditions:
- IFCB Dashboard sample (bin) has autoclass csv file with scores per class label from automated classifier
- IFCB Dashboard sample has been populated with a dataset name, volume_analyzed, datetime, latitude, longitude, and depth
- For autoclass labels: A lookup table has been prepared with thresholds per class label

This workflow is being developed to meet the EU Horizon 2020 “Best practices and recommendations for plankton imagery data management” http://dx.doi.org/10.25607/OBP-1742

## Classification
In this step, we interpret the autoclass scores from the autoclass.csv file on the IFCB Dashboard. We will filter to the targeted class labels, apply a threshold per class label, and determine the “winning” class label per ROI, thus transforming the automated classification into a presence/absence table.


```r
target_labels = read_csv(here("data", "target_classification_labels.csv"))

kable(target_labels) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;"> label </th>
   <th style="text-align:left;"> intended_worms_taxon </th>
   <th style="text-align:right;"> autoclass_threshold </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:right;"> 0.2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 0.7 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 0.7 </td>
  </tr>
</tbody>
</table></div>


The order of operations is important in this filtering and thresholding process. If the filtering is applied prior to thresholding, the concentration is possibly (likely) to be overestimated by excluding other classes that may have higher scores.

**Thresholds used in this prototype are for testing purposes only.**

Our initial prototype will retain as ‘absence’ (zero count) when no ROIs exceed per-class threshold. However, we acknowledge that data providers may want to use a different per-class threshold to report absence, and might only want to report presence.

Once the output from this Classification step is matched to scientific names and IDs (next step) the intermediate table loosely corresponds to Level 1b SeaBASS file (classification per ROI).



```r
sample_bin = "D20210926T181303_IFCB158"
bin_details = get_bin_details(sample_bin)
# Thresholds used in this prototype are for testing purposes only.

bin_occurrences = get_bin_occurrences(sample_bin, target_labels)
kable(bin_occurrences) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;"> pid </th>
   <th style="text-align:left;"> class </th>
   <th style="text-align:right;"> score </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158_01203 </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 0.9565 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158_01634 </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 0.7026 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158_01650 </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 0.9560 </td>
  </tr>
</tbody>
</table></div>

## Matching class labels to scientific names and IDs
In this step, we use (a portion of) each autoclass label to query the API of the World Register of Marine Species (WoRMS) taxonomic database to return an accepted scientific name, its paired Aphia ID, and its taxon rank and kingdom.


```r
wm_records = get_worms_taxonomy(target_labels$intended_worms_taxon)
kable(wm_records) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:right;"> AphiaID </th>
   <th style="text-align:left;"> scientificname </th>
   <th style="text-align:left;"> lsid </th>
   <th style="text-align:left;"> rank </th>
   <th style="text-align:left;"> kingdom </th>
   <th style="text-align:left;"> intended_worms_taxon </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:right;"> 109470 </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> Alexandrium </td>
  </tr>
  <tr>
   <td style="text-align:right;"> 149151 </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
  </tr>
</tbody>
</table></div>

## Summarization
In this step, we use the table from the Classification step and results from the Matching to WoRMS step to calculate concentration as number of ROIs classified to a taxon divided by volume analyzed per sample.

Output from the Summarization step loosely corresponds to Level 2 SeaBASS file.


```r
occurrences_summary = summarize_bin_occurrences(bin_details, bin_occurrences, target_labels)
kable(occurrences_summary) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;"> intended_worms_taxon </th>
   <th style="text-align:right;"> occurrences </th>
   <th style="text-align:left;"> taxon_classes </th>
   <th style="text-align:left;"> associated_rois </th>
   <th style="text-align:right;"> occurrences_per_ml </th>
   <th style="text-align:left;"> sampleTime </th>
   <th style="text-align:right;"> lat </th>
   <th style="text-align:right;"> lng </th>
   <th style="text-align:left;"> bin_id </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> 2021-09-26T18:13:03+00:00 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:right;"> 3 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> _01203 | _01634 | _01650 </td>
   <td style="text-align:right;"> 0.7109005 </td>
   <td style="text-align:left;"> 2021-09-26T18:13:03+00:00 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
  </tr>
</tbody>
</table></div>

## Transforming to Darwin Core
In this step, we transform the table from the Summarization step into two tables (an event table and an occurrence table) and add columns to meet OBIS and GBIF requirements for the Darwin Core Archive package.

We also add columns to meet the EU Horizon 2020 “Best practices and recommendations for plankton imagery data management” http://dx.doi.org/10.25607/OBP-1742

To assign the unique occurrenceID for the concentrations per taxon per sample we used eventID_taxonID, a pattern similar to the EU best practice, such that an individual included in the summed count would be represented by eventID_taxonID_roiID. Ultimately, we would like to test the DwC ResourceRelationship extension and/or DwC term associatedOrganisms to relate individuals to abundances reported to OBIS.


```r
# Build the Darwin Core Event table
event_tbl = build_event_table(bin_details)
kable(event_tbl) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;"> datasetName </th>
   <th style="text-align:left;"> eventID </th>
   <th style="text-align:left;"> eventDate </th>
   <th style="text-align:right;"> decimalLongitude </th>
   <th style="text-align:right;"> decimalLatitude </th>
   <th style="text-align:left;"> countryCode </th>
   <th style="text-align:left;"> geodeticDatum </th>
   <th style="text-align:right;"> minimumDepthInMeters </th>
   <th style="text-align:right;"> maximumDepthInMeters </th>
   <th style="text-align:right;"> sampleSizeValue </th>
   <th style="text-align:left;"> sampleSizeUnit </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T18:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.22 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
</tbody>
</table></div>



```r
# Join occurrence summary with taxon records
wm_occurrences = left_join(occurrences_summary, wm_records, by = c("intended_worms_taxon" = "intended_worms_taxon"))

# Build the Darwin Core Occurrence table
occurrence_tbl = build_occurrence_table(wm_occurrences, bin_details)
kable(occurrence_tbl) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%")
```

<div style="border: 1px solid #ddd; padding: 5px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;"> eventID </th>
   <th style="text-align:left;"> occurrenceID </th>
   <th style="text-align:left;"> basisOfRecord </th>
   <th style="text-align:left;"> identifiedBy </th>
   <th style="text-align:left;"> identificationVerificationStatus </th>
   <th style="text-align:left;"> identificationReferences </th>
   <th style="text-align:left;"> identificationRemarks </th>
   <th style="text-align:left;"> associatedMedia </th>
   <th style="text-align:left;"> verbatimIdentification </th>
   <th style="text-align:left;"> scientificName </th>
   <th style="text-align:left;"> scientificNameID </th>
   <th style="text-align:left;"> taxonRank </th>
   <th style="text-align:left;"> kingdom </th>
   <th style="text-align:left;"> occurrenceStatus </th>
   <th style="text-align:right;"> organismQuantity </th>
   <th style="text-align:left;"> organismQuantityType </th>
   <th style="text-align:left;"> institutionCode </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01203 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01634 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01650 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.7109005 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
</tbody>
</table></div>

## Extending to multiple events for time period


```r
# Demonstrating how to build the DwC tables for all bins within a span of time
start_date = "2021-09-25"
end_date = "2021-09-27"

# Read in classification input parameters
target_labels = read_csv(here("data", "target_classification_labels.csv"))

# Query WORMS lookup table
wm_records = get_worms_taxonomy(target_labels$intended_worms_taxon)

# Get the ifcb bins within time span and construct
bin_ids = get_bins_in_range(start_date, end_date)

event_tables = list()
occurrence_tables = list()

for(bin in bin_ids) {
  if (bin_has_autoclass(bin)) {
    # Build occurrence summary
    bin_details = get_bin_details(bin)
    bin_occurrences = get_bin_occurrences(bin, target_labels)
    occurrences_summary = summarize_bin_occurrences(bin_details, bin_occurrences, target_labels)
    
    # Build dwc event table
    event_tbl = build_event_table(bin_details)
    
    # Build dwc occurrence table
    wm_occurrences = left_join(occurrences_summary, wm_records, by = c("intended_worms_taxon" = "intended_worms_taxon"))
    occurrence_tbl = build_occurrence_table(wm_occurrences, bin_details)
    
    event_tables[bin] = list(event_tbl)
    occurrence_tables[bin] = list(occurrence_tbl)
  }
}

# Bind each per bin result into single event/occurrence table
event_tbl = bind_rows(event_tables)
occurrence_tbl = bind_rows(occurrence_tables)

# Save to output to .csv
write_csv(event_tbl, here("output", "event.csv"))
write_csv(occurrence_tbl, here("output", "occurrence.csv"))
```



### Aggregated event table


```r
kable(event_tbl) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%", height = "400px")
```

<div style="border: 1px solid #ddd; padding: 0px; overflow-y: scroll; height:400px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> datasetName </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> eventID </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> eventDate </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> decimalLongitude </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> decimalLatitude </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> countryCode </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> geodeticDatum </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> minimumDepthInMeters </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> maximumDepthInMeters </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> sampleSizeValue </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> sampleSizeUnit </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T211303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T21:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.336 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T18:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.220 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T151303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T15:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.482 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T121304_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T12:13:04+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.538 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T091303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T09:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.578 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T061303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T06:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.616 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T031304_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T03:13:04+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.562 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210926T001304_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-26T00:13:04+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.581 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T211305_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T21:13:05+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.328 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T181304_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T18:13:04+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.289 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T151304_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T15:13:04+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.166 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T121306_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T12:13:06+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.381 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T091303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T09:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.554 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T061303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T06:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.580 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T031303_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T03:13:03+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.558 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
  <tr>
   <td style="text-align:left;"> del-mar-mooring </td>
   <td style="text-align:left;"> D20210925T001302_IFCB158 </td>
   <td style="text-align:left;"> 2021-09-25T00:13:02+00:00 </td>
   <td style="text-align:right;"> -117.3165 </td>
   <td style="text-align:right;"> 32.92917 </td>
   <td style="text-align:left;"> US </td>
   <td style="text-align:left;"> WGS84 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 4.436 </td>
   <td style="text-align:left;"> milliliter </td>
  </tr>
</tbody>
</table></div>




### Aggregated occurrence table


```r
kable(occurrence_tbl) %>% kable_material(c("striped", "hover")) %>% scroll_box(width = "100%", height = "400px")
```

<div style="border: 1px solid #ddd; padding: 0px; overflow-y: scroll; height:400px; overflow-x: scroll; width:100%; "><table class=" lightable-material lightable-striped lightable-hover" style='font-family: "Source Sans Pro", helvetica, sans-serif; margin-left: auto; margin-right: auto;'>
 <thead>
  <tr>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> eventID </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> occurrenceID </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> basisOfRecord </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> identifiedBy </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> identificationVerificationStatus </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> identificationReferences </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> identificationRemarks </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> associatedMedia </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> verbatimIdentification </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> scientificName </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> scientificNameID </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> taxonRank </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> kingdom </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> occurrenceStatus </th>
   <th style="text-align:right;position: sticky; top:0; background-color: #FFFFFF;"> organismQuantity </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> organismQuantityType </th>
   <th style="text-align:left;position: sticky; top:0; background-color: #FFFFFF;"> institutionCode </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> D20210926T211303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T211303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T211303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T211303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T211303_IFCB158&amp;image=00672 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T211303_IFCB158&amp;image=00950 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4612546 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T181303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T181303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01203 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01634 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T181303_IFCB158&amp;image=01650 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.7109005 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T151303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T151303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T151303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T151303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T151303_IFCB158&amp;image=00999 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.2231147 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T121304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T121304_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T121304_IFCB158&amp;image=00076 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T121304_IFCB158&amp;image=00928 </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4407228 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T121304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T121304_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T121304_IFCB158&amp;image=00739 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T121304_IFCB158&amp;image=01033 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4407228 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T091303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T091303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T091303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T091303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00133 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00188 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00519 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00556 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00575 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T091303_IFCB158&amp;image=00673 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 1.3106160 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T061303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T061303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T061303_IFCB158 </td>
   <td style="text-align:left;"> D20210926T061303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T061303_IFCB158&amp;image=00481 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T061303_IFCB158&amp;image=00882 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4332756 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T031304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T031304_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T031304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T031304_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T031304_IFCB158&amp;image=00188 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T031304_IFCB158&amp;image=00982 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4384042 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T001304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T001304_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210926T001304_IFCB158 </td>
   <td style="text-align:left;"> D20210926T001304_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210926T001304_IFCB158&amp;image=00694 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.2182929 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T211305_IFCB158 </td>
   <td style="text-align:left;"> D20210925T211305_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T211305_IFCB158 </td>
   <td style="text-align:left;"> D20210925T211305_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00078 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00110 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00164 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00287 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00563 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00717 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00749 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00845 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=00946 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01037 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01056 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01220 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01222 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01256 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01620 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T211305_IFCB158&amp;image=01688 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 3.6968577 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T181304_IFCB158 </td>
   <td style="text-align:left;"> D20210925T181304_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T181304_IFCB158 </td>
   <td style="text-align:left;"> D20210925T181304_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=00186 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=00227 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=00675 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=00676 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=01000 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=01416 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=01465 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=01728 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T181304_IFCB158&amp;image=01824 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 2.0983912 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T151304_IFCB158 </td>
   <td style="text-align:left;"> D20210925T151304_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=01191 </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.2400384 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T151304_IFCB158 </td>
   <td style="text-align:left;"> D20210925T151304_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00125 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00272 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00364 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00438 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00606 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00892 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00905 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00908 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=00952 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=01016 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=01201 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=01358 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T151304_IFCB158&amp;image=01959 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 3.1204993 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T121306_IFCB158 </td>
   <td style="text-align:left;"> D20210925T121306_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T121306_IFCB158 </td>
   <td style="text-align:left;"> D20210925T121306_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=00364 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=00441 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=00690 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=00943 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=01005 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=01117 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T121306_IFCB158&amp;image=01352 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 1.5978087 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T091303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T091303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T091303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T091303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T091303_IFCB158&amp;image=00138 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T091303_IFCB158&amp;image=00197 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T091303_IFCB158&amp;image=00365 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.6587615 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T061303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T061303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T061303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T061303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T061303_IFCB158&amp;image=01003 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.2183406 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T031303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T031303_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T031303_IFCB158 </td>
   <td style="text-align:left;"> D20210925T031303_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T031303_IFCB158&amp;image=00190 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T031303_IFCB158&amp;image=00673 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T031303_IFCB158&amp;image=01017 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T031303_IFCB158&amp;image=01019 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.8775779 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T001302_IFCB158 </td>
   <td style="text-align:left;"> D20210925T001302_IFCB158_109470 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Alexandrium catenella </td>
   <td style="text-align:left;"> Alexandrium </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:109470 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> absent </td>
   <td style="text-align:right;"> 0.0000000 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
  <tr>
   <td style="text-align:left;"> D20210925T001302_IFCB158 </td>
   <td style="text-align:left;"> D20210925T001302_IFCB158_149151 </td>
   <td style="text-align:left;"> MachineObservation </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> PredictedByMachine </td>
   <td style="text-align:left;"> Trained machine learning model: `20220416_Delmar_NES_1.ptl` (recommend publishing to a community or institutional repository for DOI) | Software to run the trained machine learning model: https://github.com/WHOIGit/ifcb_classifier (recommend referring to GitHub release or commit if not published for DOI) | Software to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/ifcb_autoclass_eval.R | Input parameters to interpret autoclass scores: https://github.com/sccoos/OBIS_workshop_2023_IFCB/blob/e4bbb4ced39270d517a7c4e396dd828e9bb688cb/data/target_classification_labels.csv </td>
   <td style="text-align:left;"> Arbitrary threshold used for both presence and absence without testing for false positives. </td>
   <td style="text-align:left;"> https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T001302_IFCB158&amp;image=00368 | https://ifcb.caloos.org/image?dataset=del-mar-mooring&amp;bin=D20210925T001302_IFCB158&amp;image=01219 </td>
   <td style="text-align:left;"> Pseudo-nitzschia | pennate Pseudo-nitzschia </td>
   <td style="text-align:left;"> Pseudo-nitzschia </td>
   <td style="text-align:left;"> urn:lsid:marinespecies.org:taxname:149151 </td>
   <td style="text-align:left;"> Genus </td>
   <td style="text-align:left;"> Chromista </td>
   <td style="text-align:left;"> present </td>
   <td style="text-align:right;"> 0.4508566 </td>
   <td style="text-align:left;"> counts per milliliter </td>
   <td style="text-align:left;"> AxiomROR </td>
  </tr>
</tbody>
</table></div>



### Visualizing results

```r
# Join event timestamp to occurrences
eo = left_join(occurrence_tbl, event_tbl, by = join_by(eventID)) %>% mutate(eventDate = as_datetime(eventDate)) %>% select(eventID, eventDate, scientificName, organismQuantity)


# Built plotly
p = eo %>% ggplot(aes(x=eventDate, y=organismQuantity, color = scientificName)) + geom_point() + geom_line() + labs(x = "", y = "organismQuantity (counts per milliliter)", title = paste0("Del Mar IFCB Occurrence Data (", start_date, " - ", end_date, ")"))

ggplotly(p) %>% layout(legend = list(title = "", x = 0.75, y = 0.9))
```

```{=html}
<div class="plotly html-widget html-fill-item-overflow-hidden html-fill-item" id="htmlwidget-636c3f0c085f2e0ef842" style="width:100%;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-636c3f0c085f2e0ef842">{"x":{"data":[{"x":[1632690783,1632679983,1632669183,1632658384,1632647583,1632636783,1632625984,1632615184,1632604385,1632593584,1632582784,1632571986,1632561183,1632550383,1632539583,1632528782],"y":[0,0,0,0.440722785368004,0,0,0,0,0,0,0.240038406144983,0,0,0,0,0],"text":["eventDate: 2021-09-26 21:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 18:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 15:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 12:13:04<br />organismQuantity: 0.4407228<br />scientificName: Alexandrium","eventDate: 2021-09-26 09:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 06:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 03:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 00:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 21:13:05<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 18:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 15:13:04<br />organismQuantity: 0.2400384<br />scientificName: Alexandrium","eventDate: 2021-09-25 12:13:06<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 09:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 06:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 03:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 00:13:02<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium"],"type":"scatter","mode":"markers","marker":{"autocolorscale":false,"color":"rgba(248,118,109,1)","opacity":1,"size":5.66929133858268,"symbol":"circle","line":{"width":1.88976377952756,"color":"rgba(248,118,109,1)"}},"hoveron":"points","name":"Alexandrium","legendgroup":"Alexandrium","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1632690783,1632679983,1632669183,1632658384,1632647583,1632636783,1632625984,1632615184,1632604385,1632593584,1632582784,1632571986,1632561183,1632550383,1632539583,1632528782],"y":[0.461254612546125,0.710900473933649,0.223114680946006,0.440722785368004,1.31061598951507,0.433275563258232,0.438404208680403,0.218292949137743,3.69685767097967,2.09839123338774,3.12049927988478,1.59780871947044,0.658761528326746,0.218340611353712,0.877577885037297,0.450856627592426],"text":["eventDate: 2021-09-26 21:13:03<br />organismQuantity: 0.4612546<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 18:13:03<br />organismQuantity: 0.7109005<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 15:13:03<br />organismQuantity: 0.2231147<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 12:13:04<br />organismQuantity: 0.4407228<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 09:13:03<br />organismQuantity: 1.3106160<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 06:13:03<br />organismQuantity: 0.4332756<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 03:13:04<br />organismQuantity: 0.4384042<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 00:13:04<br />organismQuantity: 0.2182929<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 21:13:05<br />organismQuantity: 3.6968577<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 18:13:04<br />organismQuantity: 2.0983912<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 15:13:04<br />organismQuantity: 3.1204993<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 12:13:06<br />organismQuantity: 1.5978087<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 09:13:03<br />organismQuantity: 0.6587615<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 06:13:03<br />organismQuantity: 0.2183406<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 03:13:03<br />organismQuantity: 0.8775779<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 00:13:02<br />organismQuantity: 0.4508566<br />scientificName: Pseudo-nitzschia"],"type":"scatter","mode":"markers","marker":{"autocolorscale":false,"color":"rgba(0,191,196,1)","opacity":1,"size":5.66929133858268,"symbol":"circle","line":{"width":1.88976377952756,"color":"rgba(0,191,196,1)"}},"hoveron":"points","name":"Pseudo-nitzschia","legendgroup":"Pseudo-nitzschia","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1632528782,1632539583,1632550383,1632561183,1632571986,1632582784,1632593584,1632604385,1632615184,1632625984,1632636783,1632647583,1632658384,1632669183,1632679983,1632690783],"y":[0,0,0,0,0,0.240038406144983,0,0,0,0,0,0,0.440722785368004,0,0,0],"text":["eventDate: 2021-09-25 00:13:02<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 03:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 06:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 09:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 12:13:06<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 15:13:04<br />organismQuantity: 0.2400384<br />scientificName: Alexandrium","eventDate: 2021-09-25 18:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-25 21:13:05<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 00:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 03:13:04<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 06:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 09:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 12:13:04<br />organismQuantity: 0.4407228<br />scientificName: Alexandrium","eventDate: 2021-09-26 15:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 18:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium","eventDate: 2021-09-26 21:13:03<br />organismQuantity: 0.0000000<br />scientificName: Alexandrium"],"type":"scatter","mode":"lines","line":{"width":1.88976377952756,"color":"rgba(248,118,109,1)","dash":"solid"},"hoveron":"points","name":"Alexandrium","legendgroup":"Alexandrium","showlegend":false,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1632528782,1632539583,1632550383,1632561183,1632571986,1632582784,1632593584,1632604385,1632615184,1632625984,1632636783,1632647583,1632658384,1632669183,1632679983,1632690783],"y":[0.450856627592426,0.877577885037297,0.218340611353712,0.658761528326746,1.59780871947044,3.12049927988478,2.09839123338774,3.69685767097967,0.218292949137743,0.438404208680403,0.433275563258232,1.31061598951507,0.440722785368004,0.223114680946006,0.710900473933649,0.461254612546125],"text":["eventDate: 2021-09-25 00:13:02<br />organismQuantity: 0.4508566<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 03:13:03<br />organismQuantity: 0.8775779<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 06:13:03<br />organismQuantity: 0.2183406<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 09:13:03<br />organismQuantity: 0.6587615<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 12:13:06<br />organismQuantity: 1.5978087<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 15:13:04<br />organismQuantity: 3.1204993<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 18:13:04<br />organismQuantity: 2.0983912<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-25 21:13:05<br />organismQuantity: 3.6968577<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 00:13:04<br />organismQuantity: 0.2182929<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 03:13:04<br />organismQuantity: 0.4384042<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 06:13:03<br />organismQuantity: 0.4332756<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 09:13:03<br />organismQuantity: 1.3106160<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 12:13:04<br />organismQuantity: 0.4407228<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 15:13:03<br />organismQuantity: 0.2231147<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 18:13:03<br />organismQuantity: 0.7109005<br />scientificName: Pseudo-nitzschia","eventDate: 2021-09-26 21:13:03<br />organismQuantity: 0.4612546<br />scientificName: Pseudo-nitzschia"],"type":"scatter","mode":"lines","line":{"width":1.88976377952756,"color":"rgba(0,191,196,1)","dash":"solid"},"hoveron":"points","name":"Pseudo-nitzschia","legendgroup":"Pseudo-nitzschia","showlegend":false,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null}],"layout":{"margin":{"t":43.7625570776256,"r":7.30593607305936,"b":25.5707762557078,"l":31.4155251141553},"plot_bgcolor":"rgba(235,235,235,1)","paper_bgcolor":"rgba(255,255,255,1)","font":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187},"title":{"text":"Del Mar IFCB Occurrence Data (2021-09-25 - 2021-09-27)","font":{"color":"rgba(0,0,0,1)","family":"","size":17.5342465753425},"x":0,"xref":"paper"},"xaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[1632520681.95,1632698883.05],"tickmode":"array","ticktext":["Sep 25 00:00","Sep 25 12:00","Sep 26 00:00","Sep 26 12:00"],"tickvals":[1632528000,1632571200,1632614400,1632657600],"categoryorder":"array","categoryarray":["Sep 25 00:00","Sep 25 12:00","Sep 26 00:00","Sep 26 12:00"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.65296803652968,"tickwidth":0.66417600664176,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.689497716895},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176,"zeroline":false,"anchor":"y","title":{"text":"","font":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187}},"hoverformat":".2f"},"yaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[-0.184842883548983,3.88170055452865],"tickmode":"array","ticktext":["0","1","2","3"],"tickvals":[0,1,2,3],"categoryorder":"array","categoryarray":["0","1","2","3"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.65296803652968,"tickwidth":0.66417600664176,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.689497716895},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176,"zeroline":false,"anchor":"x","title":{"text":"organismQuantity (counts per milliliter)","font":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187}},"hoverformat":".2f"},"shapes":[{"type":"rect","fillcolor":null,"line":{"color":null,"width":0,"linetype":[]},"yref":"paper","xref":"paper","x0":0,"x1":1,"y0":0,"y1":1}],"showlegend":true,"legend":{"bgcolor":"rgba(255,255,255,1)","bordercolor":"transparent","borderwidth":1.88976377952756,"font":{"color":"rgba(0,0,0,1)","family":"","size":11.689497716895},"title":"","x":0.75,"y":0.9},"hovermode":"closest","barmode":"relative"},"config":{"doubleClick":"reset","modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"source":"A","attrs":{"15ab93bece860":{"x":{},"y":{},"colour":{},"type":"scatter"},"15ab93e8c155c":{"x":{},"y":{},"colour":{}}},"cur_data":"15ab93bece860","visdat":{"15ab93bece860":["function (y) ","x"],"15ab93e8c155c":["function (y) ","x"]},"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.2,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>
```

