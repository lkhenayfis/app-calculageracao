library(data.table)
library(polijus)
library(curvacolina)

source("R/validadores.r")
source("R/leitura.r")

# AUXILIARES ---------------------------------------------------------------------------------------

reform_list <- function(lixo) {
    lixo <- split(lixo, seq_len(nrow(lixo)))
    lixo <- lapply(lixo, as.list)
    lixo <- lapply(lixo, function(l) l[!sapply(l, is.na)])
    lixo <- lapply(lixo, function(l) {l$turbinamento <- l$turbinamento[[1]]; l})
    lixo <- unname(lixo)
    return(lixo)
}

parseparametros <- function(params, hidr) {
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
            volume_jus <- params[usinas == cod_jus][[1]]$volume
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
    polijus <- le_polijus(cod, "s3://ons-pem-historico", "gtdp/app-calculager")
    dat  <- data.table(vazao = turb + vert, nmont = param$nmont_jus)
    njus <- predicted.polijusM(polijus, dat)

    # rendimento de colina
    colinas <- usinas_ugs[codigo == cod, unique(colina)]
    colinas <- le_colina(cod, colinas, "s3://ons-pem-historico", "gtdp/app-calculager")

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

    PARAMETROS <- reform_list(PARAMETROS)

    hidr <- aws.s3::s3read_using(readRDS, object = "gtdp/app-calculager/hidr.rds",
        bucket = "s3://ons-pem-historico")
    usinas_ugs <- aws.s3::s3read_using(readRDS, object = "gtdp/app-calculager/usinas_ugs.rds",
        bucket = "s3://ons-pem-historico")

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

lambdr::start_lambda()