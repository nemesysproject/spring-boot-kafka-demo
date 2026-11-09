package com.demo.notification;

import com.demo.notification.controller.NotificationController;
import com.demo.notification.model.dto.NotificationRequest;
import com.demo.notification.model.dto.NotificationResponse;
import com.demo.notification.model.entity.Notification;
import com.demo.notification.model.enums.NotificationChannel;
import com.demo.notification.model.enums.NotificationStatus;
import com.demo.notification.model.enums.NotificationType;
import com.demo.notification.service.notification.NotificationService;
import com.demo.notification.service.notification.SseEmitterService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(NotificationController.class)
class NotificationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private NotificationService notificationService;

    @MockBean
    private SseEmitterService sseEmitterService;

    @Test
    void shouldCreateNotification() throws Exception {
        NotificationRequest request = new NotificationRequest(
                "Factura Generada",
                "Su factura del mes de mayo está disponible",
                "cliente@demo.com",
                NotificationChannel.EMAIL,
                NotificationType.INFO,
                null
        );

        NotificationResponse response = new NotificationResponse(
                "track-999",
                NotificationStatus.PENDING,
                "Encolado",
                LocalDateTime.now()
        );

        when(notificationService.enqueueNotification(any(NotificationRequest.class))).thenReturn(response);

        mockMvc.perform(post("/notifications")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.trackingId").value("track-999"))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void shouldReturnValidationErrorsOnInvalidRequest() throws Exception {
        NotificationRequest invalidRequest = new NotificationRequest();

        mockMvc.perform(post("/notifications")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.errors").exists());
    }

    @Test
    void shouldGetRecentNotifications() throws Exception {
        Notification notification = new Notification(
                "track-001",
                "Prueba",
                "Mensaje de prueba",
                "dev@demo.com",
                NotificationChannel.WEB,
                NotificationType.INFO,
                NotificationStatus.PROCESSED,
                null
        );

        when(notificationService.getRecentNotifications()).thenReturn(List.of(notification));

        mockMvc.perform(get("/notifications"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].trackingId").value("track-001"))
                .andExpect(jsonPath("$[0].title").value("Prueba"));
    }

    @Test
    void shouldGetNotificationByTrackingId() throws Exception {
        Notification notification = new Notification(
                "track-001",
                "Prueba",
                "Mensaje de prueba",
                "dev@demo.com",
                NotificationChannel.WEB,
                NotificationType.INFO,
                NotificationStatus.PROCESSED,
                null
        );

        when(notificationService.getByTrackingId("track-001")).thenReturn(Optional.of(notification));

        mockMvc.perform(get("/notifications/track-001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trackingId").value("track-001"));
    }
}

