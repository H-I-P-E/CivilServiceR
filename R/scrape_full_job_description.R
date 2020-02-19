
job_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi?SID=b3duZXJ0eXBlPWZhaXImdXNlcnNlYXJjaGNvbnRleHQ9OTQ3NzE3NDEmcGFnZWNsYXNzPUpvYnMmc2VhcmNoX3NsaWNlX2N1cnJlbnQ9NSZqb2JsaXN0X3ZpZXdfdmFjPTE2Njc0MDcmb3duZXI9NTA3MDAwMCZwYWdlYWN0aW9uPXZpZXd2YWNieWpvYmxpc3QmY3NvdXJjZT1jc2ZzZWFyY2gmcmVxc2lnPTE1ODIxMjkxODMtYzdiMzM1NDM3ZDY4NzEzMTgyY2QyYWEzMzkzYmE3N2I2Yjk4NGE4Zg=="


scrape_full_job <- function(job_url, session){

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
      dplyr::mutate(job_ref = reference_number)

    return(narrow_data)
}
