param (
	[string]$baseIRI = "tre:",
	[string]$project = "project",
	[string]$directoryPath = ""
)

################################
# Setup variables
$provenanceDirPath = $directoryPath + "\Provenance\"

# This will store all the dynamically created description objects
$trace = [System.Collections.ArrayList]::new()

# Load additional files/functions
$DatabaseTableMappings = Join-Path -Path $PSScriptRoot -ChildPath "utils\DatabaseTableMappings.csv" | Import-CSV
$entities = Join-Path -Path $PSScriptRoot -ChildPath "functions\entities.ps1"
$entityStats = Join-Path -Path $PSScriptRoot -ChildPath "functions\entityStats.ps1"
$activities = Join-Path -Path $PSScriptRoot -ChildPath "functions\activities.ps1"

# Check if entities.ps1 exists and dot source it
if (Test-Path $entities -PathType Leaf) {. $entities} else { Write-Host "entities.ps1 was not found in the functions subfolder."}
# Check if entityStats.ps1 exists and dot source it
if (Test-Path $entityStats -PathType Leaf) {. $entityStats} else { Write-Host "entityStats.ps1 was not found in the functions subfolder."}
# Check if activities.ps1 exists and dot source it
if (Test-Path $activities -PathType Leaf) {. $activities} else { Write-Host "activities.ps1 was not found in the functions subfolder."}

################################
# LIST FILES FOR PROCESSING
$files = Get-ChildItem $directoryPath -Recurse -Include '*.*csv' | Where-Object { $_.PSIsContainer -eq $false }

# Flag DLP and Link files
$files = $files | Select-Object *, @{
    Name = 'Type'
    Expression = {	if ($_.BaseName -match 'DLP') {'DLP'}
					elseif ($_.BaseName -match 'Link') {'Link'} 
					else {'Data'}}
}

################################
# SEQUENTIAL PROCESSING
if ($files -ne $null) {
    $activities, $fileInfoArray = Get-Activities -base $baseIRI -project $project -directoryPath $directoryPath -files $files -trace $trace -DatabaseTableMappings $DatabaseTableMappings
    foreach ($file in $fileInfoArray) {
               if ($file.FileType -eq 'DLP'){
                   CreateDLPDescription -trace $trace -base $baseIRI -project $project -file $file -descriptionString 'DLP description.' -DatabaseTableMappings $DatabaseTableMappings
               }
               elseif ($file.FileType -eq 'Link' -or $file.FileType -eq 'Data'){
                   CreateDatasetDescription -trace $trace -base $baseIRI -project $project -file $file -description "Dataset description."
               }
               else {Write-Host "Found an extra file that's not data nor DLP nor Link:" + $file.FullName}
    }
}
 else {
    Write-Host "Failed to retrieve file paths."
}

################################
# WRITE OUTPUT TO JSON
# Create provenance directory if doesn't exist
if (-Not (Test-Path -Path $provenanceDirPath -PathType Container)) {
    New-Item -Path $provenanceDirPath -ItemType Directory
    Write-Host "Directory created successfully."
} else {
    Write-Host "Directory already exists."
}

# Define the paths to static context files
$context = Join-Path -Path $PSScriptRoot -ChildPath "static\context.json"
$context = Get-Content $context -Raw
$contextSHP = Join-Path -Path $PSScriptRoot -ChildPath "static\contextSHP.json"
$contextSHP = Get-Content $contextSHP -Raw

# Combine the two JSON strings
$combinedJsonString = '{"@context": [' + $context + ',' + $contextSHP + '], "@graph": ' + ($trace | ConvertTo-Json -Depth 10) + '}'

# Save the combined JSON to a new file
$combinedFilePath = ($directoryPath + "\Provenance\" + "provenanceFull.jsonld")
$combinedJsonString | Set-Content -Path $combinedFilePath

# Add empty comments json file
'' | Set-Content -Path ($directoryPath + "\Provenance\" + "comments.jsonld")

Write-Host 'Provenance trace for ' + $project + 'has been created.'