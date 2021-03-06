#' @title Resolve names using Global Names Recognition and Discovery.
#'
#' @description Uses the Global Names Recognition and Discovery service, see
#' \url{http://gnrd.globalnames.org/}.
#'
#' Note: this function sometimes gives data back and sometimes not. The API
#' that this function is extremely buggy.
#'
#' @export
#' @param url An encoded URL for a web page, PDF, Microsoft Office document, or
#' image file, see examples
#' @param file When using multipart/form-data as the content-type, a file may
#' be sent. This should be a path to your file on your machine.
#' @param text Type: string. Text content; best used with a POST request, see
#' examples
#' @param engine (optional) (integer) Default: 0. Either 1 for TaxonFinder,
#' 2 for NetiNeti, or 0 for both. If absent, both engines are used.
#' @param unique (optional) (logical) If \code{TRUE} (default), response has
#' unique names without offsets.
#' @param verbatim (optional) Type: boolean, If \code{TRUE} (default to
#' \code{FALSE}), response excludes verbatim strings.
#' @param detect_language (optional) Type: boolean, When \code{TRUE} (default),
#' NetiNeti is not used if the language of incoming text is determined not to
#' be English. When \code{FALSE}, NetiNeti will be used if requested.
#' @param all_data_sources (optional) Type: boolean. Resolve found names
#' against all available Data Sources.
#' @param data_source_ids (optional) Type: string. Pipe separated list of
#' data source ids to resolve found names against. See list of Data Sources
#' \url{http://resolver.globalnames.org/data_sources}.
#' @param return_content (logical) return OCR'ed text. returns text
#' string in \code{x$meta$content} slot. Default: \code{FALSE}
#' @param ... Further args passed to \code{\link[crul]{verb-GET}}
#' @author Scott Chamberlain {myrmecocystus@@gmail.com}
#' @return A list of length two, first is metadata, second is the data as a
#' data.frame.
#' @details One of url, file, or text must be specified - and only one of them.
#' @examples \dontrun{
#' # Get data from a website using its URL
#' scrapenames('http://en.wikipedia.org/wiki/Araneae')
#' scrapenames('http://en.wikipedia.org/wiki/Animalia')
#' scrapenames('http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0095068')
#' scrapenames('http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0080498')
#' scrapenames('http://ucjeps.berkeley.edu/cgi-bin/get_JM_treatment.pl?CARYOPHYLLACEAE')
#'
#' # Scrape names from a pdf at a URL
#' url <- 'http://www.plosone.org/article/fetchObject.action?uri=
#' info%3Adoi%2F10.1371%2Fjournal.pone.0058268&representation=PDF'
#' scrapenames(url = sub('\n', '', url))
#'
#' # With arguments
#' scrapenames(url = 'http://www.mapress.com/zootaxa/2012/f/z03372p265f.pdf',
#'   unique=TRUE)
#' scrapenames(url = 'http://en.wikipedia.org/wiki/Araneae',
#'   data_source_ids=c(1, 169))
#'
#' # Get data from a file
#' speciesfile <- system.file("examples", "species.txt", package = "taxize")
#' scrapenames(file = speciesfile)
#'
#' nms <- paste0(names_list("species"), collapse="\n")
#' file <- tempfile(fileext = ".txt")
#' writeLines(nms, file)
#' scrapenames(file = file)
#'
#' # Get data from text string
#' scrapenames(text='A spider named Pardosa moesta Banks, 1892')
#'
#' # return OCR content
#' scrapenames(url='http://www.mapress.com/zootaxa/2012/f/z03372p265f.pdf',
#'   return_content = TRUE)
#' }
scrapenames <- function(url = NULL, file = NULL, text = NULL, engine = NULL,
  unique = NULL, verbatim = NULL, detect_language = NULL,
  all_data_sources = NULL, data_source_ids = NULL,
  return_content = FALSE, ...) {

  method <- tc(list(url = url, file = file, text = text))
  if (length(method) > 1) {
    stop("Only one of url, file, or text can be used", call. = FALSE)
  }

  base <- "http://gnrd.globalnames.org/name_finder.json"
  if (!is.null(data_source_ids))
    data_source_ids <- paste0(data_source_ids, collapse = "|")
  args <- tc(list(url = url, text = text, engine = engine, unique = unique,
                  verbatim = verbatim, detect_language = detect_language,
                  all_data_sources = all_data_sources,
                  data_source_ids = data_source_ids,
                  return_content = as_l(return_content)))
  cli <- crul::HttpClient$new(base, headers = tx_ual, opts = list(...))
  if (names(method) == 'url') {
    tt <- cli$get(query = args)
    tt$raise_for_status()
    out <- jsonlite::fromJSON(tt$parse("UTF-8"))
    token_url <- out$token_url
  } else {
    if (names(method) == "text") {
      tt <- cli$post(body = list(text = text), encode = "form",
                 followlocation = 0)
    } else {
      tt <- cli$post(query = argsnull(args), encode = "multipart",
                 body = list(file = crul::upload(file)), 
                 followlocation = 0)
    }
    if (tt$status_code != 303) tt$raise_for_status()
    token_url <- tt$response_headers$location
  }

  st <- 303
  while (st == 303) {
    dat <- crul::HttpClient$new(token_url, headers = tx_ual)$get()
    dat$raise_for_status()
    datout <- jsonlite::fromJSON(dat$parse("UTF-8"))
    st <- datout$status
  }
  meta <- datout[!names(datout) %in% c("names")]
  list(meta = meta, data = nmslwr(datout$names))
}
