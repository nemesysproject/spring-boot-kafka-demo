import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DashboardComponent } from './features/dashboard/dashboard.component';
import { LogViewerComponent } from './features/log-viewer/log-viewer.component';
import { NotificationService } from './core/services/notification.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, DashboardComponent, LogViewerComponent],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {
  protected readonly notificationService = inject(NotificationService);
  activeTab = signal<'DASHBOARD' | 'LOGS'>('DASHBOARD');

  setActiveTab(tab: 'DASHBOARD' | 'LOGS'): void {
    this.activeTab.set(tab);
  }
}
