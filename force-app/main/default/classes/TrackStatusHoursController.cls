public without sharing class TrackStatusHoursController {
	@AuraEnabled(cacheable=true)
    public static Map<String, String> getStatusTimeTracker(String objectName, String recordId, String fieldName, String filterFieldName) {
        String whereClauseName = 'ParentId';
        String query;
        String parentQuery;
        Map<String, String> mapOfTimeTracker = new Map<String, String>();
        List<SObject> parentRecord = new List<SObject>();
        
        if (String.isBlank(objectName) || String.isBlank(fieldName) || String.isBlank(recordId)) {
            throw new AuraHandledException('Invalid input parameters');
        }
        
        if (objectName.endsWith('__c')) {
            parentQuery = 'SELECT Id, CreatedDate, ' + filterFieldName + ' FROM ' + objectName +
                ' WHERE Id = :recordId ORDER BY CreatedDate DESC';
            parentRecord = Database.query(parentQuery);
            
            objectName = objectName.substring(0, objectName.length() - 1) + 'History';
            query = 'SELECT ' + fieldName + ', CreatedById FROM ' + objectName +
                ' WHERE ' + whereClauseName + ' = :recordId AND Field = :filterFieldName ORDER BY CreatedDate DESC';
        }else {
            parentQuery = 'SELECT Id, CreatedDate, ' + filterFieldName + ' FROM ' + objectName +
                ' WHERE Id = :recordId ORDER BY CreatedDate DESC';
            parentRecord = Database.query(parentQuery);
            
            whereClauseName = objectName + 'Id';
            objectName = objectName + 'History';
            query = 'SELECT ' + fieldName + ', CreatedById FROM ' + objectName +
                ' WHERE ' + whereClauseName + ' = :recordId AND Field = :filterFieldName ORDER BY CreatedDate DESC';
        }
        
        List<SObject> records = Database.query(query);
        if (records.isEmpty()) {
            Sobject parRecord = parentRecord[0];
            mapOfTimeTracker.put('latestStatusValue', String.valueOf(parRecord.get(filterFieldName)));
            DateTime parentStartTime = (DateTime) parRecord.get('CreatedDate');
            Long elapsedMillis = System.now().getTime() - parentStartTime.getTime();
            mapOfTimeTracker.put('latestCreatedDateTime', String.valueOf(elapsedMillis / 1000));
            return mapOfTimeTracker;
        }
        
        mapOfTimeTracker = calculateStatusTime(records, objectName, filterFieldName,parentRecord);
        SObject latestRecord = records[0];
        
        DateTime startTime = (DateTime)latestRecord.get('CreatedDate');
        Long elapsedMillis = System.now().getTime() - startTime.getTime();
        mapOfTimeTracker.put('latestStatusValue', String.valueOf(latestRecord.get('NewValue')));
        mapOfTimeTracker.put('latestCreatedDateTime', String.valueOf(elapsedMillis / 1000));
        
        return mapOfTimeTracker;
    }


    public static Map<String, String> calculateStatusTime(List<SObject> records, String objName, String filterFieldName,List<SObject> parentRecord) {
        Map<String, String> mapOfCalculatedValue = new Map<String, String>(); 
        Map<String, Long> mapOfStatusDuration = new Map<String, Long>(); 
        String lastStatus;
        DateTime lastStatusDateTime;
        SObject parentRecordObj = parentRecord[0];
        DateTime parentStartTime = (DateTime) parentRecordObj.get('CreatedDate');
        
        if(records.size() == 1){
            SObject lastRecord = records[records.size()-1];
            lastStatus = String.valueOf(lastRecord.get('OldValue'));
            lastStatusDateTime = (DateTime) lastRecord.get('CreatedDate');
            Long durationInMillis = parentStartTime.getTime() - lastStatusDateTime.getTime();
            mapOfStatusDuration.put(lastStatus, durationInMillis);
        }else{
            for (Integer i = 0; i < records.size(); i++) {
                SObject currentRecord = records[i];
                String oldStatus = String.valueOf(currentRecord.get('OldValue'));
                DateTime startTime = (DateTime) currentRecord.get('CreatedDate');
                DateTime endTime;
                
                if (i + 1 < records.size()) {
                    endTime = (DateTime) records[i + 1].get('CreatedDate');
                } else {
                    endTime = parentStartTime;
                }
                
                if(records.size() > 1 ){
                    Long durationInMillis = endTime.getTime() - startTime.getTime();
                    if (!mapOfStatusDuration.containsKey(oldStatus)) {
                        mapOfStatusDuration.put(oldStatus, 0);
                    }
                    mapOfStatusDuration.put(oldStatus, mapOfStatusDuration.get(oldStatus) + durationInMillis);
                }
            }
        }
        
        // Convert stored durations from milliseconds to readable format
        for (String status : mapOfStatusDuration.keySet()) {
            Long timeDiffInMillis = mapOfStatusDuration.get(status);
            Long totalSeconds = timeDiffInMillis / 1000;
            
            Long days = totalSeconds / (24 * 3600);
            totalSeconds -= (days * 24 * 3600);
            
            Long hours = totalSeconds / 3600;
            totalSeconds -= (hours * 3600);
            
            Long minutes = totalSeconds / 60;
            Long seconds = totalSeconds - (minutes * 60);
            
            mapOfCalculatedValue.put(
                status,
                (-days) + ' days, ' + (-hours) + ' hours, ' + (-minutes) + ' minutes, ' + (-seconds) + ' seconds'
            );
        }
        
        return mapOfCalculatedValue;
    }
}