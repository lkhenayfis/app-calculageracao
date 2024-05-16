library(data.table)
library(polijus)
library(curvacolina)

source("R/misc.r")
source("R/validadores.r")
source("R/leitura.r")

# CALCULA GERACAO ----------------------------------------------------------------------------------

calcula_geracao_unit <- function(param, hidr, usinas_ugs) {

    cod <- param$codigo
    turb <- sum(param$turbinamento)
    vert <- param$vertimento

    # PALEATIVOS -- DEVEM SER CORRIGIDOS ##############
    perda    <- hidr[codigo == cod, perda_media]
    rend_ger <- .98
    ###################################################

    # nivel de jusante
    polijus <- le_polijus(cod)
    dat  <- data.table(vazao = turb + vert, nmont = param$nmont_jus)
    njus <- predicted.polijusM(polijus, dat)

    # rendimento de colina
    colinas <- usinas_ugs[codigo == cod, unique(colina)]
    colinas <- le_colina(cod, colinas)

    queda_liq <- param$nmont - njus - perda
    rends <- opt_calcula_rend(queda_liq, param$turbinamento, colinas, usinas_ugs[codigo == cod])

    # geracoes por maquina
    rho_g <- get_rho_g(colinas[[1]])
    rho <- rho_g[[1]]
    g   <- rho_g[[2]]
    ger <- sum(queda_liq * param$turbinamento * rends * 10^-2 * rend_ger * g * rho * 10^-6)

    return(ger)
}

calcula_geracao <- function(PARAMETROS) {

    PARAMETROS <- PARAMETROS$PARAMETROS

    hidr <- readRDS(file.path("data", "hidr.rds"))
    usinas_ugs <- readRDS(file.path("data", "usinas_ugs.rds"))

    valida_num_maq(PARAMETROS, usinas_ugs)
    valida_vol_jus(PARAMETROS, hidr)

    PARAMETROS <- parseparametros(PARAMETROS, hidr)

    geracoes <- lapply(PARAMETROS, calcula_geracao_unit, hidr = hidr, usinas_ugs = usinas_ugs)

    warns <- lapply(geracoes, attr, "WARNING")
    out   <- mapply(PARAMETROS, geracoes,
        FUN = function(par, ger) list(codigo = par$codigo, geracao = as.numeric(ger)),
        SIMPLIFY = FALSE)
    out <- c(RESULTADO = list(out), AVISOS = warns)

    return(out)
}
