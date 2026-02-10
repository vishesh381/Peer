/**
 * Queueable class to retry fetching Peer ID from Credible
 * Chains itself for retries with natural async delay between attempts
 */
public class CrediblePeerIdRetryQueueable implements Queueable, Database.AllowsCallouts {

    private Id patientAdmissionId;
    private Id opportunityId;
    private Integer maxRetries;
    private Integer currentAttempt;

    public CrediblePeerIdRetryQueueable(Id patientAdmissionId, Id opportunityId, Integer maxRetries, Integer currentAttempt) {
        this.patientAdmissionId = patientAdmissionId;
        this.opportunityId = opportunityId;
        this.maxRetries = maxRetries;
        this.currentAttempt = currentAttempt;
    }

    public void execute(QueueableContext context) {
        try {
            System.debug('CrediblePeerIdRetryQueueable - Attempt ' + currentAttempt + ' of ' + maxRetries);

            // Call the export API
            String peerId = CredibleIntegrationService.callCredibleExportApi(patientAdmissionId);

            if (!String.isBlank(peerId)) {
                // Success - update the records
                updateRecordsWithPeerId(peerId);
                logSuccess(peerId);
                sendSuccessNotification();
                return;
            }

            // Peer ID still not available
            if (currentAttempt < maxRetries) {
                // Chain another queueable for retry
                // Natural delay between queueable executions provides spacing
                System.enqueueJob(new CrediblePeerIdRetryQueueable(
                    patientAdmissionId,
                    opportunityId,
                    maxRetries,
                    currentAttempt + 1
                ));
            } else {
                // Max retries reached - log failure and notify
                logFailure();
                sendFailureNotification();
            }

        } catch (Exception e) {
            System.debug('CrediblePeerIdRetryQueueable Error: ' + e.getMessage());
            logException(e);

            // Retry on exception if attempts remaining
            if (currentAttempt < maxRetries) {
                System.enqueueJob(new CrediblePeerIdRetryQueueable(
                    patientAdmissionId,
                    opportunityId,
                    maxRetries,
                    currentAttempt + 1
                ));
            } else {
                sendFailureNotification();
            }
        }
    }

    private void updateRecordsWithPeerId(String peerId) {
        // Query the admission record
        List<pstar__Patient_Admission__c> admissions = [
            SELECT Id, pstar__Patient__c, Credible_ID__c
            FROM pstar__Patient_Admission__c
            WHERE Id = :patientAdmissionId
            LIMIT 1
        ];

        if (admissions.isEmpty()) return;

        pstar__Patient_Admission__c admission = admissions[0];
        admission.Credible_ID__c = peerId;
        update admission;

        // Update Contact if linked
        if (admission.pstar__Patient__c != null) {
            Contact patient = new Contact(
                Id = admission.pstar__Patient__c,
                Credible_Profile_ID__c = peerId
            );
            update patient;
        }
    }

    private void logSuccess(String peerId) {
        try {
            Error_Log__c log = new Error_Log__c(
                Source_Name__c = 'Credible',
                Error_Type__c = 'API',
                Error_Message__c = 'Peer ID retrieved successfully on attempt ' + currentAttempt,
                Status__c = 'Success',
                Error_Details__c = 'Peer ID: ' + peerId + ', Patient Admission: ' + patientAdmissionId
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log success: ' + e.getMessage());
        }
    }

    private void logFailure() {
        try {
            Error_Log__c log = new Error_Log__c(
                Source_Name__c = 'Credible',
                Error_Type__c = 'API',
                Error_Message__c = 'Peer ID not returned after ' + maxRetries + ' attempts',
                Status__c = 'Failed',
                Error_Details__c = 'Patient Admission: ' + patientAdmissionId
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log failure: ' + e.getMessage());
        }
    }

    private void logException(Exception e) {
        try {
            Error_Log__c log = new Error_Log__c(
                Source_Name__c = 'Credible',
                Error_Type__c = 'Apex',
                Error_Message__c = e.getMessage(),
                Status__c = 'Failed',
                Error_Details__c = e.getStackTraceString()
            );
            insert log;
        } catch (Exception ex) {
            System.debug('Failed to log exception: ' + ex.getMessage());
        }
    }

    private void sendSuccessNotification() {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Credible_Notification'
                LIMIT 1
            ];

            if (!notifTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Credible Peer ID Retrieved');
                notification.setBody('Peer ID successfully retrieved and saved.');
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(opportunityId);
                notification.send(new Set<String>{UserInfo.getUserId()});
            }
        } catch (Exception e) {
            System.debug('Error sending success notification: ' + e.getMessage());
        }
    }

    private void sendFailureNotification() {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Credible_Notification'
                LIMIT 1
            ];

            if (!notifTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Credible Peer ID Not Retrieved');
                notification.setBody('Profile was created but Peer ID could not be retrieved after ' + maxRetries + ' attempts. Please check manually.');
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(opportunityId);
                notification.send(new Set<String>{UserInfo.getUserId()});
            }
        } catch (Exception e) {
            System.debug('Error sending failure notification: ' + e.getMessage());
        }
    }
}