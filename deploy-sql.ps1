$sqlServer = $env:SQL_SERVER
$database  = $env:DATABASE
$sqlFolder = $env:SQL_FOLDER

Write-Host "SQL Deployment Started"

if (!(Test-Path $sqlFolder)) {
    Write-Host "SQL folder not found!"
    exit 1
}

$sql = "IF DB_ID('$database') IS NULL CREATE DATABASE [$database]"
sqlcmd -S $sqlServer -Q $sql -E

$files = Get-ChildItem -Path $sqlFolder -Filter *.sql | Sort-Object Name

foreach ($file in $files) {
    Write-Host "Executing: $($file.Name)"
    sqlcmd -S $sqlServer -d $database -E -i $file.FullName

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error in $($file.Name)"
        exit 1
    }
}

Write-Host "SQL Deployment Completed"
