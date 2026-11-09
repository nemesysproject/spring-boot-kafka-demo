-- Script de inicialización de la base de datos PostgreSQL para el Demo de Notificaciones

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    tracking_id VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    recipient VARCHAR(120) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    metadata TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITHOUT TIME ZONE
);

-- Índices para optimizar consultas de monitoreo
CREATE INDEX IF NOT EXISTS idx_notifications_tracking_id ON notifications (tracking_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications (status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications (type);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications (created_at DESC);

-- Datos iniciales de prueba (Seed opcional)
INSERT INTO notifications (tracking_id, title, message, recipient, channel, type, status, created_at, processed_at)
VALUES 
    ('seed-001', 'Bienvenida al Sistema', 'El sistema de notificaciones está operativo y listo para procesar eventos.', 'admin@demo.com', 'WEB', 'SUCCESS', 'PROCESSED', NOW(), NOW()),
    ('seed-002', 'Alerta de Capacidad', 'Uso de memoria del broker Kafka al 42% (Nivel saludable).', 'devops@demo.com', 'SLACK', 'INFO', 'PROCESSED', NOW(), NOW())
ON CONFLICT (tracking_id) DO NOTHING;

