Write-Host "====================================="
Write-Host "      SQL Deployment Started"
Write-Host "====================================="

# CONFIG
$server   = "CICD-SERVER"
$database = "CDPL_GMP_DEV"
$sqlFolder = "C:\BuildOutput\SQLFiles"

Write-Host "Server      : $server"
Write-Host "Database    : $database"
Write-Host "SQL Folder  : $sqlFolder"

# Check folder
if (!(Test-Path $sqlFolder)) {
    Write-Host "❌ SQL folder not found: $sqlFolder"
    exit 1
}

# Create DB
Write-Host "Checking/Creating Database..."

sqlcmd -S $server -E -C -b -Q "
IF DB_ID('$database') IS NULL
BEGIN
    CREATE DATABASE [$database];
    PRINT 'DB Created';
END
ELSE
BEGIN
    PRINT 'DB Already Exists';
END
"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create database"
    exit 1
}

# Verify DB
$dbCheck = sqlcmd -S $server -E -C -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name='$database'"

if (-not $dbCheck -or $dbCheck.Trim() -ne $database) {
    Write-Host "❌ Database does not exist"
    exit 1
}

Write-Host "✅ Database verified: $database"

# Get files
$sqlFiles = Get-ChildItem -Path $sqlFolder -Filter *.sql -Recurse | Sort-Object Name

if (!$sqlFiles -or $sqlFiles.Count -eq 0) {
    Write-Host "❌ No SQL files found"
    exit 1
}

# Execute
foreach ($file in $sqlFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Executing: $($file.FullName)"

    sqlcmd -S $server -d $database -E -C -b -i "$($file.FullName)"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error in $($file.Name)"
        exit 1
    } else {
        Write-Host "✅ Success: $($file.Name)"
    }
}

Write-Host "====================================="
Write-Host "   SQL Deployment Completed ✅"
Write-Host "====================================="
