library(aws.s3)

le_colina <- function(codigo, colinas, bucket, prefixo, localdir = "data") {
    nomes <- paste0("colina_", codigo, "_", colinas, ".rds")
    if (!missing(bucket)) {
        nomes   <- file.path(prefixo, nomes)
        colinas <- lapply(nomes, function(nome) aws.s3::s3read_using(readRDS, object = nome, bucket = bucket))
        return(colinas)
    } else {
        full_path <- file.path(localdir, nomes)
        colinas   <- lapply(full_path, function(fp) readRDS(fp))
        return(colinas)
    }
}