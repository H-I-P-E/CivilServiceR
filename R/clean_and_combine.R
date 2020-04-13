

clean_and_combine_raw_data <- function(save_in_app = T, save_csv = T){
  my_paths <- CivilServiceR::get_paths()

  all_cleaned_data <- list.files(my_paths$data_folder_path) %>%
    purrr::map(clean_data, my_paths$data_folder_path) %>%
    purrr::reduce(dplyr::bind_rows)

  if(save_in_app){
    dir.create(file.path("civil_service_jobs_explorer", "data"))
    file_path <- "civil_service_jobs_explorer\\data\\cleaned_data.rds"
    saveRDS(all_cleaned_data, file_path)
  }
  if(save_csv){
    dir.create(file.path("civil_service_jobs_explorer", "data"))
    file_path <- "civil_service_jobs_explorer\\data\\cleaned_data.csv"
    readr::write_csv(all_cleaned_data, file_path)
  }

  return(all_cleaned_data)

}

clean_data <- function(file, data_folder){
  non_data_files <- c("existing_refs.rds")
  if(file %in% non_data_files){
    return(NULL)
  }

  raw_data <- file.path(data_folder, file) %>%
    readRDS() %>%
    dplyr::filter(!is.na(value)) %>%
    dplyr::distinct(variable, job_ref, .keep_all = T)

  my_columns <- c("title", "location", "date_downloaded", "stage", "department", "grade", "Number of posts", "closingdate")

  cleaned_data <- raw_data %>%
    dplyr::filter(variable %in% my_columns) %>%
    tidyr::pivot_wider(id_cols = job_ref, names_from = "variable", values_from = "value") %>%
    dplyr::mutate(date_downloaded = lubridate::as_date(date_downloaded),
                  closing_date =  lubridate::as_date(closingdate),
                  number_of_posts = as.numeric(`Number of posts`)) %>%
    dplyr::select(-`Number of posts`, -closingdate)

  return(cleaned_data)

}


