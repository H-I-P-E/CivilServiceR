#' @title Clean and combine raw data
#' @description The folder for the raw data is defined by the get paths function. This function loads that data
#' then cleans it (reformats columns and extracts relevent data)
#' @param save_in_app Should you save a new version of the cleaned data into the Shiny app folder?
#' @param re_clean_all Should all raw data be put through the cleaning process or just the data that has not been cleaned thus far
#' @export


clean_and_combine_raw_data <- function(save_in_app = T, re_clean_all = F){

  my_paths <- CivilServiceR::get_paths()

  #create cleaned data folder if it doesn't exist
  if(!file.exists(my_paths$clean_data)){
    dir.create(my_paths$clean_data)
  }

  cleaned_files = NULL

  #the files contain job level data bases on results of the find_values_in_column function
  lookup_file_paths <- list("grades_data.rds",
                            "roles_data.rds",
                            "key_words.rds") %>%
    purrr::map(~file.path(my_paths$clean_data, . ))

  if(re_clean_all){
    #delete all the job level lookups if recleaning
    purrr::map(lookup_file_paths, file.remove)
  }

  if(!(re_clean_all|!file.exists(my_paths$cleaned_file_names_path))){
    cleaned_files <- readRDS(my_paths$cleaned_file_names_path)
  }

  cleaned_paths <- purrr::map(list.files(my_paths$data_folder_path),
              clean_data, my_paths, cleaned_files) %>%
    purrr::discard(is.null)

  all_cleaned_data <- purrr::map(cleaned_paths, readRDS) %>%
    purrr::reduce(dplyr::bind_rows)

  if(save_in_app){
    #save all the cleaned data into the Shiny app
    dir.create(file.path("civil_service_jobs_explorer", "data"))
    file_path <- "civil_service_jobs_explorer\\data\\cleaned_data.rds"
    saveRDS(all_cleaned_data, file_path)
    file.copy(lookup_file_paths, "civil_service_jobs_explorer\\data", overwrite = T)
    key_words_context <- file.path(my_paths$meta_data_folder, "key_words.csv") %>%
      readr::read_csv(progress = F)
    saveRDS(key_words_context, "civil_service_jobs_explorer\\data\\key_words_context.rds")
  }

  return(all_cleaned_data)

}
clean_data <- function(file, my_paths, cleaned_files = NULL){

  #don't look at the existing refs file
  if(file %in% c("existing_refs.rds")){
    return(NULL)
  }
  cleaned_path <- file.path(my_paths$clean_data_folder, paste0("cleaned_", file))

  #if it's already been cleaned - don't do it again
  if(file %in% cleaned_files){
    return(cleaned_path)
  }

  print(paste0("Cleaning this file: ", file ))

  raw_data <- file.path(my_paths$data_folder, file) %>%
    readRDS() %>%
    dplyr::filter(!is.na(value)) %>%
    dplyr::distinct(variable, job_ref, .keep_all = T)

  CivilServiceR::find_values_in_column(raw_data,
                                       my_paths = my_paths,
                                       lower_case = F,
                                       column = "grade",
                                       lookup_file = "grade_lookup.csv",
                                       out_file = "grades_data.rds")

  CivilServiceR::find_values_in_column(raw_data,
                                       my_paths = my_paths,
                                       lower_case = F,
                                       column = "Type of role",
                                       lookup_file = "role_lookup.csv",
                                       out_file = "roles_data.rds")

  CivilServiceR::find_values_in_column(raw_data,
                                       my_paths = my_paths,
                                       lower_case = T,
                                       column = "Job description",
                                       lookup_file = "key_words.csv",
                                       out_file = "key_words.rds")

  my_columns <- c("title", "location", "date_downloaded", "stage", "department", "grade", "Number of posts", "closingdate", "Type of role", "link")


  cleaned_data <- raw_data %>%
    dplyr::filter(variable %in% my_columns) %>%
    tidyr::pivot_wider(id_cols = job_ref, names_from = "variable", values_from = "value") %>%
    dplyr::mutate(date_downloaded = lubridate::as_date(date_downloaded),
                  closing_date = lubridate::parse_date_time(closingdate,  orders = c("ymd","dmy")),
                  closing_date = dplyr::case_when(
                    is.na(closing_date) ~ lubridate::parse_date_time(paste(purrr::map(
                          stringr::str_split(.$closingdate, pattern = "\\s"),tail, 3),
                          colllapse = " "),orders = "dmy"),
                    TRUE ~ closing_date),
                  closing_date = as.Date(as.POSIXct(closing_date, origin="1970-01-01", format =  "%Y-%m-%d")),
                  number_of_posts = as.numeric(`Number of posts`),
                  approach = stringr::str_trim(stringr::str_remove(stage, "Approach : ")),
                  grade = stringr::str_trim(stringr::str_remove(grade, "Grade : "))) %>%
    dplyr::select(-`Number of posts`, -closingdate, -stage)

  saveRDS(cleaned_data, cleaned_path)

  #add raw file to cleaned data paths list

  existing_cleaned_files <- NULL
  if(file.exists(my_paths$cleaned_file_names_path)){
    existing_cleaned_files <- readRDS(my_paths$cleaned_file_names_path)
  }

  new_cleaned_files <- c(file, existing_cleaned_files)
  saveRDS(new_cleaned_files, my_paths$cleaned_file_names_path)

  return(cleaned_path)
}


find_values_in_column <- function(data, my_paths, lower_case = F, column, lookup_file, out_file){
  lookup_path <- file.path(my_paths$meta_data_folder, lookup_file)
  lookup <- readr::read_csv(lookup_path, progress = F)

  out_file_path <- file.path(my_paths$clean_data_folder, out_file)


  variable_data <- data %>%
    dplyr::filter(variable == column) %>%
    dplyr::select(-variable)

  for(label  in lookup$label){
    if(lower_case){
      variable_data$value <- stringr::str_to_lower(variable_data$value)
    }
    variable_data[label] <- stringr::str_count(variable_data$value, label)
  }

  matches <- variable_data %>%
    dplyr::select(-value) %>%
    tidyr::pivot_longer(cols =  tidyselect::one_of(lookup$label) ,
                        names_to = "label",
                        values_to = "count") %>%
    dplyr::filter(count >0)

  previous_data <- NULL
  if(file.exists(out_file_path)){
    previous_data <- readRDS(out_file_path)
  }

  new_data <- dplyr::bind_rows(previous_data, matches)
  saveRDS(new_data, out_file_path)

}
