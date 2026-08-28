/*=====================================================================
 05_DatosPrueba.sql

 CONTENIDO:
 - Datos ficticios para demostrar el funcionamiento
 - 5 registros en entidades maestras principales

 NOTA:
 Las tablas transaccionales (Pedido, PedidoItem, Venta, Renta,
 Transaccion, Factura, Auditoria, etc.) se llenan en
 06_PruebasFuncionales.sql mediante los procedimientos reales.
=====================================================================*/

USE TiendaVideojuegos;
GO

/*---------------------------------------------------------------------
 EMPLEADOS
---------------------------------------------------------------------*/
INSERT INTO dbo.Empleado
(
    RolID, CodigoEmpleado, Nombres, Apellidos, CUI, Telefono, Correo
)
VALUES
((SELECT ID FROM dbo.Rol WHERE Nombre=N'Administrador'), 'EMP001', N'Andrea', N'Castillo', '1000000000001', '55550001', N'andrea@tienda.gt'),
((SELECT ID FROM dbo.Rol WHERE Nombre=N'Verificador'), 'EMP002', N'Luis', N'Méndez', '1000000000002', '55550002', N'luis@tienda.gt'),
((SELECT ID FROM dbo.Rol WHERE Nombre=N'Verificador'), 'EMP003', N'María', N'López', '1000000000003', '55550003', N'maria@tienda.gt'),
((SELECT ID FROM dbo.Rol WHERE Nombre=N'Soporte'), 'EMP004', N'Carlos', N'Pérez', '1000000000004', '55550004', N'carlos@tienda.gt'),
((SELECT ID FROM dbo.Rol WHERE Nombre=N'Soporte'), 'EMP005', N'Sofía', N'Ramírez', '1000000000005', '55550005', N'sofia@tienda.gt');
GO

INSERT INTO dbo.CredencialEmpleado(EmpleadoID, Usuario, HashContrasena)
VALUES
(1, N'andrea.admin', '$argon2id$hash_demo_empleado_001'),
(2, N'luis.verificador', '$argon2id$hash_demo_empleado_002'),
(3, N'maria.verificador', '$argon2id$hash_demo_empleado_003'),
(4, N'carlos.soporte', '$argon2id$hash_demo_empleado_004'),
(5, N'sofia.soporte', '$argon2id$hash_demo_empleado_005');
GO

/*---------------------------------------------------------------------
 USUARIOS
---------------------------------------------------------------------*/
INSERT INTO dbo.Usuario
(
    Nombres, Apellidos, FechaNacimiento, Telefono, Correo, PaisID
)
VALUES
(N'Ana', N'López', '2000-04-15', '55551001', N'ana@correo.com', 1),
(N'José', N'García', '1999-08-21', '55551002', N'jose@correo.com', 1),
(N'Lucía', N'Herrera', '2002-01-10', '55551003', N'lucia@correo.com', 1),
(N'Diego', N'Morales', '1998-11-30', '55551004', N'diego@correo.com', 2),
(N'Valeria', N'Ruiz', '2001-06-05', '55551005', N'valeria@correo.com', 3);
GO

INSERT INTO dbo.CredencialUsuario(UsuarioID, Usuario, HashContrasena)
VALUES
(1, N'ana.lopez', '$argon2id$hash_demo_usuario_001'),
(2, N'jose.garcia', '$argon2id$hash_demo_usuario_002'),
(3, N'lucia.herrera', '$argon2id$hash_demo_usuario_003'),
(4, N'diego.morales', '$argon2id$hash_demo_usuario_004'),
(5, N'valeria.ruiz', '$argon2id$hash_demo_usuario_005');
GO

/*---------------------------------------------------------------------
 GÉNEROS
---------------------------------------------------------------------*/
INSERT INTO dbo.Genero(Nombre, Descripcion)
VALUES
(N'Acción', N'Combate y acción en tiempo real'),
(N'Aventura', N'Exploración y narrativa'),
(N'RPG', N'Progresión de personajes y rol'),
(N'Deportes', N'Videojuegos deportivos'),
(N'Estrategia', N'Planificación y gestión de recursos');
GO

/*---------------------------------------------------------------------
 DESARROLLADORAS
---------------------------------------------------------------------*/
INSERT INTO dbo.Desarrolladora(Nombre, SitioWeb)
VALUES
(N'Nova Games', N'https://example.com/nova'),
(N'Pixel Forge', N'https://example.com/pixel'),
(N'Blue Horizon', N'https://example.com/blue'),
(N'Iron Wolf Studio', N'https://example.com/iron'),
(N'Cloud Peak Games', N'https://example.com/cloud');
GO

/*---------------------------------------------------------------------
 VIDEOJUEGOS
---------------------------------------------------------------------*/
INSERT INTO dbo.Videojuego
(
    ClasificacionID, Titulo, Descripcion, FechaLanzamiento,
    NumeroJugadores, Edicion, Idioma
)
VALUES
(3, N'Nebula Quest', N'Aventura espacial de exploración.', '2025-05-10', 1, N'Estándar', N'Español'),
(4, N'Iron Arena', N'Juego de acción competitivo.', '2024-11-02', 8, N'Deluxe', N'Multilenguaje'),
(2, N'Pixel Racers', N'Carreras arcade para toda la familia.', '2026-01-20', 4, N'Estándar', N'Español'),
(3, N'Legends of Aster', N'RPG de fantasía y mundo abierto.', '2025-08-15', 1, N'Gold', N'Multilenguaje'),
(1, N'Strategy Town', N'Construcción y estrategia de ciudades.', '2024-03-05', 1, N'Estándar', N'Español');
GO

INSERT INTO dbo.Portada(VideojuegoID, URL)
VALUES
(1, N'https://cdn.ejemplo.com/portadas/nebula.jpg'),
(2, N'https://cdn.ejemplo.com/portadas/iron.jpg'),
(3, N'https://cdn.ejemplo.com/portadas/pixel.jpg'),
(4, N'https://cdn.ejemplo.com/portadas/aster.jpg'),
(5, N'https://cdn.ejemplo.com/portadas/strategy.jpg');
GO

INSERT INTO dbo.VideojuegoGenero(VideojuegoID, GeneroID)
VALUES
(1,2),
(2,1),
(3,4),
(4,3),
(5,5);
GO

INSERT INTO dbo.VideojuegoDesarrolladora(VideojuegoID, DesarrolladoraID)
VALUES
(1,1),
(2,4),
(3,2),
(4,3),
(5,5);
GO

/*---------------------------------------------------------------------
 TARIFAS
---------------------------------------------------------------------*/
INSERT INTO dbo.Tarifa(PrecioVenta, PrecioRenta, DuracionRentaHoras)
VALUES
(299.00, 59.00, 72),
(399.00, 79.00, 72),
(249.00, 49.00, 48),
(449.00, 89.00, 96),
(199.00, 39.00, 48);
GO

/*---------------------------------------------------------------------
 PRODUCTOS
---------------------------------------------------------------------*/
INSERT INTO dbo.Producto
(
    VideojuegoID, PlataformaID, RegionID, TarifaID, SKU
)
VALUES
(1, 1, 1, 1, 'NEBULA-PC-LATAM'),
(2, 2, 1, 2, 'IRON-PS5-LATAM'),
(3, 4, 5, 3, 'PIXEL-SW-GLOBAL'),
(4, 3, 2, 4, 'ASTER-XBOX-NA'),
(5, 1, 5, 5, 'STRATEGY-PC-GLOBAL');
GO

/*---------------------------------------------------------------------
 DESCUENTOS
---------------------------------------------------------------------*/
INSERT INTO dbo.Descuento
(
    ProductoID, Tipo, Valor, FechaInicio, FechaFin
)
VALUES
(1, 'PORCENTAJE', 10.00, DATEADD(DAY,-1,SYSDATETIME()), DATEADD(DAY,30,SYSDATETIME())),
(2, 'MONTO_FIJO', 25.00, DATEADD(DAY,-1,SYSDATETIME()), DATEADD(DAY,30,SYSDATETIME())),
(3, 'PORCENTAJE', 15.00, DATEADD(DAY,-1,SYSDATETIME()), DATEADD(DAY,30,SYSDATETIME())),
(4, 'MONTO_FIJO', 40.00, DATEADD(DAY,-1,SYSDATETIME()), DATEADD(DAY,30,SYSDATETIME())),
(5, 'PORCENTAJE', 5.00, DATEADD(DAY,-1,SYSDATETIME()), DATEADD(DAY,30,SYSDATETIME()));
GO

/*---------------------------------------------------------------------
 CUPONES
---------------------------------------------------------------------*/
INSERT INTO dbo.Cupon(Codigo, Tipo, Valor, FechaExpiracion)
VALUES
('BIENVENIDA10', 'PORCENTAJE', 10.00, DATEADD(MONTH,3,SYSDATETIME())),
('DESC20', 'MONTO_FIJO', 20.00, DATEADD(MONTH,2,SYSDATETIME())),
('GAMER15', 'PORCENTAJE', 15.00, DATEADD(MONTH,1,SYSDATETIME())),
('RENTA25', 'MONTO_FIJO', 25.00, DATEADD(MONTH,1,SYSDATETIME())),
('PROMO5', 'PORCENTAJE', 5.00, DATEADD(MONTH,6,SYSDATETIME()));
GO

/*---------------------------------------------------------------------
 LICENCIAS DIGITALES
 5 licencias por producto = 25 licencias.
---------------------------------------------------------------------*/
DECLARE @Producto BIGINT = 1;

WHILE @Producto <= 5
BEGIN
    DECLARE @N INT = 1;

    WHILE @N <= 5
    BEGIN
        INSERT INTO dbo.LicenciaDigital
        (
            ProductoID,
            CodigoLicencia
        )
        VALUES
        (
            @Producto,
            CONCAT('KEY-', FORMAT(@Producto,'00'), '-', FORMAT(@N,'000'))
        );

        SET @N += 1;
    END;

    SET @Producto += 1;
END;
GO

PRINT '05_DatosPrueba.sql ejecutado correctamente.';
GO
