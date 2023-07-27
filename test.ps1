# Function to get the PostgreSQL servers for a given subscription and optionally a resource group
function Get-PostgreSqlServers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$subscriptionId,
        
        [string]$resourceGroupName
    )

    # Set the context to the specified subscription
    Set-AzContext -Subscription $subscriptionId

    # prepare the query string
    if($resourceGroupName){
        $queryString = "where type =~ 'Microsoft.DbforPostgreSQL/servers' and resourceGroup == '$resourceGroupName' | project name, type, location, resourceGroup"
    }
    else {
        $queryString = "where type =~ 'Microsoft.DbforPostgreSQL/servers' | project name, type, location, resourceGroup"
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
        [string]$outputFilePath,
        
        [Parameter(Mandatory = $true)]
        [int]$startIndex,
        
        [Parameter(Mandatory = $true)]
        [int]$endIndex
    )

    # import CSV file
    $csvData = Import-Csv -Path $inputFilePath

    # Prepare the output data
    $results = @()
    $totalCount = $endIndex - $startIndex + 1
    $currentCount = 0

    # iterate through each row in the csv in the specified range
    for ($i = $startIndex; $i -le $endIndex; $i++){
        $row = $csvData[$i]
        # append to results
        $results += Get-PostgreSqlServers -subscriptionId $row.SubscriptionId -resourceGroupName $row.ResourceGroupName
        Append-ToCSV -data $results -outputFilePath $outputFilePath
        $results = @()

        # increment the current count and display the progress bar
        $currentCount++
        $progress = ($currentCount / $totalCount) * 100
        Write-Progress -Activity "Searching for PostgreSQL servers" -Status "$progress% Complete:" -PercentComplete $progress
    }
}

# import CSV file
$csvData = Import-Csv -Path 'C:\path\to\your\input.csv'

# Determine batch size and total number of batches
$batchSize = 1000
$totalBatches = [math]::Ceiling($csvData.Count / $batchSize)

# Iterate through each batch and call Export-PostgreSqlServersToCsv
for ($i = 0; $i -lt $totalBatches; $i++) {
    $startIndex = $i * $batchSize
    $endIndex = $startIndex + $batchSize - 1
    if ($endIndex -gt $csvData.Count - 1) {
        $endIndex = $csvData.Count - 1
    }

    Export-PostgreSqlServersToCsv -inputFilePath 'C:\path\to\your\input.csv' -outputFilePath 'C:\path\to\your\output.csv' -startIndex $startIndex -endIndex $endIndex
}
