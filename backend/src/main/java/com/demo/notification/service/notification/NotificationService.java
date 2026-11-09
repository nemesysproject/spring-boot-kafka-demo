package com.demo.notification.service.notification;

import com.demo.notification.config.MetricsConfig;
import com.demo.notification.model.dto.NotificationEvent;
import com.demo.notification.model.dto.NotificationRequest;
import com.demo.notification.model.dto.NotificationResponse;
import com.demo.notification.model.dto.NotificationStatsResponse;
import com.demo.notification.model.entity.Notification;
import com.demo.notification.model.enums.NotificationStatus;
import com.demo.notification.model.enums.NotificationType;
import com.demo.notification.repository.NotificationRepository;
import com.demo.notification.service.kafka.NotificationKafkaProducer;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    public static final String WEBSOCKET_DESTINATION = "/topic/notifications";

    private final NotificationRepository repository;
    private final NotificationKafkaProducer kafkaProducer;
    private final SimpMessagingTemplate messagingTemplate;
    private final SseEmitterService sseEmitterService;
    private final ObjectMapper objectMapper;
    private final Counter processedCounter;
    private final Counter failedCounter;
    private final Timer processingTimer;

    public NotificationService(
            NotificationRepository repository,
            NotificationKafkaProducer kafkaProducer,
            SimpMessagingTemplate messagingTemplate,
            SseEmitterService sseEmitterService,
            ObjectMapper objectMapper,
            @Qualifier("notificationsProcessedCounter") Counter processedCounter,
            @Qualifier("notificationsFailedCounter") Counter failedCounter,
            @Qualifier("notificationProcessingTimer") Timer processingTimer) {
        this.repository = repository;
        this.kafkaProducer = kafkaProducer;
        this.messagingTemplate = messagingTemplate;
        this.sseEmitterService = sseEmitterService;
        this.objectMapper = objectMapper;
        this.processedCounter = processedCounter;
        this.failedCounter = failedCounter;
        this.processingTimer = processingTimer;
    }

    /**
     * Paso 1 y 2 del flujo: Recibe la solicitud REST, crea el registro PENDING en base de datos
     * y publica el mensaje en Apache Kafka.
     */
    @Transactional
    public NotificationResponse enqueueNotification(NotificationRequest request) {
        String trackingId = UUID.randomUUID().toString();
        String metadataJson = serializeMetadata(request.getMetadata());

        Notification entity = new Notification(
                trackingId,
                request.getTitle(),
                request.getMessage(),
                request.getRecipient(),
                request.getChannel(),
                request.getType(),
                NotificationStatus.PENDING,
                metadataJson
        );
        repository.save(entity);

        NotificationEvent event = new NotificationEvent(
                trackingId,
                request.getTitle(),
                request.getMessage(),
                request.getRecipient(),
                request.getChannel(),
                request.getType(),
                NotificationStatus.PENDING,
                request.getMetadata(),
                LocalDateTime.now()
        );

        kafkaProducer.sendNotification(event);

        return new NotificationResponse(
                trackingId,
                NotificationStatus.PENDING,
                "Notificación encolada exitosamente para procesamiento asíncrono",
                LocalDateTime.now()
        );
    }

    /**
     * Paso 3 y 4 del flujo: Consumido desde Apache Kafka, se procesa, se persiste en PostgreSQL
     * y se emite en tiempo real vía WebSockets y SSE al frontend.
     */
    @Transactional
    public void processAndPersist(NotificationEvent event) {
        Timer.Sample sample = Timer.start();
        try {
            log.info("Procesando evento de Kafka con trackingId='{}'", event.getTrackingId());

            Notification entity = repository.findByTrackingId(event.getTrackingId())
                    .orElseGet(() -> new Notification(
                            event.getTrackingId(),
                            event.getTitle(),
                            event.getMessage(),
                            event.getRecipient(),
                            event.getChannel(),
                            event.getType(),
                            NotificationStatus.PROCESSED,
                            serializeMetadata(event.getMetadata())
                    ));

            entity.setStatus(NotificationStatus.PROCESSED);
            entity.setProcessedAt(LocalDateTime.now());
            Notification saved = repository.save(entity);

            // Actualizar status del evento para la emisión en tiempo real
            event.setStatus(NotificationStatus.PROCESSED);

            // Emisión en tiempo real vía WebSocket (STOMP)
            log.info("Emitiendo notificación a WebSocket '{}'", WEBSOCKET_DESTINATION);
            messagingTemplate.convertAndSend(WEBSOCKET_DESTINATION, event);

            // Emisión complementaria vía Server-Sent Events (SSE)
            sseEmitterService.broadcast(event);

            processedCounter.increment();
            sample.stop(processingTimer);

            log.info("Notificación con trackingId='{}' procesada, persistida y difundida en tiempo real (ID={})",
                    event.getTrackingId(), saved.getId());
        } catch (Exception e) {
            log.error("Fallo al procesar y persistir la notificación con trackingId='{}': {}",
                    event.getTrackingId(), e.getMessage(), e);
            failedCounter.increment();
            sample.stop(processingTimer);
            throw e;
        }
    }

    @Transactional(readOnly = true)
    public List<Notification> getRecentNotifications() {
        return repository.findTop100ByOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public Optional<Notification> getByTrackingId(String trackingId) {
        return repository.findByTrackingId(trackingId);
    }

    @Transactional(readOnly = true)
    public NotificationStatsResponse getStats() {
        long total = repository.count();

        Map<String, Long> byStatus = new HashMap<>();
        for (NotificationStatus status : NotificationStatus.values()) {
            byStatus.put(status.name(), repository.countByStatus(status));
        }

        Map<String, Long> byType = new HashMap<>();
        for (NotificationType type : NotificationType.values()) {
            byType.put(type.name(), repository.countByType(type));
        }

        return new NotificationStatsResponse(total, byStatus, byType);
    }

    private String serializeMetadata(Map<String, Object> metadata) {
        if (metadata == null || metadata.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(metadata);
        } catch (JsonProcessingException e) {
            log.warn("No se pudo serializar metadata a JSON: {}", e.getMessage());
            return metadata.toString();
        }
    }
}

