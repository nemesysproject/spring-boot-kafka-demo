package com.demo.notification.service.notification;

import com.demo.notification.model.dto.NotificationEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class SseEmitterService {

    private static final Logger log = LoggerFactory.getLogger(SseEmitterService.class);

    // Timeout de 30 minutos para conexiones SSE en desarrollo
    private static final long SSE_TIMEOUT = 30L * 60L * 1000L;

    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    public SseEmitter createEmitter() {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT);

        emitters.add(emitter);

        emitter.onCompletion(() -> {
            log.debug("Conexión SSE completada");
            emitters.remove(emitter);
        });

        emitter.onTimeout(() -> {
            log.debug("Conexión SSE expirada por timeout");
            emitter.complete();
            emitters.remove(emitter);
        });

        emitter.onError(e -> {
            log.debug("Error en conexión SSE: {}", e.getMessage());
            emitters.remove(emitter);
        });

        try {
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data("Conexión SSE establecida con el servicio de notificaciones"));
        } catch (IOException e) {
            emitters.remove(emitter);
        }

        return emitter;
    }

    public void broadcast(NotificationEvent event) {
        log.info("Difundiendo evento SSE a {} clientes conectados para trackingId='{}'", emitters.size(), event.getTrackingId());
        List<SseEmitter> deadEmitters = new CopyOnWriteArrayList<>();

        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event()
                        .name("NOTIFICATION")
                        .data(event));
            } catch (Exception e) {
                deadEmitters.add(emitter);
            }
        }

        emitters.removeAll(deadEmitters);
    }
}

