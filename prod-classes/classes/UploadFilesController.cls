public class UploadFilesController {
    
    public Id recordId {get; set;}
    public final sObject sObj;
    public List<String> fldList;
    public Integer uploadFileCnt{get;set;}
    
    public UploadFilesController(){
        uploadFileCnt = 0;
        
        // Get record Id from the page parameter
        Id recId = (Id)ApexPages.currentPage().getParameters().get('id'); 
        Schema.SObjectType sobjectType = recId.getSObjectType();
        String sobjectName = sobjectType.getDescribe().getName();
        
        // Fetch all field names available in the org
        fldList = new List<String>(SObjectType.getDescribe().fields.getMap().keySet());
        
        // Verify if the SObject type exists in org schema
        if (Schema.getGlobalDescribe().containsKey(sObjectName)) {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(sObjectName);
            Schema.DescribeSObjectResult describeSObj = sObjType.getDescribe();
            
            // Only proceed if object is accessible and queryable
            if (describeSObj.isQueryable() && describeSObj.isAccessible()) {
                Map<String, Schema.SObjectField> fieldMap = describeSObj.fields.getMap();
                List<String> accessibleFields = new List<String>();
                
                // Include only accessible fields in query
                for (String fieldName : fldList) {
                    if (fieldMap.containsKey(fieldName) &&
                        fieldMap.get(fieldName).getDescribe().isAccessible()) {
                            accessibleFields.add(fieldName);
                        }
                }
                
                // Dynamically query the record to use field values for filename placeholders
                if(!accessibleFields.isEmpty()){
                    String query = 'SELECT '+String.join(accessibleFields, ',')+' FROM '+String.escapeSingleQuotes(sObjectName)+' WHERE Id=: recId';
                    this.sObj = Database.query(query);
                }
            }
        }
        
        // Store recordId if passed in the VF parameters
        if(Apexpages.currentPage().getParameters().containsKey('id') && Apexpages.currentPage().getParameters().get('id')!= null){
            recordId = Apexpages.currentPage().getParameters().get('id');
            system.debug('recordId '+recordId);
        }
    }
    public UploadFilesController(ApexPages.StandardController stdController){
        uploadFileCnt = 0;
        
        // Get record Id from StandardController
        Id recId = (Id)stdController.getRecord().get('Id');
        Schema.SObjectType sobjectType = recId.getSObjectType();
        String sobjectName = sobjectType.getDescribe().getName();
        fldList = new List<String>(SObjectType.getDescribe().fields.getMap().keySet());
        
        if (Schema.getGlobalDescribe().containsKey(sobjectName)) {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(sobjectName);
            Schema.DescribeSObjectResult describeSObj = sObjType.getDescribe();
            
            if (describeSObj.isQueryable() && describeSObj.isAccessible()) {
                
                Map<String, Schema.SObjectField> fieldMap = describeSObj.fields.getMap();
                List<String> accessibleFields = new List<String>();
                
                for (String fieldName : fldList) {
                    if (fieldMap.containsKey(fieldName) && fieldMap.get(fieldName).getDescribe().isAccessible()) {
                        accessibleFields.add(fieldName);
                    }
                }
                
                if (!accessibleFields.isEmpty()) {
                    String query = 'SELECT '+String.join(accessibleFields, ',')+' FROM '+String.escapeSingleQuotes(sObjectName)+' WHERE Id=: recId';
                    this.sObj = Database.query(query);
                }
            }
        }
        if(Apexpages.currentPage().getParameters().containsKey('id') && Apexpages.currentPage().getParameters().get('id')!= null){
            recordId = Apexpages.currentPage().getParameters().get('id');
            system.debug('recordId '+recordId);
        }
    }
    
    // Reset uploaded file count
    public void emptyData(){
        uploadFileCnt = 0;
    }
    
    public void uploadFile(){
        try{
            // Check if Base64 image string exists in parameters
            if(Apexpages.currentPage().getParameters().containsKey('image')){
                String image = Apexpages.currentPage().getParameters().get('image');
                // Extract base64 portion from Data URL
                String blobStr = image.substring( image.indexOf('base64,')+7 , image.length());
                
                // Get filename and check for placeholders like {FieldName}
                String fileName = Apexpages.currentPage().getParameters().get('fileName');
                Integer ind = fileName.indexOf('{');
                
                // Replace placeholder with actual field value if exists
                if(ind != -1 && fileName.indexOf('}',ind) != -1){
                    String fld = fileName.subString(fileName.indexOf('{')+1,fileName.indexOf('}'));
                    if(fldList.contains(fld.toLowerCase())){
                        if(sObj.get(fld) != NULL && sObj.get(fld) != ''){
                            fileName = fileName.replace('{'+fld+'}',(String)sObj.get(fld));
                        }
                    }
                }
                
                // If fileName becomes empty, fallback to a default
                if (String.isBlank(fileName)){
                    fileName = 'File';
                }else{
                    Integer lastSpaceIdx = fileName.lastIndexOf(' ');
                    if (lastSpaceIdx != -1 && lastSpaceIdx < fileName.length() - 1) {
                        String afterSpace = fileName.substring(lastSpaceIdx + 1);
                        
                        // Check if the text after last space is purely numeric
                        if (Pattern.matches('\\d+', afterSpace)) {
                            fileName = fileName.substring(0, lastSpaceIdx).trim();
                        }
                    }
                } 
                
                // Validate access for ContentVersion creation
                if(Schema.sObjectType.ContentVersion.fields.VersionData.isCreateable() && Schema.sObjectType.ContentVersion.fields.Title.isCreateable() && Schema.sObjectType.ContentVersion.fields.PathOnClient.isCreateable()){
                    // Add timestamp to make filename unique
                    String timeStamp = Datetime.now().format('yyyyMMdd_HHmmss');
                    String uniqueFileName = fileName + '_' + timeStamp;
                    
                    // Create ContentVersion
                    ContentVersion cv = new ContentVersion();
                    cv.Title = uniqueFileName;
                    cv.VersionData = EncodingUtil.base64decode(blobStr);
                    cv.PathOnClient = uniqueFileName + '.PNG' ; 
                    insert cv;
                    
                    // Retrieve the ContentDocumentId for linking
                    List<ContentVersion> cvList = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id];
                    
                    // Create ContentDocumentLink to associate file with the record
                    if(Schema.sObjectType.ContentDocumentLink.fields.ShareType.isCreateable() && Schema.sObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() && Schema.sObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable()){
                        ContentDocumentLink cl = new ContentDocumentLink();
                        cl.ContentDocumentId = cvList[0].ContentDocumentId;
                        cl.LinkedEntityId = recordId;
                        cl.ShareType = 'V';
                        insert cl;
                    }
                }
                uploadFileCnt ++ ;
            }else{
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Base64 is Empty'));
            }
        }catch(Exception err){
            System.debug('Error => '+err.getMessage()+' line'+err.getLineNumber());
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,err.getMessage()));
        }
    }
}