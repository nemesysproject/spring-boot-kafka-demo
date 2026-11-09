import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { NotificationService } from '../../core/services/notification.service';
import { NotificationItem } from '../../core/models/notification.model';

@Component({
  selector: 'app-log-viewer',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './log-viewer.component.html',
  styleUrl: './log-viewer.component.css'
})
export class LogViewerComponent {
  protected readonly notificationService = inject(NotificationService);

  searchQuery = signal('');
  selectedType = signal('ALL');
  selectedStatus = signal('ALL');
  selectedChannel = signal('ALL');

  selectedItem = signal<NotificationItem | null>(null);

  filteredNotifications = computed(() => {
    const list = this.notificationService.notifications();
    const query = this.searchQuery().toLowerCase().trim();
    const typeFilter = this.selectedType();
    const statusFilter = this.selectedStatus();
    const channelFilter = this.selectedChannel();

    return list.filter(item => {
      const matchesQuery = !query || 
        item.title.toLowerCase().includes(query) ||
        item.message.toLowerCase().includes(query) ||
        item.recipient.toLowerCase().includes(query) ||
        item.trackingId.toLowerCase().includes(query);

      const matchesType = typeFilter === 'ALL' || item.type === typeFilter;
      const matchesStatus = statusFilter === 'ALL' || item.status === statusFilter;
      const matchesChannel = channelFilter === 'ALL' || item.channel === channelFilter;

      return matchesQuery && matchesType && matchesStatus && matchesChannel;
    });
  });

  refresh(): void {
    this.notificationService.loadInitialData();
  }

  openDetail(item: NotificationItem): void {
    this.selectedItem.set(item);
  }

  closeDetail(): void {
    this.selectedItem.set(null);
  }
}
