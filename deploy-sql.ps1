Write-Host "====================================="
Write-Host "      SQL Deployment Started"
Write-Host "====================================="

$server = "localhost"
$database = "TEST_DB"
$sqlPath = ".\repo\SQLFiles\*.sql"

# ✅ Create DB
Write-Host "Checking/Creating Database..."

sqlcmd -S $server -E -Q "IF DB_ID('$database') IS NULL BEGIN CREATE DATABASE [$database]; PRINT 'DB Created'; END ELSE PRINT 'DB Already Exists';"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create database"
    exit 1
}

# ✅ Verify
sqlcmd -S $server -E -Q "SELECT name FROM sys.databases WHERE name='$database'"

# ✅ Get SQL files
$files = Get-ChildItem -Path $sqlPath -ErrorAction SilentlyContinue

if (!$files -or $files.Count -eq 0) {
    Write-Host "❌ No SQL files found!"
    exit 1
}

# ✅ Execute
foreach ($file in $files) {
    Write-Host "Executing: $($file.Name)"

    sqlcmd -S $server -d $database -E -i "$($file.FullName)"

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
