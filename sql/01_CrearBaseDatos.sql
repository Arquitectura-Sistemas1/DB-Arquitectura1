/*=====================================================================
 01_CrearBaseDatos.sql
 PROYECTO: Tienda de venta y alquiler de videojuegos
 MOTOR: Microsoft SQL Server 2022

 CONTENIDO:
 - Creación de la base de datos
 - Tablas
 - Claves primarias y foráneas
 - UNIQUE, CHECK y DEFAULT
 - Índices
=====================================================================*/

SET NOCOUNT ON;
GO

IF DB_ID(N'TiendaVideojuegos') IS NULL
BEGIN
    CREATE DATABASE TiendaVideojuegos;
END;
GO

USE TiendaVideojuegos;
GO

/*=====================================================================
 TABLAS DE ROLES Y EMPLEADOS
=====================================================================*/

CREATE TABLE dbo.Rol
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(60) NOT NULL,

    CONSTRAINT PK_Rol PRIMARY KEY (ID),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.VistaSistema
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_VistaSistema PRIMARY KEY (ID),
    CONSTRAINT UQ_VistaSistema_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.RolVista
(
    RolID           INT NOT NULL,
    VistaID         INT NOT NULL,

    CONSTRAINT PK_RolVista PRIMARY KEY (RolID, VistaID),
    CONSTRAINT FK_RolVista_Rol
        FOREIGN KEY (RolID) REFERENCES dbo.Rol(ID),
    CONSTRAINT FK_RolVista_VistaSistema
        FOREIGN KEY (VistaID) REFERENCES dbo.VistaSistema(ID)
);
GO

CREATE TABLE dbo.Empleado
(
    ID              INT IDENTITY(1,1) NOT NULL,
    RolID           INT NOT NULL,
    CodigoEmpleado  VARCHAR(20) NOT NULL,
    Nombres         NVARCHAR(80) NOT NULL,
    Apellidos       NVARCHAR(80) NOT NULL,
    CUI             VARCHAR(20) NOT NULL,
    Telefono        VARCHAR(25) NULL,
    Correo          NVARCHAR(150) NOT NULL,

    CONSTRAINT PK_Empleado PRIMARY KEY (ID),
    CONSTRAINT UQ_Empleado_Codigo UNIQUE (CodigoEmpleado),
    CONSTRAINT UQ_Empleado_CUI UNIQUE (CUI),
    CONSTRAINT UQ_Empleado_Correo UNIQUE (Correo),
    CONSTRAINT FK_Empleado_Rol
        FOREIGN KEY (RolID) REFERENCES dbo.Rol(ID)
);
GO

CREATE TABLE dbo.CredencialEmpleado
(
    ID              INT IDENTITY(1,1) NOT NULL,
    EmpleadoID      INT NOT NULL,
    Usuario         NVARCHAR(80) NOT NULL,
    HashContrasena  VARCHAR(255) NOT NULL,

    CONSTRAINT PK_CredencialEmpleado PRIMARY KEY (ID),
    CONSTRAINT UQ_CredencialEmpleado_Empleado UNIQUE (EmpleadoID),
    CONSTRAINT UQ_CredencialEmpleado_Usuario UNIQUE (Usuario),
    CONSTRAINT FK_CredencialEmpleado_Empleado
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado(ID)
        ON DELETE CASCADE
);
GO

/*=====================================================================
 USUARIOS
=====================================================================*/

CREATE TABLE dbo.Pais
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(80) NOT NULL,

    CONSTRAINT PK_Pais PRIMARY KEY (ID),
    CONSTRAINT UQ_Pais_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Usuario
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    Nombres         NVARCHAR(80) NOT NULL,
    Apellidos       NVARCHAR(80) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Telefono        VARCHAR(25) NULL,
    Correo          NVARCHAR(150) NOT NULL,
    PaisID          INT NOT NULL,

    CONSTRAINT PK_Usuario PRIMARY KEY (ID),
    CONSTRAINT UQ_Usuario_Correo UNIQUE (Correo),
    CONSTRAINT FK_Usuario_Pais
        FOREIGN KEY (PaisID) REFERENCES dbo.Pais(ID)
);
GO

CREATE TABLE dbo.CredencialUsuario
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    UsuarioID       BIGINT NOT NULL,
    Usuario         NVARCHAR(80) NOT NULL,
    HashContrasena  VARCHAR(255) NOT NULL,

    CONSTRAINT PK_CredencialUsuario PRIMARY KEY (ID),
    CONSTRAINT UQ_CredencialUsuario_UsuarioID UNIQUE (UsuarioID),
    CONSTRAINT UQ_CredencialUsuario_Usuario UNIQUE (Usuario),
    CONSTRAINT FK_CredencialUsuario_Usuario
        FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario(ID)
        ON DELETE CASCADE
);
GO

/*=====================================================================
 CATÁLOGO
=====================================================================*/

CREATE TABLE dbo.Clasificacion
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Codigo          VARCHAR(20) NOT NULL,
    EdadMinima      TINYINT NOT NULL,
    Descripcion     NVARCHAR(250) NULL,

    CONSTRAINT PK_Clasificacion PRIMARY KEY (ID),
    CONSTRAINT UQ_Clasificacion_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Clasificacion_Edad CHECK (EdadMinima <= 21)
);
GO

CREATE TABLE dbo.Plataforma
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100) NOT NULL,
    Fabricante      NVARCHAR(100) NULL,

    CONSTRAINT PK_Plataforma PRIMARY KEY (ID),
    CONSTRAINT UQ_Plataforma_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Region
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(80) NOT NULL,

    CONSTRAINT PK_Region PRIMARY KEY (ID),
    CONSTRAINT UQ_Region_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Genero
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(80) NOT NULL,
    Descripcion     NVARCHAR(250) NULL,

    CONSTRAINT PK_Genero PRIMARY KEY (ID),
    CONSTRAINT UQ_Genero_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Desarrolladora
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(150) NOT NULL,
    SitioWeb        NVARCHAR(250) NULL,

    CONSTRAINT PK_Desarrolladora PRIMARY KEY (ID),
    CONSTRAINT UQ_Desarrolladora_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Videojuego
(
    ID               BIGINT IDENTITY(1,1) NOT NULL,
    ClasificacionID  INT NOT NULL,
    Titulo           NVARCHAR(200) NOT NULL,
    Descripcion      NVARCHAR(MAX) NULL,
    FechaLanzamiento DATE NULL,
    NumeroJugadores  SMALLINT NOT NULL
        CONSTRAINT DF_Videojuego_NumeroJugadores DEFAULT (1),
    Edicion          NVARCHAR(100) NULL,
    Idioma           NVARCHAR(80) NULL,

    CONSTRAINT PK_Videojuego PRIMARY KEY (ID),
    CONSTRAINT CK_Videojuego_Jugadores CHECK (NumeroJugadores >= 1),
    CONSTRAINT FK_Videojuego_Clasificacion
        FOREIGN KEY (ClasificacionID) REFERENCES dbo.Clasificacion(ID)
);
GO

CREATE TABLE dbo.Portada
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    VideojuegoID    BIGINT NOT NULL,
    URL             NVARCHAR(500) NOT NULL,

    CONSTRAINT PK_Portada PRIMARY KEY (ID),
    CONSTRAINT FK_Portada_Videojuego
        FOREIGN KEY (VideojuegoID) REFERENCES dbo.Videojuego(ID)
        ON DELETE CASCADE
);
GO

CREATE TABLE dbo.VideojuegoGenero
(
    VideojuegoID    BIGINT NOT NULL,
    GeneroID        INT NOT NULL,

    CONSTRAINT PK_VideojuegoGenero PRIMARY KEY (VideojuegoID, GeneroID),
    CONSTRAINT FK_VideojuegoGenero_Videojuego
        FOREIGN KEY (VideojuegoID) REFERENCES dbo.Videojuego(ID)
        ON DELETE CASCADE,
    CONSTRAINT FK_VideojuegoGenero_Genero
        FOREIGN KEY (GeneroID) REFERENCES dbo.Genero(ID)
        ON DELETE CASCADE
);
GO

CREATE TABLE dbo.VideojuegoDesarrolladora
(
    VideojuegoID        BIGINT NOT NULL,
    DesarrolladoraID    INT NOT NULL,

    CONSTRAINT PK_VideojuegoDesarrolladora
        PRIMARY KEY (VideojuegoID, DesarrolladoraID),
    CONSTRAINT FK_VideojuegoDesarrolladora_Videojuego
        FOREIGN KEY (VideojuegoID) REFERENCES dbo.Videojuego(ID)
        ON DELETE CASCADE,
    CONSTRAINT FK_VideojuegoDesarrolladora_Desarrolladora
        FOREIGN KEY (DesarrolladoraID) REFERENCES dbo.Desarrolladora(ID)
        ON DELETE CASCADE
);
GO

/*=====================================================================
 TARIFAS, PRODUCTOS, DESCUENTOS Y LICENCIAS
=====================================================================*/

CREATE TABLE dbo.Tarifa
(
    ID                  INT IDENTITY(1,1) NOT NULL,
    PrecioVenta         DECIMAL(10,2) NULL,
    PrecioRenta         DECIMAL(10,2) NULL,
    DuracionRentaHoras  INT NULL,

    CONSTRAINT PK_Tarifa PRIMARY KEY (ID),
    CONSTRAINT CK_Tarifa_PrecioVenta
        CHECK (PrecioVenta IS NULL OR PrecioVenta >= 0),
    CONSTRAINT CK_Tarifa_PrecioRenta
        CHECK (PrecioRenta IS NULL OR PrecioRenta >= 0),
    CONSTRAINT CK_Tarifa_AlgunPrecio
        CHECK (PrecioVenta IS NOT NULL OR PrecioRenta IS NOT NULL),
    CONSTRAINT CK_Tarifa_Duracion
        CHECK
        (
            (PrecioRenta IS NULL AND DuracionRentaHoras IS NULL)
            OR
            (PrecioRenta IS NOT NULL
             AND DuracionRentaHoras IS NOT NULL
             AND DuracionRentaHoras > 0)
        )
);
GO

CREATE TABLE dbo.Producto
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    VideojuegoID    BIGINT NOT NULL,
    PlataformaID    INT NOT NULL,
    RegionID        INT NOT NULL,
    TarifaID        INT NOT NULL,
    SKU             VARCHAR(80) NOT NULL,

    CONSTRAINT PK_Producto PRIMARY KEY (ID),
    CONSTRAINT UQ_Producto_SKU UNIQUE (SKU),
    CONSTRAINT UQ_Producto_Variante
        UNIQUE (VideojuegoID, PlataformaID, RegionID),
    CONSTRAINT FK_Producto_Videojuego
        FOREIGN KEY (VideojuegoID) REFERENCES dbo.Videojuego(ID),
    CONSTRAINT FK_Producto_Plataforma
        FOREIGN KEY (PlataformaID) REFERENCES dbo.Plataforma(ID),
    CONSTRAINT FK_Producto_Region
        FOREIGN KEY (RegionID) REFERENCES dbo.Region(ID),
    CONSTRAINT FK_Producto_Tarifa
        FOREIGN KEY (TarifaID) REFERENCES dbo.Tarifa(ID)
);
GO

CREATE TABLE dbo.Descuento
(
    ID              INT IDENTITY(1,1) NOT NULL,
    ProductoID      BIGINT NOT NULL,
    Tipo            VARCHAR(20) NOT NULL,
    Valor           DECIMAL(10,2) NOT NULL,
    FechaInicio     DATETIME2(0) NOT NULL,
    FechaFin        DATETIME2(0) NOT NULL,

    CONSTRAINT PK_Descuento PRIMARY KEY (ID),
    CONSTRAINT CK_Descuento_Tipo
        CHECK (Tipo IN ('PORCENTAJE','MONTO_FIJO')),
    CONSTRAINT CK_Descuento_Valor CHECK (Valor >= 0),
    CONSTRAINT CK_Descuento_Porcentaje
        CHECK (Tipo <> 'PORCENTAJE' OR Valor <= 100),
    CONSTRAINT CK_Descuento_Fechas CHECK (FechaFin > FechaInicio),
    CONSTRAINT FK_Descuento_Producto
        FOREIGN KEY (ProductoID) REFERENCES dbo.Producto(ID)
        ON DELETE CASCADE
);
GO

/*=====================================================================
 CUPONES Y PEDIDOS
=====================================================================*/

CREATE TABLE dbo.Cupon
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Codigo          VARCHAR(45) NOT NULL,
    Tipo            VARCHAR(20) NOT NULL,
    Valor           DECIMAL(10,2) NOT NULL,
    FechaExpiracion DATETIME2(0) NOT NULL,

    CONSTRAINT PK_Cupon PRIMARY KEY (ID),
    CONSTRAINT UQ_Cupon_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Cupon_Tipo
        CHECK (Tipo IN ('PORCENTAJE','MONTO_FIJO')),
    CONSTRAINT CK_Cupon_Valor CHECK (Valor >= 0),
    CONSTRAINT CK_Cupon_Porcentaje
        CHECK (Tipo <> 'PORCENTAJE' OR Valor <= 100)
);
GO

CREATE TABLE dbo.Pedido
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    UsuarioID       BIGINT NOT NULL,
    CuponID         INT NULL,
    Subtotal        DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Pedido_Subtotal DEFAULT (0),
    DescuentoTotal  DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Pedido_Descuento DEFAULT (0),
    Impuestos       DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Pedido_Impuestos DEFAULT (0),
    Total           DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Pedido_Total DEFAULT (0),
    Estado          VARCHAR(30) NOT NULL
        CONSTRAINT DF_Pedido_Estado DEFAULT ('CREADO'),
    FechaCreacion   DATETIME2(0) NOT NULL
        CONSTRAINT DF_Pedido_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Pedido PRIMARY KEY (ID),
    CONSTRAINT CK_Pedido_Estado CHECK
    (
        Estado IN
        (
            'CREADO',
            'PENDIENTE_PAGO',
            'PAGADO',
            'APROBADO',
            'RECHAZADO',
            'COMPLETADO',
            'CANCELADO'
        )
    ),
    CONSTRAINT CK_Pedido_Subtotal CHECK (Subtotal >= 0),
    CONSTRAINT CK_Pedido_Descuento CHECK (DescuentoTotal >= 0),
    CONSTRAINT CK_Pedido_Impuestos CHECK (Impuestos >= 0),
    CONSTRAINT CK_Pedido_Total CHECK (Total >= 0),
    CONSTRAINT FK_Pedido_Usuario
        FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario(ID),
    CONSTRAINT FK_Pedido_Cupon
        FOREIGN KEY (CuponID) REFERENCES dbo.Cupon(ID)
);
GO

CREATE TABLE dbo.PedidoItem
(
    ID                  BIGINT IDENTITY(1,1) NOT NULL,
    PedidoID            BIGINT NOT NULL,
    ProductoID          BIGINT NOT NULL,
    TipoItem            VARCHAR(10) NOT NULL,
    PrecioAplicado      DECIMAL(10,2) NOT NULL,
    DescuentoAplicado   DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_PedidoItem_Descuento DEFAULT (0),
    SubtotalItem AS
        CONVERT(DECIMAL(10,2), PrecioAplicado - DescuentoAplicado) PERSISTED,

    CONSTRAINT PK_PedidoItem PRIMARY KEY (ID),
    CONSTRAINT CK_PedidoItem_Tipo CHECK (TipoItem IN ('VENTA','RENTA')),
    CONSTRAINT CK_PedidoItem_Precio CHECK (PrecioAplicado >= 0),
    CONSTRAINT CK_PedidoItem_Descuento
        CHECK
        (
            DescuentoAplicado >= 0
            AND DescuentoAplicado <= PrecioAplicado
        ),
    CONSTRAINT FK_PedidoItem_Pedido
        FOREIGN KEY (PedidoID) REFERENCES dbo.Pedido(ID),
    CONSTRAINT FK_PedidoItem_Producto
        FOREIGN KEY (ProductoID) REFERENCES dbo.Producto(ID)
);
GO

CREATE TABLE dbo.Venta
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    PedidoItemID    BIGINT NOT NULL,
    FechaVenta      DATETIME2(0) NOT NULL
        CONSTRAINT DF_Venta_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Venta PRIMARY KEY (ID),
    CONSTRAINT UQ_Venta_PedidoItem UNIQUE (PedidoItemID),
    CONSTRAINT FK_Venta_PedidoItem
        FOREIGN KEY (PedidoItemID) REFERENCES dbo.PedidoItem(ID)
);
GO

CREATE TABLE dbo.Renta
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    PedidoItemID    BIGINT NOT NULL,
    FechaInicio     DATETIME2(0) NOT NULL,
    FechaFin        DATETIME2(0) NOT NULL,
    Estado          VARCHAR(20) NOT NULL
        CONSTRAINT DF_Renta_Estado DEFAULT ('ACTIVA'),

    CONSTRAINT PK_Renta PRIMARY KEY (ID),
    CONSTRAINT UQ_Renta_PedidoItem UNIQUE (PedidoItemID),
    CONSTRAINT CK_Renta_Estado
        CHECK (Estado IN ('ACTIVA','VENCIDA','CANCELADA')),
    CONSTRAINT CK_Renta_Fechas CHECK (FechaFin > FechaInicio),
    CONSTRAINT FK_Renta_PedidoItem
        FOREIGN KEY (PedidoItemID) REFERENCES dbo.PedidoItem(ID)
);
GO

CREATE TABLE dbo.LicenciaDigital
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    ProductoID      BIGINT NOT NULL,
    CodigoLicencia  NVARCHAR(255) NOT NULL,
    Estado          VARCHAR(20) NOT NULL
        CONSTRAINT DF_LicenciaDigital_Estado DEFAULT ('DISPONIBLE'),
    PedidoItemID    BIGINT NULL,
    FechaAsignacion DATETIME2(0) NULL,

    CONSTRAINT PK_LicenciaDigital PRIMARY KEY (ID),
    CONSTRAINT UQ_LicenciaDigital_Codigo UNIQUE (CodigoLicencia),
    CONSTRAINT CK_LicenciaDigital_Estado
        CHECK (Estado IN ('DISPONIBLE','ASIGNADA','EXPIRADA','REVOCADA')),
    CONSTRAINT FK_LicenciaDigital_Producto
        FOREIGN KEY (ProductoID) REFERENCES dbo.Producto(ID),
    CONSTRAINT FK_LicenciaDigital_PedidoItem
        FOREIGN KEY (PedidoItemID) REFERENCES dbo.PedidoItem(ID)
);
GO

CREATE UNIQUE INDEX UX_LicenciaDigital_PedidoItem
ON dbo.LicenciaDigital(PedidoItemID)
WHERE PedidoItemID IS NOT NULL;
GO

/*=====================================================================
 REVISIÓN E HISTORIAL
=====================================================================*/

CREATE TABLE dbo.PedidoRevision
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    PedidoID        BIGINT NOT NULL,
    EmpleadoID      INT NOT NULL,
    Resultado       VARCHAR(20) NOT NULL,
    Observacion     NVARCHAR(500) NULL,
    FechaRevision   DATETIME2(0) NOT NULL
        CONSTRAINT DF_PedidoRevision_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_PedidoRevision PRIMARY KEY (ID),
    CONSTRAINT CK_PedidoRevision_Resultado
        CHECK (Resultado IN ('APROBADO','RECHAZADO')),
    CONSTRAINT FK_PedidoRevision_Pedido
        FOREIGN KEY (PedidoID) REFERENCES dbo.Pedido(ID),
    CONSTRAINT FK_PedidoRevision_Empleado
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado(ID)
);
GO

CREATE TABLE dbo.HistorialEstadoPedido
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    PedidoID        BIGINT NOT NULL,
    EmpleadoID      INT NULL,
    EstadoAnterior  VARCHAR(30) NULL,
    EstadoNuevo     VARCHAR(30) NOT NULL,
    FechaCambio     DATETIME2(0) NOT NULL
        CONSTRAINT DF_HistorialEstadoPedido_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_HistorialEstadoPedido PRIMARY KEY (ID),
    CONSTRAINT FK_HistorialEstadoPedido_Pedido
        FOREIGN KEY (PedidoID) REFERENCES dbo.Pedido(ID)
        ON DELETE CASCADE,
    CONSTRAINT FK_HistorialEstadoPedido_Empleado
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado(ID)
);
GO

/*=====================================================================
 PAGOS, DEVOLUCIONES Y FACTURACIÓN
=====================================================================*/

CREATE TABLE dbo.MetodoPago
(
    ID              INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100) NOT NULL,
    Instrucciones   NVARCHAR(MAX) NULL,

    CONSTRAINT PK_MetodoPago PRIMARY KEY (ID),
    CONSTRAINT UQ_MetodoPago_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Devolucion
(
    ID                  BIGINT IDENTITY(1,1) NOT NULL,
    PedidoItemID        BIGINT NOT NULL,
    UsuarioID           BIGINT NOT NULL,
    EmpleadoID          INT NULL,
    FechaSolicitud      DATETIME2(0) NOT NULL
        CONSTRAINT DF_Devolucion_FechaSolicitud DEFAULT (SYSDATETIME()),
    Motivo              NVARCHAR(MAX) NOT NULL,
    Estado              VARCHAR(20) NOT NULL
        CONSTRAINT DF_Devolucion_Estado DEFAULT ('SOLICITADA'),
    FechaResolucion     DATETIME2(0) NULL,
    NotasAdministrador  NVARCHAR(MAX) NULL,

    CONSTRAINT PK_Devolucion PRIMARY KEY (ID),
    CONSTRAINT CK_Devolucion_Estado
        CHECK (Estado IN ('SOLICITADA','APROBADA','RECHAZADA','REEMBOLSADA')),
    CONSTRAINT FK_Devolucion_PedidoItem
        FOREIGN KEY (PedidoItemID) REFERENCES dbo.PedidoItem(ID),
    CONSTRAINT FK_Devolucion_Usuario
        FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario(ID),
    CONSTRAINT FK_Devolucion_Empleado
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado(ID)
);
GO

CREATE TABLE dbo.Transaccion
(
    ID                  BIGINT IDENTITY(1,1) NOT NULL,
    PedidoID            BIGINT NULL,
    DevolucionID        BIGINT NULL,
    MetodoPagoID        INT NOT NULL,
    TransaccionOrigenID BIGINT NULL,
    Tipo                VARCHAR(20) NOT NULL,
    Monto               DECIMAL(12,2) NOT NULL,
    ReferenciaExterna   VARCHAR(120) NULL,
    Estado              VARCHAR(20) NOT NULL
        CONSTRAINT DF_Transaccion_Estado DEFAULT ('PENDIENTE'),
    FechaRegistro       DATETIME2(0) NOT NULL
        CONSTRAINT DF_Transaccion_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Transaccion PRIMARY KEY (ID),
    CONSTRAINT CK_Transaccion_Tipo CHECK (Tipo IN ('PAGO','REEMBOLSO')),
    CONSTRAINT CK_Transaccion_Estado
        CHECK (Estado IN ('PENDIENTE','APROBADA','RECHAZADA')),
    CONSTRAINT CK_Transaccion_Monto CHECK (Monto > 0),
    CONSTRAINT CK_Transaccion_Relacion CHECK
    (
        (Tipo = 'PAGO'
         AND PedidoID IS NOT NULL
         AND DevolucionID IS NULL
         AND TransaccionOrigenID IS NULL)
        OR
        (Tipo = 'REEMBOLSO'
         AND PedidoID IS NULL
         AND DevolucionID IS NOT NULL
         AND TransaccionOrigenID IS NOT NULL)
    ),
    CONSTRAINT FK_Transaccion_Pedido
        FOREIGN KEY (PedidoID) REFERENCES dbo.Pedido(ID),
    CONSTRAINT FK_Transaccion_Devolucion
        FOREIGN KEY (DevolucionID) REFERENCES dbo.Devolucion(ID),
    CONSTRAINT FK_Transaccion_MetodoPago
        FOREIGN KEY (MetodoPagoID) REFERENCES dbo.MetodoPago(ID),
    CONSTRAINT FK_Transaccion_Origen
        FOREIGN KEY (TransaccionOrigenID) REFERENCES dbo.Transaccion(ID)
);
GO

CREATE TABLE dbo.Factura
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    TransaccionID   BIGINT NOT NULL,
    NumeroFactura   VARCHAR(60) NOT NULL,
    NITCliente      VARCHAR(25) NULL,
    NombreCliente   NVARCHAR(180) NOT NULL,
    Fecha           DATETIME2(0) NOT NULL
        CONSTRAINT DF_Factura_Fecha DEFAULT (SYSDATETIME()),
    Monto           DECIMAL(12,2) NOT NULL,
    PDFUrl          NVARCHAR(500) NULL,

    CONSTRAINT PK_Factura PRIMARY KEY (ID),
    CONSTRAINT UQ_Factura_Transaccion UNIQUE (TransaccionID),
    CONSTRAINT UQ_Factura_Numero UNIQUE (NumeroFactura),
    CONSTRAINT CK_Factura_Monto CHECK (Monto >= 0),
    CONSTRAINT FK_Factura_Transaccion
        FOREIGN KEY (TransaccionID) REFERENCES dbo.Transaccion(ID)
);
GO

/*=====================================================================
 AUDITORÍA
=====================================================================*/

CREATE TABLE dbo.Auditoria
(
    ID              BIGINT IDENTITY(1,1) NOT NULL,
    EmpleadoID      INT NULL,
    TablaAfectada   NVARCHAR(80) NOT NULL,
    RegistroID      VARCHAR(80) NOT NULL,
    Accion          VARCHAR(10) NOT NULL,
    ValorAnterior   NVARCHAR(MAX) NULL,
    ValorNuevo      NVARCHAR(MAX) NULL,
    FechaRegistro   DATETIME2(0) NOT NULL
        CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Auditoria PRIMARY KEY (ID),
    CONSTRAINT CK_Auditoria_Accion
        CHECK (Accion IN ('INSERT','UPDATE','DELETE')),
    CONSTRAINT FK_Auditoria_Empleado
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado(ID)
);
GO

/*=====================================================================
 ÍNDICES
=====================================================================*/

CREATE INDEX IX_Videojuego_Titulo
ON dbo.Videojuego(Titulo);
GO

CREATE INDEX IX_Producto_Videojuego
ON dbo.Producto(VideojuegoID);
GO

CREATE INDEX IX_Producto_Plataforma_Region
ON dbo.Producto(PlataformaID, RegionID);
GO

CREATE INDEX IX_LicenciaDigital_Producto_Estado
ON dbo.LicenciaDigital(ProductoID, Estado);
GO

CREATE INDEX IX_Pedido_Usuario_Estado
ON dbo.Pedido(UsuarioID, Estado);
GO

CREATE INDEX IX_Pedido_Estado_Fecha
ON dbo.Pedido(Estado, FechaCreacion);
GO

CREATE INDEX IX_PedidoItem_Pedido
ON dbo.PedidoItem(PedidoID);
GO

CREATE INDEX IX_PedidoItem_Producto
ON dbo.PedidoItem(ProductoID);
GO

CREATE INDEX IX_Renta_Estado_FechaFin
ON dbo.Renta(Estado, FechaFin);
GO

CREATE INDEX IX_Transaccion_Pedido_Estado
ON dbo.Transaccion(PedidoID, Estado);
GO

CREATE INDEX IX_Transaccion_Fecha
ON dbo.Transaccion(FechaRegistro);
GO

CREATE INDEX IX_Devolucion_Estado_Fecha
ON dbo.Devolucion(Estado, FechaSolicitud);
GO

CREATE INDEX IX_Auditoria_Tabla_Fecha
ON dbo.Auditoria(TablaAfectada, FechaRegistro);
GO

PRINT '01_CrearBaseDatos.sql ejecutado correctamente.';
GO
