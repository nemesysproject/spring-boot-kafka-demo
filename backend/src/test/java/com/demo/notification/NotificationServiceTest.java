package com.demo.notification;

import com.demo.notification.model.dto.NotificationEvent;
import com.demo.notification.model.dto.NotificationRequest;
import com.demo.notification.model.dto.NotificationResponse;
import com.demo.notification.model.entity.Notification;
import com.demo.notification.model.enums.NotificationChannel;
import com.demo.notification.model.enums.NotificationStatus;
import com.demo.notification.model.enums.NotificationType;
import com.demo.notification.repository.NotificationRepository;
import com.demo.notification.service.kafka.NotificationKafkaProducer;
import com.demo.notification.service.notification.NotificationService;
import com.demo.notification.service.notification.SseEmitterService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository repository;

    @Mock
    private NotificationKafkaProducer kafkaProducer;

    @Mock
    private SimpMessagingTemplate messagingTemplate;

    @Mock
    private SseEmitterService sseEmitterService;

    private NotificationService notificationService;

    @BeforeEach
    void setUp() {
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        var processedCounter = registry.counter("test.processed");
        var failedCounter = registry.counter("test.failed");
        var timer = registry.timer("test.timer");

        notificationService = new NotificationService(
                repository,
                kafkaProducer,
                messagingTemplate,
                sseEmitterService,
                new ObjectMapper(),
                processedCounter,
                failedCounter,
                timer
        );
    }

    @Test
    void shouldEnqueueNotificationAndPublishToKafka() {
        NotificationRequest request = new NotificationRequest(
                "Alerta de Seguridad",
                "Inicio de sesión sospechoso detectado",
                "admin@example.com",
                NotificationChannel.WEB,
                NotificationType.WARNING,
                Map.of("ip", "192.168.1.100")
        );

        when(repository.save(any(Notification.class))).thenAnswer(invocation -> invocation.getArgument(0));

        NotificationResponse response = notificationService.enqueueNotification(request);

        assertNotNull(response.getTrackingId());
        assertEquals(NotificationStatus.PENDING, response.getStatus());

        verify(repository).save(any(Notification.class));
        verify(kafkaProducer).sendNotification(any(NotificationEvent.class));
    }

    @Test
    void shouldProcessAndPersistNotificationAndBroadcastToWebSocket() {
        String trackingId = "test-tracking-123";
        NotificationEvent event = new NotificationEvent(
                trackingId,
                "Transferencia Exitosa",
                "Tu transferencia de $500 ha sido completada",
                "user@example.com",
                NotificationChannel.WEB,
                NotificationType.SUCCESS,
                NotificationStatus.PENDING,
                Map.of("amount", 500),
                LocalDateTime.now()
        );

        Notification existingEntity = new Notification(
                trackingId,
                event.getTitle(),
                event.getMessage(),
                event.getRecipient(),
                event.getChannel(),
                event.getType(),
                NotificationStatus.PENDING,
                null
        );

        when(repository.findByTrackingId(trackingId)).thenReturn(Optional.of(existingEntity));
        when(repository.save(any(Notification.class))).thenAnswer(invocation -> invocation.getArgument(0));

        notificationService.processAndPersist(event);

        assertEquals(NotificationStatus.PROCESSED, existingEntity.getStatus());
        assertNotNull(existingEntity.getProcessedAt());

        verify(repository).save(existingEntity);
        verify(messagingTemplate).convertAndSend(eq(NotificationService.WEBSOCKET_DESTINATION), any(NotificationEvent.class));
        verify(sseEmitterService).broadcast(any(NotificationEvent.class));
    }
}

