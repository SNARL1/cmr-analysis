Capture-mark-recapture analyses associated with mountain yellow-legged frog recovery efforts
----------------------------------------

### Authors of this repository

Roland A. Knapp (roland.knapp(at)ucsb.edu) [![ORCiD](https://img.shields.io/badge/ORCiD-0000--0002--1954--2745-green.svg)](http://orcid.org/0000-0002-1954-2745)

Thomas C. Smith (tcsmith(at)ucsb.edu [![ORCiD](https://img.shields.io/badge/ORCiD-0000--0001--7908--438X-green.svg)](http://orcid.org/0000-0001-7908-438X)

### Overview of contents

This repository contains data from capture-mark-recapture surveys conducted on populations of the endangered [mountain yellow-legged frog](https://www.fws.gov/sacramento/es_species/Accounts/Amphibians-Reptiles/sn_yellow_legged_frog/documents/Mountain-Yellow-Legged-Frog-Conservation-Strategy-Signed-508.pdf), and the code to analyze the survey data. The results from these analyses are used to describe the status of frog populations of particular interest, including populations that were established using translocations of adult frogs (e.g., [Joseph and Knapp 2018](https://doi.org/10.1002/ecs2.2499)), and donor populations from which frogs are collected for translocations. Results from many of these analyses are included in a manuscript (in preparation) that describes the establishment dynamics of frog populations following translocations. 

This repository contains the following directories and files:
* `code/` directory: Contains `Rmd` files that describe the creation of all datasets for each site (`xxxxx_createdata_mrmr.Rmd`), and analysis of those data using the [mrmr](https://github.com/SNARL1/mrmr) package (`xxxx_analysis_mrmr.Rmd`). 
* `data/` directory: Contains raw data, and cleaned data that are error-checked and formatted for use in mrmr. 
* `out/` directory: Contains model fit `Rds` files, figures displaying frog survival, adult frog abundance, and frog recruitment, tables displaying the survival of translocated frogs, and html-rendered "notebooks" of all `Rmd` files and their associated outputs. The html version of notebooks are particularly useful for reviewing the current status of each population without having to run the code in the relevant `xxxxx_analysis_mrmr.Rmd` files. 

All sites are referenced only by 5-digit unique identifiers. No site names or x-y coordinates are provided to protect these sensitive populations to the maximum extent possible. 

### Licenses

Code: [MIT](https://choosealicense.com/licenses/mit/) | year: 2022, copyright holder: Roland Knapp

Data: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)

See [LICENSE](https://github.com/SNARL1/cmr-analysis/blob/main/LICENSE.md) for details. 

### Contact

Roland Knapp, Research Biologist, University of California Sierra Nevada Aquatic Research Laboratory, Mammoth Lakes, CA 93546 USA; rolandknapp(at)ucsb.edu,
<https://mountainlakesresearch.com/roland-knapp/>
