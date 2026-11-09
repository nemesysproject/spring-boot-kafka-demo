package com.demo.notification.service.kafka;

import com.demo.notification.model.dto.NotificationEvent;
import io.micrometer.core.instrument.Counter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
public class NotificationKafkaProducer {

    private static final Logger log = LoggerFactory.getLogger(NotificationKafkaProducer.class);

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final String notificationTopic;
    private final Counter receivedCounter;
    private final Counter failedCounter;

    public NotificationKafkaProducer(
            KafkaTemplate<String, Object> kafkaTemplate,
            @Value("${app.kafka.topic.notifications:notification-events}") String notificationTopic,
            @Qualifier("notificationsReceivedCounter") Counter receivedCounter,
            @Qualifier("notificationsFailedCounter") Counter failedCounter) {
        this.kafkaTemplate = kafkaTemplate;
        this.notificationTopic = notificationTopic;
        this.receivedCounter = receivedCounter;
        this.failedCounter = failedCounter;
    }

    public CompletableFuture<SendResult<String, Object>> sendNotification(NotificationEvent event) {
        log.info("Publicando evento en Kafka topic '{}' con trackingId='{}'", notificationTopic, event.getTrackingId());
        receivedCounter.increment();

        CompletableFuture<SendResult<String, Object>> future = kafkaTemplate.send(notificationTopic, event.getTrackingId(), event);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                log.error("Error al publicar evento con trackingId='{}' en Kafka: {}", event.getTrackingId(), ex.getMessage(), ex);
                failedCounter.increment();
            } else {
                log.info("Evento publicado exitosamente. TrackingId='{}', Partition={}, Offset={}",
                        event.getTrackingId(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset());
            }
        });

        return future;
    }
}

