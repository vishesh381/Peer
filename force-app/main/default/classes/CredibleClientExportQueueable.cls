/**
 * Queueable class to sync Client/Patient data from Credible to Salesforce
 * Called by CredibleExportScheduler every 30 minutes
 */
public class CredibleClientExportQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        Date today = Date.today();
        Date todayDate = Date.newInstance(today.year(), today.month(), today.day());

        // Import client data for today (both created and updated)
        CredibleExportsService.importClientData(null, null, todayDate, todayDate, null);
    }
}
