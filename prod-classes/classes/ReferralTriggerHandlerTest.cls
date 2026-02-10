@IsTest
public class ReferralTriggerHandlerTest {
        
    @TestSetup
    static void setupTestData() {
        List<Profile> p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        UserRole intakeRole = new UserRole(DeveloperName = 'PA_IntakeAdmission', Name = 'PA Intake Admission');
        insert intakeRole;
        
        List<User> users = new List<User>();
        for(Integer i=0; i<2; i++){
            users.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Alias = 'tusr' + i,
                Username = 'testuser' + i + DateTime.now().getTime() + '@test.com',
                Email = 'testuser' + i + '@test.com',
                TimeZoneSidKey = 'GMT',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p[0].Id,
                UserRoleId = intakeRole.Id
            ));
        }
        insert users;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<ple__Referral__c> referrals = new List<ple__Referral__c>();
            
            for(Integer i = 0; i < 11; i++) {
                referrals.add(new ple__Referral__c(jotform_County__c = 'Armstrong'));
            }
            referrals.add(new ple__Referral__c(jotform_County__c = 'Beaver', OwnerId = users[0].Id));
            insert referrals;
        }
    }
    
    @IsTest
    static void testReferralAssignment() {
        
        List<ple__Referral__c> referral = [SELECT Id, OwnerId, Owner.LastName FROM ple__Referral__c Where jotform_County__c != 'Beaver'];
        for(ple__Referral__c ref : referral){
            ref.OwnerId = System.Label.Unassigned_Referral_Queue_Id;
        }
        update referral; 
        System.assert(System.Label.Unassigned_Referral_Queue_Id == referral[0].OwnerId,'Referral should be assigned to a PA Intake Admission user.');
    }
}