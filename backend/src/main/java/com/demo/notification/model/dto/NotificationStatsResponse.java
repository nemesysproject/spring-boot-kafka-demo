package com.demo.notification.model.dto;

import java.util.Map;

public class NotificationStatsResponse {

    private long total;
    private Map<String, Long> byStatus;
    private Map<String, Long> byType;

    public NotificationStatsResponse() {
    }

    public NotificationStatsResponse(long total, Map<String, Long> byStatus, Map<String, Long> byType) {
        this.total = total;
        this.byStatus = byStatus;
        this.byType = byType;
    }

    public long getTotal() {
        return total;
    }

    public void setTotal(long total) {
        this.total = total;
    }

    public Map<String, Long> getByStatus() {
        return byStatus;
    }

    public void setByStatus(Map<String, Long> byStatus) {
        this.byStatus = byStatus;
    }

    public Map<String, Long> getByType() {
        return byType;
    }

    public void setByType(Map<String, Long> byType) {
        this.byType = byType;
    }
}

