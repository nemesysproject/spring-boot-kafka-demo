package com.demo.notification.service.kafka;

import com.demo.notification.model.dto.NotificationEvent;
import com.demo.notification.service.notification.NotificationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;

@Service
public class NotificationKafkaConsumer {

    private static final Logger log = LoggerFactory.getLogger(NotificationKafkaConsumer.class);

    private final NotificationService notificationService;

    public NotificationKafkaConsumer(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @KafkaListener(
            topics = "${app.kafka.topic.notifications:notification-events}",
            groupId = "${spring.kafka.consumer.group-id:notification-monitoring-group}"
    )
    public void consumeNotificationEvent(
            @Payload NotificationEvent event,
            @Header(name = KafkaHeaders.RECEIVED_KEY, required = false) String key,
            @Header(name = KafkaHeaders.RECEIVED_PARTITION, required = false) Integer partition,
            @Header(name = KafkaHeaders.OFFSET, required = false) Long offset) {

        log.info("Mensaje Kafka consumido. Key='{}', Partition={}, Offset={}, TrackingId='{}'",
                key, partition, offset, event != null ? event.getTrackingId() : "null");

        if (event != null) {
            notificationService.processAndPersist(event);
        } else {
            log.warn("Se recibió un evento nulo desde Kafka");
        }
    }
}

