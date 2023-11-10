library(data.table)

# AUXILIARES ---------------------------------------------------------------------------------------

is.univoca <- function(surfchave) {
    if (attr(surfchave, "ncurvas") == 1) return(TRUE) else return(FALSE)
}

# VALIDADORES UNITARIOS ----------------------------------------------------------------------------

#' Validadores Por Usina
#' 
#' Checagens de dados realizadas isoladamente por usina
#' 
#' @param lst lista proveniente do json de entrada

valida_num_maq <- function(lst, usi_ug = usinas_ugs) {
    usinas <- sapply(lst, "[[", "codigo")
    nmaq   <- usi_ug[, .N, by = codigo]
    nmaq   <- nmaq[match(usinas, codigo), N]
    num_turbs <- sapply(lapply(lst, "[[", "turbinamento"), length)
    nmaq == num_turbs
}

valida_vol_jus <- function(lst, HIDR = hidr) {
    
    usinas <- sapply(lst, "[[", "codigo")

    univoca <- HIDR[match(usinas, codigo), univoca]

    jusantes <- HIDR[match(usinas, codigo), jusante]
    jusantes_in_arq <- jusantes %in% usinas

    contem_voljus <- sapply(lst, "[[", "volume_jusante")
    contem_voljus <- !sapply(contem_voljus, is.null)

    out <- univoca | contem_voljus | jusantes_in_arq

    return(out)
}