Write-Host "SQL Deployment Started"

$server = "localhost"
$database = "TEST_DB"

# ✅ Create DB if not exists
sqlcmd -S $server -E -Q "IF DB_ID('$database') IS NULL CREATE DATABASE [$database]" -Encrypt Yes -TrustServerCertificate Yes

# ✅ Execute SQL files
$path = ".\repo\SQLFiles\*.sql"

Write-Host "Looking in path: $path"

Get-ChildItem -Path $path | ForEach-Object {
    Write-Host "Executing: $($_.Name)"

    sqlcmd -S $server -d $database -E -i $_.FullName -Encrypt Yes -TrustServerCertificate Yes

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error in $($_.Name)"
        exit 1
    } else {
        Write-Host "✅ Success: $($_.Name)"
    }
}
