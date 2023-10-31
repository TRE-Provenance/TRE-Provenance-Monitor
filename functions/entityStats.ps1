# Custom CSV parsing function
function Parse-CsvLine($line) {
        $escaped = $false
        $values = @()
        $currentValue = ""
         foreach ($char in $line.ToCharArray()) {
            if ($char -eq '"') {
                $escaped = !$escaped
            } elseif ($char -eq ',' -and !$escaped) {
                $values += $currentValue
                $currentValue = ""
            } else {
                $currentValue += $char
            }
        }
        $values += $currentValue
        return $values
    }
     # List of common date formats
    $dateFormats = @(
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "dd/MM/yyyy",
        "yyyy-MM-dd HH:mm:ss",
        "MM/dd/yyyy HH:mm:ss",
        "dd/MM/yyyy HH:mm:ss",
        "yyyy-MM-ddTHH:mm:ss",
        "yyyy-MM-ddTHH:mm:ss.fffffff",
        "yyyy-MM-ddTHH:mm:ssZ",
        "yyyy-MM-ddTHH:mm:ss.fffffffZ",
        "yyyy-MM-ddTHH:mm:sszzz",
        "yyyy-MM-ddTHH:mm:ss.fffffffzzz"
)

function Check-Date ($stringToCheck) {
    # Check if the string is a valid date using each format
    $isValidDate = $false
    $validFormat = $null
    foreach ($format in $dateFormats) {
		try {
			$date = Get-Date -Date $stringToCheck -Format $format -ErrorAction:SilentlyContinue
			}
			catch{}
			if ($date -ne $null) {
				$isValidDate = $true
				$validFormat = $format
				break
			}
    }
    return $isValidDate
}

function Get-Date-Custom ($stringToCheck) {
    # Check if the string is a valid date using each format
    $isValidDate = $false
    $validFormat = $null

    foreach ($format in $dateFormats) {
		try{
			$date = Get-Date -Date $stringToCheck -Format $format -ErrorAction:SilentlyContinue
			}
			catch{}

			if ($date -ne $null) {
				break
			}
    }
    return $date
}
 
function Get-FileStats  {
	param (
		[string]$InputFilePath
	)
    # Open a StreamReader to read the CSV file
    $streamReader = [System.IO.StreamReader]::new($InputFilePath)

    $numberOfRows = 0
    $columnData = @()

    # Read the header line to identify columns
    $headerLine = $streamReader.ReadLine()
    $columns = Parse-CsvLine $headerLine

    foreach ($column in $columns) {
        $columnData += @{
            'Name' = $column
            'IsNumeric' = $false
            'IsDate' = $false
            'MinValue' = $null
            'MaxValue' = $null
            'Sum' = 0
            'SumSquares' = 0
            'Count' = 0
        }
    }
    # Read the file line by line and process data
    while ($line = $streamReader.ReadLine()) {
        $numberOfRows++
        $values = Parse-CsvLine $line

        for ($i = 0; $i -lt $values.Count; $i++) {
            $value = $values[$i]
            $column = $columnData[$i]
            if (-not $column['IsNumeric'] -and [double]::TryParse($value, [ref]$null)) {
                $column['IsNumeric'] = $true
            }
            $check =Check-Date ($value) 
            if (-not $column['IsDate'] -and   $check) {
                $column['IsDate'] = $true
            }
            if ($column['IsNumeric']) {
                $parsedValue = [double]$value
                $column['Count']++
                $column['SumSquares'] += $parsedValue * $parsedValue

                if ($column['MinValue'] -eq $null -or $parsedValue -lt $column['MinValue']) {
                    $column['MinValue'] = $parsedValue
                }
                if ($column['MaxValue'] -eq $null -or $parsedValue -gt $column['MaxValue']) {
                    $column['MaxValue'] = $parsedValue
                }
            } elseif ($column['IsDate']) {
                $parsedDate = Get-Date-Custom ($value)
                if ($column['MinValue'] -eq $null -or $parsedDate -lt $column['MinValue']) {
                    $column['MinValue'] = $parsedDate
                }
                if ($column['MaxValue'] -eq $null -or $parsedDate -gt $column['MaxValue']) {
                    $column['MaxValue'] = $parsedDate
                }
            }
            $columnData[$i] = $column
        }
    }
    # Close the StreamReader
    $streamReader.Close()
    $result = @{}
    $result["columns"] = $columnData
    $result["rowCount"] = $numberOfRows
    return $result
}