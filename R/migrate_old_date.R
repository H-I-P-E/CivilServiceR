#You can ignore this if you are running this from scratch
#only relevent if you used the previous version of this code

save_old_data <- function(){
path_to_old_basic <- "C:\\Users\\tobias.jolly\\Documents\\civil_service_jobs\\data\\basic_advert_data.csv"
path_to_old_full <- "C:\\Users\\tobias.jolly\\Documents\\civil_service_jobs\\data\\full_advert_data.csv"

my_paths <- CivilServiceR::get_paths()

if(file.exists(my_paths$existing_refs_path)){
  existing_refs <- readRDS(my_paths$existing_refs_path)
} else {
  existing_refs <- NULL
}



narrow_adverts <- data.table::fread(path_to_old_full) %>%
  dplyr::select(-filename, -data, -html_nodes) %>%
  dplyr::filter(!is.na(job_ref)) %>%
  dplyr::mutate(`Reference number` = stringr::str_extract(`Reference number`, "(\\d)+"))

narrow_full <- readr::read_csv(path_to_old_basic) %>%
  dplyr::transmute(job_id = job_id,
                   department = department,
                   grade = grade,
                   location = location,
                   salary = salary,
                   stage = approach,
                   title = job_title,
                   link = link,
                   closingdate = closing_date,
                   job_id = job_id)%>%
  dplyr::filter(!is.na(job_id)) %>%
  dplyr::left_join(narrow_adverts , c("job_id" = "job_ref" )) %>%
  dplyr::mutate(job_ref = ifelse(is.na(`Reference number`),
                                 paste0("old_", job_id),
                                 `Reference number`)) %>%
  dplyr::mutate_all(as.character) %>%
  tidyr::pivot_longer(names_to = "variable", cols = -tidyr::one_of("job_ref")) %>%
  dplyr::filter(!job_ref %in% existing_refs$job_ref)


old_data_name <- lubridate::today() %>%
  as.character() %>%
  paste("_old_data",".rds", sep = "")

new_file_path = file.path(my_paths$data_folder_path, old_data_name)

new_refs <- narrow_full %>%
  dplyr::select(job_ref) %>%
  unique()

if (is.null(existing_refs)){
  saveRDS(new_refs, my_paths$existing_refs_path)
} else {
  existing_refs <- dplyr::bind_rows(existing_refs, new_refs)
  saveRDS(existing_refs, existing_refs_path)
}

saveRDS(narrow_full, new_file_path)

}
