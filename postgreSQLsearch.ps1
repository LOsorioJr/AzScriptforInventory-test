# Import the necessary modules
import-module AzureRM.Subscription
import-module AzureRM.ResourceGraph

# Get the subscription IDs for a given batch of subscription data
function Get-SubscriptionIdsFromBatch($batch, $subClient) {
    $subscriptionIds = @()
    $notFoundSubs = @()
    $invalidSubs = @()
    for ($subscription in $batch) {
        $subId = Get-SubscriptionId($subClient, $subscription['SubscriptionName'])
        if ($subId -eq $null) {
            $notFoundSubs += $subscription['SubscriptionName']
        } elseif (![Guid]::TryParse($subId, [ref]$subId)) {
            $invalidSubs += $subscription['SubscriptionName']
        } else {
            $subscriptionIds += $subId
        }
    }
    return $subscriptionIds, $notFoundSubs, $invalidSubs
}

# Main function
function Main() {
    $batchSize = 500
    $inputCSVFile = "subscriptions.csv"
    $notFoundFile = "not_found_subscriptions.csv"
    $invalidFile = "invalid_subscriptions.csv"

    # Read the subscription data from the CSV file
    $subscriptionData = Import-Csv $inputCSVFile

    # Create a subscription client
    $subClient = New-AzureRMSubscriptionClient

    # Get the subscription IDs in batches
    $batches = $subscriptionData | Split-Path -Length $batchSize
    foreach ($batch in $batches) {
        $subscriptionIds, $notFoundSubs, $invalidSubs = Get-SubscriptionIdsFromBatch($batch, $subClient)

        # Save the not found subscriptions
        Write-Host "Saving not found subscriptions to $notFoundFile"
        $notFoundSubs | Export-Csv $notFoundFile

        # Save the invalid subscriptions
        Write-Host "Saving invalid subscriptions to $invalidFile"
        $invalidSubs | Export-Csv $invalidFile
    }
}

# Run the main function
Main
