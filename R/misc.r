
to_dataframe <- function(PARAMETROS, RESULTADO) {
    PARAMETROS <- PARAMETROS$PARAMETROS
    hidr <- readRDS(file.path("data", "hidr.rds"))
    usinas_ugs <- readRDS(file.path("data", "usinas_ugs.rds"))
    valida_num_maq(PARAMETROS, usinas_ugs)
    valida_vol_jus(PARAMETROS, hidr)
    PARAMETROS <- parseparametros(PARAMETROS, hidr)
    PARAMETROS <- lapply(PARAMETROS, function(x) {
        x$turbinamento <- sum(x$turbinamento)
        as.data.table(x[c("codigo", "volume", "nmont", "vertimento", "turbinamento")])
    })
    PARAMETROS <- rbindlist(PARAMETROS)
    RESULTADO <- lapply(RESULTADO$RESULTADO, as.data.table)
    RESULTADO <- rbindlist(RESULTADO)
    out <- cbind(PARAMETROS, RESULTADO[, .(geracao)])
    return(out)
}

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

get_rho_g <- function(colina) {
    if (!is.null(colina$colina)) {
        colina <- colina$colina
    } else {
        colina <- colina[["superficies"]][[1]]$colina
    }

    rho <- attr(colina, "rho")
    g   <- attr(colina, "g")

    return(list(rho, g))
}

dummy_rend <- function() data.table(hl = 0, vaz = 0, rend = 0, inhull = FALSE)

opt_calcula_rend <- function(queda_liq, turbinamentos, colinas, ug2colina) {
    ug2colina[, turb := turbinamentos]
    uniques <- ug2colina[, .(turb = unique(turb)), by = colina]

    rends <- sapply(seq_len(nrow(uniques)), function(i) {
        if (uniques[i, turb] == 0) return(0)
        colina   <- colinas[[as.character(uniques[i, colina])]]
        dat  <- data.table(hl = queda_liq, vaz = uniques[i, turb])
        predict(colina, dat, as.gradecolina = FALSE)
    })

    uniques[, rend := rends]

    out <- merge(ug2colina, uniques, by = c("colina", "turb"), sort = FALSE)$rend

    return(out)
}
