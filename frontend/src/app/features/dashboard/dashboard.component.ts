import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { NotificationService } from '../../core/services/notification.service';
import {
  NotificationChannel,
  NotificationType,
  NotificationRequest
} from '../../core/models/notification.model';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.css'
})
export class DashboardComponent {
  protected readonly notificationService = inject(NotificationService);

  // Formulario para emitir eventos de prueba a Kafka
  simTitle = 'Alerta de Transacción';
  simMessage = 'Pago aprobado por $1,250.00 MXN en terminal POS';
  simRecipient = 'usuario.demo@empresa.com';
  simChannel: NotificationChannel = 'WEB';
  simType: NotificationType = 'SUCCESS';

  isPublishing = signal(false);
  publishSuccessMessage = signal<string | null>(null);
  publishErrorMessage = signal<string | null>(null);

  quickTemplates = [
    {
      label: '💳 Transacción Exitosa',
      title: 'Transacción Aprobada',
      message: 'Se autorizó el cargo de $450.00 en tarjeta terminación 9921',
      recipient: 'cliente@demo.com',
      channel: 'PUSH' as NotificationChannel,
      type: 'SUCCESS' as NotificationType
    },
    {
      label: '⚠️ Pico de CPU',
      title: 'Alerta de Infraestructura',
      message: 'Broker Kafka alcanzó 88% de utilización de memoria',
      recipient: 'devops-team@demo.com',
      channel: 'SLACK' as NotificationChannel,
      type: 'WARNING' as NotificationType
    },
    {
      label: '❌ Error de Autenticación',
      title: 'Fallo de Seguridad',
      message: 'Intento fallido de login desde IP 192.168.1.150 (3 intentos)',
      recipient: 'secops@demo.com',
      channel: 'EMAIL' as NotificationChannel,
      type: 'ERROR' as NotificationType
    },
    {
      label: 'ℹ️ Información del Sistema',
      title: 'Despliegue Completado',
      message: 'La versión v1.4.0 del backend se ha inicializado con éxito',
      recipient: 'developers@demo.com',
      channel: 'WEB' as NotificationChannel,
      type: 'INFO' as NotificationType
    }
  ];

  applyTemplate(template: typeof this.quickTemplates[0]): void {
    this.simTitle = template.title;
    this.simMessage = template.message;
    this.simRecipient = template.recipient;
    this.simChannel = template.channel;
    this.simType = template.type;
  }

  sendEvent(): void {
    if (!this.simTitle || !this.simMessage || !this.simRecipient) {
      this.publishErrorMessage.set('Todos los campos son obligatorios');
      return;
    }

    this.isPublishing.set(true);
    this.publishSuccessMessage.set(null);
    this.publishErrorMessage.set(null);

    const payload: NotificationRequest = {
      title: this.simTitle,
      message: this.simMessage,
      recipient: this.simRecipient,
      channel: this.simChannel,
      type: this.simType,
      metadata: {
        sentFrom: 'Angular Monitoring Portal',
        timestamp: new Date().toISOString()
      }
    };

    this.notificationService.sendNotification(payload).subscribe({
      next: (res) => {
        this.isPublishing.set(false);
        this.publishSuccessMessage.set(`Evento encolado en Kafka con Tracking ID: ${res.trackingId}`);
        setTimeout(() => this.publishSuccessMessage.set(null), 5000);
      },
      error: (err) => {
        this.isPublishing.set(false);
        this.publishErrorMessage.set(`Error al publicar: ${err.message || 'Fallo de conexión'}`);
        setTimeout(() => this.publishErrorMessage.set(null), 5000);
      }
    });
  }
}
