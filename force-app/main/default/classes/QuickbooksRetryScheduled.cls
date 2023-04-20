public with sharing class QuickbooksRetryScheduled implements Schedulable, Database.AllowsCallouts {

    // This is a simple schedulable class that is used by QuickbooksHelper for retries

    Set<Id> accountIds;

    public QuickbooksRetryScheduled(Set<Id> accountIds) {
        this.accountIds = accountIds;
    }
        
    public void execute(SchedulableContext SC) {
        QuickbooksHelper.CreateCustomers(accountIds, true);
    }
}