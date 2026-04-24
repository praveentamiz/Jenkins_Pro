Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# 🔧 CONFIGURATION (FROM JENKINS ENV)
# =====================================
$server     = $env:SQL_SERVER
$database   = $env:DATABASE
$baseFolder = $env:SQL_FOLDER

Write-Host "Server      : $server"
Write-Host "Database    : $database"
Write-Host "Backup Path : $baseFolder"

# =====================================
# ✅ CHECK BACKUP FOLDER
# =====================================
if (!(Test-Path $baseFolder)) {
    Write-Host "❌ Backup folder not found: $baseFolder"
    exit 1
}

# =====================================
# ✅ GET LATEST .BAK FILE
# =====================================
Write-Host "Searching for latest .bak file..."

$bakFile = Get-ChildItem -Path $baseFolder -Filter *.bak |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

if (!$bakFile) {
    Write-Host "❌ No .bak file found in $baseFolder"
    exit 1
}

$backupPath = $bakFile.FullName

Write-Host "✅ Selected Backup File:"
Write-Host $backupPath

# =====================================
# ✅ CHECK IF DATABASE EXISTS
# =====================================
$dbExists = sqlcmd -S $server -E -C -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name='$database'"

# =====================================
# ✅ SET SINGLE USER (IF EXISTS)
# =====================================
if ($dbExists -and $dbExists.Trim() -eq $database) {

    Write-Host "Setting database to SINGLE_USER mode..."

    sqlcmd -S $server -E -C -Q "
    ALTER DATABASE [$database]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    "
}

# =====================================
# ✅ RESTORE DATABASE
# =====================================
Write-Host "Restoring database..."

sqlcmd -S $server -E -C -b -Q "
RESTORE DATABASE [$database]
FROM DISK = N'$backupPath'
WITH REPLACE, RECOVERY, STATS = 10;
"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Restore failed"
    exit 1
}

# =====================================
# ✅ SET MULTI USER
# =====================================
Write-Host "Setting database to MULTI_USER mode..."

sqlcmd -S $server -E -C -Q "
ALTER DATABASE [$database]
SET MULTI_USER;
"

# =====================================
# ✅ VERIFY DATABASE
# =====================================
$dbCheck = sqlcmd -S $server -E -C -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name='$database'"

if (-not $dbCheck -or $dbCheck.Trim() -ne $database) {
    Write-Host "❌ Database restore verification failed"
    exit 1
}

# =====================================
# ✅ DONE
# =====================================
Write-Host "====================================="
Write-Host " Database Restored Successfully ✅"
Write-Host "====================================="
