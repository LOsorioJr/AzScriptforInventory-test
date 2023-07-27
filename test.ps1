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

# Function to append data to CSV
function Append-ToCSV {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$data,

        [Parameter(Mandatory = $true)]
        [string]$outputFilePath
    )

    # Check if the file exists
    if (Test-Path -Path $outputFilePath -PathType Leaf) {
        # Don't write the header again
        $data | Export-Csv -Path $outputFilePath -Append -NoTypeInformation
    }
    else {
        $data | Export-Csv -Path $outputFilePath -NoTypeInformation
    }
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
    $batchSize = 1000

    # iterate through each row in the csv
    foreach($row in $csvData){
        # append to results
        $results += Get-PostgreSqlServers -subscriptionName $row.SubscriptionName -resourceGroupName $row.ResourceGroupName

        # if results size is 1000 or more, append to the CSV file and clear results
        if($results.Count -ge $batchSize){
            Append-ToCSV -data $results -outputFilePath $outputFilePath
            $results = @()
        }
    }

    # export the remaining results to the csv file
    if($results.Count -gt 0){
        Append-ToCSV -data $results -outputFilePath $outputFilePath
    }
}

# calling the function
Export-PostgreSqlServersToCsv -inputFilePath 'C:\path\to\your\input.csv' -outputFilePath 'C:\path\to\your\output.csv'
