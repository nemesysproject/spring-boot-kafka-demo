package com.demo.notification.model.dto;

import com.demo.notification.model.enums.NotificationChannel;
import com.demo.notification.model.enums.NotificationStatus;
import com.demo.notification.model.enums.NotificationType;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Map;

public class NotificationEvent implements Serializable {

    private String trackingId;
    private String title;
    private String message;
    private String recipient;
    private NotificationChannel channel;
    private NotificationType type;
    private NotificationStatus status;
    private Map<String, Object> metadata;
    private LocalDateTime timestamp;

    public NotificationEvent() {
    }

    public NotificationEvent(String trackingId, String title, String message, String recipient,
                             NotificationChannel channel, NotificationType type,
                             NotificationStatus status, Map<String, Object> metadata,
                             LocalDateTime timestamp) {
        this.trackingId = trackingId;
        this.title = title;
        this.message = message;
        this.recipient = recipient;
        this.channel = channel;
        this.type = type;
        this.status = status;
        this.metadata = metadata;
        this.timestamp = timestamp;
    }

    public String getTrackingId() {
        return trackingId;
    }

    public void setTrackingId(String trackingId) {
        this.trackingId = trackingId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getRecipient() {
        return recipient;
    }

    public void setRecipient(String recipient) {
        this.recipient = recipient;
    }

    public NotificationChannel getChannel() {
        return channel;
    }

    public void setChannel(NotificationChannel channel) {
        this.channel = channel;
    }

    public NotificationType getType() {
        return type;
    }

    public void setType(NotificationType type) {
        this.type = type;
    }

    public NotificationStatus getStatus() {
        return status;
    }

    public void setStatus(NotificationStatus status) {
        this.status = status;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return "NotificationEvent{" +
                "trackingId='" + trackingId + '\'' +
                ", title='" + title + '\'' +
                ", recipient='" + recipient + '\'' +
                ", channel=" + channel +
                ", type=" + type +
                ", status=" + status +
                ", timestamp=" + timestamp +
                '}';
    }
}

