# Function to get the PostgreSQL servers for a given subscription and optionally a resource group
function Get-PostgreSqlServers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$subscriptionName,
        
        [string]$resourceGroupName
    )

    # Set the context to the specified subscription
    Set-AzContext -Subscription $subscriptionName

    # prepare the query string
    if($resourceGroupName){
        $queryString = "where type =~ 'Microsoft.DbforPostgreSQL/servers' and resourceGroup == '$resourceGroupName'"
    }
    else {
        $queryString = "where type =~ 'Microsoft.DbforPostgreSQL/servers'"
    }

    # execute the resource graph query
    return Search-AzGraph -Query $queryString
}

# Function to import data from CSV, execute query for each row and export results to a CSV
function Export-PostgreSqlServersToCsv {
    param (
        [Parameter(Mandatory = $true)]
        [string]$inputFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$outputFilePath
    )

    # import CSV file
    $csvData = Import-Csv -Path $inputFilePath

    # prepare the output data
    $results = @()

    # iterate through each row in the csv
    foreach($row in $csvData){
        # append to results
        $results += Get-PostgreSqlServers -subscriptionName $row.SubscriptionName -resourceGroupName $row.ResourceGroupName
    }

    # export the results to a csv file
    $results | Export-Csv -Path $outputFilePath -NoTypeInformation
}

# calling the function
Export-PostgreSqlServersToCsv -inputFilePath 'C:\path\to\your\input.csv' -outputFilePath 'C:\path\to\your\output.csv'
