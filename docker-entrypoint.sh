#!/usr/bin/env bash
set -Eeuo pipefail

DB_NAME="${DB_NAME:-TiendaVideojuegos}"
LOAD_DEMO_DATA="${LOAD_DEMO_DATA:-false}"

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
    echo "ERROR: MSSQL_SA_PASSWORD no está definida."
    exit 1
fi

if [[ -x /opt/mssql-tools18/bin/sqlcmd ]]; then
    SQLCMD=/opt/mssql-tools18/bin/sqlcmd
elif [[ -x /opt/mssql-tools/bin/sqlcmd ]]; then
    SQLCMD=/opt/mssql-tools/bin/sqlcmd
else
    echo "ERROR: no se encontró sqlcmd dentro de la imagen."
    exit 1
fi

SQLCMD_ARGS=(
    -S localhost
    -U sa
    -P "$MSSQL_SA_PASSWORD"
    -C
    -b
    -r1
)

run_sql_file() {
    local file="$1"
    echo "------------------------------------------------------------"
    echo "Ejecutando: $(basename "$file")"
    "$SQLCMD" "${SQLCMD_ARGS[@]}" -i "$file"
}

/opt/mssql/bin/sqlservr &
SQL_PID=$!

shutdown_sqlserver() {
    echo "Deteniendo SQL Server..."
    kill -TERM "$SQL_PID" 2>/dev/null || true
    wait "$SQL_PID" 2>/dev/null || true
}
trap shutdown_sqlserver TERM INT

printf 'Esperando que SQL Server esté disponible'
READY=0
for _ in $(seq 1 90); do
    if "$SQLCMD" "${SQLCMD_ARGS[@]}" -Q "SET NOCOUNT ON; SELECT 1;" >/dev/null 2>&1; then
        READY=1
        break
    fi
    printf '.'
    sleep 2
done
echo

if [[ "$READY" -ne 1 ]]; then
    echo "ERROR: SQL Server no respondió dentro del tiempo esperado."
    shutdown_sqlserver
    exit 1
fi

echo "SQL Server listo."

DB_EXISTS=$(
    "$SQLCMD" "${SQLCMD_ARGS[@]}" -h -1 -W \
        -Q "SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'${DB_NAME}') IS NULL THEN 0 ELSE 1 END;" \
        | tr -d '\r[:space:]'
)

if [[ "$DB_EXISTS" == "0" ]]; then
    echo "Primera inicialización de ${DB_NAME}."

    run_sql_file /opt/tienda/sql/01_CrearBaseDatos.sql
    run_sql_file /opt/tienda/sql/02_ObjetosProgramables.sql
    run_sql_file /opt/tienda/sql/03_Seguridad.sql
    run_sql_file /opt/tienda/sql/04_DatosIniciales.sql
    run_sql_file /opt/tienda/sql/11_RegistroVerificacionUsuarios.sql
    run_sql_file /opt/tienda/sql/12_CatalogoVideojuegos.sql

    if [[ "${LOAD_DEMO_DATA,,}" == "true" ]]; then
        echo "LOAD_DEMO_DATA=true: cargando datos de demostración."
        run_sql_file /opt/tienda/sql/opcional/05_DatosPrueba.sql
    else
        echo "Datos de prueba omitidos (LOAD_DEMO_DATA=false)."
    fi
else
    echo "${DB_NAME} ya existe. No se volverán a cargar estructura ni datos iniciales."
    echo "Reaplicando objetos programables, permisos y migraciones idempotentes..."

    run_sql_file /opt/tienda/sql/02_ObjetosProgramables.sql
    run_sql_file /opt/tienda/sql/03_Seguridad.sql
    run_sql_file /opt/tienda/sql/11_RegistroVerificacionUsuarios.sql
    run_sql_file /opt/tienda/sql/12_CatalogoVideojuegos.sql
fi

echo "============================================================"
echo "Despliegue de ${DB_NAME} finalizado correctamente."
echo "============================================================"

wait "$SQL_PID"
