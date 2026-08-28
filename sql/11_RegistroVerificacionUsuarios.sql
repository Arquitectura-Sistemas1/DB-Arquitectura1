/*=====================================================================
 11_RegistroVerificacionUsuarios.sql
 TiendaVideojuegos

 REQUISITOS:
 - 01_CrearBaseDatos.sql
 - 02_ObjetosProgramables.sql
 - Deben existir dbo.Usuario, dbo.CredencialUsuario, dbo.Pais y
   dbo.sp_RegistrarUsuario.
=====================================================================*/

USE TiendaVideojuegos;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*=====================================================================
 1. TABLA: SolicitudRegistroUsuario

 Conserva temporalmente la informacion enviada durante el registro.
 Cuando la solicitud se completa, el hash de contrasena se elimina de
 esta tabla y queda solamente en CredencialUsuario.
=====================================================================*/

IF OBJECT_ID(N'dbo.SolicitudRegistroUsuario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudRegistroUsuario
    (
        ID                  BIGINT IDENTITY(1,1) NOT NULL,
        Nombres             NVARCHAR(80) NOT NULL,
        Apellidos           NVARCHAR(80) NOT NULL,
        FechaNacimiento     DATE NOT NULL,
        Telefono            VARCHAR(25) NULL,
        Correo              NVARCHAR(150) NOT NULL,
        PaisID              INT NOT NULL,
        Usuario             NVARCHAR(80) NOT NULL,
        HashContrasena      VARCHAR(255) NULL,
        Estado              VARCHAR(15) NOT NULL
            CONSTRAINT DF_SolicitudRegistroUsuario_Estado
            DEFAULT ('PENDIENTE'),
        FechaSolicitud      DATETIME2(0) NOT NULL
            CONSTRAINT DF_SolicitudRegistroUsuario_FechaSolicitud
            DEFAULT (SYSDATETIME()),
        FechaVerificacion   DATETIME2(0) NULL,
        FechaCompletado     DATETIME2(0) NULL,
        UsuarioCreadoID     BIGINT NULL,

        CONSTRAINT PK_SolicitudRegistroUsuario PRIMARY KEY (ID),

        CONSTRAINT FK_SolicitudRegistroUsuario_Pais
            FOREIGN KEY (PaisID)
            REFERENCES dbo.Pais(ID),

        CONSTRAINT FK_SolicitudRegistroUsuario_UsuarioCreado
            FOREIGN KEY (UsuarioCreadoID)
            REFERENCES dbo.Usuario(ID)
            ON DELETE SET NULL,

        CONSTRAINT CK_SolicitudRegistroUsuario_Estado
            CHECK
            (
                Estado IN
                (
                    'PENDIENTE',
                    'VERIFICADA',
                    'COMPLETADA',
                    'VENCIDA',
                    'CANCELADA'
                )
            ),

        CONSTRAINT CK_SolicitudRegistroUsuario_Hash
            CHECK
            (
                HashContrasena IS NULL
                OR LEN(HashContrasena) >= 20
            )
    );
END;
GO

/* Solo puede existir una solicitud PENDIENTE por correo. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SolicitudRegistroUsuario')
      AND name = N'UX_SolicitudRegistroUsuario_Correo_Pendiente'
)
BEGIN
    CREATE UNIQUE INDEX UX_SolicitudRegistroUsuario_Correo_Pendiente
        ON dbo.SolicitudRegistroUsuario(Correo)
        WHERE Estado = 'PENDIENTE';
END;
GO

/* Solo puede existir una solicitud PENDIENTE por nombre de usuario. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SolicitudRegistroUsuario')
      AND name = N'UX_SolicitudRegistroUsuario_Usuario_Pendiente'
)
BEGIN
    CREATE UNIQUE INDEX UX_SolicitudRegistroUsuario_Usuario_Pendiente
        ON dbo.SolicitudRegistroUsuario(Usuario)
        WHERE Estado = 'PENDIENTE';
END;
GO

/* Una solicitud completada solo puede apuntar a un usuario definitivo. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SolicitudRegistroUsuario')
      AND name = N'UX_SolicitudRegistroUsuario_UsuarioCreadoID'
)
BEGIN
    CREATE UNIQUE INDEX UX_SolicitudRegistroUsuario_UsuarioCreadoID
        ON dbo.SolicitudRegistroUsuario(UsuarioCreadoID)
        WHERE UsuarioCreadoID IS NOT NULL;
END;
GO

/*=====================================================================
 2. TABLA: CodigoRegistro

 Relacion 1:N:
 SolicitudRegistroUsuario (1) ---- (N) CodigoRegistro

 El diseno 1:N permite incorporar posteriormente reenvio de codigos
 sin sobrescribir los anteriores.
=====================================================================*/

IF OBJECT_ID(N'dbo.CodigoRegistro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CodigoRegistro
    (
        ID                      BIGINT IDENTITY(1,1) NOT NULL,
        SolicitudRegistroID     BIGINT NOT NULL,
        HashCodigo              VARBINARY(32) NOT NULL,
        SaltCodigo              VARBINARY(16) NOT NULL,
        Intentos                TINYINT NOT NULL
            CONSTRAINT DF_CodigoRegistro_Intentos DEFAULT (0),
        MaxIntentos             TINYINT NOT NULL
            CONSTRAINT DF_CodigoRegistro_MaxIntentos DEFAULT (5),
        FechaCreacion           DATETIME2(0) NOT NULL
            CONSTRAINT DF_CodigoRegistro_FechaCreacion
            DEFAULT (SYSDATETIME()),
        ValidoHasta             DATETIME2(0) NOT NULL,
        Utilizado               BIT NOT NULL
            CONSTRAINT DF_CodigoRegistro_Utilizado DEFAULT (0),
        FechaUso                DATETIME2(0) NULL,

        CONSTRAINT PK_CodigoRegistro PRIMARY KEY (ID),

        CONSTRAINT FK_CodigoRegistro_Solicitud
            FOREIGN KEY (SolicitudRegistroID)
            REFERENCES dbo.SolicitudRegistroUsuario(ID)
            ON DELETE CASCADE,

        CONSTRAINT CK_CodigoRegistro_Intentos
            CHECK
            (
                MaxIntentos BETWEEN 1 AND 10
                AND Intentos <= MaxIntentos
            ),

        CONSTRAINT CK_CodigoRegistro_Validez
            CHECK (ValidoHasta > FechaCreacion)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.CodigoRegistro')
      AND name = N'IX_CodigoRegistro_Solicitud_Estado'
)
BEGIN
    CREATE INDEX IX_CodigoRegistro_Solicitud_Estado
        ON dbo.CodigoRegistro
        (
            SolicitudRegistroID,
            Utilizado,
            FechaCreacion DESC
        )
        INCLUDE (ValidoHasta, Intentos, MaxIntentos);
END;
GO

/*=====================================================================
 3. PROCEDIMIENTO: sp_CrearSolicitudRegistro

 Inserta la solicitud y su codigo en una sola transaccion.
 El codigo recibido NO se almacena en texto plano.
=====================================================================*/

CREATE OR ALTER PROCEDURE dbo.sp_CrearSolicitudRegistro
    @Nombres                NVARCHAR(80),
    @Apellidos              NVARCHAR(80),
    @FechaNacimiento        DATE,
    @Telefono               VARCHAR(25) = NULL,
    @Correo                 NVARCHAR(150),
    @PaisID                 INT,
    @Usuario                NVARCHAR(80),
    @HashContrasena         VARCHAR(255),
    @Codigo                 VARCHAR(20),
    @MinutosValidez         INT = 10,
    @MaxIntentos            TINYINT = 5,
    @SolicitudRegistroID    BIGINT OUTPUT,
    @CodigoRegistroID       BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @SolicitudRegistroID = NULL;
    SET @CodigoRegistroID = NULL;

    IF LEN(@HashContrasena) < 20
        THROW 50040, 'Debe enviarse un hash de contrasena valido.', 1;

    IF LEN(@Codigo) < 6 OR LEN(@Codigo) > 12
        THROW 50041, 'El codigo de verificacion debe contener entre 6 y 12 caracteres.', 1;

    IF @MinutosValidez < 1 OR @MinutosValidez > 60
        THROW 50042, 'La vigencia del codigo debe estar entre 1 y 60 minutos.', 1;

    IF @MaxIntentos < 1 OR @MaxIntentos > 10
        THROW 50043, 'La cantidad maxima de intentos debe estar entre 1 y 10.', 1;

    IF @FechaNacimiento > CAST(SYSDATETIME() AS DATE)
        THROW 50044, 'La fecha de nacimiento no puede ser futura.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pais
        WHERE ID = @PaisID
    )
        THROW 50045, 'El pais indicado no existe.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE Correo = @Correo
    )
        THROW 50046, 'El correo ya pertenece a un usuario registrado.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CredencialUsuario
        WHERE Usuario = @Usuario
    )
        THROW 50047, 'El nombre de usuario ya se encuentra registrado.', 1;

    BEGIN TRANSACTION;

    BEGIN TRY
        /*
          Si existe una solicitud pendiente cuyo codigo ya no es util,
          se marca como VENCIDA antes de crear una nueva.
        */
        UPDATE s
        SET Estado = 'VENCIDA'
        FROM dbo.SolicitudRegistroUsuario s
        WHERE s.Estado = 'PENDIENTE'
          AND (s.Correo = @Correo OR s.Usuario = @Usuario)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.CodigoRegistro c
              WHERE c.SolicitudRegistroID = s.ID
                AND c.Utilizado = 0
                AND c.ValidoHasta > SYSDATETIME()
                AND c.Intentos < c.MaxIntentos
          );

        /*
          Bloquear una segunda solicitud activa para el mismo correo
          o nombre de usuario.
        */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.SolicitudRegistroUsuario WITH (UPDLOCK, HOLDLOCK)
            WHERE (Correo = @Correo OR Usuario = @Usuario)
              AND Estado IN ('PENDIENTE', 'VERIFICADA')
        )
            THROW 50048, 'Ya existe una solicitud de registro activa para ese correo o usuario.', 1;

        INSERT INTO dbo.SolicitudRegistroUsuario
        (
            Nombres,
            Apellidos,
            FechaNacimiento,
            Telefono,
            Correo,
            PaisID,
            Usuario,
            HashContrasena
        )
        VALUES
        (
            @Nombres,
            @Apellidos,
            @FechaNacimiento,
            @Telefono,
            @Correo,
            @PaisID,
            @Usuario,
            @HashContrasena
        );

        SET @SolicitudRegistroID = SCOPE_IDENTITY();

        DECLARE @SaltCodigo VARBINARY(16) = CRYPT_GEN_RANDOM(16);
        DECLARE @HashCodigo VARBINARY(32);

        SET @HashCodigo = HASHBYTES
        (
            'SHA2_256',
            @SaltCodigo + CONVERT(VARBINARY(100), @Codigo)
        );

        INSERT INTO dbo.CodigoRegistro
        (
            SolicitudRegistroID,
            HashCodigo,
            SaltCodigo,
            MaxIntentos,
            ValidoHasta
        )
        VALUES
        (
            @SolicitudRegistroID,
            @HashCodigo,
            @SaltCodigo,
            @MaxIntentos,
            DATEADD(MINUTE, @MinutosValidez, SYSDATETIME())
        );

        SET @CodigoRegistroID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT
            @SolicitudRegistroID AS SolicitudRegistroID,
            @CodigoRegistroID AS CodigoRegistroID,
            'PENDIENTE' AS Estado,
            DATEADD(MINUTE, @MinutosValidez, SYSDATETIME()) AS ValidoAproximadamenteHasta;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*=====================================================================
 4. PROCEDIMIENTO: sp_ValidarCodigoRegistro

 Sustituye la idea de "obtener el codigo".
 Recibe correo o nombre de usuario y el codigo introducido por la
 persona usuaria. Compara el hash internamente sin revelar el codigo
 ni su hash al backend.
=====================================================================*/

CREATE OR ALTER PROCEDURE dbo.sp_ValidarCodigoRegistro
    @Login                  NVARCHAR(150),
    @Codigo                 VARCHAR(20),
    @SolicitudRegistroID    BIGINT OUTPUT,
    @EsValido               BIT OUTPUT,
    @IntentosRestantes      SMALLINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @SolicitudRegistroID = NULL;
    SET @EsValido = 0;
    SET @IntentosRestantes = 0;

    DECLARE
        @EstadoSolicitud    VARCHAR(15),
        @CodigoRegistroID   BIGINT,
        @HashCodigo         VARBINARY(32),
        @SaltCodigo         VARBINARY(16),
        @Intentos           TINYINT,
        @MaxIntentos        TINYINT,
        @ValidoHasta        DATETIME2(0);

    BEGIN TRANSACTION;

    BEGIN TRY
        SELECT TOP (1)
            @SolicitudRegistroID = s.ID,
            @EstadoSolicitud = s.Estado
        FROM dbo.SolicitudRegistroUsuario s WITH (UPDLOCK, HOLDLOCK)
        WHERE (s.Usuario = @Login OR s.Correo = @Login)
          AND s.Estado IN ('PENDIENTE', 'VERIFICADA')
        ORDER BY s.FechaSolicitud DESC, s.ID DESC;

        IF @SolicitudRegistroID IS NULL
            THROW 50049, 'No existe una solicitud de registro activa para el usuario o correo indicado.', 1;

        /* Permitir reintentos idempotentes despues de una validacion exitosa. */
        IF @EstadoSolicitud = 'VERIFICADA'
        BEGIN
            SET @EsValido = 1;
            SET @IntentosRestantes = 0;

            COMMIT TRANSACTION;

            SELECT
                @SolicitudRegistroID AS SolicitudRegistroID,
                @EsValido AS EsValido,
                'VERIFICADA' AS Estado,
                @IntentosRestantes AS IntentosRestantes,
                N'La solicitud ya habia sido verificada.' AS Mensaje;
            RETURN;
        END;

        SELECT TOP (1)
            @CodigoRegistroID = c.ID,
            @HashCodigo = c.HashCodigo,
            @SaltCodigo = c.SaltCodigo,
            @Intentos = c.Intentos,
            @MaxIntentos = c.MaxIntentos,
            @ValidoHasta = c.ValidoHasta
        FROM dbo.CodigoRegistro c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.SolicitudRegistroID = @SolicitudRegistroID
          AND c.Utilizado = 0
        ORDER BY c.FechaCreacion DESC, c.ID DESC;

        IF @CodigoRegistroID IS NULL
            THROW 50050, 'La solicitud no posee un codigo de verificacion disponible.', 1;

        IF SYSDATETIME() > @ValidoHasta
        BEGIN
            UPDATE dbo.SolicitudRegistroUsuario
            SET Estado = 'VENCIDA'
            WHERE ID = @SolicitudRegistroID;

            SET @EsValido = 0;
            SET @IntentosRestantes = 0;

            COMMIT TRANSACTION;

            SELECT
                @SolicitudRegistroID AS SolicitudRegistroID,
                @EsValido AS EsValido,
                'VENCIDA' AS Estado,
                @IntentosRestantes AS IntentosRestantes,
                N'El codigo de verificacion ha vencido.' AS Mensaje;
            RETURN;
        END;

        IF @Intentos >= @MaxIntentos
        BEGIN
            UPDATE dbo.SolicitudRegistroUsuario
            SET Estado = 'CANCELADA'
            WHERE ID = @SolicitudRegistroID;

            SET @EsValido = 0;
            SET @IntentosRestantes = 0;

            COMMIT TRANSACTION;

            SELECT
                @SolicitudRegistroID AS SolicitudRegistroID,
                @EsValido AS EsValido,
                'CANCELADA' AS Estado,
                @IntentosRestantes AS IntentosRestantes,
                N'Se alcanzo el maximo de intentos permitidos.' AS Mensaje;
            RETURN;
        END;

        IF HASHBYTES
        (
            'SHA2_256',
            @SaltCodigo + CONVERT(VARBINARY(100), @Codigo)
        ) = @HashCodigo
        BEGIN
            UPDATE dbo.CodigoRegistro
            SET
                Utilizado = 1,
                FechaUso = SYSDATETIME()
            WHERE ID = @CodigoRegistroID;

            UPDATE dbo.SolicitudRegistroUsuario
            SET
                Estado = 'VERIFICADA',
                FechaVerificacion = SYSDATETIME()
            WHERE ID = @SolicitudRegistroID;

            SET @EsValido = 1;
            SET @IntentosRestantes = @MaxIntentos - @Intentos;

            COMMIT TRANSACTION;

            SELECT
                @SolicitudRegistroID AS SolicitudRegistroID,
                @EsValido AS EsValido,
                'VERIFICADA' AS Estado,
                @IntentosRestantes AS IntentosRestantes,
                N'Codigo validado correctamente.' AS Mensaje;
            RETURN;
        END;

        /* Codigo incorrecto: aumentar el contador. */
        SET @Intentos = @Intentos + 1;

        UPDATE dbo.CodigoRegistro
        SET Intentos = @Intentos
        WHERE ID = @CodigoRegistroID;

        SET @IntentosRestantes =
            CASE
                WHEN @MaxIntentos > @Intentos
                    THEN @MaxIntentos - @Intentos
                ELSE 0
            END;

        IF @Intentos >= @MaxIntentos
        BEGIN
            UPDATE dbo.SolicitudRegistroUsuario
            SET Estado = 'CANCELADA'
            WHERE ID = @SolicitudRegistroID;

            SET @EstadoSolicitud = 'CANCELADA';
        END
        ELSE
        BEGIN
            SET @EstadoSolicitud = 'PENDIENTE';
        END;

        COMMIT TRANSACTION;

        SELECT
            @SolicitudRegistroID AS SolicitudRegistroID,
            @EsValido AS EsValido,
            @EstadoSolicitud AS Estado,
            @IntentosRestantes AS IntentosRestantes,
            N'Codigo incorrecto.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*=====================================================================
 5. PROCEDIMIENTO: sp_ConfirmarRegistroUsuario

 Convierte una solicitud VERIFICADA en un usuario definitivo.
 Reutiliza dbo.sp_RegistrarUsuario para respetar el flujo ya existente
 de Usuario + CredencialUsuario.
=====================================================================*/

CREATE OR ALTER PROCEDURE dbo.sp_ConfirmarRegistroUsuario
    @SolicitudRegistroID    BIGINT,
    @UsuarioID              BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @UsuarioID = NULL;

    DECLARE
        @Nombres            NVARCHAR(80),
        @Apellidos          NVARCHAR(80),
        @FechaNacimiento    DATE,
        @Telefono           VARCHAR(25),
        @Correo             NVARCHAR(150),
        @PaisID             INT,
        @Usuario            NVARCHAR(80),
        @HashContrasena     VARCHAR(255),
        @Estado             VARCHAR(15),
        @UsuarioCreadoID    BIGINT;

    BEGIN TRANSACTION;

    BEGIN TRY
        SELECT
            @Nombres = Nombres,
            @Apellidos = Apellidos,
            @FechaNacimiento = FechaNacimiento,
            @Telefono = Telefono,
            @Correo = Correo,
            @PaisID = PaisID,
            @Usuario = Usuario,
            @HashContrasena = HashContrasena,
            @Estado = Estado,
            @UsuarioCreadoID = UsuarioCreadoID
        FROM dbo.SolicitudRegistroUsuario WITH (UPDLOCK, HOLDLOCK)
        WHERE ID = @SolicitudRegistroID;

        IF @Estado IS NULL
            THROW 50051, 'La solicitud de registro no existe.', 1;

        /* Idempotencia: si ya fue completada, devolver el mismo usuario. */
        IF @Estado = 'COMPLETADA' AND @UsuarioCreadoID IS NOT NULL
        BEGIN
            SET @UsuarioID = @UsuarioCreadoID;

            COMMIT TRANSACTION;

            SELECT
                @SolicitudRegistroID AS SolicitudRegistroID,
                @UsuarioID AS UsuarioID,
                'COMPLETADA' AS Estado,
                N'La solicitud ya habia sido completada.' AS Mensaje;
            RETURN;
        END;

        IF @Estado <> 'VERIFICADA'
            THROW 50052, 'La solicitud debe estar VERIFICADA antes de crear el usuario.', 1;

        IF @HashContrasena IS NULL OR LEN(@HashContrasena) < 20
            THROW 50053, 'La solicitud no contiene un hash de contrasena valido.', 1;

        /*
          Reutiliza el procedimiento oficial existente para mantener
          las reglas de Usuario y CredencialUsuario en un solo lugar.
        */
        EXEC dbo.sp_RegistrarUsuario
            @Nombres = @Nombres,
            @Apellidos = @Apellidos,
            @FechaNacimiento = @FechaNacimiento,
            @Telefono = @Telefono,
            @Correo = @Correo,
            @PaisID = @PaisID,
            @Usuario = @Usuario,
            @HashContrasena = @HashContrasena,
            @UsuarioID = @UsuarioID OUTPUT;

        UPDATE dbo.SolicitudRegistroUsuario
        SET
            Estado = 'COMPLETADA',
            FechaCompletado = SYSDATETIME(),
            UsuarioCreadoID = @UsuarioID,
            /* Minimizar la duplicacion de datos sensibles. */
            HashContrasena = NULL
        WHERE ID = @SolicitudRegistroID;

        COMMIT TRANSACTION;

        SELECT
            @SolicitudRegistroID AS SolicitudRegistroID,
            @UsuarioID AS UsuarioID,
            'COMPLETADA' AS Estado,
            N'Usuario creado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*=====================================================================
 6. PERMISOS PARA BACKEND

 El backend usa procedimientos y no necesita SELECT directo sobre las
 tablas SolicitudRegistroUsuario o CodigoRegistro.

 Si el usuario que ejecuta este script no puede conceder permisos,
 estas tres sentencias deben ser ejecutadas por el administrador.
=====================================================================*/

IF DATABASE_PRINCIPAL_ID(N'rol_backend') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.sp_CrearSolicitudRegistro
        TO rol_backend;

    GRANT EXECUTE ON OBJECT::dbo.sp_ValidarCodigoRegistro
        TO rol_backend;

    GRANT EXECUTE ON OBJECT::dbo.sp_ConfirmarRegistroUsuario
        TO rol_backend;
END;
GO

/*=====================================================================
 7. VERIFICACION DE OBJETOS CREADOS
=====================================================================*/

SELECT
    o.name AS Objeto,
    o.type_desc AS Tipo
FROM sys.objects o
WHERE o.name IN
(
    N'SolicitudRegistroUsuario',
    N'CodigoRegistro',
    N'sp_CrearSolicitudRegistro',
    N'sp_ValidarCodigoRegistro',
    N'sp_ConfirmarRegistroUsuario'
)
ORDER BY o.type_desc, o.name;
GO

PRINT '11_RegistroVerificacionUsuarios.sql finalizado.';
GO

/*=====================================================================
 EJEMPLO DE FLUJO PARA BACKEND (NO EJECUTAR COMO DATOS REALES)
 ---------------------------------------------------------------------

 1) Backend genera un codigo aleatorio seguro, por ejemplo: 483921.

 2) Backend llama dbo.sp_CrearSolicitudRegistro enviando los datos del
    formulario, el hash de contrasena y el codigo generado.

 3) Backend envia 483921 al correo. La BD NO conserva 483921 en texto.

 4) La persona escribe el codigo. Backend llama:
       dbo.sp_ValidarCodigoRegistro
    usando correo o usuario + codigo introducido.

 5) Si EsValido = 1, backend llama:
       dbo.sp_ConfirmarRegistroUsuario

 6) La informacion definitiva queda en:
       dbo.Usuario
       dbo.CredencialUsuario

 7) SolicitudRegistroUsuario queda como historial y su HashContrasena
    temporal se establece en NULL.
=====================================================================*/
