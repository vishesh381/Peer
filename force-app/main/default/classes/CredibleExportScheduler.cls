/**
 * Schedulable class to sync data from Credible to Salesforce
 * Runs every 30 minutes to pull changes from Credible
 *
 * To schedule:
 * System.schedule('Credible Sync Every 30 Min', '0 0 * * * ?', new CredibleExportScheduler());
 * System.schedule('Credible Sync Every 30 Min - Half Hour', '0 30 * * * ?', new CredibleExportScheduler());
 */
global class CredibleExportScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        System.debug('CredibleExportScheduler: Running scheduled job to sync from Credible.');

        // Enqueue the data sync queueables
        System.enqueueJob(new CredibleClientExportQueueable());
        System.enqueueJob(new CredibleEmployeeExportQueueable());
        System.enqueueJob(new CredibleClientVisitExportQueueable());
    }

    /**
     * Helper method to schedule this job for every 30 minutes
     */
    public static void scheduleJob() {
        // Schedule for top of every hour
        String jobName1 = 'Credible Sync - On the Hour';
        String cronExp1 = '0 0 * * * ?';

        // Schedule for half past every hour
        String jobName2 = 'Credible Sync - Half Past';
        String cronExp2 = '0 30 * * * ?';

        // Check if jobs already exist before scheduling
        List<CronTrigger> existingJobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name IN (:jobName1, :jobName2)
        ];

        Set<String> existingJobNames = new Set<String>();
        for (CronTrigger ct : existingJobs) {
            existingJobNames.add(ct.CronJobDetail.Name);
        }

        if (!existingJobNames.contains(jobName1)) {
            System.schedule(jobName1, cronExp1, new CredibleExportScheduler());
        }

        if (!existingJobNames.contains(jobName2)) {
            System.schedule(jobName2, cronExp2, new CredibleExportScheduler());
        }
    }

    /**
     * Helper method to unschedule the jobs
     */
    public static void unscheduleJobs() {
        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Credible Sync%'
        ];

        for (CronTrigger ct : jobs) {
            System.abortJob(ct.Id);
        }
    }
}
