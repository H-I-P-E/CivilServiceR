scrape_full_job <- function(job_url, i, my_session, new_advert_count){
  print(paste0("Scraping job: ", as.character(i), " of ", as.character(new_advert_count)))
  job_url_session <- rvest::jump_to(my_session, job_url)
  job_html <- xml2::read_html(job_url_session)


  basic_info_css <- '.vac_display_field_value , h3'
  nodes <- rvest::html_nodes(job_html, css = basic_info_css)

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

    date_run <- tibble::tibble(job_ref =reference_number,
                      variable = "date_downloaded",
                      value = (as.character(lubridate::today())))

    narrow_data <- narrow_data %>%
      dplyr::mutate(job_ref = reference_number)  %>%
      dplyr::mutate_all(as.character())%>%
      dplyr::bind_rows(date_run) %>%
      dplyr::select(job_ref, variable, value)

    return(narrow_data)
}
