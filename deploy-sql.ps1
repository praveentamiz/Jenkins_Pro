Write-Host "====================================="
Write-Host "      SQL Deployment Started"
Write-Host "====================================="

# =====================================
# 🔧 CONFIGURATION (FROM JENKINS ENV)
# =====================================
$server       = $env:SQL_SERVER
$database     = $env:DATABASE
$baseFolder   = $env:SQL_FOLDER

$sqlFolder    = $baseFolder
$backupFolder = "$baseFolder\Backup"

Write-Host "Server        : $server"
Write-Host "Database      : $database"
Write-Host "SQL Folder    : $sqlFolder"
Write-Host "Backup Folder : $backupFolder"

# =====================================
# ✅ CHECK FOLDERS
# =====================================
if (!(Test-Path $sqlFolder)) {
    Write-Host "❌ SQL folder not found: $sqlFolder"
    exit 1
}

if (!(Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder | Out-Null
    Write-Host "✅ Backup folder created"
}

# =====================================
# ✅ CREATE DATABASE IF NOT EXISTS
# =====================================
Write-Host "Checking/Creating Database..."

sqlcmd -S $server -E -C -b -Q "
IF DB_ID('$database') IS NULL
BEGIN
    CREATE DATABASE [$database];
END
"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create database"
    exit 1
}

Write-Host "✅ Database Ready: $database"

# =====================================
# ✅ BACKUP DATABASE
# =====================================
Write-Host "Taking Database Backup..."

$timestamp  = Get-Date -Format "yyyyMMddHHmmss"
$backupFile = "$backupFolder\$database" + "_$timestamp.bak"

sqlcmd -S $server -E -C -b -Q "
BACKUP DATABASE [$database]
TO DISK = N'$backupFile'
WITH INIT, FORMAT
"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backup failed"
    exit 1
}

Write-Host "✅ Backup created: $backupFile"

# =====================================
# ✅ GET SQL FILES
# =====================================
$sqlFiles = Get-ChildItem -Path $sqlFolder -Filter *.sql -File | Sort-Object Name

if (!$sqlFiles) {
    Write-Host "❌ No SQL files found"
    exit 1
}

Write-Host "====================================="
Write-Host "Execution Order:"
$sqlFiles | ForEach-Object { Write-Host $_.Name }
Write-Host "====================================="

# =====================================
# ✅ EXECUTE SQL FILES (FIXED)
# =====================================
foreach ($file in $sqlFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Executing: $($file.Name)"

    # Read SQL file
    $content = Get-Content $file.FullName -Raw

    # 🔥 REMOVE ALL USE statements (fix your error)
    $content = $content -replace "(?i)USE\s+\[?.+?\]?\s*;?", ""

    # Add correct DB context at top
    $content = "USE [$database];`nGO`n" + $content

    # Save temp file
    $tempFile = "$env:TEMP\sql_$(Get-Random).sql"
    $content | Out-File -Encoding UTF8 $tempFile

    # Execute
    sqlcmd -S $server -E -C -b -i "$tempFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error in file: $($file.Name)"
        exit 1
    }

    Write-Host "✅ Success: $($file.Name)"

    Remove-Item $tempFile -Force
}

# =====================================
# ✅ DONE
# =====================================
Write-Host "====================================="
Write-Host " SQL Deployment Completed SUCCESSFULLY ✅"
Write-Host "====================================="
