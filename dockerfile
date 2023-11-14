FROM public.ecr.aws/lambda/provided:al2

ENV R_VERSION=4.3.0

RUN yum -y install wget git tar lib libxml2-devel

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm

ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

RUN yum -y install openssl-devel

COPY . .

RUN Rscript -e "renv::restore()"

RUN rm .Renviron
RUN chmod 755 -R runtime.r

RUN printf '#!/bin/sh\nRscript runtime.r' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap

CMD ["calcula_geracao"]