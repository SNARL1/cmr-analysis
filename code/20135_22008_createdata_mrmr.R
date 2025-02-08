# Thomas C. Smith, modified by Roland Knapp 
# 05 November 2019

# This script fetches data from the MLRG postgres amphibians database and CSV files (containing 2019 data), 
# and sets up tibbles (R objects) based on the postgres tables. The script creates/manages 
# ids in each tibble to mimic the relationships that exist in the postgres database, allowing user
# to link visit, survey, and capture tables, and perform 'queries' and tidyr data
# management and manipulation operations.

# Extract data from Tyndall CMR sites: Tyndall Pond & Ranger Station Pond

# Load packages
library(tidyverse)
library(RPostgreSQL)
library(lubridate)

# Set working directory
setwd("/media/rknapp/Data/Box Sync/SNARL shared folder/Projects/cmr_analysis/sites/tyndall")

# Create a table of sites of interest - Tyndall CMR sites
site.subset <- read_csv("site_id, basin_name
                          22008, tyndall_pond
                          22019, tyndall_pond
                          22020, tyndall_pond
                          20135, rangersta_pond
                          21521, rangersta_pond
                          21519, rangersta_pond
                          21520, rangersta_pond")
site.subset$site_id <- as.integer(site.subset$site_id)

# Fetch data from posgres database `amphibians`. This section of code was written by Ericka Hegeman. Run one line at a time.
# don't forget to connect your VPN
myus <- readline(prompt="Enter username: ")
us <- paste(myus)
mypw <- readline(prompt="Enter password: ")
pw <- paste(mypw)
  pg = dbDriver("PostgreSQL")
    con = dbConnect(pg, user = us, password = pw,
                    host = "frogdb.eri.ucsb.edu", port = 5432, dbname = "amphibians") #host would be "localhost" if not stored in remote location
# OPTIONAL - show the tables in the database
dbListTables(con)
# OPTIONAL - show the tables in the database and referenced schema
dbGetQuery(con, "SELECT table_name FROM information_schema.tables WHERE table_schema  = 'amphibians'")

# Create r objects & copy from the database tables (copies created in case originals are incorrectly altered).
# Will see warnings about "unrecognised PostgreSQL field type uuid... etc.". This has not created any issues.
visit.pg.copy <- visit.pg <- dbReadTable(con, c("amphibians", "visit")) %>% as_tibble()
survey.pg.copy <- survey.pg <- dbReadTable(con, c("amphibians", "survey")) %>% as_tibble()
site.pg.copy <- site.pg <- dbReadTable(con, c("amphibians", "site")) %>% as_tibble()
visual_survey.pg.copy <- visual_survey.pg <- dbReadTable(con, c("amphibians", "visual_survey")) %>% as_tibble()
capture_survey.pg.copy <- capture_survey.pg <- dbReadTable(con, c("amphibians", "capture_survey")) %>% as_tibble()

# Always disconnect after tables are read into R objects
dbDisconnect(con) #always close connection

# Connect to postgres database "translocate_reintroduce"
con = dbConnect(pg, user=us, password=pw,
                host="frogdb.eri.ucsb.edu", port=5432, dbname="translocate_reintroduce") #host would be "localhost" if not stored in remote location

# Create r object & copy from postgres database 'translocate-reintroduce'
# that contains information about frogs that were translocated or reintroduced
transreintro.pg.copy <- transreintro.pg <-dbReadTable(con, c("transreintro")) %>% as_tibble()

# Save file for future use
saveRDS(transreintro.pg, file = "transreintro.rds")


# Disconnect from database, also remember to disconnect from VPN
dbDisconnect(con)

# Fetch data from CSV files containing 2019 survey data
visit.2019 <- read.csv("/media/rknapp/Data/Box Sync/SNARL shared folder/Database/Yearly databases/2019/final_2019_data/visit.csv", 
                       header = TRUE, stringsAsFactors = FALSE)
survey.2019 <- read.csv("/media/rknapp/Data/Box Sync/SNARL shared folder/Database/Yearly databases/2019/final_2019_data/survey.csv", 
                       header = TRUE, stringsAsFactors = FALSE)
capture.2019 <- read.csv("/media/rknapp/Data/Box Sync/SNARL shared folder/Database/Yearly databases/2019/final_2019_data/capture.csv", 
                       header = TRUE, stringsAsFactors = FALSE)

# Format data in .2019 files
visit.2019$visit_date <- ymd(visit.2019$visit_date)

survey.2019$visit_date <- ymd(survey.2019$visit_date)

capture.2019$date_capture <- ymd(capture.2019$date_capture)
capture.2019$pit_tag_ref <- as.character(as.numeric(capture.2019$pit_tag_ref))

# For datasets from 'amphibians' database change the names of the unique id fields in the 'parent' tables 
# to match the postgres-given name for that field in the child table, 
# change names of to avoid duplicate column names,drop unnecessary columns.
visit.pg1 <- visit.pg %>% 
  mutate(visit_id = id, comment_visit = comment) %>% 
  select(-id, -comment)
survey.pg1 <- survey.pg %>% 
  mutate(survey_id = id, comment_survey = comment) %>% 
  select(-id, -surveyor1, -comment)
visual_survey.pg1 <- visual_survey.pg %>% 
  mutate(visual_id = id, comment_survey = comment) %>% 
  select(-id, -comment)
capture_survey.pg1 <- capture_survey.pg %>% 
  mutate(capture_id = id, comment_capture = swab_comment) %>% 
  select(-id, -swab_comment, -surveyor_id, -frog_comment)

# For datasets from '2019 Fulcrum' database change the names of the unique id columns 
# to match the names for those columns in the postgres 'amphibians' tables, 
# change names of to avoid duplicate column names,drop unnecessary columns
visit.2019a <- visit.2019 %>% 
  mutate(visit_id = fulcrum_record_id, comment_visit = comment) %>% 
  select(-fulcrum_record_id, -comment)
survey.2019a <- survey.2019 %>% 
  mutate(visit_id = fulcrum_record_id, survey_id = fulcrum_id, site_id_survey = site_id, visit_date_survey = visit_date, 
         comment_survey = general_survey_comment) %>% 
  select(-fulcrum_record_id, -fulcrum_id, -fulcrum_parent_id, -surveyor_id, -site_id, -visit_date, -general_survey_comment)
capture.2019a <- capture.2019 %>% 
  mutate(survey_id = fulcrum_parent_id, capture_id = fulcrum_id, site_id_capture = site_id) %>% 
  select(-fulcrum_record_id, -fulcrum_id, -fulcrum_parent_id, -swabber_id, -site_id)

# Append 2019 data to r objects created from postgres database tables
visit <- bind_rows(visit.pg1, visit.2019a)
survey <- bind_rows(survey.pg1, survey.2019a)
capture <- bind_rows(capture_survey.pg1, capture.2019a)

# Create cmr dataset using joins between tables. 
tyndall.capture.innerjoin <- site.subset %>%
  inner_join(visit, by = c("site_id")) %>%
    select(site_id, basin_name, visit_date, visit_status, visit_id) %>% 
  inner_join(survey, by = c("visit_id")) %>% 
    select(site_id, basin_name, visit_date, visit_status, survey_type, visit_id, survey_id, comment_survey) %>% 
  inner_join(capture, by = c("survey_id")) %>% 
    select(site_id, basin_name, visit_date, visit_status, survey_type, method, pit_tag_ref, tag_new, species, 
         capture_life_stage, capture_animal_state, sex, comment_survey, comment_capture, capture_id, visit_id, survey_id)

# Retain only those records collected during cmr surveys
# Drop record that was not part of "official" cmr
tyndall.capture.cmr <- tyndall.capture.innerjoin %>%
  filter(method == 'cmr') %>% 
  filter(!(site_id == 22019 & visit_date == '2016-08-17'))

# Export file for future use - to avoid having to recreate dataset from scratch. Use readRDS to read back in
saveRDS(tyndall.capture.cmr, file = "tyndall_cmr_data.rds")

# Check for capture_animal_state is NULL, update to "healthy"
tyndall.capture.cmr %>% 
  filter(is.na(capture_animal_state))

tyndall.capture.cmr <- tyndall.capture.cmr %>%
  replace_na(list(capture_animal_state = 'healthy'))

# Check for records of dead frogs and remove from tibble
tyndall.capture.cmr %>%
  filter(capture_animal_state == 'dead')

tyndall.capture.cmr <- tyndall.capture.cmr %>%
  filter(!(capture_animal_state == 'dead'))

# ADD CHECK FOR MISENTERED SEX VALUES (E.G., CHANGES FROM ONE SEX TO ANOTHER), UPDATE NA VALUES TO ACTUAL SEX

# Check for duplicate captures within a secondary period (i.e., date)
tyndall.capture.cmr %>% group_by(basin_name, visit_date, pit_tag_ref) %>% 
  filter(n() > 1)

# Subset transreintro.pg, join to tyndall.capture.cmr to add treatment column
# that indicates whether reintroduced frogs were Bd-exposed or not, change NA to "resident"
tyndall.reintro <- transreintro.pg %>% 
  select(pit_tag_id, treatment, release_location) %>%
  filter(release_location %in% c("20135", "22008")) %>%
  mutate(category = treatment) %>%
  select(pit_tag_id, category)

tyndall.capture.cmr1 <- tyndall.capture.cmr %>%
  mutate(pit_tag_id = pit_tag_ref) %>%
  select(-pit_tag_ref) %>%
  left_join(tyndall.reintro, by = c("pit_tag_id")) %>%
  replace_na(list(category = "resident"))

# Change a column name, select only relevant columns for final tyndall capture dataset
tyndall.capture.cmr2 <- tyndall.capture.cmr1 %>%
  mutate(survey_date = visit_date) %>%
  select(site_id, basin_name, survey_date, pit_tag_id, sex, category)

# Create tables of frog captures, export as two "capture" csv files
# ADD CODE TO SORT DATA BEFORE EXPORTING
tyndallpond.capture <- tyndall.capture.cmr2 %>%
  filter(basin_name == "tyndall_pond")
write.csv(tyndallpond.capture, file = "captures.tyndallpond.mrmr.csv", row.names = FALSE)

rangerstapond.capture <- tyndall.capture.cmr2 %>%
  filter(basin_name == "rangersta_pond")
write.csv(rangerstapond.capture, file = "captures.rangerstapond.mrmr.csv", row.names = FALSE)
 
# Create tables of reintroduced frogs, export as two "translocation" csv files
tyndallpond.reintro <- transreintro.pg %>% 
  select(pit_tag_id, release_date, release_location, treatment) %>%
  filter(release_location == "22008")
  write.csv(tyndallpond.reintro, file = "translocations.tyndallpond.mrmr.csv", row.names = FALSE)
  
rangerstapond.reintro <- transreintro.pg %>% 
  select(pit_tag_id, release_date, release_location, treatment) %>%
  filter(release_location == "20135")
  write.csv(rangersta.pond.reintro, file = "translocations.rangerstapond.mrmr.csv", row.names = FALSE)
  
# Create tables of surveys containing only unique dates, add new columns, export as two "survey" csv files
tyndallpond.surveydate.unique <- tyndall.capture.cmr2 %>%
  distinct(basin_name, survey_date) %>%
  filter(basin_name == "tyndall_pond") %>%
  add_column(primary_period = as.integer(1), secondary_period = as.integer(1))
  write.csv(tyndallpond.surveydate.unique, file = "surveys.tyndallpond.mrmr.csv", row.names = FALSE)

  rangerstapond.surveydate.unique <- tyndall.capture.cmr2 %>%
  distinct(basin_name, survey_date) %>%
  filter(basin_name == "rangersta_pond") %>%
  add_column(primary_period = as.integer(1), secondary_period = as.integer(1))
  write.csv(rangerstapond.surveydate.unique, file = "surveys.rangerstapond.mrmr.csv", row.names = FALSE)