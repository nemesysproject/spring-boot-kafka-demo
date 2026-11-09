package com.demo.notification.model.dto;

import com.demo.notification.model.enums.NotificationStatus;
import java.time.LocalDateTime;

public class NotificationResponse {

    private String trackingId;
    private NotificationStatus status;
    private String message;
    private LocalDateTime timestamp;

    public NotificationResponse() {
    }

    public NotificationResponse(String trackingId, NotificationStatus status, String message, LocalDateTime timestamp) {
        this.trackingId = trackingId;
        this.status = status;
        this.message = message;
        this.timestamp = timestamp;
    }

    public String getTrackingId() {
        return trackingId;
    }

    public void setTrackingId(String trackingId) {
        this.trackingId = trackingId;
    }

    public NotificationStatus getStatus() {
        return status;
    }

    public void setStatus(NotificationStatus status) {
        this.status = status;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }
}

