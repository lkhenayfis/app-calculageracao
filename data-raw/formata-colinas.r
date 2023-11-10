library(data.table)
library(curvacolina)

ROOT <- "/mnt/c/Users/lucas/OneDrive/Área de Trabalho/colinas/tabelas"

dirs <- list.dirs(ROOT, recursive = FALSE)

usi_ug <- list()

for (dir_tab in dirs) {
    dir_mod <- sub("tabelas", "modelos", dir_tab)

    tab <- fread(file.path(dir_tab, "colina_original", "associacao_maquinas_colina.csv"))
    tab <- tab[!duplicated(ug, fromLast = TRUE)]
    usi_ug <- c(usi_ug, list(tab))

    arq_mods <- list.files(dir_mod, pattern = "_vaz_[[:digit:]]+.rds")
 
    tag <- tab[, paste0("colina_", cod[1])]
    outarqs <- sub(".*vaz", tag, arq_mods)
    file.copy(file.path(dir_mod, arq_mods), file.path("data", outarqs))
}

usi_ug <- rbindlist(usi_ug)
setorder(usi_ug, cod)
saveRDS(usi_ug, "data/usinas_ugs.rds")
