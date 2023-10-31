function Get-Activities {
	param (
        [string]$base,
        [string]$project,
        [string]$directoryPath,
        [System.Collections.ArrayList]$files,
        [System.Collections.ArrayList]$trace,
        [System.Array]$DatabaseTableMappings
    )

    ################################
    # List files for analysis
	# Create an empty array to store file information
    $fileInfoArray = @()
    # Iterate through each file and gather information
    foreach ($file in $files) {
        $fileInfo = [PSCustomObject]@{
            FileName           = $file.Name
            FullName           = $file.FullName
            BaseName           = $file.BaseName
            Directory          = $file.Directory
            TaskNo             = [int](([regex]::Matches((Get-Item (Split-Path $file.FullName)).Name, '\d') | Select-Object -First 2 | ForEach-Object { $_.Value }) -join '')
            ActivityCompleted   = (Get-Item (Split-Path $file.FullName)).Name -replace '^\w+_\d{2}_', ''
            ActivityNo         = [int](Get-Item (Split-Path (Split-Path $file.FullName) -Parent)).Name.Substring(0,2)
            ActivityType       = (Get-Item (Split-Path (Split-Path $file.FullName) -Parent)).Name.Substring(3)
            Owner              = (Get-Acl $file.Directory).Owner
            Hash               = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
            FileType            = $file.Type
        }
        $fileInfoArray += $fileInfo
    }
	
	# Select unique activities and tasks only
    $distinctActivities = $fileInfoArray | Select-Object -Property TaskNo, ActivityNo -Unique

    ################################
	
	# Create object to store activities
    $activitiesInfoArray = @()

    # Generate activities descriptions
    foreach ($activity in $distinctActivities) {
        # Standard setup
        $temp = ($fileInfoArray | Where-Object { [int]$_.TaskNo -eq $activity.TaskNo -and $_.ActivityNo -eq $activity.ActivityNo})[0]
        $activityID = $base + $project + "/" + $temp.ActivityType + "/" + $temp.TaskNo + '/' + $temp.ActivityCompleted + "T00:00:00+00:00"
        $inputs = $fileInfoArray | Where-Object { [int]$_.TaskNo -eq $activity.TaskNo -and $_.ActivityNo-eq $activity.ActivityNo-1}
        $outputs = $fileInfoArray | Where-Object { $_.TaskNo -eq $activity.TaskNo -and $_.ActivityNo-eq $activity.ActivityNo}

        # Generate import info based on activity number (if 1 - NHS import then select databases as data sources if 2 - linkage then continue with default inputs based on files
        # If activity is Imported then find the matching source datasets and store any extra data sources
        if ($temp.ActivityNo -eq 1){
            
			$CurrentDataSources = @()
            $extraSources = @()

            foreach ($BaseName in $outputs.BaseName) { #todo
                foreach ($source in $DatabaseTableMappings.Table) {
                    if ($BaseName -match $source) {
                        $CurrentDataSources += $source
                        break
                        } 
                    }
                if (($BaseName -notmatch $source) -and ($BaseName -notin $extraSources) -and !($BaseName -match 'DLP') -and !($BaseName -match 'Link')){
                    $extraSources += $BaseName
                    }}
        $inputs = $CurrentDataSources
        }elseif ($temp.ActivityNo -eq 2){
        
                $inputs = $fileInfoArray | Where-Object { [int]$_.TaskNo -eq $activity.TaskNo -and $_.ActivityNo-eq $activity.ActivityNo-1}
                if ($inputs -eq $null){  
                    $inputs = $fileInfoArray | Where-Object { [int]$_.TaskNo -eq $activity.TaskNo-1 -and $_.ActivityNo-eq $activity.ActivityNo-1}     
                    $i = 2
                    while ('DLP' -cnotin $inputs.FileType){
                        $inputs = $fileInfoArray | Where-Object { [int]$_.TaskNo -eq $activity.TaskNo-$i -and $_.ActivityNo -eq $activity.ActivityNo-1 -and $_.FileType -eq 'DLP'}
                        $i++
                        }
                }
        }

        # Create activityInfo object
        $activityInfo = [PSCustomObject]@{

            '@id' =  $activityID

            '@type' = switch ($temp.ActivityNo){    
                    1{@("CreateAction", "shp_DashActivity")}
                    2{"CreateAction", "shp_IdLinkage"}
                    3{"CreateAction", "shp_ValidationCheck"}
                    4{"CreateAction", "shp_SignOff"}
                    5{"CreateAction", "shp_DatasetRelease"}
                    }
            agent = @(@{"@id" = ($base + "staff/" + $temp.Owner.Substring(4))})
            description = switch ($temp.ActivityNo){
                    1{"Analysts joined, filtered, deidentified with pseudo-UIDs and exported datasets from NHS/external sources."}
                    2{"Analyst replaced pseudo-UIDs imported from NHS and replaced with a new set of pseudo-UIDs linking all datasets."}
                    3{"A second analyst checked code and files."}
                    4{"Final check/sign off before data release."}
                    5{"Data made available to researchers."}
                    default {Write-Host("Activity number extracted from the folder is incorrect.")}
                    }
            endTime = $temp.ActivityCompleted + "T00:00:00+00:00"
            label = switch ($temp.ActivityNo){
                    1{"NHS Data Extraction"}
                    2{'Data Linkage'}
                    3{'Validation Check'}
                    4{'Sign off'}
                    5{'Data Release'}
                    default {Write-Host('Activity number extracted from the folder is incorrect.')}
                    }
			# Select inputs
            object = switch ($temp.ActivityNo) {
                    1 {@($inputs | ForEach-Object {@{"@id" = $base + "database/" + $_}})}
                    default{@($inputs | ForEach-Object {@{"@id" = $base + $project + "/" + $_.ActivityType + '/' + $_.TaskNo + '/' + $_.ActivityCompleted + '/' + $_.FileName}})}
                    }
            result = @($outputs | ForEach-Object {@{"@id" = $base + $project + "/" + $_.ActivityType + '/' + $_.TaskNo + '/' + $_.ActivityCompleted + '/' + $_.FileName}})
        }

	################################
    # Append single activityInfo to activitiesInfoArray
    $activitiesInfoArray += $activityInfo
	# Append to trace
    [void]($trace.Add($activityInfo))
    }
	
    return $activitiesInfoArray,  $fileInfoArray
}
