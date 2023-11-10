library(data.table)
library(polijus)

# auxiliares ---------------------------------------------------------------------------------------

splitporpat <- function(pat, orig = polijus_raw) {
    out <- orig[grep(paste0("^(", pat, ")"), orig)]
    out <- sub(paste0(pat, " +"), "", out)
    out <- split(out, substr(out, 1, 4))
    return(out)
}

parsecoefs <- function(x) {
    indexes <- substr(x, 10, 12)
    x <- gsub("D", "e", gsub("-\\.", "-0.", x))
    x <- sub("[[:digit:]]*  +[[:digit:]]*  +", "", x)
    x <- split(x, indexes)
    x <- lapply(x, strsplit, " ")
    x <- lapply(x, function(xi) lapply(xi, as.numeric))

    bounds <- lapply(x, function(pol) lapply(pol, head, 2))
    coefs <- lapply(x, function(pol) lapply(pol, function(xi) xi[-seq(2)]))

    out <- list(bounds, coefs)

    return(out)
}

# leitura do hidr ----------------------------------------------------------------------------------

hidr <- fread("data-raw/Hidr_CadUsH.csv")
hidr <- hidr[, 1:7]
colnames(hidr) <- c("codigo", "nome", "subsistema", "empresa", "posto", "posto_bdh", "jusante")

hidr[, jusante := as.numeric(sub(" -.*", "", substr(jusante, 1, 4)))]

saveRDS(hidr, "data/hidr.rds")

# leitura e padronizacao do polijus ----------------------------------------------------------------

polijus_raw <- readLines("data-raw/polinjus.dat")

# parte de info das curvas
curvajus <- splitporpat("CURVAJUS")
curvajus <- lapply(curvajus, function(s) as.numeric(substr(s, 19, 26)))

# coeficientes de ajuste
pppjus <- splitporpat("PPPJUS")
pppjus <- lapply(pppjus, parsecoefs)

# monta objetos finais
dummy <- list(
    hist = data.table(vazao = 0, njus = 0),
    ext = list()
)

polijus <- mapply(curvajus, pppjus, FUN = function(refs, data) {
    bounds <- data[[1]]
    coefs  <- data[[2]]
    refs[-1] <- paste0("pat ", formatC(refs[-1], format = "f", digits = 1))
    refs[1]  <- "curvabase"

    polis <- mapply(bounds, coefs, refs, FUN = function(bound, coef, tag) {
        vcov <- matrix(0, length(unlist(coef)), length(unlist(coef)))
        new_polijusU(coef, bound, dummy, vcov, "", tag)
    }, SIMPLIFY = FALSE)

    new_polijusM(dummy, polis[[1]], polis[-1])
}, SIMPLIFY = FALSE)

usinas <- names(polijus)
usinas <- as.numeric(usinas)

for (i in seq_along(polijus)) {
    outarq <- file.path("data", paste0("polijus_", usinas[i], ".rds"))
    saveRDS(polijus[[i]], outarq)
}
