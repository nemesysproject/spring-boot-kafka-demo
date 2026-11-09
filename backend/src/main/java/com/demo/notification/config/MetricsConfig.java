package com.demo.notification.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfig {

    public static final String METRIC_NOTIFICATIONS_RECEIVED = "notifications.received.total";
    public static final String METRIC_NOTIFICATIONS_PROCESSED = "notifications.processed.total";
    public static final String METRIC_NOTIFICATIONS_FAILED = "notifications.failed.total";
    public static final String METRIC_NOTIFICATIONS_PROCESSING_TIME = "notifications.processing.time";

    @Bean
    public Counter notificationsReceivedCounter(MeterRegistry meterRegistry) {
        return Counter.builder(METRIC_NOTIFICATIONS_RECEIVED)
                .description("Total de eventos de notificación recibidos en la API")
                .register(meterRegistry);
    }

    @Bean
    public Counter notificationsProcessedCounter(MeterRegistry meterRegistry) {
        return Counter.builder(METRIC_NOTIFICATIONS_PROCESSED)
                .description("Total de eventos de notificación consumidos y persistidos con éxito")
                .register(meterRegistry);
    }

    @Bean
    public Counter notificationsFailedCounter(MeterRegistry meterRegistry) {
        return Counter.builder(METRIC_NOTIFICATIONS_FAILED)
                .description("Total de eventos de notificación con fallo en producción o consumo")
                .register(meterRegistry);
    }

    @Bean
    public Timer notificationProcessingTimer(MeterRegistry meterRegistry) {
        return Timer.builder(METRIC_NOTIFICATIONS_PROCESSING_TIME)
                .description("Tiempo empleado en procesar y persistir la notificación")
                .publishPercentiles(0.5, 0.95, 0.99)
                .register(meterRegistry);
    }
}

