library(jsonlite)

# --------------------------------------------------------------------------------------------------

roda_query <- function(arq_params) {
    conf <- readLines(arq_params)
    conf <- trimws(conf)
    conf <- do.call(paste0, as.list(conf))
    conf <- paste0("'", conf, "'")

    exec <- paste0('curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d ', conf)

    out <- tryCatch(system(exec, intern = TRUE), error = function(e) "ERRO")

    return(out)
}

# --------------------------------------------------------------------------------------------------

arqs <- list.files("conf/issues", full.names = TRUE)

valids <- lapply(arqs, roda_query)

if (all(valids != "ERRO")) cat("\n\n======================\n TODAS ISSUES OK \n======================")
