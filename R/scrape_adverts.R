#' @title Scrape those adverts
#' @description Scrapes adverts
#' @param civil_service_user Do you have a Civil Service details file in this project?
#' @export
#' @examples
#' scrape_adverts(session = my_http_session)

library(magrittr)

scrape_adverts <- function(session){

  search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi?SID=YWdlbnRfY29kZT0xNjU5NTc5JmNzb3VyY2U9Y3NhbGVydHNlYXJjaCZ1c2Vyc2VhcmNoY29udGV4dD0mb3duZXJ0eXBlPWZhaXImc3RvcmVzZWFyY2hjb250ZXh0PTEmcGFnZWFjdGlvbj1zZWFyY2hieWFnZW50Y29kZSZwYWdlY2xhc3M9Sm9icyZvd25lcj01MDcwMDAwJnJlcXNpZz0xNTgzMzE3ODg3LTZlOTlmNzg1MGIyZmZmNWQ5NmRjMGMzYmU1MGY2NTY3MWIxZTE4MzQ="
  search_pages <- CivilServiceR::get_all_search_pages(session, search_url)[1:2]

  results <- NULL
  for(page in search_pages){
    data <- scrape_search_page(session, page)
    results = rbind(results, data, fill = T )
    #check if I already have them
  }
  return(results)

}

get_all_search_pages <- function(my_session, search_url){
  url_session <- rvest::jump_to(my_session, search_url)
  search_html <- xml2::read_html(url_session)
  xpath = "//div//div//div//a"
  nodes <- rvest::html_nodes(search_html, xpath =xpath)
  node_details <- data.frame(
    link = rvest::html_attr(nodes,'href'),
    alt = rvest::html_attr(nodes,'alt'))

  links <- node_details %>%
    dplyr::mutate(search = stringr::str_detect(alt, "Go to search")) %>%
    dplyr::filter(search)%>%
    dplyr::pull(link) %>%
    unique() %>%
    as.character()
   links_with_first_page <- c(search_url, links)
  return(links_with_first_page)
}

scrape_search_page <- function(my_session, search_page_url){
  print("scraping page")
  print(search_page_url)
  url_session <- rvest::jump_to(my_session, search_page_url)
  search_html <- xml2::read_html(url_session)
  xpath <- "//ul//li//div | //ul//li//div//a"
  nodes <- rvest::html_nodes(search_html, xpath =xpath)
  node_details <- data.frame(
    job_link = as.character(rvest::html_attr(nodes,'href')),
    node_class = as.character(rvest::html_attr(nodes,'class')),
    text = as.character(rvest::html_text(nodes)))

  links <- node_details %>%
    dplyr::filter(!is.na(job_link)) %>%
    dplyr::select(-node_class) %>%
    dplyr::filter(job_link != "https://www.gov.uk",
           job_link != "/csr/index.cgi")

  data<- node_details %>%
    dplyr::mutate(is_data = stringr::str_detect(node_class,"search\\-results\\-job\\-box")) %>%
    dplyr::filter(is_data & text != "") %>%
    dplyr::mutate(variable = stringr::str_replace(node_class, "search-results-job-box-", "")) %>%
    dplyr::mutate(row = row.names(.)) %>%
    dplyr::mutate(row = ifelse(variable == "title", row, NA_character_)) %>%
    tidyr::fill(row) %>%
    dplyr::select(variable, text, row) %>%
    tidyr::spread(variable, text) %>%
    dplyr::mutate_all(as.character())
  data$link = links$job_link

  return(data)
}
