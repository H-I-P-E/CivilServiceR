

clean_raw_data <- function(save_in_app = T, re_clean_all = F){

  my_paths <- CivilServiceR::get_paths()

  #create cleaned data folder if it doesn't exist
  if(!file.exists(my_paths$clean_data)){
    dir.create(my_paths$clean_data)
  }

  cleaned_refs = NULL

  if(!(re_clean_all|!file.exists(my_paths$cleaned_file_names_path))){
    cleaned_refs <- readRDS(my_paths$cleaned_file_names_path)
  }

  cleaned_paths <- purrr::map(list.files(my_paths$data_folder_path),
              clean_data, my_paths, cleaned_files)

  all_cleaned_data <- purrr::map(cleaned_paths, readRDS) %>%
    purrr::reduce(bind_rows)

  if(save_in_app){
    dir.create(file.path("civil_service_jobs_explorer", "data"))
    file_path <- "civil_service_jobs_explorer\\data\\cleaned_data.rds"
    saveRDS(all_cleaned_data, file_path)
    lookup_file_paths <- list("grades_data.rds",
                              "roles_data.rds") %>%
      purrr::map(~file.path(my_paths$clean_data, . ))
    file.copy(lookup_file_paths, "civil_service_jobs_explorer\\data")
  }

  return(all_cleaned_data)

}
clean_data <- function(file, my_paths, cleaned_files = NULL){

  if(file %in% c("existing_refs.rds")){
    return(NULL)
  }

  cleaned_path <- file.path(my_paths$clean_data_folder, paste0("cleaned_", file))

  if(file %in% cleaned_files){
    return(cleaned_path)
  }

  raw_data <- file.path(my_paths$data_folder, file) %>%
    readRDS() %>%
    dplyr::filter(!is.na(value))
    dplyr::distinct(variable, job_ref, .keep_all = T)

  my_columns <- c("title", "location", "date_downloaded", "stage", "department", "grade", "Number of posts", "closingdate", "Type of role")

  create_grades <- CivilServiceR::find_values_in_column(raw_data,
                                                        my_paths = my_paths,
                                                        column = "grade",
                                                        lookup_file = "grade_lookup.csv",
                                                        out_file = "grades_data.rds")

  create_roles <- CivilServiceR::find_values_in_column(raw_data,
                                                       my_paths = my_paths,
                                                       column = "Type of role",
                                                       lookup_file = "role_lookup",
                                                       out_file = "roles_data.rds")

  create_policy_areas <- find_policy_areas(raw_data)

  cleaned_data <- raw_data %>%
    dplyr::filter(variable %in% my_columns) %>%
    tidyr::pivot_wider(id_cols = job_ref, names_from = "variable", values_from = "value") %>%
    dplyr::mutate(date_downloaded = lubridate::as_date(date_downloaded),
                  closing_date = lubridate::parse_date_time(closingdate,  orders = "dmy"),
                  closing_date = ifelse(is.na(closing_date),
                                        format(
                                        lubridate::parse_date_time(
                                          paste(
                                            purrr::map(
                                              stringr::str_split(.$closingdate, pattern = "\\s"),tail, 3),colllapse = " "),
                                          orders = "dmy"),format="%Y-%m-%d")),
                  number_of_posts = as.numeric(`Number of posts`),
                  approach = paste(purrr::map(stringr::str_split(.$stage, pattern = "\\s"),tail, 1),colllapse = " ")) %>%
    dplyr::select(-`Number of posts`, -closingdate, -stage)

  saveRDS(cleaned_data, cleaned_path)

  #add raw file to cleaned data paths list

  existing_cleaned_files <- NULL
  if(file.exists(my_paths$cleaned_file_names_path)){
    existing_cleaned_files <- readRDS(my_paths$cleaned_file_names_path)
  }

  new_cleaned_files <- c(cleaned_path, existing_cleaned_files)
  saveRDS(new_cleaned_files, my_paths$cleaned_file_names_path)

  return(cleaned_path)
}


find_values_in_column <- function(data, my_paths, column, lookup_file, out_file, reclean_all = F){
  lookup_path <- file.path(my_paths$meta_data_folder, lookup_file)
  lookup <- readr::read_csv(lookup_path)

  out_file_path <- file.path(my_paths$clean_data_folder, out_file)


  variable_data <- data %>%
    dplyr::filter(variable == column) %>%
    dplyr::select(-variable)

  for(label  in lookup$label){
    variable_data[label] <- stringr::str_detect(variable_data$value, label)
  }

  matches <- variable_data %>%
    dplyr::select(-value) %>%
    tidyr::pivot_longer(cols =  tidyselect::one_of(lookup$label) ,
                        names_to = "label",
                        values_to = "value") %>%
    dplyr::filter(value) %>%
    dplyr::select(-value)


  previous_data <- NULL
  if(file.exists(out_file_path)){
    previous_data <-readRDS(out_file_path)
  }
  new_data <- dplyr::bind_rows(previous_data, matches)
  saveRDS(new_data, out_file_path)

}

find_policy_areas <- function(raw_data){

}

file = "2020-04-17_49899_39927_.rds"

data_folder <- my_paths$data_folder

