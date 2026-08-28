/*=====================================================================
 12_CatalogoVideojuegos.sql
  Versión compatible: validaciones con RAISERROR en lugar de THROW
 PROYECTO: TiendaVideojuegos

 OBJETIVO:
 - Permitir al backend crear videojuegos mediante procedimientos.
 - Registrar una portada inicial de forma opcional y atómica.
 - Permitir agregar portadas adicionales a un videojuego existente.
 - Permitir consultar las portadas sin dar acceso directo a la tabla.

 REQUISITOS:
 - Base de datos TiendaVideojuegos ya implementada.
 - Tablas dbo.Videojuego, dbo.Portada, dbo.Clasificacion,
   dbo.Genero, dbo.Desarrolladora, dbo.VideojuegoGenero y
   dbo.VideojuegoDesarrolladora existentes.

 NOTA:
 - Este script NO modifica la estructura de las tablas existentes.
 - Puede ejecutarse después de los scripts 01-11.
=====================================================================*/

USE TiendaVideojuegos;
GO

/*=====================================================================
 1. CREAR VIDEOJUEGO

 Permite crear el registro principal del videojuego y, opcionalmente:
 - relacionarlo con un género;
 - relacionarlo con una desarrolladora;
 - registrar una portada inicial.

 Todo se ejecuta dentro de una misma transacción para evitar registros
 incompletos si alguna operación falla.
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_CrearVideojuego
    @ClasificacionID      INT,
    @Titulo               NVARCHAR(200),
    @Descripcion          NVARCHAR(MAX) = NULL,
    @FechaLanzamiento     DATE = NULL,
    @NumeroJugadores      SMALLINT = 1,
    @Edicion              NVARCHAR(100) = NULL,
    @Idioma               NVARCHAR(80) = NULL,
    @GeneroID             INT = NULL,
    @DesarrolladoraID     INT = NULL,
    @PortadaURL           NVARCHAR(500) = NULL,
    @VideojuegoID         BIGINT OUTPUT,
    @PortadaID            BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @VideojuegoID = NULL;
    SET @PortadaID = NULL;

    /* Validaciones básicas */
    IF NULLIF(LTRIM(RTRIM(@Titulo)), N'') IS NULL
    BEGIN
        RAISERROR(N'El título del videojuego es obligatorio.', 16, 1);
        RETURN;
    END;

    IF @NumeroJugadores < 1
    BEGIN
        RAISERROR(N'El número de jugadores debe ser mayor o igual a 1.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Clasificacion
        WHERE ID = @ClasificacionID
    )
    BEGIN
        RAISERROR(N'La clasificación indicada no existe.', 16, 1);
        RETURN;
    END;

    IF @GeneroID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Genero
           WHERE ID = @GeneroID
       )
    BEGIN
        RAISERROR(N'El género indicado no existe.', 16, 1);
        RETURN;
    END;

    IF @DesarrolladoraID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Desarrolladora
           WHERE ID = @DesarrolladoraID
       )
    BEGIN
        RAISERROR(N'La desarrolladora indicada no existe.', 16, 1);
        RETURN;
    END;

    IF @PortadaURL IS NOT NULL
       AND NULLIF(LTRIM(RTRIM(@PortadaURL)), N'') IS NULL
    BEGIN
        RAISERROR(N'La URL de portada no puede estar vacía.', 16, 1);
        RETURN;
    END;

    BEGIN TRANSACTION;

    BEGIN TRY
        INSERT INTO dbo.Videojuego
        (
            ClasificacionID,
            Titulo,
            Descripcion,
            FechaLanzamiento,
            NumeroJugadores,
            Edicion,
            Idioma
        )
        VALUES
        (
            @ClasificacionID,
            LTRIM(RTRIM(@Titulo)),
            @Descripcion,
            @FechaLanzamiento,
            @NumeroJugadores,
            @Edicion,
            @Idioma
        );

        SET @VideojuegoID = CONVERT(BIGINT, SCOPE_IDENTITY());

        /* Relación opcional con género */
        IF @GeneroID IS NOT NULL
        BEGIN
            INSERT INTO dbo.VideojuegoGenero
            (
                VideojuegoID,
                GeneroID
            )
            VALUES
            (
                @VideojuegoID,
                @GeneroID
            );
        END;

        /* Relación opcional con desarrolladora */
        IF @DesarrolladoraID IS NOT NULL
        BEGIN
            INSERT INTO dbo.VideojuegoDesarrolladora
            (
                VideojuegoID,
                DesarrolladoraID
            )
            VALUES
            (
                @VideojuegoID,
                @DesarrolladoraID
            );
        END;

        /* Portada inicial opcional */
        IF NULLIF(LTRIM(RTRIM(@PortadaURL)), N'') IS NOT NULL
        BEGIN
            INSERT INTO dbo.Portada
            (
                VideojuegoID,
                URL
            )
            VALUES
            (
                @VideojuegoID,
                LTRIM(RTRIM(@PortadaURL))
            );

            SET @PortadaID = CONVERT(BIGINT, SCOPE_IDENTITY());
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN;
    END CATCH;
END;
GO

/*=====================================================================
 2. AGREGAR PORTADA A UN VIDEOJUEGO EXISTENTE

 La tabla Portada permite varias filas por VideojuegoID, por lo que este
 procedimiento sirve para agregar una portada o imagen adicional sin
 modificar el videojuego.
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_AgregarPortadaVideojuego
    @VideojuegoID    BIGINT,
    @URL             NVARCHAR(500),
    @PortadaID       BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @PortadaID = NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Videojuego
        WHERE ID = @VideojuegoID
    )
    BEGIN
        RAISERROR(N'El videojuego indicado no existe.', 16, 1);
        RETURN;
    END;

    IF NULLIF(LTRIM(RTRIM(@URL)), N'') IS NULL
    BEGIN
        RAISERROR(N'La URL de portada es obligatoria.', 16, 1);
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Portada
        WHERE VideojuegoID = @VideojuegoID
          AND URL = LTRIM(RTRIM(@URL))
    )
    BEGIN
        RAISERROR(N'Esta portada ya está registrada para el videojuego.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.Portada
    (
        VideojuegoID,
        URL
    )
    VALUES
    (
        @VideojuegoID,
        LTRIM(RTRIM(@URL))
    );

    SET @PortadaID = CONVERT(BIGINT, SCOPE_IDENTITY());
END;
GO

/*=====================================================================
 3. CONSULTAR PORTADAS DE UN VIDEOJUEGO

 Evita otorgar SELECT directo sobre dbo.Portada al usuario del backend.
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerPortadasVideojuego
    @VideojuegoID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Videojuego
        WHERE ID = @VideojuegoID
    )
    BEGIN
        RAISERROR(N'El videojuego indicado no existe.', 16, 1);
        RETURN;
    END;

    SELECT
        ID AS PortadaID,
        VideojuegoID,
        URL
    FROM dbo.Portada
    WHERE VideojuegoID = @VideojuegoID
    ORDER BY ID;
END;
GO

/*=====================================================================
 4. PERMISOS PARA BACKEND

 El backend ejecuta procedimientos y no necesita INSERT/SELECT directo
 sobre las tablas Videojuego y Portada.
=====================================================================*/
IF DATABASE_PRINCIPAL_ID(N'rol_backend') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_CrearVideojuego TO rol_backend;
    GRANT EXECUTE ON dbo.sp_AgregarPortadaVideojuego TO rol_backend;
    GRANT EXECUTE ON dbo.sp_ObtenerPortadasVideojuego TO rol_backend;
END;
GO

/*=====================================================================
 5. COMPROBACIÓN DE OBJETOS
=====================================================================*/
SELECT
    name AS Procedimiento,
    create_date AS FechaCreacion,
    modify_date AS FechaModificacion
FROM sys.procedures
WHERE name IN
(
    'sp_CrearVideojuego',
    'sp_AgregarPortadaVideojuego',
    'sp_ObtenerPortadasVideojuego'
)
ORDER BY name;
GO

PRINT '12_CatalogoVideojuegos.sql ejecutado correctamente.';
GO