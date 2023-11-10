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

valida_num_maq <- function(lst, USINAS_UGS) {
    usinas <- sapply(lst, "[[", "codigo")
    nmaq   <- USINAS_UGS[, .N, by = codigo]
    nmaq   <- nmaq[match(usinas, codigo), N]
    num_turbs <- sapply(lapply(lst, "[[", "turbinamento"), length)
    check <- nmaq == num_turbs

    if (!all(check)) {
        errados <- which(!v_maq)
        usinas <- usinas[errados]
        msg <- paste0("Usinas (", paste0(usinas, collapse = ", "), ") informadas com vetor ",
            "de turbinamentos de comprimento diferente do numero de maquinas")
        stop(msg)
    }

    return(NULL)
}

valida_vol_jus <- function(lst, HIDR) {
    
    usinas <- sapply(lst, "[[", "codigo")

    univoca <- HIDR[match(usinas, codigo), univoca]

    jusantes <- HIDR[match(usinas, codigo), jusante]
    jusantes_in_arq <- jusantes %in% usinas

    contem_voljus <- sapply(lst, "[[", "volume_jusante")
    contem_voljus <- !sapply(contem_voljus, is.null)

    check <- univoca | contem_voljus | jusantes_in_arq

    if (!all(check)) {
        errados <- which(!check)
        usinas <- usinas[errados]
        msg <- paste0("Usinas (", paste0(usinas, collapse = ", "), ") necessitam volume da usina",
            " de jusante porem nao foi informado")
        stop(msg)
    }

    return(NULL)
}