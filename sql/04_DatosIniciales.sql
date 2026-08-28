/*=====================================================================
 04_DatosIniciales.sql

 CONTENIDO:
 - Catálogos mínimos del sistema
 - Roles funcionales
 - Secciones del sistema
 - Países, regiones, clasificaciones, plataformas y métodos de pago

 Estos no son datos transaccionales de prueba.
=====================================================================*/

USE TiendaVideojuegos;
GO

INSERT INTO dbo.Rol(Nombre)
VALUES
(N'Administrador'),
(N'Verificador'),
(N'Soporte');
GO

INSERT INTO dbo.VistaSistema(Nombre)
VALUES
(N'Catalogo'),
(N'Pedidos'),
(N'Devoluciones'),
(N'Reportes'),
(N'Auditoria');
GO

INSERT INTO dbo.RolVista(RolID, VistaID)
SELECT r.ID, v.ID
FROM dbo.Rol r
CROSS JOIN dbo.VistaSistema v
WHERE r.Nombre = N'Administrador';
GO

INSERT INTO dbo.RolVista(RolID, VistaID)
SELECT r.ID, v.ID
FROM dbo.Rol r
INNER JOIN dbo.VistaSistema v
    ON v.Nombre IN (N'Pedidos', N'Devoluciones')
WHERE r.Nombre = N'Verificador';
GO

INSERT INTO dbo.Pais(Nombre)
VALUES
(N'Guatemala'),
(N'México'),
(N'Estados Unidos'),
(N'Canadá'),
(N'España');
GO

INSERT INTO dbo.Region(Nombre)
VALUES
(N'Latinoamérica'),
(N'Norteamérica'),
(N'Europa'),
(N'Asia'),
(N'Global');
GO

INSERT INTO dbo.Clasificacion(Codigo, EdadMinima, Descripcion)
VALUES
('E', 0,  N'Apto para todas las edades'),
('E10+', 10, N'Mayores de 10 años'),
('T', 13, N'Adolescentes'),
('M', 17, N'Mayores de 17 años'),
('AO', 18, N'Solo adultos');
GO

INSERT INTO dbo.Plataforma(Nombre, Fabricante)
VALUES
(N'PC', N'Varios'),
(N'PlayStation 5', N'Sony'),
(N'Xbox Series X|S', N'Microsoft'),
(N'Nintendo Switch', N'Nintendo'),
(N'PlayStation 4', N'Sony');
GO

INSERT INTO dbo.MetodoPago(Nombre, Instrucciones)
VALUES
(N'Tarjeta', N'Pago procesado mediante pasarela externa.'),
(N'Transferencia bancaria', N'El empleado verifica la referencia del pago.'),
(N'PayPal', N'Pago mediante proveedor externo.'),
(N'Google Pay', N'Pago mediante proveedor externo.'),
(N'Apple Pay', N'Pago mediante proveedor externo.');
GO

PRINT '04_DatosIniciales.sql ejecutado correctamente.';
GO
