Write-Host "SQL Deployment Started"

$server = "localhost"
$database = "TEST_DB"

Get-ChildItem -Path ".\SQLFiles\*.sql" | ForEach-Object {
    Write-Host "Executing: $($_.Name)"

    sqlcmd -S $server -d $database -E -i $_.FullName -Encrypt Yes -TrustServerCertificate Yes

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error in $($_.Name)"
        exit 1
    }
}
