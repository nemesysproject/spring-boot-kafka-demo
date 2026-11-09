import { Injectable, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, Subject, interval } from 'rxjs';
import { Client, IMessage } from '@stomp/stompjs';
import {
  NotificationItem,
  NotificationRequest,
  NotificationResponse,
  NotificationStats,
  ConnectionStatus
} from '../models/notification.model';

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private readonly baseUrl = 'http://localhost:8080/api/v1';
  private readonly wsUrl = 'ws://localhost:8080/api/v1/ws-notifications';
  private readonly sseUrl = `${this.baseUrl}/notifications/stream`;

  // Signals para estado reactivo en Angular
  readonly notifications = signal<NotificationItem[]>([]);
  readonly connectionStatus = signal<ConnectionStatus>('DISCONNECTED');
  readonly connectionMode = signal<'WEBSOCKET' | 'SSE' | 'POLLING'>('WEBSOCKET');
  readonly stats = signal<NotificationStats>({
    total: 0,
    byStatus: { PENDING: 0, PROCESSED: 0, DELIVERED: 0, FAILED: 0 },
    byType: { INFO: 0, SUCCESS: 0, WARNING: 0, ERROR: 0 }
  });
  readonly lastReceivedAt = signal<Date | null>(null);

  private stompClient: Client | null = null;
  private sseSource: EventSource | null = null;
  private newNotification$ = new Subject<NotificationItem>();

  constructor(private http: HttpClient) {
    this.initRealtimeConnection();
    this.loadInitialData();

    // Actualización periódica de métricas de fondo cada 10 segundos
    interval(10000).subscribe(() => this.loadStats());
  }

  get onNewNotification(): Observable<NotificationItem> {
    return this.newNotification$.asObservable();
  }

  /**
   * Carga historial inicial y estadísticas del backend
   */
  loadInitialData(): void {
    this.http.get<NotificationItem[]>(`${this.baseUrl}/notifications`).subscribe({
      next: (items) => {
        this.notifications.set(items || []);
        this.loadStats();
      },
      error: (err) => console.warn('No se pudo cargar el historial inicial de notificaciones:', err)
    });
  }

  loadStats(): void {
    this.http.get<NotificationStats>(`${this.baseUrl}/notifications/stats`).subscribe({
      next: (s) => this.stats.set(s),
      error: (err) => console.warn('No se pudieron obtener estadísticas:', err)
    });
  }

  /**
   * Publicar una nueva notificación desde el simulador del frontend hacia el backend
   */
  sendNotification(payload: NotificationRequest): Observable<NotificationResponse> {
    return this.http.post<NotificationResponse>(`${this.baseUrl}/notifications`, payload);
  }

  /**
   * Inicializa la conexión en tiempo real:
   * Primero intenta WebSocket (STOMP). Si no está disponible, activa Server-Sent Events (SSE).
   */
  initRealtimeConnection(): void {
    this.connectionStatus.set('CONNECTING');

    try {
      this.stompClient = new Client({
        brokerURL: this.wsUrl,
        reconnectDelay: 5000,
        heartbeatIncoming: 4000,
        heartbeatOutgoing: 4000,
        debug: (str) => {
          // Descomentar para depuración detallada: console.debug(str);
        }
      });

      this.stompClient.onConnect = () => {
        this.connectionStatus.set('CONNECTED');
        this.connectionMode.set('WEBSOCKET');
        console.log('✅ Conectado a WebSocket STOMP');

        this.stompClient?.subscribe('/topic/notifications', (message: IMessage) => {
          try {
            const event: NotificationItem = JSON.parse(message.body);
            this.handleIncomingEvent(event);
          } catch (e) {
            console.error('Error al parsear mensaje WebSocket:', e);
          }
        });
      };

      this.stompClient.onStompError = (frame) => {
        console.warn('Fallo STOMP broker:', frame.headers['message']);
        this.fallbackToSse();
      };

      this.stompClient.onWebSocketClose = () => {
        if (this.connectionMode() === 'WEBSOCKET') {
          this.connectionStatus.set('CONNECTING');
        }
      };

      this.stompClient.activate();
    } catch (e) {
      console.warn('Error inicializando WebSocket, recurriendo a SSE:', e);
      this.fallbackToSse();
    }
  }

  /**
   * Conexión complementaria / fallback vía Server-Sent Events (SSE nativo)
   */
  private fallbackToSse(): void {
    if (this.sseSource) {
      return;
    }
    console.log('Iniciando fallback a Server-Sent Events (SSE)...');
    this.connectionMode.set('SSE');

    try {
      this.sseSource = new EventSource(this.sseUrl);

      this.sseSource.addEventListener('open', () => {
        this.connectionStatus.set('CONNECTED');
        console.log('✅ Conexión SSE establecida con el backend');
      });

      this.sseSource.addEventListener('NOTIFICATION', (event: MessageEvent) => {
        try {
          const item: NotificationItem = JSON.parse(event.data);
          this.handleIncomingEvent(item);
        } catch (e) {
          console.error('Error al procesar evento SSE:', e);
        }
      });

      this.sseSource.onerror = (e) => {
        console.warn('Error en conexión SSE:', e);
        this.connectionStatus.set('DISCONNECTED');
      };
    } catch (err) {
      console.error('No se pudo establecer conexión SSE:', err);
      this.connectionStatus.set('DISCONNECTED');
    }
  }

  private handleIncomingEvent(event: NotificationItem): void {
    this.lastReceivedAt.set(new Date());

    // Actualiza o inserta en la lista reactiva de notificaciones al principio
    const currentList = this.notifications();
    const existingIndex = currentList.findIndex(n => n.trackingId === event.trackingId);

    if (existingIndex !== -1) {
      const updated = [...currentList];
      updated[existingIndex] = { ...updated[existingIndex], ...event };
      this.notifications.set(updated);
    } else {
      this.notifications.set([event, ...currentList.slice(0, 99)]);
    }

    // Actualizar contadores
    this.loadStats();
    this.newNotification$.next(event);
  }

  disconnect(): void {
    if (this.stompClient) {
      this.stompClient.deactivate();
      this.stompClient = null;
    }
    if (this.sseSource) {
      this.sseSource.close();
      this.sseSource = null;
    }
    this.connectionStatus.set('DISCONNECTED');
  }
}
