#' @title Scrape those adverts
#' @description Scrapes adverts
#' @param civil_service_user Do you have a Civil Service details file in this project?
#' @export
#' @examples
#' scrape_adverts(session = my_http_session)

library(magrittr)

scrape_adverts <- function(session,
                           search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi?SID=cGFnZWNsYXNzPUpvYnMma2V5PTUwNzAwMDAmcGFnZWFjdGlvbj1zZWFyY2hieWNvbnRleHRpZCZ1c2Vyc2VhcmNoY29udGV4dD05ODE0Nzk3OSZyZXFzaWc9MTU4Nzc0MzA1MC1lYjEzNTQxODUxZWFkODdhYzJiNGYzNmJhNWZmZTRkZjNlNWFmZGRm"){

  search_pages <- CivilServiceR::get_all_search_pages(session, search_url)

  results <- NULL
  i=1
  for(page in search_pages){
    print(paste0("Scraping page: ", as.character(i), " of ", as.character(length(search_pages))))
    data <- scrape_search_page(session, page) %>%
      dplyr::mutate_all(as.character)
    results = dplyr::bind_rows(results, data)
    #check if I already have them
    i = i+1
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
    dplyr::filter(stringr::str_detect(alt, "Go to search")) %>%
    dplyr::pull(link) %>%
    unique() %>%
    as.character()
   links_with_first_page <- c(search_url, links)
  return(links_with_first_page)
}

scrape_search_page <- function(my_session, search_page_url){
  url_session <- rvest::jump_to(my_session, search_page_url)
  search_html <- xml2::read_html(url_session)
  xpath <- "//ul//li//div | //ul//li//div//a"
  nodes <- rvest::html_nodes(search_html, xpath =xpath)
  node_details <- data.frame(
    link = as.character(rvest::html_attr(nodes,'href')),
    node_class = as.character(rvest::html_attr(nodes,'class')),
    text = as.character(rvest::html_text(nodes)))

  node_details$row <- seq.int(nrow(node_details))

  links <- node_details %>%
    dplyr::filter(!is.na(link)) %>%
    dplyr::select(row, link) %>%
    dplyr::filter(link != "https://www.gov.uk",
                  link != "/csr/index.cgi") %>%
    dplyr::mutate(row = as.character(as.numeric(row)-1))

  data<- node_details %>%
    dplyr::mutate(is_data = stringr::str_detect(node_class,"search\\-results\\-job\\-box")) %>%
    dplyr::filter(is_data & text != "") %>%
    dplyr::mutate(variable = stringr::str_replace(node_class, "search-results-job-box-", "")) %>%
    dplyr::mutate(row = ifelse(variable == "title", row, NA_character_)) %>%
    tidyr::fill(row) %>%
    dplyr::select(variable, text, row) %>%
    tidyr::spread(variable, text) %>%
    dplyr::mutate_all(as.character()) %>%
    dplyr::left_join(links, c("row" = "row" )) %>%
    dplyr::select(-row)

  return(data)
}
