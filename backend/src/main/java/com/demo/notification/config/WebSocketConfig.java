package com.demo.notification.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        // Habilita un broker simple en memoria para enviar mensajes a los clientes en los topics suscritos
        registry.enableSimpleBroker("/topic");
        // Prefijo para mensajes dirigidos a métodos anotados con @MessageMapping en el backend
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Seguridad: Restringe los orígenes permitidos para mitigar CSWSH (Cross-Site WebSocket Hijacking)
        String[] allowedOrigins = {
            "http://localhost", "http://localhost:*",
            "http://127.0.0.1", "http://127.0.0.1:*",
            "https://localhost", "https://localhost:*"
        };

        // Endpoint STOMP con soporte de SockJS (ideal para clientes web y Angular)
        registry.addEndpoint("/ws-notifications")
                .setAllowedOriginPatterns(allowedOrigins)
                .withSockJS();

        // Endpoint WebSocket nativo sin SockJS
        registry.addEndpoint("/ws-notifications")
                .setAllowedOriginPatterns(allowedOrigins);
    }
}

