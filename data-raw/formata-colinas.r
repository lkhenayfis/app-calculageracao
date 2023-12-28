library(data.table)
library(curvacolina)

ROOT <- "/mnt/c/Users/lucas/OneDrive/Área de Trabalho/colinas/tabelas"
ROOT <- "/mnt/gtdp/Ciclo 3 - 2015 a 2024/_Resultados Finais por Usina/"
dirs <- list.dirs(ROOT, recursive = FALSE)

usi_ug <- list()

for (dir in dirs) {
    print(sub(".*Usina/+", "", dir))

    dir <- file.path(dir, "Curva de colina")
    dir_mod <- file.path(dir, "modelos")

    tab <- fread(file.path(dir, "original", "associacao_maquinas_colina.csv"),
        colClasses = c("integer", "integer", "numeric", "numeric", "Date", "Date", "integer"))
    tab <- tab[!duplicated(ug, fromLast = TRUE)]
    usi_ug <- c(usi_ug, list(tab))

    arq_mods <- list.files(dir_mod, pattern = "_vaz_[[:digit:]]+.rds")

    tag <- tab[, paste0("colina_", cod[1])]
    outarqs <- sub(".*vaz", tag, arq_mods)
    file.copy(file.path(dir_mod, arq_mods), file.path("data", outarqs))
}

usi_ug <- rbindlist(usi_ug)[, c(1:4, 7)]
colnames(usi_ug) <- c("codigo", "ug", "potencia_nominal", "vazao_efetiva", "colina")
setorder(usi_ug, codigo)
saveRDS(usi_ug, "data/usinas_ugs.rds")
