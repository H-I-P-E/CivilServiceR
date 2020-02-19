


update_database <- function(civil_service_user){
  if(civil_service_user){
    session = CivilServiceR::login('user_name_and_password.R')
  } else {
    session = NULL
  }

  existing_refs <- get_existing_refs(path = T)


  basic_new_data <- scrape_adverts(session, existing_refs)


    new_job_urls <-


    full_new_data <- NULL
  for(job_url in new_job_urls){
    scrape_full_job(job_url, session)
  }

}



get_existing_refs <- function(path){

}




login <- function(username_and_password_file){
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
