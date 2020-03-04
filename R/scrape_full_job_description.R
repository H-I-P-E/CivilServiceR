
scrape_full_job <- function(job_url, session){
  print(job_url)
  job_url_session <- rvest::jump_to(session, job_url)
  job_html <- xml2::read_html(job_url_session)

  basic_info_css <- '.vac_display_field_value , h3'
  nodes <- basic_info_css <- rvest::html_nodes(job_html, css = basic_info_css)

  as_data <- data.frame(type = rvest::html_name(nodes),
                        text = rvest::html_text(nodes)) %>%
    dplyr::mutate(row = as.integer(row.names(.)),
                  dummy = TRUE)

  narrow_data <- dplyr::full_join(as_data %>% dplyr::filter(type != 'h3'),
                                      as_data %>% dplyr::filter(type == 'h3'),
                                      by = c('dummy')) %>%
    dplyr::filter(row.x > row.y) %>%
    dplyr::group_by(row.x) %>%
    dplyr::filter(row.y == max(row.y)) %>%
    dplyr::ungroup() %>%
    dplyr::transmute(variable = as.character(text.y),
                     value = as.character(text.x)) %>%
    dplyr::group_by(variable) %>%
    dplyr::summarise(value = paste(value, collapse = "!!!"))

    reference_number = narrow_data %>%
      dplyr::filter(variable == "Reference number") %>%
      dplyr::pull(value) %>%
      stringr::str_trim()

    narrow_data <- narrow_data %>%
      dplyr::mutate(job_ref = reference_number) %>%
      dplyr::mutate_all(as.character()) %>%
      dplyr::select(job_ref, variable, value)

    return(narrow_data)
}
