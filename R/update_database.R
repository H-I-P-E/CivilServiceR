#' @title Update jobs database
#' @description Performs the Civil Service Jobs scrape - cleans the new data
#' @param civil_service_user Are yoy a Civil Service User - if you are - you will need your username and password
#' in the working directory as an R file called user_name_and_password.R with the structure:
#' username = [CSJ username]
#' password = [CSJ password]
#' @export

update_database <- function(civil_service_user = T){
  if(civil_service_user){
    session = CivilServiceR::login('user_name_and_password.R')
  } else {
    session = NULL
  }
  my_paths <- get_paths()

  #Create data folder if it doesn't exist
  if (!file.exists(my_paths$data_folder)){
    dir.create(file.path(my_paths$parent_folder_path, my_paths$data_folder))
  }

  #existing_refs is a list of jobs that have already been scraped
  if(file.exists(my_paths$existing_refs_path)){
    existing_refs <- readRDS(my_paths$existing_refs_path)
  } else {
    existing_refs <- NULL
  }

  new_data <- CivilServiceR::get_new_data(session, existing_refs)

  CivilServiceR::save_new_data(existing_refs,
                               my_paths$existing_refs_path,
                               my_paths$data_folder_path,
                               new_data
  )

  CivilServiceR::clean_and_combine_raw_data()

}

save_new_data <- function(existing_refs,
                          existing_refs_path,
                          data_folder_path,
                          new_data){

  new_refs <- new_data %>%
    dplyr::select(job_ref) %>%
    unique()

  #min and max don't really matter here -  they are just a way of creating a unique file name
  max_ref <- as.character(max(as.numeric(new_refs$job_ref), na.rm = T))
  min_ref <- as.character(min(as.numeric(new_refs$job_ref), na.rm = T))

  new_file_name <- lubridate::today() %>%
    as.character() %>%
    paste(max_ref, min_ref, ".rds", sep = "_")

  new_file_path = file.path(data_folder_path,new_file_name)

  saveRDS(new_data, new_file_path)

  if (is.null(existing_refs)){
    saveRDS(new_refs, existing_refs_path)
  } else {
    existing_refs <- dplyr::bind_rows(existing_refs, new_refs)
    saveRDS(existing_refs, existing_refs_path)
  }
}





login <- function(username_and_password_file){
  #Log into Civil Service Jobs
  source(username_and_password_file)
  login_url <- "https://www.civilservicejobs.service.gov.uk/csr/login.cgi"
  session <- rvest::html_session(login_url)
  form <- rvest::html_form(xml2::read_html(login_url))[[1]]
  filled_form <- rvest::set_values(form,
                                   username = username,
                                   password_login_window = password)
  session <- rvest::submit_form(session, filled_form)
  return(session)
}

get_new_data <- function(session, existing_refs){
  #Get any data for job refs that have not yet been scraped

  #Scrape the search results pages for basic data
  basic_data <- CivilServiceR::scrape_adverts(session)

  #filter the basic data to those that have not yet been scraped
  basic_new_data <- basic_data %>%
    dplyr::mutate(job_ref = as.character(stringr::str_replace(refcode,"Reference: ", ""))) %>%
    dplyr::filter(!(job_ref %in% existing_refs$job_ref))

  if(nrow(basic_new_data) == 0){
    print("No new jobs today :(")
    return(NULL)
  }

  #get the links to new jobs
  new_job_urls <- basic_new_data %>%
    dplyr::pull(link)

  #make basic data narrow so it can be combined with the full jobs page data
  narrow_new_data <- basic_new_data %>%
    tidyr::pivot_longer(cols = -tidyr::one_of("job_ref"), names_to = "variable", values_to = "value")

  new_advert_count <- length(new_job_urls)
  i <- seq(1,new_advert_count)

  #get the full page jobs data
  full_jobs_data <- new_job_urls %>%
    purrr::map2(i, CivilServiceR::scrape_full_job, session, new_advert_count) %>%
    purrr::reduce(dplyr::bind_rows)

  #combine the basic and full advert data (both are narrow at this point)
  all_jobs_data <- full_jobs_data %>%
    dplyr::bind_rows(narrow_new_data)

  return(all_jobs_data)
}

get_paths <- function(){
  data_folder <- "data"
  meta_data = "meta_data"
  clean_data = "clean_data"
  parent_folder_path <- here::here()
  data_folder_path <- here::here(data_folder)
  existing_refs_path <- file.path(data_folder_path, "existing_refs.rds")
  cleaned_files_path <- file.path(clean_data, "cleaned_files.rds")

  paths <- list(
    data_folder = data_folder,
    parent_folder_path = parent_folder_path,
    data_folder_path = data_folder_path,
    existing_refs_path = existing_refs_path,
    meta_data_folder = meta_data,
    clean_data_folder = clean_data,
    cleaned_file_names_path = cleaned_files_path
  )
  return(paths)
}
