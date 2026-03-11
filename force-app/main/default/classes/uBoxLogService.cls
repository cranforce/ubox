public without sharing class uBoxLogService {

    public static Id createLog(String action, Id targetUserId, Id performedById, String status, String detail) {
        uBox_Log__c log = new uBox_Log__c(
            Action__c = action,
            Target_User__c = targetUserId,
            Performed_By__c = performedById,
            Status__c = status,
            Detail__c = detail
        );
        insert log;
        return log.Id;
    }

    public static void sendCompletionNotification(Id recipientId, Id targetUserId, String action, String status, String detail, Id logRecordId) {
        try {
            CustomNotificationType notifType = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'uBox_Assignment_Complete'
                LIMIT 1
            ];

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notifType.Id);

            String title = status == 'Success'
                ? 'User Assignments Complete'
                : 'User Assignment Errors';
            notification.setTitle(title);

            String body = action + ': ' + (String.isNotBlank(detail) ? detail.abbreviate(250) : status);
            notification.setBody(body);

            notification.setTargetId(logRecordId);

            notification.send(new Set<String>{ recipientId });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to send uBox notification: ' + e.getMessage());
        }
    }
}
