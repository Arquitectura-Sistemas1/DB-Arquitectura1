/*=====================================================================
 03_Seguridad.sql

 CONTENIDO:
 - Roles de base de datos
 - Permisos mínimos
 - Ejemplos de creación de LOGIN/USER

 REQUISITOS:
 - 01_CrearBaseDatos.sql
 - 02_ObjetosProgramables.sql
=====================================================================*/

USE TiendaVideojuegos;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_backend') IS NULL
    CREATE ROLE rol_backend;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_reportes') IS NULL
    CREATE ROLE rol_reportes;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_auditoria') IS NULL
    CREATE ROLE rol_auditoria;
GO

/* Backend: acceso por vistas/procedimientos, no por tablas completas */
GRANT SELECT ON dbo.vw_Catalogo TO rol_backend;
GRANT SELECT ON dbo.vw_PedidosPorRevisar TO rol_backend;
GRANT SELECT ON dbo.vw_RentasActivas TO rol_backend;

GRANT EXECUTE ON dbo.sp_ObtenerCredencialUsuario TO rol_backend;
GRANT EXECUTE ON dbo.sp_ObtenerCredencialEmpleado TO rol_backend;
GRANT EXECUTE ON dbo.sp_RegistrarUsuario TO rol_backend;
GRANT EXECUTE ON dbo.sp_CrearPedido TO rol_backend;
GRANT EXECUTE ON dbo.sp_AgregarItemPedido TO rol_backend;
GRANT EXECUTE ON dbo.sp_AplicarCupon TO rol_backend;
GRANT EXECUTE ON dbo.sp_RegistrarPago TO rol_backend;
GRANT EXECUTE ON dbo.sp_RevisarPedido TO rol_backend;
GRANT EXECUTE ON dbo.sp_EntregarItemDigital TO rol_backend;
GRANT EXECUTE ON dbo.sp_CompletarPedido TO rol_backend;
GRANT EXECUTE ON dbo.sp_SolicitarDevolucion TO rol_backend;
GRANT EXECUTE ON dbo.sp_ResolverDevolucion TO rol_backend;
GRANT EXECUTE ON dbo.sp_RegistrarReembolso TO rol_backend;
GRANT EXECUTE ON dbo.sp_GenerarFactura TO rol_backend;
GO

/* Reportes: solo lectura */
GRANT SELECT ON dbo.vw_Catalogo TO rol_reportes;
GRANT SELECT ON dbo.vw_ResumenVentas TO rol_reportes;
GRANT SELECT ON dbo.vw_RentasActivas TO rol_reportes;
GO

/* Auditoría: solo lectura */
GRANT SELECT ON dbo.Auditoria TO rol_auditoria;
GRANT SELECT ON dbo.HistorialEstadoPedido TO rol_auditoria;
GO

/*=====================================================================
 EJEMPLO DE CUENTAS DE SQL SERVER
 NO se ejecutan automáticamente para no dejar contraseñas en el script.

 En MASTER:
-----------------------------------------------------------------------
CREATE LOGIN app_backend
WITH PASSWORD = 'Cambiar_Esta_Contrasena_123!';
GO

CREATE LOGIN lector_reportes
WITH PASSWORD = 'Cambiar_Esta_Contrasena_456!';
GO
-----------------------------------------------------------------------

 En TiendaVideojuegos:
-----------------------------------------------------------------------
CREATE USER app_backend FOR LOGIN app_backend;
ALTER ROLE rol_backend ADD MEMBER app_backend;

CREATE USER lector_reportes FOR LOGIN lector_reportes;
ALTER ROLE rol_reportes ADD MEMBER lector_reportes;
-----------------------------------------------------------------------

 Nunca conectar el backend usando sa o db_owner.
=====================================================================*/

PRINT '03_Seguridad.sql ejecutado correctamente.';
GO
