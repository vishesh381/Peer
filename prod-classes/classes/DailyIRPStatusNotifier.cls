public class DailyIRPStatusNotifier implements Schedulable {
    
    public static void sendIRPCompletedNotification() {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        Map<String, Id> emailDocuments = new Map<String, Id>();
        for (Document doc : [
            SELECT Id, Name FROM Document 
            WHERE Name = 'Pulse Email Footer' OR Name = 'Pulse Email Header'
        ]) {
            emailDocuments.put(doc.Name, doc.Id);
        }
        
        List<Group> rsmQueue = [
            SELECT Id, Email, Name, DoesSendEmailToMembers  
            FROM Group  
            WHERE Type = 'Queue'  
            AND Name = 'RSM Queue'  
            AND Email != null  
            LIMIT 1
        ];
        if (rsmQueue.isEmpty()) {
            return;
        }
        
        String recipientEmail = rsmQueue[0].Email;
        Set<String> membersEmail = new Set<String>();
        if (rsmQueue[0].DoesSendEmailToMembers) {
            membersEmail = getQueueMemberEmails();
        }
        
        Date yesterday = Date.today().addDays(-1);
        
        List<ple__Action__c> actions = [
            SELECT Id, IRP_Completion_Date__c, ple__Referral__r.Id, ple__Referral__r.Name,
            IRP_Date__c, IRP_Specialist__c, IRP_Status__c,
            ple__Referral__r.ple__Patient__r.Name,
            ple__Referral__r.ple__Patient__r.MailingStreet, 
            ple__Referral__r.ple__Patient__r.MailingCity, 
            ple__Referral__r.ple__Patient__r.MailingState, 
            ple__Referral__r.ple__Patient__r.MailingPostalCode, 
            ple__Referral__r.ple__Patient__r.MailingCountry, 
            ple__Referral__r.ple__Source__r.Name, 
            ple__Referral__r.ple__Source__c, 
            ple__Referral__r.ple__Patient__r.ple__County__c,
            ple__Referral__r.ple__Patient__r.Peer_Type__c 
            FROM ple__Action__c 
            WHERE  IRP_Completion_Date__c = :yesterday AND IRP_Status__c = 'Completed' 
            AND ple__Referral__c != null Order By ple__Referral__r.ple__Patient__r.ple__County__c, IRP_Date__c
        ];
        
        String htmlBody = '<html><body style="font-family: Arial, sans-serif; font-size: 14px;">' +
            '<img src="' + baseUrl + '/servlet/servlet.ImageServer?id=' + emailDocuments.get('Pulse Email Header') +
            '&oid=' + UserInfo.getOrganizationId() + '" style="max-width: 100%;" />' +
            '<div style="background-color:#f5f5ff;padding:5px 5px;">' + 
            '<p>Hi Team,</p>';
        
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        
        if (actions.isEmpty()) {
            htmlBody += '<p>No Referrals with IRP Completed yesterday.</p>';
            attachment = null;
        } else {
            Map<Id, Set<String>> referralServicesMap = new Map<Id, Set<String>>();
            Set<Id> referralIds = new Set<Id>();
            
            for (ple__Action__c action : actions) {
                referralIds.add(action.ple__Referral__r.Id);
            }
            
            if (!referralIds.isEmpty()) {
                for (ple__Referral_Service__c rs : [
                    SELECT ple__Referral__c, ple__Service__r.Name   
                    FROM ple__Referral_Service__c    
                    WHERE ple__Referral__c IN :referralIds  
                    AND ple__Service__c != NULL
                ]) {
                    if (!referralServicesMap.containsKey(rs.ple__Referral__c)) {
                        referralServicesMap.put(rs.ple__Referral__c, new Set<String>());
                    }
                    referralServicesMap.get(rs.ple__Referral__c).add(rs.ple__Service__r.Name);
                }
            }
            
            htmlBody += '<p>Below is the list of Referrals where IRP Status was updated to Completed yesterday.</p>';
            htmlBody += '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse;">';
            htmlBody += '<tr style="background-color: #f2f2f2;">' +
              '<th>Referral ID</th><th>Client Name</th><th>IRP Date</th>' +
              '<th>IRP Specialist</th><th>Program/Service</th><th>Peer Address</th>' +
              '<th>County</th><th>Peer Type</th><th>Source</th></tr>';
            
            for (ple__Action__c action : actions) {
                htmlBody += '<tr>';
                htmlBody += '<td><a href="' + baseUrl + '/' + action.ple__Referral__r.Id + '">' + 
                    action.ple__Referral__r.Id + '</a></td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r != null ? 
                                      action.ple__Referral__r.ple__Patient__r.Name : '') + '</td>';
                htmlBody += '<td>' + (action.IRP_Date__c != null ?  
                                      action.IRP_Date__c.date().format() : '') + '</td>';
                htmlBody += '<td>' + (action.IRP_Specialist__c != null ? 
                                      action.IRP_Specialist__c : '') + '</td>';
                
                
                Set<String> services = referralServicesMap.containsKey(action.ple__Referral__r.Id) 
                    ? referralServicesMap.get(action.ple__Referral__r.Id)  
                    : new Set<String>();
                
                htmlBody += '<td>' + (services.isEmpty() ? 'N/A' : String.join(services, ', ')) + '</td>';
                
                List<String> addressParts = new List<String>();
                String stateWithPostalCode = '';
                if (action.ple__Referral__r.ple__Patient__r.MailingStreet != null)
                    addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingStreet);
                if (action.ple__Referral__r.ple__Patient__r.MailingCity != null)
                    addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingCity);
                if (action.ple__Referral__r.ple__Patient__r.MailingState != null)
                    stateWithPostalCode += action.ple__Referral__r.ple__Patient__r.MailingState;
                if (action.ple__Referral__r.ple__Patient__r.MailingPostalCode != null)
                    stateWithPostalCode += ' ' + action.ple__Referral__r.ple__Patient__r.MailingPostalCode;
                if (!String.isBlank(stateWithPostalCode))
                    addressParts.add(stateWithPostalCode);
                if (action.ple__Referral__r.ple__Patient__r.MailingCountry != null)
                    addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingCountry);
                
                String fullAddress = addressParts.isEmpty() ? '' : String.join(addressParts, ', ');
                
                htmlBody += '<td>' + fullAddress + '</td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r.ple__County__c != null ? 
                                      action.ple__Referral__r.ple__Patient__r.ple__County__c : '') + '</td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r.Peer_Type__c != null ? 
                                      action.ple__Referral__r.ple__Patient__r.Peer_Type__c : '') + '</td>';
                htmlBody += '<td>' + 
                    (action.ple__Referral__r.ple__Source__c != null && 
                     action.ple__Referral__r.ple__Source__r.Name != null 
                     ? '<a href="' + baseUrl + '/' + action.ple__Referral__r.ple__Source__c + '">' + 
                     action.ple__Referral__r.ple__Source__r.Name + '</a>' 
                     : '') + 
                    '</td>';
                htmlBody += '</tr>';
            }
            
            htmlBody += '</table>';
            
            String excelContent = '<html xmlns:x="urn:schemas-microsoft-com:office:excel">' +
                '<head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" /></head><body>' +
                '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;">' +
                '<tr style="background-color:#f2f2f2;">' +
                //'<th>Referral ID</th><th>Client Name</th><th>IRP Date</th><th>IRP Specialist</th>' +
                //'<th>Program/Service</th><th>Peer Address</th><th>County</th><th>Peer Type</th><th>Source</th></tr>' +
                htmlBody.substringAfter('<tr style="background-color: #f2f2f2;">') +
                '</table></body></html>';
            
            Blob excelBlob = Blob.valueOf(excelContent);
            attachment.setFileName('IRP_Completed_Report_' + yesterday.format().replace('/', '-') + '.xls');
            attachment.setBody(excelBlob);
            attachment.setContentType('application/vnd.ms-excel');
        }
        
        htmlBody += '<p>Let us know if you have any questions.<br/>Thanks for your continued support!</p></div>' +
            '<div><img src="' + baseUrl + '/servlet/servlet.ImageServer?id=' + emailDocuments.get('Pulse Email Footer') +
            '&oid=' + UserInfo.getOrganizationId() + '" style="max-width: 100%;" /></div></body></html>';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { recipientEmail });
        if (!membersEmail.isEmpty()) {
            mail.setCcAddresses(new List<String>(membersEmail));
        }
        mail.setSubject('Daily Referrals with IRP Completed – ' + yesterday.format());
        mail.setHtmlBody(htmlBody);
        
        if (attachment != null) {
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        }
        
        mail.setSaveAsActivity(false);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    
    
    public static void sendIRPScheduledNotification(){
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        Map<String, Id> emailDocuments = new Map<String,Id>();
        for (Document doc : [Select ID, Name from Document Where Name = 'Pulse Email Footer' OR Name ='Pulse Email Header']) {
            emailDocuments.put(doc.Name, doc.Id);
        }
        List<Group> rsmQueue = [SELECT Id, Email, Name, DoesSendEmailToMembers  FROM Group  WHERE Type = 'Queue'  AND Name = 'RSM Queue' AND Email != null  LIMIT 1];
        if (rsmQueue.isEmpty()) {
            return;
        }
        
        String recipientEmail = rsmQueue[0].Email;
        Set<String> membersEmail = new Set<String>();
        if(rsmQueue[0].DoesSendEmailToMembers){
            membersEmail =   getQueueMemberEmails();
        }
        
        List<ple__Action__c> actions = [SELECT Id, IRP_Date__c, IRP_Specialist__c, IRP_Status__c, ple__Referral__r.Id, ple__Referral__r.Name, ple__Referral__r.ple__Patient__r.Name, ple__Referral__r.ple__Patient__r.MailingStreet, ple__Referral__r.ple__Patient__r.MailingCity, ple__Referral__r.ple__Patient__r.MailingState, ple__Referral__r.ple__Patient__r.MailingPostalCode, ple__Referral__r.ple__Patient__r.MailingCountry, ple__Referral__r.ple__Patient__r.ple__County__c ,ple__Referral__r.ple__Source__r.Name, ple__Referral__r.ple__Source__c,ple__Referral__r.ple__Patient__r.Peer_Type__c  FROM ple__Action__c WHERE  IRP_Status__c ='Scheduled' ANd ple__Referral__c != null Order By ple__Referral__r.ple__Patient__r.ple__County__c, IRP_Date__c ];
        
        String htmlBody =  '<html><body style="font-family: Arial, sans-serif; font-size: 14px;">' +
            '<img src="' + baseUrl + '/servlet/servlet.ImageServer?id=' + emailDocuments.get('Pulse Email Header') + '&oid=' + UserInfo.getOrganizationId() + '" style="max-width: 100%;" />' +
            '<div style="background-color:#f5f5ff;padding:5px 5px;">'+ 
            '<p>Hi Team,</p>';
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        
        if (actions.isEmpty()) {
            htmlBody += '<p>No Referrals with IRP Scheduled.</p>';
            attachment = null;
        } else {
            Map<Id, Set<String>> referralServicesMap = new Map<Id, Set<String>>();
            Set<Id> referralIds = new Set<Id>();
            
            for (ple__Action__c action : actions) {
                referralIds.add(action.ple__Referral__r.Id);
            }
            
            if (!referralIds.isEmpty()) {
                for (ple__Referral_Service__c rs :  [ SELECT ple__Referral__c, ple__Service__r.Name   FROM ple__Referral_Service__c    WHERE ple__Referral__c IN :referralIds  AND ple__Service__c != Null]) {
                    Id refId = rs.ple__Referral__c;
                    
                    if (!referralServicesMap.containsKey(refId)) {
                        referralServicesMap.put(refId, new Set<String>());
                    }
                    
                    referralServicesMap.get(refId).add(rs.ple__Service__r.Name);
                }
            }
            
            htmlBody += '<p>Below is the list of Referrals where IRP Status is Scheduled.</p>';
            htmlBody += '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse;">';
            htmlBody += '<tr style="background-color: #f2f2f2;">';
            htmlBody += '<th>Referral ID</th><th>Client Name</th><th>IRP Date</th><th>IRP Specialist</th><th>Program/Service</th></th><th>Peer Address</th><th>County</th><th>Peer Type</th><th>Source</th></tr>';
            String csvContent = 'Referral ID,Client Name,IRP Date,IRP Specialist,Program/Service,Peer Address,County,Peer Type,Source\n';
            
            for (ple__Action__c action : actions) {
                htmlBody += '<tr>';
                htmlBody += '<td><a href="' + baseUrl + '/' + action.ple__Referral__r.Id + '">' + action.ple__Referral__r.Id + '</a></td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r !=  null ? action.ple__Referral__r.ple__Patient__r.Name : '' ) + '</td>';
                htmlBody += '<td>' + (action.IRP_Date__c != null ?  action.IRP_Date__c.date().format() : '') + '</td>';
                htmlBody += '<td>' + (action.IRP_Specialist__c != null ? action.IRP_Specialist__c : '') + '</td>';
                
                Set<String> services = referralServicesMap.containsKey(action.ple__Referral__r.Id) ? referralServicesMap.get(action.ple__Referral__r.Id)  : new Set<String>();
                
                htmlBody += '<td>' + (services.isEmpty() ? 'N/A' : String.join(services, ', ')) + '</td>';
                String stateWithPostalCode ='';
                List<String> addressParts = new List<String>();
                if(action.ple__Referral__r.ple__Patient__r.MailingStreet != null) addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingStreet);
                if(action.ple__Referral__r.ple__Patient__r.MailingCity != null) addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingCity);
                if(action.ple__Referral__r.ple__Patient__r.MailingState != null) stateWithPostalCode += action.ple__Referral__r.ple__Patient__r.MailingState ;
                if(action.ple__Referral__r.ple__Patient__r.MailingPostalCode != null) stateWithPostalCode  = stateWithPostalCode + ' ' + action.ple__Referral__r.ple__Patient__r.MailingPostalCode ;
                if(!String.isBlank(stateWithPostalCode)) addressParts.add(stateWithPostalCode);
                if(action.ple__Referral__r.ple__Patient__r.MailingCountry != null) addressParts.add(action.ple__Referral__r.ple__Patient__r.MailingCountry );
                String fullAddress = '';
                if(!addressParts.isEmpty()){
                    fullAddress = String.join(addressParts, ', ');
                }
                
                htmlBody += '<td>' + fullAddress + '</td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r.ple__County__c !=null  ? action.ple__Referral__r.ple__Patient__r.ple__County__c : '') + '</td>';
                htmlBody += '<td>' + (action.ple__Referral__r.ple__Patient__r.Peer_Type__c !=null  ? action.ple__Referral__r.ple__Patient__r.Peer_Type__c : '') + '</td>';
                
                htmlBody += '<td>'
                    + (action.ple__Referral__r.ple__Source__c != null && action.ple__Referral__r.ple__Source__r.Name != null 
                       ? '<a href="' + baseUrl + '/' + action.ple__Referral__r.ple__Source__c + '">' + action.ple__Referral__r.ple__Source__r.Name + '</a>' 
                       : '') 
                    + '</td>';
                
                htmlBody += '</tr>';
                
                csvContent += '"' + action.ple__Referral__r.Id + '","' +
                 	(action.ple__Referral__r.ple__Patient__r != null ?  action.ple__Referral__r.ple__Patient__r.Name : '') + '","' +
                    (action.IRP_Date__c != null ? action.IRP_Date__c.format() : '') + '","' +
                    (action.IRP_Specialist__c != null ? action.IRP_Specialist__c : '') + '","' +
                    (services.isEmpty() ? '' : String.join(services, ', ')) + '","' +
                    fullAddress + '","' +
                    (action.ple__Referral__r.ple__Patient__r.ple__County__c != null ? action.ple__Referral__r.ple__Patient__r.ple__County__c : '') + '","' +
                    (action.ple__Referral__r.ple__Patient__r.Peer_Type__c != null ? action.ple__Referral__r.ple__Patient__r.Peer_Type__c : '') + '","' +
                    (action.ple__Referral__r.ple__Source__c != null && action.ple__Referral__r.ple__Source__r.Name != null  ? action.ple__Referral__r.ple__Source__r.Name : '') + '"\n';
                
            }
            
            htmlBody += '</table>';
            /*Blob excelBlob = Blob.valueOf(csvContent);
			attachment.setFileName('IRP_Scheduled_Report_' + Date.today().format().replace('/', '-') + '.xls');
            attachment.setBody(excelBlob);*/
            // Convert HTML table to Excel-friendly format
            String excelContent = '<html xmlns:x="urn:schemas-microsoft-com:office:excel">' +
                '<head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" /></head><body>' +
                '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;">' +
                '<tr style="background-color:#f2f2f2;">' +
                //'<th>Referral ID</th><th>Client Name</th><th>IRP Date</th><th>IRP Specialist</th>' +
                //'<th>Program/Service</th><th>Peer Address</th><th>County</th><th>Peer Type</th><th>Source</th></tr>' +
                htmlBody.substringAfter('<tr style="background-color: #f2f2f2;">') +  // reuse rows
                '</table></body></html>';

            Blob excelBlob = Blob.valueOf(excelContent);
            attachment.setFileName('IRP_Scheduled_Report_' + Date.today().format().replace('/', '-') + '.xls');
            attachment.setBody(excelBlob);
            
        }
        
        htmlBody +=  
            '<p>Let us know if you have any questions.<br/>Thanks for your continued support!</p></div>';
        
        htmlBody += 
            '<div>' +
            '<img src="' + baseUrl + '/servlet/servlet.ImageServer?id=' + emailDocuments.get('Pulse Email Footer') + '&oid=' + UserInfo.getOrganizationId() + '" style="max-width: 100%;" />' +
            '</div></body></html>';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { recipientEmail });
        if (!membersEmail.isEmpty()) {
            mail.setCcAddresses(new List<String>(membersEmail));
        }   
        mail.setSubject('Daily Referrals with IRP Scheduled');
        mail.setHtmlBody(htmlBody);
        if (attachment != null) { 
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        }
        
        mail.setSaveAsActivity(false);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
    }
    
    
    private static Set<String> getQueueMemberEmails() {
        Set<Id> memberIds = new Set<Id>();
        
        List<GroupMember> members = [SELECT UserOrGroupId FROM GroupMember  WHERE Group.DeveloperName = 'RSM_Queue'];
        
        for (GroupMember gm : members) {
            memberIds.add(gm.UserOrGroupId);
        }
        
        List<User> queueUsers = [SELECT Email FROM User WHERE Id IN :memberIds];
        Set<String> memberEmails = new Set<String>();
        
        for (User user : queueUsers) {
            if (!String.isBlank(user.Email)) {
                memberEmails.add(user.Email);
            }
        }
        
        return memberEmails;
    }
    
    public  void execute(SchedulableContext sc) {
        sendIRPCompletedNotification();
        sendIRPScheduledNotification();
    }
}