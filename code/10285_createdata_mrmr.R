# Load dependencies
source('R/load-deps.R')

# Read in data from PostgreSQL databases

# Connect to PostgreSQL database `amphibians`
con = dbConnect(dbDriver("PostgreSQL"), 
                user = rstudioapi::askForPassword("user name"), 
                password = rstudioapi::askForPassword("password"),
                host = "frogdb.eri.ucsb.edu", 
                port = 5432, 
                dbname = "amphibians")

# Create R objects from the relevant database tables
site.pg <- dbReadTable(con, c("site")) %>% as_tibble()
visit.pg <- dbReadTable(con, c("visit")) %>% as_tibble()
survey.pg <- dbReadTable(con, c("survey")) %>% as_tibble()
capture_survey.pg <- dbReadTable(con, c("capture_survey")) %>% as_tibble()

# Disconnect from database 'amphibians'
dbDisconnect(con) 

# Connect to PostgreSQL database "translocate_reintroduce"
con = dbConnect(dbDriver("PostgreSQL"), 
                user = rstudioapi::askForPassword("user name"), 
                password = rstudioapi::askForPassword("password"),
                host = "frogdb.eri.ucsb.edu", 
                port = 5432, 
                dbname = "translocate_reintroduce")

### Create R object from the relevant database table
transreintro.pg <-dbReadTable(con, c("transreintro")) %>% as_tibble()

# Disconnect from database 'translocate_reintroduce'
dbDisconnect(con) 

# Edit tables to enable joins between parent and child tables
visit <- visit.pg %>% 
  mutate(visit_id = id, comment_visit = comment) %>% 
  select(-id, -comment)
survey <- survey.pg %>% 
  mutate(survey_id = id, comment_survey = comment) %>% 
  select(-id, -comment)
capture_survey <- capture_survey.pg %>% 
  mutate(capture_id = id, comment_capture = comment) %>% 
  select(-id, -comment, -surveyor_id)

# Create table of sites to include in dataset
site_subset <- tibble(site_id = c(10284, 10285), basin_name = "ruskin") 
site_subset$site_id <- as.integer(site_subset$site_id)

# Create capture-mark-recapture (cmr) dataset
captures <- site_subset %>%
  inner_join(visit, by = c("site_id")) %>%
  select(site_id, basin_name, visit_date, visit_status, visit_id) %>% 
  inner_join(survey, by = c("visit_id")) %>% 
  select(site_id, basin_name, visit_date, visit_status, survey_type, visit_id, survey_id, comment_survey) %>% 
  inner_join(capture_survey, by = c("survey_id")) %>% 
  filter(survey_type == 'cmr') %>%
  select(site_id, basin_name, visit_date, visit_status, survey_type, pit_tag_ref, tag_new, species, 
         capture_life_stage, capture_animal_state, length, sex, swab_id, comment_survey, comment_capture, capture_id, visit_id, survey_id)

# Export tibble as rds file for later data cleaning
saveRDS(captures, "./data/raw/captures_ruskin_uncleaned.rds")

# Create survey dataset
surveys <- site_subset %>%
  inner_join(visit, by = c("site_id")) %>%
  select(basin_name, site_id, visit_date, visit_status, visit_id, comment_visit) %>% 
  inner_join(survey, by = c("visit_id")) %>% 
  filter(survey_type == "cmr") %>%
  select(basin_name, site_id, visit_date, visit_status, survey_type, wind, sky, start_time, end_time, duration, description, comment_visit, comment_survey,
         survey_id, visit_id) 

# Export original data as rds file 
saveRDS(surveys, file = "./data/raw/surveys_ruskin_uncleaned.rds")

# Create translocations dataset
translocations <- transreintro.pg %>% 
  filter(release_location %in% c(10285)) %>% 
  select(release_location, release_date, pit_tag_ref, type, comments) %>%
  arrange(release_date)

# Export original data as rds file 
saveRDS(translocations, file = "./data/raw/translocations_ruskin_uncleaned.rds")


# Data checks and fixes

# Load dependencies
source('R/load-deps.R')

# Read in captures data from rds file
captures1 <- read_rds("./data/raw/captures_ruskin_uncleaned.rds")

# Check for records where pit_tag_ref is NULL
assert_that(noNA(captures1$pit_tag_ref))

# Check for records containing pit tags shorter than 15 characters
captures1 %>% filter(nchar(pit_tag_ref) != 15)

# Check for records containing pit tags that end with ".1" (known to be potentially incorrect) 
captures1 %>% filter(grepl("*\\.1", pit_tag_ref))

# Check records where capture_animal_state is NULL
assert_that(noNA(captures1$capture_animal_state)) 

# Check for records where capture_animal_state == "dead"
assert_that(!any(captures1$capture_animal_state == 'dead'))

# Check for records of subadult frogs
assert_that(!any(captures1$length < 40))

# Check for duplicate capture records on each date
captures1 %>% group_by(basin_name, visit_date, pit_tag_ref) %>% 
  filter(n() > 1)

# Drop capture from October (survey is too lake in season)
captures1 <- captures1 %>% filter(visit_date != '2014-10-07')

# Prepare final captures file
captures2 <- captures1 %>%
  mutate(survey_date = visit_date, pit_tag_id = pit_tag_ref) %>%
  select(basin_name, site_id, survey_date, pit_tag_id) %>%
  arrange(survey_date, pit_tag_id)

# Save captures file as csv for use in mrmr
captures2 %>% write.csv(file = "./data/clean/captures_ruskin.csv", row.names = FALSE)


# Check translocations file to find problem records (read comments too)

# Read in translocations data from rds file
translocations1 <- read_rds("./data/raw/translocations_ruskin_uncleaned.rds")

# Check for records where pit_tag_ref is NULL?
assert_that(noNA(translocations1$pit_tag_ref))

# Check for records containing pit tags shorter than 15 characters
translocations1 %>% filter(nchar(pit_tag_ref) != 15)

# Check for records containing pit tags that end with ".1" (known to be potentially incorrect) 
translocations1 %>% filter(grepl("*\\.1", pit_tag_ref))

# Check whether tags of all tag_new = FALSE frogs captured at recipient site match those of translocated frogs - only works for sites w/o recruitment
tagcheck <- captures1 %>%
  filter(tag_new == FALSE) %>%
  select(site_id, pit_tag_ref) %>% 
  distinct(pit_tag_ref, .keep_all = TRUE) %>%
  left_join(translocations1, by = c("pit_tag_ref")) %>%
  filter(is.na(release_location))

# Create final translocations file
translocations2 <- translocations1 %>%
  mutate(site_id = release_location, pit_tag_id = pit_tag_ref) %>% 
  select(site_id, release_date, pit_tag_id, type) %>% 
  arrange(release_date, pit_tag_id)

# Save translocations file as csv for use in mrmr
translocations2 %>% write.csv(file = "./data/clean/translocations_ruskin.csv", row.names = FALSE)

## Clean surveys file
### Check survey.cmr file created earlier for aberrant surveys and visual surveys for which no CMR survey exists (for inclusion in file)

# Read in surveys data from rds file
surveys1 <- read_rds("./data/raw/surveys_ruskin_uncleaned.rds")

# Review surveys data to find abberant surveys

# Select relevant columns and rows
surveys2 <- surveys1 %>%
  add_count(visit_date) %>% 
  select(basin_name, site_id, visit_date, visit_status, survey_type, n, survey_id)

# Create surveys table with only unique surveys (by basin & date, necessary when more than one site_id is included in cmr)
surveys2 <- surveys2 %>%
  filter(n > 1 & site_id == 10285 | n == 1)

# Drop unsuitable surveys (conducted too late in season)
surveys2 <- surveys2 %>%
  filter(visit_date != '2014-10-07') 

# Read in captures_ruskin file
captures <- read.csv("./data/clean/captures_ruskin.csv")
captures$survey_date <-  ymd(captures$survey_date)

# Create list of unique capture dates for use in joins
capture.dates <- captures %>%
  distinct(basin_name, survey_date) %>%
  mutate(visit_date = survey_date, basin_capture = basin_name) %>%
  select(-survey_date, -basin_name)

### Do all survey dates have frog captures? If not, do frogless surveys need to be dropped?
surveys2 %>%
  left_join(capture.dates, by = c("visit_date")) %>% View 

# Do all capture dates have associated surveys?
surveys2 %>%
  right_join(capture.dates, by = c("visit_date")) %>% View

# Remove unnecessary columns
surveys2 <- surveys2 %>%
  select(basin_name, site_id, visit_date, survey_type)

# Add reintroduction/translocation dates to surveys file

# Read in translocations_ruskin data
translocations <- read.csv("./data/clean/translocations_ruskin.csv")
translocations$release_date <- ymd(translocations$release_date)
translocations$type <- as.character(translocations$type)

# Create list of distinct reintro events (by date) from final translocations_ruskin file
reintro.dates <- translocations %>%
  mutate(visit_date = release_date, survey_type = type) %>% 
  select(site_id, visit_date, survey_type) %>% 
  distinct(visit_date, .keep_all = TRUE) %>%
  add_column(basin_name = as.character('ruskin'), primary_period = as.integer(1), secondary_period = as.integer (0))  

# add reintro events to survey file
surveyreintro <- surveys2 %>%
  arrange(visit_date) %>%
  add_column(primary_period = as.integer(2:7), secondary_period = as.integer(1)) %>%
  bind_rows(reintro.dates) %>% 
  mutate(survey_date = visit_date) %>%
  select(basin_name, site_id, survey_date, survey_type, primary_period, secondary_period) %>%
  arrange(survey_date)

# Check for cmr & translocation surveys conducted on the same date
surveyreintro %>% 
  group_by(survey_date) %>% 
  filter(n() > 1)

# Save surveys file as csv for use in mrmr
surveyreintro %>%  write.csv(file = "./data/clean/surveys_ruskin.csv", row.names = FALSE)