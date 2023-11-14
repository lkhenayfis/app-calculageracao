library(data.table)
library(polijus)
library(curvacolina)

source("R/validadores.r")

# AUXILIARES ---------------------------------------------------------------------------------------

parseparametros <- function(params) {
    params <- lapply(params, function(param) {
        param$turbinamento <- unlist(param$turbinamento)
        param
    })

    # nivel de montante de cada usina
    params <- lapply(params, function(param) {
        #volmax <- hidr[codigo == param$codigo, volume_maximo]
        volume <- param$volume #* volmax
        nmont <- sum(hidr[codigo == param$codigo, 5:9] * volume^(0:4))
        param$nmont <- nmont
        param
    })

    # nivel de montante das usinas a jusante caso necessario
    usinas <- sapply(params, "[[", "codigo")
    params <- lapply(params, function(param) {
        cod <- param$codigo

        if (hidr[codigo == cod, univoca]) {
            param$nmont_jus <- 0
            return(param)
        }

        # Se for nao univoca, ou o volume de jusante esta no proprio registro ou no da usina
        # de jusante
        cod_jus <- hidr[codigo == cod, jusante]
        if (is.null(param$volume_jusante)) {
            volume_jus <- params[usinas == cod_jus]$volume_jusante
        } else {
            volume_jus <- param$volume_jusante
        }

        param$nmont_jus <- sum(hidr[codigo == cod_jus, 5:9] * volume_jus^(0:4))
        return(param)
    })

    return(params)
}

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
    #polijus <- readRDS(file.path("data", paste0("polijus_", cod, ".rds")))
    #dat  <- data.table(vazao = turb + vert, nmont = param$nmont_jus)
    #njus <- predicted.polijusM(polijus, dat)
    njus <- hidr[codigo == cod, canal_fuga_medio]

    # rendimento de colina
    colinas <- usinas_ugs[codigo == cod, unique(colina)]
    colinas <- lapply(file.path("data", paste0("colina_", cod, "_", colinas, ".rds")), readRDS)

    queda_liq <- param$nmont - njus - perda
    rends <- lapply(seq_along(param$turbinamento), function(i) {
        idcolina <- usinas_ugs[(codigo == cod) & (ug == i), colina]
        colina   <- colinas[[idcolina]]
        dat  <- data.table(hl = queda_liq, vaz = param$turbinamento[i])
        predict(colina, dat, full.output = TRUE)
    })
    rends <- rbindlist(rends)
    rends[, rend := rend * 10^-2]

    # geracoes por maquina
    rho <- attr(colinas[[1]]$colina, "rho")
    g   <- attr(colinas[[1]]$colina, "g")
    ger <- sum(rends[, hl * vaz * rend * rend_ger * g * rho * 10^-6])

    if (!all(rends$inhull)) {
        outhull <- which(!rends$inhull)
        warn <- paste0("Usina ", cod, " teve interpolacao das maquinas (",
            paste0(outhull, collapse = ", "), ") fora da envoltoria da colina")
        attr(ger, "WARNING") <- warn
    }

    return(ger)
}

calcula_geracao <- function(PARAMETROS) {

    hidr <- readRDS("data/hidr.rds")
    usinas_ugs <- readRDS("data/usinas_ugs.rds")

    valida_num_maq(PARAMETROS, usinas_ugs)
    valida_vol_jus(PARAMETROS, hidr)

    PARAMETROS <- parseparametros(PARAMETROS)

    geracoes <- lapply(PARAMETROS, calcula_geracao_unit, hidr = hidr, usinas_ugs = usinas_ugs)

    warns <- lapply(geracoes, attr, "WARNING")
    out   <- mapply(PARAMETROS, geracoes,
        FUN = function(par, ger) list(codigo = par$codigo, geracao = ger),
        SIMPLIFY = FALSE)
    out <- c(RESULTADO = list(out), AVISOS = warns)

    return(out)
}