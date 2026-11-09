package com.demo.notification.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    @Value("${app.kafka.topic.notifications:notification-events}")
    private String notificationTopic;

    @Value("${app.kafka.topic.partitions:3}")
    private int partitions;

    @Value("${app.kafka.topic.replication-factor:1}")
    private short replicationFactor;

    @Bean
    public NewTopic notificationEventsTopic() {
        return TopicBuilder.name(notificationTopic)
                .partitions(partitions)
                .replicas(replicationFactor)
                .build();
    }
}

