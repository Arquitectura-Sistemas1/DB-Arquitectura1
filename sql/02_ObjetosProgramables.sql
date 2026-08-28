/*=====================================================================
 02_ObjetosProgramables.sql

 CONTENIDO:
 - Vistas SQL
 - Procedimientos almacenados
 - Triggers

 REQUISITO:
 - Ejecutar primero 01_CrearBaseDatos.sql
=====================================================================*/

USE TiendaVideojuegos;
GO

/*=====================================================================
 VISTAS
=====================================================================*/

CREATE OR ALTER VIEW dbo.vw_Catalogo
AS
SELECT
    p.ID AS ProductoID,
    p.SKU,
    v.ID AS VideojuegoID,
    v.Titulo,
    v.Descripcion,
    v.Edicion,
    v.Idioma,
    c.Codigo AS Clasificacion,
    pl.Nombre AS Plataforma,
    r.Nombre AS Region,
    t.PrecioVenta,
    t.PrecioRenta,
    t.DuracionRentaHoras
FROM dbo.Producto p
INNER JOIN dbo.Videojuego v ON v.ID = p.VideojuegoID
INNER JOIN dbo.Clasificacion c ON c.ID = v.ClasificacionID
INNER JOIN dbo.Plataforma pl ON pl.ID = p.PlataformaID
INNER JOIN dbo.Region r ON r.ID = p.RegionID
INNER JOIN dbo.Tarifa t ON t.ID = p.TarifaID;
GO

CREATE OR ALTER VIEW dbo.vw_PedidosPorRevisar
AS
SELECT
    p.ID AS PedidoID,
    p.FechaCreacion,
    CONCAT(u.Nombres, N' ', u.Apellidos) AS Cliente,
    u.Correo,
    p.Total
FROM dbo.Pedido p
INNER JOIN dbo.Usuario u ON u.ID = p.UsuarioID
WHERE p.Estado = 'PAGADO';
GO

CREATE OR ALTER VIEW dbo.vw_RentasActivas
AS
SELECT
    r.ID AS RentaID,
    r.FechaInicio,
    r.FechaFin,
    p.ID AS PedidoID,
    u.ID AS UsuarioID,
    CONCAT(u.Nombres, N' ', u.Apellidos) AS Cliente,
    v.Titulo,
    pr.SKU
FROM dbo.Renta r
INNER JOIN dbo.PedidoItem pi ON pi.ID = r.PedidoItemID
INNER JOIN dbo.Pedido p ON p.ID = pi.PedidoID
INNER JOIN dbo.Usuario u ON u.ID = p.UsuarioID
INNER JOIN dbo.Producto pr ON pr.ID = pi.ProductoID
INNER JOIN dbo.Videojuego v ON v.ID = pr.VideojuegoID
WHERE r.Estado = 'ACTIVA';
GO

CREATE OR ALTER VIEW dbo.vw_ResumenVentas
AS
SELECT
    CAST(v.FechaVenta AS DATE) AS Fecha,
    COUNT_BIG(*) AS CantidadVentas,
    SUM(pi.SubtotalItem) AS TotalVendido
FROM dbo.Venta v
INNER JOIN dbo.PedidoItem pi ON pi.ID = v.PedidoItemID
GROUP BY CAST(v.FechaVenta AS DATE);
GO

/*=====================================================================
 PROCEDIMIENTOS
=====================================================================*/

CREATE OR ALTER PROCEDURE dbo.sp_EstablecerEmpleadoAuditoria
    @EmpleadoID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @EmpleadoID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Empleado
           WHERE ID = @EmpleadoID
       )
        THROW 50001, 'El empleado indicado no existe.', 1;

    EXEC sys.sp_set_session_context
        @key = N'EmpleadoID',
        @value = @EmpleadoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCredencialUsuario
    @Login NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        cu.UsuarioID,
        cu.Usuario,
        cu.HashContrasena,
        u.Correo
    FROM dbo.CredencialUsuario cu
    INNER JOIN dbo.Usuario u ON u.ID = cu.UsuarioID
    WHERE cu.Usuario = @Login
       OR u.Correo = @Login;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCredencialEmpleado
    @Login NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        ce.EmpleadoID,
        ce.Usuario,
        ce.HashContrasena,
        e.Correo,
        e.RolID
    FROM dbo.CredencialEmpleado ce
    INNER JOIN dbo.Empleado e ON e.ID = ce.EmpleadoID
    WHERE ce.Usuario = @Login
       OR e.Correo = @Login;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarUsuario
    @Nombres            NVARCHAR(80),
    @Apellidos          NVARCHAR(80),
    @FechaNacimiento    DATE,
    @Telefono           VARCHAR(25) = NULL,
    @Correo             NVARCHAR(150),
    @PaisID             INT,
    @Usuario            NVARCHAR(80),
    @HashContrasena     VARCHAR(255),
    @UsuarioID          BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF LEN(@HashContrasena) < 20
        THROW 50002, 'Debe enviarse un hash de contraseña válido.', 1;

    BEGIN TRANSACTION;

    BEGIN TRY
        INSERT INTO dbo.Usuario
        (
            Nombres, Apellidos, FechaNacimiento,
            Telefono, Correo, PaisID
        )
        VALUES
        (
            @Nombres, @Apellidos, @FechaNacimiento,
            @Telefono, @Correo, @PaisID
        );

        SET @UsuarioID = SCOPE_IDENTITY();

        INSERT INTO dbo.CredencialUsuario
        (
            UsuarioID, Usuario, HashContrasena
        )
        VALUES
        (
            @UsuarioID, @Usuario, @HashContrasena
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CrearPedido
    @UsuarioID BIGINT,
    @PedidoID  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE ID = @UsuarioID
    )
        THROW 50003, 'El usuario no existe.', 1;

    INSERT INTO dbo.Pedido(UsuarioID)
    VALUES (@UsuarioID);

    SET @PedidoID = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RecalcularPedido
    @PedidoID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Subtotal       DECIMAL(12,2) = 0,
        @CuponID        INT = NULL,
        @TipoCupon      VARCHAR(20) = NULL,
        @ValorCupon     DECIMAL(10,2) = 0,
        @Descuento      DECIMAL(12,2) = 0,
        @Impuestos      DECIMAL(12,2) = 0;

    SELECT
        @Subtotal = COALESCE(SUM(SubtotalItem), 0)
    FROM dbo.PedidoItem
    WHERE PedidoID = @PedidoID;

    SELECT
        @CuponID = CuponID,
        @Impuestos = Impuestos
    FROM dbo.Pedido
    WHERE ID = @PedidoID;

    IF @CuponID IS NOT NULL
    BEGIN
        SELECT
            @TipoCupon = Tipo,
            @ValorCupon = Valor
        FROM dbo.Cupon
        WHERE ID = @CuponID
          AND FechaExpiracion >= SYSDATETIME();

        IF @TipoCupon = 'PORCENTAJE'
            SET @Descuento = ROUND(@Subtotal * (@ValorCupon / 100.0), 2);
        ELSE IF @TipoCupon = 'MONTO_FIJO'
            SET @Descuento =
                CASE
                    WHEN @ValorCupon > @Subtotal THEN @Subtotal
                    ELSE @ValorCupon
                END;
    END;

    UPDATE dbo.Pedido
    SET
        Subtotal = @Subtotal,
        DescuentoTotal = @Descuento,
        Total =
            CASE
                WHEN (@Subtotal - @Descuento + @Impuestos) < 0 THEN 0
                ELSE (@Subtotal - @Descuento + @Impuestos)
            END
    WHERE ID = @PedidoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AgregarItemPedido
    @PedidoID       BIGINT,
    @ProductoID     BIGINT,
    @TipoItem       VARCHAR(10),
    @PedidoItemID   BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Precio             DECIMAL(10,2) = NULL,
        @TipoDescuento      VARCHAR(20) = NULL,
        @ValorDescuento     DECIMAL(10,2) = 0,
        @DescuentoAplicado  DECIMAL(10,2) = 0;

    IF @TipoItem NOT IN ('VENTA','RENTA')
        THROW 50004, 'TipoItem debe ser VENTA o RENTA.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pedido
        WHERE ID = @PedidoID
          AND Estado IN ('CREADO','PENDIENTE_PAGO')
    )
        THROW 50005, 'El pedido no existe o ya no admite modificaciones.', 1;

    IF @TipoItem = 'VENTA'
    BEGIN
        SELECT @Precio = t.PrecioVenta
        FROM dbo.Producto p
        INNER JOIN dbo.Tarifa t ON t.ID = p.TarifaID
        WHERE p.ID = @ProductoID;
    END
    ELSE
    BEGIN
        SELECT @Precio = t.PrecioRenta
        FROM dbo.Producto p
        INNER JOIN dbo.Tarifa t ON t.ID = p.TarifaID
        WHERE p.ID = @ProductoID;
    END;

    IF @Precio IS NULL
        THROW 50006, 'El producto no posee precio para esta operación.', 1;

    SELECT TOP (1)
        @TipoDescuento = Tipo,
        @ValorDescuento = Valor
    FROM dbo.Descuento
    WHERE ProductoID = @ProductoID
      AND SYSDATETIME() BETWEEN FechaInicio AND FechaFin
    ORDER BY FechaInicio DESC;

    IF @TipoDescuento = 'PORCENTAJE'
        SET @DescuentoAplicado =
            ROUND(@Precio * (@ValorDescuento / 100.0), 2);
    ELSE IF @TipoDescuento = 'MONTO_FIJO'
        SET @DescuentoAplicado =
            CASE
                WHEN @ValorDescuento > @Precio THEN @Precio
                ELSE @ValorDescuento
            END;

    INSERT INTO dbo.PedidoItem
    (
        PedidoID, ProductoID, TipoItem,
        PrecioAplicado, DescuentoAplicado
    )
    VALUES
    (
        @PedidoID, @ProductoID, @TipoItem,
        @Precio, @DescuentoAplicado
    );

    SET @PedidoItemID = SCOPE_IDENTITY();

    UPDATE dbo.Pedido
    SET Estado = 'PENDIENTE_PAGO'
    WHERE ID = @PedidoID
      AND Estado = 'CREADO';
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AplicarCupon
    @PedidoID BIGINT,
    @Codigo   VARCHAR(45)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CuponID INT;

    SELECT @CuponID = ID
    FROM dbo.Cupon
    WHERE Codigo = @Codigo
      AND FechaExpiracion >= SYSDATETIME();

    IF @CuponID IS NULL
        THROW 50007, 'El cupón no existe o está vencido.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pedido
        WHERE ID = @PedidoID
          AND Estado IN ('CREADO','PENDIENTE_PAGO')
    )
        THROW 50008, 'El pedido no admite cupón en su estado actual.', 1;

    UPDATE dbo.Pedido
    SET CuponID = @CuponID
    WHERE ID = @PedidoID;

    EXEC dbo.sp_RecalcularPedido @PedidoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @PedidoID           BIGINT,
    @MetodoPagoID       INT,
    @Monto              DECIMAL(12,2),
    @ReferenciaExterna  VARCHAR(120) = NULL,
    @Estado             VARCHAR(20),
    @TransaccionID      BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Total DECIMAL(12,2);

    SELECT @Total = Total
    FROM dbo.Pedido
    WHERE ID = @PedidoID
      AND Estado = 'PENDIENTE_PAGO';

    IF @Total IS NULL
        THROW 50009, 'El pedido no está pendiente de pago.', 1;

    IF @Estado NOT IN ('PENDIENTE','APROBADA','RECHAZADA')
        THROW 50010, 'Estado de transacción inválido.', 1;

    IF @Estado = 'APROBADA' AND @Monto < @Total
        THROW 50011, 'El monto aprobado no cubre el total del pedido.', 1;

    BEGIN TRANSACTION;

    BEGIN TRY
        INSERT INTO dbo.Transaccion
        (
            PedidoID, DevolucionID, MetodoPagoID,
            TransaccionOrigenID, Tipo, Monto,
            ReferenciaExterna, Estado
        )
        VALUES
        (
            @PedidoID, NULL, @MetodoPagoID,
            NULL, 'PAGO', @Monto,
            @ReferenciaExterna, @Estado
        );

        SET @TransaccionID = SCOPE_IDENTITY();

        IF @Estado = 'APROBADA'
        BEGIN
            UPDATE dbo.Pedido
            SET Estado = 'PAGADO'
            WHERE ID = @PedidoID;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RevisarPedido
    @PedidoID       BIGINT,
    @EmpleadoID     INT,
    @Aprobar        BIT,
    @Observacion    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Resultado VARCHAR(20);

    IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE ID = @EmpleadoID)
        THROW 50012, 'El empleado no existe.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pedido
        WHERE ID = @PedidoID
          AND Estado = 'PAGADO'
    )
        THROW 50013, 'El pedido no está disponible para revisión.', 1;

    SET @Resultado =
        CASE WHEN @Aprobar = 1 THEN 'APROBADO' ELSE 'RECHAZADO' END;

    EXEC dbo.sp_EstablecerEmpleadoAuditoria @EmpleadoID;

    INSERT INTO dbo.PedidoRevision
    (
        PedidoID, EmpleadoID, Resultado, Observacion
    )
    VALUES
    (
        @PedidoID, @EmpleadoID, @Resultado, @Observacion
    );

    UPDATE dbo.Pedido
    SET Estado = @Resultado
    WHERE ID = @PedidoID;

    EXEC dbo.sp_EstablecerEmpleadoAuditoria NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EntregarItemDigital
    @PedidoItemID BIGINT,
    @LicenciaID   BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ProductoID         BIGINT,
        @TipoItem           VARCHAR(10),
        @EstadoPedido       VARCHAR(30),
        @DuracionRentaHoras INT;

    BEGIN TRANSACTION;

    BEGIN TRY
        SELECT
            @ProductoID = pi.ProductoID,
            @TipoItem = pi.TipoItem,
            @EstadoPedido = p.Estado,
            @DuracionRentaHoras = t.DuracionRentaHoras
        FROM dbo.PedidoItem pi
        INNER JOIN dbo.Pedido p ON p.ID = pi.PedidoID
        INNER JOIN dbo.Producto pr ON pr.ID = pi.ProductoID
        INNER JOIN dbo.Tarifa t ON t.ID = pr.TarifaID
        WHERE pi.ID = @PedidoItemID;

        IF @ProductoID IS NULL
            THROW 50014, 'El detalle del pedido no existe.', 1;

        IF @EstadoPedido <> 'APROBADO'
            THROW 50015, 'El pedido debe estar APROBADO antes de entregar.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.LicenciaDigital
            WHERE PedidoItemID = @PedidoItemID
        )
            THROW 50016, 'El detalle ya posee una licencia asignada.', 1;

        SELECT TOP (1)
            @LicenciaID = ID
        FROM dbo.LicenciaDigital WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE ProductoID = @ProductoID
          AND Estado = 'DISPONIBLE'
        ORDER BY ID;

        IF @LicenciaID IS NULL
            THROW 50017, 'No hay licencias digitales disponibles.', 1;

        UPDATE dbo.LicenciaDigital
        SET
            Estado = 'ASIGNADA',
            PedidoItemID = @PedidoItemID,
            FechaAsignacion = SYSDATETIME()
        WHERE ID = @LicenciaID;

        IF @TipoItem = 'VENTA'
        BEGIN
            INSERT INTO dbo.Venta(PedidoItemID)
            VALUES (@PedidoItemID);
        END
        ELSE
        BEGIN
            IF @DuracionRentaHoras IS NULL OR @DuracionRentaHoras <= 0
                THROW 50018, 'La tarifa de renta no posee duración válida.', 1;

            INSERT INTO dbo.Renta
            (
                PedidoItemID, FechaInicio, FechaFin, Estado
            )
            VALUES
            (
                @PedidoItemID,
                SYSDATETIME(),
                DATEADD(HOUR, @DuracionRentaHoras, SYSDATETIME()),
                'ACTIVA'
            );
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CompletarPedido
    @PedidoID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @TotalItems      INT,
        @ItemsEntregados INT;

    SELECT @TotalItems = COUNT(*)
    FROM dbo.PedidoItem
    WHERE PedidoID = @PedidoID;

    SELECT @ItemsEntregados = COUNT(*)
    FROM dbo.PedidoItem pi
    INNER JOIN dbo.LicenciaDigital ld
        ON ld.PedidoItemID = pi.ID
    WHERE pi.PedidoID = @PedidoID
      AND ld.Estado = 'ASIGNADA';

    IF @TotalItems = 0 OR @TotalItems <> @ItemsEntregados
        THROW 50019, 'Aún existen productos sin entregar.', 1;

    UPDATE dbo.Pedido
    SET Estado = 'COMPLETADO'
    WHERE ID = @PedidoID
      AND Estado = 'APROBADO';

    IF @@ROWCOUNT = 0
        THROW 50020, 'El pedido no está en estado APROBADO.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SolicitarDevolucion
    @PedidoItemID    BIGINT,
    @UsuarioID       BIGINT,
    @Motivo          NVARCHAR(MAX),
    @DevolucionID    BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.PedidoItem pi
        INNER JOIN dbo.Pedido p ON p.ID = pi.PedidoID
        WHERE pi.ID = @PedidoItemID
          AND p.UsuarioID = @UsuarioID
          AND p.Estado = 'COMPLETADO'
    )
        THROW 50021, 'El producto no corresponde a un pedido completado del usuario.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Devolucion
        WHERE PedidoItemID = @PedidoItemID
          AND Estado IN ('SOLICITADA','APROBADA','REEMBOLSADA')
    )
        THROW 50022, 'Ya existe una devolución vigente para este producto.', 1;

    INSERT INTO dbo.Devolucion
    (
        PedidoItemID, UsuarioID, Motivo
    )
    VALUES
    (
        @PedidoItemID, @UsuarioID, @Motivo
    );

    SET @DevolucionID = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ResolverDevolucion
    @DevolucionID    BIGINT,
    @EmpleadoID      INT,
    @Aprobar         BIT,
    @Notas           NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Devolucion
        WHERE ID = @DevolucionID
          AND Estado = 'SOLICITADA'
    )
        THROW 50023, 'La devolución no está pendiente.', 1;

    EXEC dbo.sp_EstablecerEmpleadoAuditoria @EmpleadoID;

    UPDATE dbo.Devolucion
    SET
        EmpleadoID = @EmpleadoID,
        Estado = CASE WHEN @Aprobar = 1 THEN 'APROBADA' ELSE 'RECHAZADA' END,
        FechaResolucion = SYSDATETIME(),
        NotasAdministrador = @Notas
    WHERE ID = @DevolucionID;

    EXEC dbo.sp_EstablecerEmpleadoAuditoria NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarReembolso
    @DevolucionID        BIGINT,
    @MetodoPagoID        INT,
    @Monto               DECIMAL(12,2),
    @TransaccionOrigenID BIGINT,
    @ReferenciaExterna   VARCHAR(120) = NULL,
    @TransaccionID       BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PedidoItemID BIGINT;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Transaccion
        WHERE ID = @TransaccionOrigenID
          AND Tipo = 'PAGO'
          AND Estado = 'APROBADA'
    )
        THROW 50024, 'La transacción de origen no es un pago aprobado.', 1;

    SELECT @PedidoItemID = PedidoItemID
    FROM dbo.Devolucion
    WHERE ID = @DevolucionID
      AND Estado = 'APROBADA';

    IF @PedidoItemID IS NULL
        THROW 50025, 'La devolución debe estar APROBADA.', 1;

    BEGIN TRANSACTION;

    BEGIN TRY
        INSERT INTO dbo.Transaccion
        (
            PedidoID, DevolucionID, MetodoPagoID,
            TransaccionOrigenID, Tipo, Monto,
            ReferenciaExterna, Estado
        )
        VALUES
        (
            NULL, @DevolucionID, @MetodoPagoID,
            @TransaccionOrigenID, 'REEMBOLSO', @Monto,
            @ReferenciaExterna, 'APROBADA'
        );

        SET @TransaccionID = SCOPE_IDENTITY();

        UPDATE dbo.Devolucion
        SET Estado = 'REEMBOLSADA'
        WHERE ID = @DevolucionID;

        UPDATE dbo.LicenciaDigital
        SET Estado = 'REVOCADA'
        WHERE PedidoItemID = @PedidoItemID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GenerarFactura
    @TransaccionID   BIGINT,
    @NumeroFactura   VARCHAR(60),
    @NITCliente      VARCHAR(25) = NULL,
    @NombreCliente   NVARCHAR(180),
    @PDFUrl          NVARCHAR(500) = NULL,
    @FacturaID       BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Monto DECIMAL(12,2);

    SELECT @Monto = Monto
    FROM dbo.Transaccion
    WHERE ID = @TransaccionID
      AND Tipo = 'PAGO'
      AND Estado = 'APROBADA';

    IF @Monto IS NULL
        THROW 50026, 'Solo puede facturarse un pago aprobado.', 1;

    INSERT INTO dbo.Factura
    (
        TransaccionID, NumeroFactura, NITCliente,
        NombreCliente, Monto, PDFUrl
    )
    VALUES
    (
        @TransaccionID, @NumeroFactura, @NITCliente,
        @NombreCliente, @Monto, @PDFUrl
    );

    SET @FacturaID = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarRentasVencidas
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Renta
    SET Estado = 'VENCIDA'
    WHERE Estado = 'ACTIVA'
      AND FechaFin <= SYSDATETIME();

    UPDATE ld
    SET ld.Estado = 'EXPIRADA'
    FROM dbo.LicenciaDigital ld
    INNER JOIN dbo.Renta r
        ON r.PedidoItemID = ld.PedidoItemID
    WHERE r.Estado = 'VENCIDA'
      AND ld.Estado = 'ASIGNADA';
END;
GO

/*=====================================================================
 TRIGGERS
=====================================================================*/

CREATE OR ALTER TRIGGER dbo.tr_PedidoItem_RecalcularPedido
ON dbo.PedidoItem
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Pedidos TABLE (PedidoID BIGINT PRIMARY KEY);

    INSERT INTO @Pedidos(PedidoID)
    SELECT PedidoID FROM inserted
    UNION
    SELECT PedidoID FROM deleted;

    DECLARE @PedidoID BIGINT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT PedidoID FROM @Pedidos;

    OPEN cur;
    FETCH NEXT FROM cur INTO @PedidoID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.sp_RecalcularPedido @PedidoID;
        FETCH NEXT FROM cur INTO @PedidoID;
    END;

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Venta_ValidarTipo
ON dbo.Venta
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.PedidoItem pi ON pi.ID = i.PedidoItemID
        WHERE pi.TipoItem <> 'VENTA'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50027, 'Solo un PedidoItem de tipo VENTA puede registrarse en Venta.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Renta_ValidarTipo
ON dbo.Renta
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.PedidoItem pi ON pi.ID = i.PedidoItemID
        WHERE pi.TipoItem <> 'RENTA'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50028, 'Solo un PedidoItem de tipo RENTA puede registrarse en Renta.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Pedido_HistorialEstado
ON dbo.Pedido
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoID INT =
        TRY_CONVERT(INT, SESSION_CONTEXT(N'EmpleadoID'));

    INSERT INTO dbo.HistorialEstadoPedido
    (
        PedidoID, EmpleadoID, EstadoAnterior, EstadoNuevo
    )
    SELECT
        i.ID, @EmpleadoID, NULL, i.Estado
    FROM inserted i
    LEFT JOIN deleted d ON d.ID = i.ID
    WHERE d.ID IS NULL;

    INSERT INTO dbo.HistorialEstadoPedido
    (
        PedidoID, EmpleadoID, EstadoAnterior, EstadoNuevo
    )
    SELECT
        i.ID, @EmpleadoID, d.Estado, i.Estado
    FROM inserted i
    INNER JOIN deleted d ON d.ID = i.ID
    WHERE ISNULL(d.Estado, '') <> ISNULL(i.Estado, '');
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Pedido_Auditoria
ON dbo.Pedido
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoID INT =
        TRY_CONVERT(INT, SESSION_CONTEXT(N'EmpleadoID'));

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'Pedido',
        CONVERT(VARCHAR(80), i.ID),
        'UPDATE',
        CONCAT(
            N'Estado=', d.Estado,
            N'; Subtotal=', d.Subtotal,
            N'; Descuento=', d.DescuentoTotal,
            N'; Total=', d.Total
        ),
        CONCAT(
            N'Estado=', i.Estado,
            N'; Subtotal=', i.Subtotal,
            N'; Descuento=', i.DescuentoTotal,
            N'; Total=', i.Total
        )
    FROM inserted i
    INNER JOIN deleted d ON d.ID = i.ID;

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'Pedido',
        CONVERT(VARCHAR(80), d.ID),
        'DELETE',
        CONCAT(
            N'UsuarioID=', d.UsuarioID,
            N'; Estado=', d.Estado,
            N'; Total=', d.Total
        ),
        NULL
    FROM deleted d
    LEFT JOIN inserted i ON i.ID = d.ID
    WHERE i.ID IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Transaccion_Auditoria
ON dbo.Transaccion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoID INT =
        TRY_CONVERT(INT, SESSION_CONTEXT(N'EmpleadoID'));

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'Transaccion',
        CONVERT(VARCHAR(80), i.ID),
        'INSERT',
        NULL,
        CONCAT(
            N'Tipo=', i.Tipo,
            N'; Monto=', i.Monto,
            N'; Estado=', i.Estado,
            N'; Referencia=', ISNULL(i.ReferenciaExterna,'')
        )
    FROM inserted i
    LEFT JOIN deleted d ON d.ID = i.ID
    WHERE d.ID IS NULL;

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'Transaccion',
        CONVERT(VARCHAR(80), i.ID),
        'UPDATE',
        CONCAT(
            N'Monto=', d.Monto,
            N'; Estado=', d.Estado,
            N'; Referencia=', ISNULL(d.ReferenciaExterna,'')
        ),
        CONCAT(
            N'Monto=', i.Monto,
            N'; Estado=', i.Estado,
            N'; Referencia=', ISNULL(i.ReferenciaExterna,'')
        )
    FROM inserted i
    INNER JOIN deleted d ON d.ID = i.ID;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_Devolucion_Auditoria
ON dbo.Devolucion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoID INT =
        TRY_CONVERT(INT, SESSION_CONTEXT(N'EmpleadoID'));

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'Devolucion',
        CONVERT(VARCHAR(80), i.ID),
        'UPDATE',
        CONCAT(
            N'Estado=', d.Estado,
            N'; EmpleadoID=', ISNULL(CONVERT(VARCHAR(20), d.EmpleadoID), 'NULL')
        ),
        CONCAT(
            N'Estado=', i.Estado,
            N'; EmpleadoID=', ISNULL(CONVERT(VARCHAR(20), i.EmpleadoID), 'NULL')
        )
    FROM inserted i
    INNER JOIN deleted d ON d.ID = i.ID;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_LicenciaDigital_Auditoria
ON dbo.LicenciaDigital
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoID INT =
        TRY_CONVERT(INT, SESSION_CONTEXT(N'EmpleadoID'));

    INSERT INTO dbo.Auditoria
    (
        EmpleadoID, TablaAfectada, RegistroID,
        Accion, ValorAnterior, ValorNuevo
    )
    SELECT
        @EmpleadoID,
        N'LicenciaDigital',
        CONVERT(VARCHAR(80), i.ID),
        'UPDATE',
        CONCAT(
            N'Estado=', d.Estado,
            N'; PedidoItemID=', ISNULL(CONVERT(VARCHAR(30), d.PedidoItemID), 'NULL')
        ),
        CONCAT(
            N'Estado=', i.Estado,
            N'; PedidoItemID=', ISNULL(CONVERT(VARCHAR(30), i.PedidoItemID), 'NULL')
        )
    FROM inserted i
    INNER JOIN deleted d ON d.ID = i.ID
    WHERE
        ISNULL(d.Estado,'') <> ISNULL(i.Estado,'')
        OR ISNULL(d.PedidoItemID,-1) <> ISNULL(i.PedidoItemID,-1);
END;
GO

PRINT '02_ObjetosProgramables.sql ejecutado correctamente.';
GO
