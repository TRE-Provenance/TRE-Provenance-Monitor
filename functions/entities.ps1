function CreateDatasetDescription {
   param (
       [System.Collections.ArrayList]$trace,
	   [string]$base,
	   [string]$project,
	   [System.Object]$file,
	   [string]$descriptionString	   
   )
    $entityId = $base + $project + '/' + $file.ActivityType + '/' + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName

	$dataset = @{
		'@id' = $entityId		
		'@type' = @( "File", "shp_DataSet" )		
		description = $descriptionString		
		label = $file.FileName
		path = $file.FullName.Replace('\', '/')
		shp_hash = $file.Hash
	}	

	#Add exif data 
	Get-ExifDataForEntity -entityId $entityId -trace $trace -dataset $dataset -filePath $file.FullName
}

function Get-ExifDataForEntity {
    param (
        [string]$entityId,
        [string]$base,
        [string]$project,
		[System.Collections.ArrayList]$trace,
		[hashtable]$dataset, 
		[string]$filePath,
        [string]$provenanceDirPath
    )  
	
	$selectedVariablesId = @{
		'@id' = $base + $project + $entityId + "#selectedVariables"
	}
	
	$summaryStats = @{
		'@id' = $base + $project + $entityId + "#summaryStats"
	}
	$exif = @()
	$exif +=  $summaryStats 
	$exif +=  $selectedVariablesId	
	$stats = Get-FileStats -InputFilePath $filePath
	$columnStats = $stats["columns"]
	
	foreach ($item in $columnStats) {	
		$statId = @{
			'@id' = $base + $project + $entityId + "#"+ $item["Name"]
		}
		
		$exif +=  $statId
		
		$statIdObj = @{
			'@id' = $base + $project + $entityId + "#" + $item["Name"]	
			'@type' = @( "shp_EntityCharacteristic")
		}
		if ($item['IsNumeric']) {

			$statIdObj["shp_dataType"] = "numeric"  		
			$statIdObj["shp_minValue"] = @{
										   '@value' =  $item['MinValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#double"
										  }
			$statIdObj["shp_maxValue"] = @{
										   '@value' =  $item['MaxValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#double"
										  }
		}
		elseif ($item['IsDate']) {
			
			$statIdObj["shp_dataType"] = "date"		
			$statIdObj["shp_minValue"] = @{
										   '@value' =  $item['MinValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#date"
										  }
			$statIdObj["shp_maxValue"] = @{
										   '@value' =  $item['MaxValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#date"
											}
		}
		else {
			
			$statIdObj["shp_dataType"] = "string" 		
			$statIdObj["shp_minValue"] = @{
										   '@value' =  $item['MinValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#string"
										  }
			$statIdObj["shp_maxValue"] = @{
										   '@value' =  $item['MaxValue']
											'@type' =  "http://www.w3.org/2001/XMLSchema#string"
										  }
		}
		# Add to trace
		[void]($trace.Add($statIdObj))	
	}
	
	$summaryStatsObj = @{
		
		'@id' = $base + $project + $entityId + "#summaryStats"		
		'@type' = @( "shp_EntityCharacteristic")		
		shp_rowCount = @{
		'@value' =  $stats["rowCount"]
		'@type' =  "http://www.w3.org/2001/XMLSchema#integer"
		}		
		shp_targetFile = $base + $project + $entityId
	}
	
	$dataset["exifData"] = @($exif)
	# Add outputs to provenance trace
	[void]($trace.Add($dataset))
	[void]($trace.Add($summaryStatsObj))

}

function Get-AllCSVColumns {
    param (
        [string]$filePath
    )

    # Validate that the file exists
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        Write-Host "File not found: $filePath"
        return
    }

    # Open the CSV file for reading as a stream
    $reader = [System.IO.File]::OpenText($filePath)

    try {
        # Read the first line to get the header
        $headerLine = $reader.ReadLine()
        if ($headerLine -eq $null) {
            Write-Host "File is empty: $filePath"
            return
        }

        # Split the header line to get column names
        $headerColumns = $headerLine.Split(',')

        return $headerColumns
    }
    finally {
        $reader.Close()
    }
}

function CreateDLPDescription {
   param (
       [System.Collections.ArrayList]$trace,
	   [string]$base,
	   [string]$project,
	   [System.Object]$file,
	   [string]$descriptionString,
       [System.Array]$DatabaseTableMappings
   )

   # Import DLP
    $DLP = Import-Csv -path $file.FullName
    $DLP = $DLP | Sort-Object Source_dataset
	# Since source databases can have multiple source tables a mapping using imported static mapping file needs to be created
    $DLP | ForEach-Object {
        $row = $_
        $matchingRow = $DatabaseTableMappings | Where-Object {$row.Source_dataset -match  $_.Table}
        $row | Add-Member -MemberType NoteProperty -Name Database -Value $matchingRow.Database}

    $DLPInfo = [PSCustomObject]@{

	    '@id' = $base + $project + "/" + $file.ActivityType + "/" + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName
	    '@type' = @( "File", "shp_DataLinkagePlan")
	    description = 'Data Linkage Plan for ' + $project + '. Version ' + $file.TaskNo
	    label = 'DLP'
        path = $file.FullName.Replace('\', '/')
        shp_hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
	    wasAttributedTo = @{'@id' = $base + "staff/" + ((Get-Acl $file.FullName).Owner -replace '^[A-Za-z]+\\', '')}
        "exifData" = @(
			$DLP.Database | Select-Object -Unique |  foreach {
				@{'@id' = $base + $project + "/" + $file.ActivityType + "/" + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName + '#' + 'DataSource.' + $_}}
        )
    }

    $shp_LinkagePlanDataSources = [System.Collections.ArrayList]::new()
    $shp_RequestedVariables = [System.Collections.ArrayList]::new()
    $shp_VariableConstraints = [System.Collections.ArrayList]::new()
    $temp_shp_RequestedVariables = [System.Collections.ArrayList]::new()

    $i = 0
    foreach ($Variable in $DLP){
        $i++
        if($Variable.Requested -eq 1){        
            if(-not ($shp_LinkagePlanDataSources.'@id' -match $Variable.Database)){ # if new source only
                if(-not($shp_LinkagePlanDataSource.'@id' -match $Variable.Database)){ # if old source in buffer
                    if ($temp_shp_RequestedVariables.hadMember.Count -ne 0){
                        [void]($shp_LinkagePlanDataSources.Add($shp_LinkagePlanDataSource)) # unload to the top array
                        [void]($shp_RequestedVariables.Add($temp_shp_RequestedVariables)) # unload to the top array
                    }
                $shp_LinkagePlanDataSource = [PSCustomObject]@{
                    '@id' = $base + $project + "/" + $file.ActivityType + "/" + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName + '#' + 'DataSource.' + $Variable.Database
                    '@type' = @('shp_LinkagePlanDataSource')
                    'label' = $Variable.Database + ' Data Source'
                    'shp_database' = @{'@id' = $base + 'database/' + $Variable.Database}
                    'shp_requestedVariables' = @{'@id' = $base + $project + "/" + $file.ActivityType + "/" + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName + '#' + 'RequestedVariables.' + $Variable.Database}
                    'shp_constraint' = @{} ## todo
                    }    
                $temp_shp_RequestedVariables = [PSCustomObject]@{
                    '@id' = [string]$shp_LinkagePlanDataSource.shp_requestedVariables.Values
                    '@type' = 'shp_RequestedVariables'
                    'hadMember' = @()
                    }
                }
            }

			$RequestedVar = @{'@id' = $base + $Variable.Database + '/variable/' + $Variable.Variable}
			$temp_shp_RequestedVariables.hadMember += $RequestedVar

			if($Variable.Max.Length -ne 0 -or $Variable.Min.Length -ne 0){
				$id = $base + $project + "/" + $file.ActivityType + "/" + $file.TaskNo + '/' + $file.ActivityCompleted + '/' + $file.FileName + '#' + 'VariableConstraint.' + $Variable.Database + '_' + $Variable.Variable
				
				$shp_LinkagePlanDataSource.shp_constraint = @{'@id' = $id}

				$shp_VariableContraint = [PSCustomObject]@{
					'@id' = $id
					'@type' = 'shp_VariableConstraint'
					'shp_minValue' = @(
						@{'@value' = $Variable.Min}
						@{'@type' = "http://www.w3.org/2001/XMLSchema#date"}
						)
					'shp_maxValue' = @(
						@{'@value' = $Variable.Max}
						@{'@type' = "http://www.w3.org/2001/XMLSchema#date"}
						)
					'shp_targetFeature' = @{
						'@id' = $base + $Variable.Database + '/variable/' + $Variable.Variable}
				}
			
				[void]($shp_VariableConstraints.Add($shp_VariableContraint))

			}

			if($i -eq $DLP.Length){ # if the last variable
				[void]($shp_LinkagePlanDataSources.Add($shp_LinkagePlanDataSource)) # unload to the top array
				[void]($shp_RequestedVariables.Add($temp_shp_RequestedVariables)) # unload to the top array
			}

			$shp_Variable = [PSCustomObject]@{
				"@id" = $base + $Variable.Database + '/variable/' + $Variable.Variable
				"@type" = "shp_Variable"
				"label"  = $Variable.Label}

			[void]($trace.Add($shp_Variable))

        }
    }     

	# Add outputs to provencance trace
    [void]($trace.Add($DLPInfo))
    foreach($shp_LinkagePlanDataSource in $shp_LinkagePlanDataSources){[void]($trace.Add($shp_LinkagePlanDataSource))}  
    foreach($shp_RequestedVariable in $shp_RequestedVariables){[void]($trace.Add($shp_RequestedVariable))}
    foreach($shp_VariableConstraint in $shp_VariableConstraints){[void]($trace.Add($shp_VariableConstraint))}
}