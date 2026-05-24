-- ============================================
-- ESQUEMA DE BASE DE DATOS DISTRIBUIDA
-- Historia Clínica Electrónica con Citus
-- ============================================

-- ============================================
-- 1. TABLA DISTRIBUIDA: USUARIO (PACIENTE)
-- Distribuida por documento_id (sharding key)
-- ============================================
CREATE TABLE IF NOT EXISTS usuario (
    documento_id BIGINT PRIMARY KEY,
    pais_nacionalidad VARCHAR(100),
    nombre_completo VARCHAR(255) NOT NULL,
    fecha_nacimiento DATE,
    edad INTEGER,
    sexo VARCHAR(10),
    genero VARCHAR(20),
    ocupacion VARCHAR(100),
    voluntad_anticipada BOOLEAN DEFAULT false,
    categoria_discapacidad VARCHAR(50),
    zona_residencia VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. TABLA DISTRIBUIDA: ATENCION
-- Co-localizada con usuario (misma clave de distribución)
-- ============================================
CREATE TABLE IF NOT EXISTS atencion (
    atencion_id SERIAL,
    documento_id BIGINT NOT NULL,
    entidad_salud VARCHAR(255),
    fecha_ingreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_salida TIMESTAMP,
    modalidad_entrega VARCHAR(50),
    causa_atencion TEXT,
    clasificacion_triage VARCHAR(10),
    PRIMARY KEY (atencion_id, documento_id)
);

-- ============================================
-- 3. TABLA DISTRIBUIDA: DIAGNOSTICO
-- ============================================
CREATE TABLE IF NOT EXISTS diagnostico (
    diagnostico_id SERIAL,
    documento_id BIGINT NOT NULL,
    atencion_id INTEGER NOT NULL,
    diagnostico_ingreso TEXT,
    diagnostico_egreso TEXT,
    codigo_cie10 VARCHAR(10),
    fecha_diagnostico TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (diagnostico_id, documento_id)
);

-- ============================================
-- 4. TABLA DISTRIBUIDA: TECNOLOGIA_SALUD (Medicamentos)
-- ============================================
CREATE TABLE IF NOT EXISTS tecnologia_salud (
    tecnologia_id SERIAL,
    documento_id BIGINT NOT NULL,
    atencion_id INTEGER NOT NULL,
    descripcion_medicamento VARCHAR(255),
    dosis VARCHAR(100),
    frecuencia VARCHAR(100),
    duracion_dias INTEGER,
    id_personal_salud UUID,
    PRIMARY KEY (tecnologia_id, documento_id)
);

-- ============================================
-- 5. TABLA DISTRIBUIDA: EGRESO
-- ============================================
CREATE TABLE IF NOT EXISTS egreso (
    egreso_id SERIAL,
    documento_id BIGINT NOT NULL,
    atencion_id INTEGER NOT NULL,
    fecha_egreso TIMESTAMP,
    condicion_egreso VARCHAR(100),
    incapacidad_dias INTEGER DEFAULT 0,
    recomendaciones TEXT,
    PRIMARY KEY (egreso_id, documento_id)
);

-- ============================================
-- 6. TABLA REPLICADA (copia completa en cada worker)
-- ============================================
CREATE TABLE IF NOT EXISTS profesional_salud (
    id_personal_salud UUID PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    especialidad VARCHAR(100),
    registro_medico VARCHAR(50),
    activo BOOLEAN DEFAULT true
);

-- ============================================
-- ÍNDICES PARA RENDIMIENTO
-- ============================================
CREATE INDEX idx_usuario_nombre ON usuario(nombre_completo);
CREATE INDEX idx_atencion_fecha ON atencion(fecha_ingreso);
CREATE INDEX idx_diagnostico_codigo ON diagnostico(codigo_cie10);

-- ============================================
-- DATOS DE EJEMPLO (Profesionales de salud)
-- ============================================
INSERT INTO profesional_salud (id_personal_salud, nombre, especialidad, registro_medico) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Dra. María Rodríguez', 'Medicina Interna', 'RM12345'),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Dr. Carlos Sánchez', 'Cardiología', 'RM12346'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Dra. Ana Martínez', 'Pediatría', 'RM12347');

-- ============================================
-- NOTA: Estos comandos se ejecutan en init-citus.sh
-- No los ejecutes directamente aquí
-- ============================================
-- SELECT create_distributed_table('usuario', 'documento_id');
-- SELECT create_distributed_table('atencion', 'documento_id');
-- SELECT create_distributed_table('diagnostico', 'documento_id');
-- SELECT create_distributed_table('tecnologia_salud', 'documento_id');
-- SELECT create_distributed_table('egreso', 'documento_id');
-- SELECT create_reference_table('profesional_salud');
