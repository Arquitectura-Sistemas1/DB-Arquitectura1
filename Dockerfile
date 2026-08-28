FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

WORKDIR /opt/tienda

COPY docker-entrypoint.sh /opt/tienda/docker-entrypoint.sh
COPY sql/ /opt/tienda/sql/

RUN chmod +x /opt/tienda/docker-entrypoint.sh \
    && chown -R mssql:root /opt/tienda

USER mssql

EXPOSE 1433

ENTRYPOINT ["/opt/tienda/docker-entrypoint.sh"]
