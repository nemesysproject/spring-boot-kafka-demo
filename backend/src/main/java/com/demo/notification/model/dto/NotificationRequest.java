package com.demo.notification.model.dto;

import com.demo.notification.model.enums.NotificationChannel;
import com.demo.notification.model.enums.NotificationType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.Map;

public class NotificationRequest {

    @NotBlank(message = "El título es obligatorio")
    private String title;

    @NotBlank(message = "El mensaje es obligatorio")
    private String message;

    @NotBlank(message = "El destinatario es obligatorio")
    private String recipient;

    @NotNull(message = "El canal es obligatorio (WEB, EMAIL, SMS, PUSH, SLACK)")
    private NotificationChannel channel;

    @NotNull(message = "El tipo es obligatorio (INFO, SUCCESS, WARNING, ERROR)")
    private NotificationType type;

    private Map<String, Object> metadata;

    public NotificationRequest() {
    }

    public NotificationRequest(String title, String message, String recipient,
                               NotificationChannel channel, NotificationType type,
                               Map<String, Object> metadata) {
        this.title = title;
        this.message = message;
        this.recipient = recipient;
        this.channel = channel;
        this.type = type;
        this.metadata = metadata;
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

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }
}

