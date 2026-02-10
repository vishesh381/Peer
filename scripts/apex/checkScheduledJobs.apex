// Check scheduled Credible sync jobs
List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Credible Sync%'
];

System.debug('Found ' + jobs.size() + ' scheduled Credible sync jobs:');
for (CronTrigger ct : jobs) {
    System.debug('Job: ' + ct.CronJobDetail.Name);
    System.debug('  Cron: ' + ct.CronExpression);
    System.debug('  State: ' + ct.State);
    System.debug('  Next Run: ' + ct.NextFireTime);
}
