package com.demo.notification.controller;

import com.demo.notification.model.dto.NotificationEvent;
import com.demo.notification.model.dto.NotificationRequest;
import com.demo.notification.model.dto.NotificationResponse;
import com.demo.notification.model.dto.NotificationStatsResponse;
import com.demo.notification.model.entity.Notification;
import com.demo.notification.service.notification.NotificationService;
import com.demo.notification.service.notification.SseEmitterService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;

@RestController
@RequestMapping("/notifications")
@Tag(name = "Notifications", description = "Endpoints para ingesta, consulta y streaming de notificaciones")
public class NotificationController {

    private final NotificationService notificationService;
    private final SseEmitterService sseEmitterService;

    public NotificationController(NotificationService notificationService, SseEmitterService sseEmitterService) {
        this.notificationService = notificationService;
        this.sseEmitterService = sseEmitterService;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Ingestar y publicar notificación", description = "Recibe una nueva notificación, la encola en Apache Kafka y responde con el trackingId.")
    public ResponseEntity<NotificationResponse> createNotification(@Valid @RequestBody NotificationRequest request) {
        NotificationResponse response = notificationService.enqueueNotification(request);
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
    }

    @GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Listar notificaciones recientes", description = "Retorna el historial de las últimas 100 notificaciones persistidas en PostgreSQL.")
    public ResponseEntity<List<Notification>> getRecentNotifications() {
        return ResponseEntity.ok(notificationService.getRecentNotifications());
    }

    @GetMapping(value = "/{trackingId}", produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Consultar notificación por trackingId", description = "Busca el estado y detalle de una notificación por su identificador único de rastreo.")
    public ResponseEntity<Notification> getNotificationByTrackingId(@PathVariable String trackingId) {
        return notificationService.getByTrackingId(trackingId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping(value = "/stats", produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Estadísticas del sistema", description = "Métricas agregadas de notificaciones por estado y categoría para el dashboard.")
    public ResponseEntity<NotificationStatsResponse> getStats() {
        return ResponseEntity.ok(notificationService.getStats());
    }

    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @Operation(summary = "Stream SSE de eventos en tiempo real", description = "Canal Server-Sent Events (SSE) para recibir notificaciones en tiempo real desde el navegador.")
    public SseEmitter streamNotifications() {
        return sseEmitterService.createEmitter();
    }
}

