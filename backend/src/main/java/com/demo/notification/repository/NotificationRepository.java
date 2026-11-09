package com.demo.notification.repository;

import com.demo.notification.model.entity.Notification;
import com.demo.notification.model.enums.NotificationStatus;
import com.demo.notification.model.enums.NotificationType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    Optional<Notification> findByTrackingId(String trackingId);

    List<Notification> findTop100ByOrderByCreatedAtDesc();

    List<Notification> findByStatusOrderByCreatedAtDesc(NotificationStatus status);

    long countByStatus(NotificationStatus status);

    long countByType(NotificationType type);
}

