import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/ExecutiveDashboardController.getDashboardData';
import { refreshApex } from '@salesforce/apex';

export default class ExecutiveCommandCenter extends NavigationMixin(LightningElement) {
    @track dashboardData;
    @track error;
    @track isLoading = true;
    @track lastRefreshTime;

    wiredResult;

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.dashboardData = result.data;
            this.lastRefreshTime = new Date().toLocaleTimeString();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || 'An error occurred loading dashboard data.';
            this.dashboardData = undefined;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
            this.lastRefreshTime = new Date().toLocaleTimeString();
        });
    }

    // ==================== COMPUTED PROPERTIES ====================

    get hasData() {
        return this.dashboardData !== undefined && this.dashboardData !== null;
    }

    get notLoading() {
        return !this.isLoading;
    }

    // Hero Metrics
    get totalActiveReferrals() {
        return this.dashboardData?.totalActiveReferrals || 0;
    }

    get admissionsThisMonth() {
        return this.dashboardData?.admissionsThisMonth || 0;
    }

    get conversionRate() {
        return this.dashboardData?.conversionRate || 0;
    }

    get conversionRateDisplay() {
        return `${this.conversionRate}%`;
    }

    get visitsCompletedToday() {
        return this.dashboardData?.visitsCompletedToday || 0;
    }

    get visitsScheduledToday() {
        return this.dashboardData?.visitsScheduledToday || 0;
    }

    get visitCompletionDisplay() {
        return `${this.visitsCompletedToday} / ${this.visitsScheduledToday}`;
    }

    // Alerts
    get totalAlerts() {
        return this.dashboardData?.totalAlerts || 0;
    }

    get expiringAuthsCount() {
        return this.dashboardData?.expiringAuthsCount || 0;
    }

    get overdueVisitsCount() {
        return this.dashboardData?.overdueVisitsCount || 0;
    }

    get criticalAgingCount() {
        return this.dashboardData?.criticalAgingCount || 0;
    }

    get irpFollowUpsDue() {
        return this.dashboardData?.irpFollowUpsDue || 0;
    }

    get hasAlerts() {
        return this.totalAlerts > 0;
    }

    get alertsClass() {
        return this.totalAlerts > 0 ? 'alert-badge critical' : 'alert-badge healthy';
    }

    // Team Capacity
    get activeSpecialistsCount() {
        return this.dashboardData?.activeSpecialistsCount || 0;
    }

    get totalActiveCases() {
        return this.dashboardData?.totalActiveCases || 0;
    }

    get avgCaseloadPerSpecialist() {
        return this.dashboardData?.avgCaseloadPerSpecialist || 0;
    }

    get specialistsAtCapacity() {
        return this.dashboardData?.specialistsAtCapacity || 0;
    }

    get capacityHealthClass() {
        const atCapacity = this.specialistsAtCapacity;
        const total = this.activeSpecialistsCount;
        if (total === 0) return 'capacity-indicator healthy';
        const ratio = atCapacity / total;
        if (ratio > 0.5) return 'capacity-indicator critical';
        if (ratio > 0.25) return 'capacity-indicator warning';
        return 'capacity-indicator healthy';
    }

    // Pipeline Stages
    get pipelineStages() {
        const stageOrder = [
            'New Referral', 'Eligibility Check', 'Authorization Pending',
            'IRP Scheduling', 'IRP Completed', 'Admission'
        ];
        const stages = this.dashboardData?.pipelineByStage || {};
        const total = this.totalActiveReferrals || 1;

        return stageOrder.map((stage, index) => {
            const count = stages[stage] || 0;
            const percentage = Math.round((count / total) * 100);
            return {
                key: `stage-${index}`,
                name: stage,
                count: count,
                percentage: percentage,
                barStyle: `width: ${Math.max(percentage, 5)}%`,
                stageClass: this.getStageClass(index)
            };
        });
    }

    getStageClass(index) {
        const classes = ['stage-1', 'stage-2', 'stage-3', 'stage-4', 'stage-5', 'stage-6'];
        return `pipeline-bar ${classes[index] || 'stage-1'}`;
    }

    // Top Performers
    get topPerformers() {
        const performers = this.dashboardData?.topPerformers || [];
        return performers.map((p, index) => ({
            ...p,
            key: `performer-${index}`,
            rank: index + 1,
            rankClass: this.getRankClass(index),
            isTop: index === 0
        }));
    }

    getRankClass(index) {
        if (index === 0) return 'rank rank-gold';
        if (index === 1) return 'rank rank-silver';
        if (index === 2) return 'rank rank-bronze';
        return 'rank';
    }

    get hasTopPerformers() {
        return this.topPerformers.length > 0;
    }

    // Referral Sources
    get referralsBySource() {
        const sources = this.dashboardData?.referralsBySource || [];
        const maxCount = sources.length > 0 ? sources[0].count : 1;

        return sources.map((s, index) => ({
            ...s,
            key: `source-${index}`,
            barStyle: `width: ${Math.round((s.count / maxCount) * 100)}%`
        }));
    }

    get hasSourceData() {
        return this.referralsBySource.length > 0;
    }

    // Daily Trend (Sparkline data)
    get dailyAdmissions() {
        return this.dashboardData?.dailyAdmissions || [];
    }

    get hasTrendData() {
        return this.dailyAdmissions.length > 0;
    }

    get trendBars() {
        const data = this.dailyAdmissions;
        const maxValue = Math.max(...data.map(d => d.value), 1);

        return data.map((d, index) => ({
            key: `trend-${index}`,
            day: d.dayLabel,
            value: d.value,
            barHeight: `${Math.max((d.value / maxValue) * 100, 5)}%`,
            isToday: index === data.length - 1
        }));
    }

    // Navigation
    navigateToIntakeDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Intake_Dashboard'
            }
        });
    }

    navigateToPeerstarHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Peerstar_Home'
            }
        });
    }

    navigateToManagerDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Manager_Dashboard'
            }
        });
    }
}