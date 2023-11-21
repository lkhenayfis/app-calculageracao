FROM public.ecr.aws/lambda/provided:al2

# Dependencias de sistema --------------------------------------------------------------------------

ENV R_VERSION=4.3.0

RUN yum -y install wget git tar lib libxml2-devel

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm

ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

RUN yum -y install openssl-devel

# Dependencias de R --------------------------------------------------------------------------------

RUN mkdir -p renv
COPY renv.lock renv.lock
COPY .Renviron .Renviron
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

ENV RENV_PATHS_ROOT="/tmp/.local/share/renv"
RUN Rscript -e "renv::restore()"

# Demais configs de R e copia dos .R ---------------------------------------------------------------

COPY R/ R/
COPY runtime.r .

# .Renviron contem uma chave privada de github, por isso deve ser apagado e refeito
RUN rm .Renviron
RUN echo 'RENV_CONFIG_SANDBOX_ENABLED=FALSE' > .Renviron
RUN chmod 755 -R runtime.r

RUN printf '#!/bin/sh\nRscript runtime.r' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap

CMD ["calcula_geracao"]