# Data from: cmr-analysis

This repository contains datasets collected during capture-mark-recapture (CMR) surveys of mountain yellow-legged frog populations. 
Survey methods are described in [Joseph and Knapp (2018)](https://doi.org/10.1002/ecs2.2499). 
All of the data are tabular, in comma separated value (CSV) format. 
Missing values in all files are coded as NA. 
The following file descriptions are specific to files in the `data/clean` directory; "xxxxx" in the file name is a placeholder for the five-digit site id. 
Each population has one `xxxxx_survey.csv` and one `xxxxx_capture.csv` file. 
If frogs have been translocated or reintroduced to the site, a `xxxxx_translocation.csv` file is also present. 
These 2-3 files per population are required for analysis using the package [`mrmr`](https://snarl1.github.io/mrmr/). 

### xxxxx_survey.csv

This CSV file contains data describing the surveys conducted at the site. 

Fields: 

- `site_id`: 5-digit site identification code.
- `survey_date`: Date on which survey was conducted (YYYY-MM-DD).
- `survey_type`: `cmr` or `translocation`. The only action performed during a `translocation` survey is frog release. 
- `primary_period`: Visit to site during which CMR survey was conducted, numbered sequentially from 1.
- `secondary_period`: Survey day within each primary period. There are typically 1-3 survey days per primary period. 

### xxxxx_capture.csv

This CSV file contains data on frogs captured during CMR surveys.

Fields:

- `site_id`: 5-digit site identification code.
- `survey_date`: Date on which survey was conducted (YYYY-MM-DD).
- `pit_tag_id`: Unique numeric id from Passive Integrated Transponder (PIT) tag implanted in frog. 

### xxxxx_translocation.csv

This CSV contains data on frogs translocated or reintroduced to a site. 

Fields:

- `site_id`: 5-digit site identification code.
- `type`: `translocation` when frog is transferred between two sites, `reintroduction` when frog is reared in captivity prior to release. 
- `release_date`: Date on which frog was released at the recipient site (YYYY-MM-DD).
- `pit_tag_id`: Unique numeric id from Passive Integrated Transponder (PIT) tag implanted in frog. 
