export type NotificationChannel = 'WEB' | 'EMAIL' | 'SMS' | 'PUSH' | 'SLACK';
export type NotificationType = 'INFO' | 'SUCCESS' | 'WARNING' | 'ERROR';
export type NotificationStatus = 'PENDING' | 'PROCESSED' | 'DELIVERED' | 'FAILED';

export interface NotificationItem {
  id?: number;
  trackingId: string;
  title: string;
  message: string;
  recipient: string;
  channel: NotificationChannel;
  type: NotificationType;
  status: NotificationStatus;
  metadata?: string | Record<string, unknown>;
  createdAt?: string;
  processedAt?: string;
  timestamp?: string;
}

export interface NotificationRequest {
  title: string;
  message: string;
  recipient: string;
  channel: NotificationChannel;
  type: NotificationType;
  metadata?: Record<string, unknown>;
}

export interface NotificationResponse {
  trackingId: string;
  status: NotificationStatus;
  message: string;
  timestamp: string;
}

export interface NotificationStats {
  total: number;
  byStatus: Record<string, number>;
  byType: Record<string, number>;
}

export type ConnectionStatus = 'CONNECTED' | 'CONNECTING' | 'DISCONNECTED';
