

clean_and_combine_raw_data <- function(){
  my_paths <- CivilServiceR::get_paths()

  all_cleaned_data <- list.files(my_paths$data_folder_path) %>%
    purrr::map(clean_data, my_paths$data_folder_path) %>%
    purrr::reduce(dplyr::bind_rows)

  return(all_cleaned_data)

}

clean_data <- function(file, data_folder){
  non_data_files <- c("2020-03-30_old_data.rds", "existing_refs.rds")
  if(file %in% non_data_files){
    return(NULL)
  }

  raw_data <- file.path(data_folder, file) %>% readRDS()
  return(raw_data)

}
