# Despliegue Docker - TiendaVideojuegos

Este paquete despliega Microsoft SQL Server 2022 y crea automáticamente la base de datos `TiendaVideojuegos` con los objetos necesarios para la aplicación.

## Scripts ejecutados automáticamente

En la primera creación del volumen se ejecutan, en este orden:

1. `01_CrearBaseDatos.sql`
2. `02_ObjetosProgramables.sql`
3. `03_Seguridad.sql`
4. `04_DatosIniciales.sql`
5. `11_RegistroVerificacionUsuarios.sql`
6. `12_CatalogoVideojuegos.sql`

`05_DatosPrueba.sql` es opcional y solo se ejecuta en la primera inicialización si `LOAD_DEMO_DATA=true`.

Los scripts de pruebas, monitoreo y backup (`06` a `10`) NO deben ejecutarse automáticamente durante el arranque de un entorno de despliegue. Se conservan como pruebas/operaciones administrativas separadas.

## 1. Configurar variables

Copia `.env.example` a `.env`:

```bash
cp .env.example .env
```

Edita `.env` y cambia `MSSQL_SA_PASSWORD` por una contraseña real y segura.

No subas `.env` al repositorio.

## 2. Construir e iniciar

```bash
docker compose up -d --build
```

## 3. Ver el proceso de inicialización

```bash
docker compose logs -f sqlserver
```

Al finalizar debe aparecer:

```text
Despliegue de TiendaVideojuegos finalizado correctamente.
```

## 4. Comprobar estado

```bash
docker compose ps
```

## 5. Conectarse desde SSMS / Azure Data Studio

- Servidor: `100.109.91.46,1433`
- Autenticación: SQL Server Authentication
- Usuario
- Contraseña: la configurada en `.env`

Para uso de la aplicación se recomienda crear/utilizar un login técnico restringido asociado a `rol_backend`; no utilizar `sa` desde backend.

## 6. Verificación rápida

```sql
USE TiendaVideojuegos;
GO

SELECT DB_NAME() AS BaseActual;

SELECT COUNT(*) AS Tablas
FROM sys.tables;

SELECT COUNT(*) AS Procedimientos
FROM sys.procedures;

SELECT name
FROM sys.procedures
WHERE name IN (
    'sp_CrearSolicitudRegistro',
    'sp_ValidarCodigoRegistro',
    'sp_ConfirmarRegistroUsuario',
    'sp_CrearVideojuego',
    'sp_AgregarPortadaVideojuego',
    'sp_ObtenerPortadasVideojuego'
)
ORDER BY name;
GO
```

## Persistencia

Los archivos de SQL Server se almacenan en el volumen Docker:

```text
tienda_videojuegos_data
```

Por ello, reiniciar o reconstruir el contenedor no elimina la base de datos.

## Reiniciar

```bash
docker compose restart
```

## Detener sin borrar datos

```bash
docker compose down
```

## Borrar también la base persistida (PELIGRO)

Solo para reiniciar completamente un entorno de pruebas:

```bash
docker compose down -v
```

Esto elimina el volumen y todos los datos almacenados.

## Datos de prueba

Para una demostración académica, antes de la primera inicialización puedes colocar:

```env
LOAD_DEMO_DATA=true
```

Para un despliegue limpio o de producción se recomienda:

```env
LOAD_DEMO_DATA=false
```

## Seguridad de red

No publiques el puerto 1433 a Internet de forma indiscriminada. Limita el acceso mediante firewall, VPN/Tailscale o una red privada y haz que el backend se conecte con una cuenta de mínimo privilegio.
