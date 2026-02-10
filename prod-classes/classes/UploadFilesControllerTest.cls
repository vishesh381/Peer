@isTest
public class UploadFilesControllerTest {

    // Helper method to create a dummy record
    private static Account createTestAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        return acc;
    }

    // Helper method to get Base64 image
    private static String getBase64Image() {
        Blob b = Blob.valueOf('Sample Image');
        return 'data:image/png;base64,' + EncodingUtil.base64Encode(b);
    }

    @isTest
    static void testConstructorWithoutStandardController() {
        Account acc = createTestAccount();

        // Setup VF Page context
        Test.startTest();
        PageReference pageRef = Page.UploadFiles; 
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', acc.Id);

        UploadFilesController ctrl = new UploadFilesController();
        Test.stopTest();

        System.assertEquals(acc.Id, ctrl.recordId, 'RecordId should match VF param');
        System.assertEquals(0, ctrl.uploadFileCnt, 'Upload count should start at 0');
    }

    @isTest
    static void testConstructorWithStandardController() {
        Account acc = createTestAccount();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(acc);

        Test.startTest();
        UploadFilesController ctrl = new UploadFilesController(stdCtrl);
        Test.stopTest();

        System.assertNotEquals(null, ctrl, 'Controller created');
        System.assertEquals(0, ctrl.uploadFileCnt, 'Upload count should initialize');
    }

	@isTest
    static void testUploadFile_Success() {
        Account acc = createTestAccount();

        Test.startTest();
        PageReference pageRef = Page.UploadFiles;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', acc.Id);
        ApexPages.currentPage().getParameters().put('image', getBase64Image());
        ApexPages.currentPage().getParameters().put('fileName', 'MyFile');

        UploadFilesController ctrl = new UploadFilesController();
        ctrl.uploadFile();
        Test.stopTest();

        System.assertEquals(1, ctrl.uploadFileCnt, 'Upload count should increase');

        ContentVersion cv = [SELECT Id, Title, PathOnClient FROM ContentVersion LIMIT 1];
        System.assert(cv.Title.contains('MyFile'), 'Filename should be reflected');
        System.assert(cv.PathOnClient.endsWith('.PNG'), 'File extension should be .PNG');

        ContentDocumentLink cdl = [
            SELECT LinkedEntityId, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :acc.Id
            LIMIT 1
        ];
        System.assertEquals(acc.Id, cdl.LinkedEntityId, 'File linked to record');
    }

    @isTest
    static void testUploadFile_WithPlaceholder() {
        Account acc = createTestAccount();

        Test.startTest();
        PageReference pageRef = Page.UploadFiles;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', acc.Id);
        ApexPages.currentPage().getParameters().put('image', getBase64Image());
        ApexPages.currentPage().getParameters().put('fileName', 'Image_{Name}');

        UploadFilesController ctrl = new UploadFilesController();
        ctrl.uploadFile();
        Test.stopTest();

        ContentVersion cv = [SELECT Title FROM ContentVersion LIMIT 1];
        System.assert(cv.Title.contains('Test Account'),
            'Placeholder {Name} should be replaced by field value');
    }

    @isTest
    static void testUploadFile_EmptyBase64() {
        Account acc = createTestAccount();

        Test.startTest();
        PageReference pageRef = Page.UploadFiles;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', acc.Id);

        UploadFilesController ctrl = new UploadFilesController();
        ctrl.uploadFile();
        Test.stopTest();

        System.assert(ApexPages.getMessages().size() > 0,
            'Error message should appear when Base64 is missing');
    }

    @isTest
    static void testUploadFile_WithNumericSuffix() {
        Account acc = createTestAccount();

        Test.startTest();
        PageReference pageRef = Page.UploadFiles;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', acc.Id);
        ApexPages.currentPage().getParameters().put('image', getBase64Image());
        ApexPages.currentPage().getParameters().put('fileName', 'MyFile 123');

        UploadFilesController ctrl = new UploadFilesController();
        ctrl.uploadFile();
        Test.stopTest();

        ContentVersion cv = [SELECT Title FROM ContentVersion LIMIT 1];
        System.assert(cv.Title.startsWith('MyFile_'),
            'Numeric suffix should be removed before timestamp append');
    }
}