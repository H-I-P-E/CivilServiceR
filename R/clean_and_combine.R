

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

  my_columns <- c("title", "location", "date_downloaded", "stage", "department", "grade", "Number of posts", "closingdate", "Type of role")

  create_grades <- CivilServiceR::find_values_in_column(raw_data,
                                                        column = "grade",
                                                        lookup_file = "grade_lookup.csv",
                                                        out_file = "grades_data.rds")

  create_roles <- CivilServiceR::find_values_in_column(raw_data,
                                                       column = "Type of role",
                                                       lookup_file = "role_lookup",
                                                       out_file = "roles_data.rds")

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

  return(cleaned_data)

}


find_values_in_column <- function(data, column, lookup_file, out_file){
  lookup_path <- file.path(my_paths$meta_data, lookup_file)
  lookup <- readr::read_csv(lookup_path)

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

  save_path <- file.path(my_paths$clean_data, out_file)


  #Code that should be done one per row - should be linked to the scraping- that means all this code

  #needs to look at the existing parsed job_refs before deciding whether to parse more


}


run_initial_cleaning(raw_file_name){

}


file = "2020-04-17_49899_39927_.rds"

data_folder <- my_paths$data_folder

