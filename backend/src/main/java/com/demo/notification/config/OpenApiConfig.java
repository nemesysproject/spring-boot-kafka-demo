package com.demo.notification.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Notification & Real-time Messaging API")
                        .version("1.0.0")
                        .description("API REST para ingesta, procesamiento con Apache Kafka, persistencia en PostgreSQL y difusión en tiempo real vía WebSockets/SSE.")
                        .contact(new Contact().name("Demo Team").email("demo@example.com"))
                        .license(new License().name("Apache 2.0")));
    }
}

