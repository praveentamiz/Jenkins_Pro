Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server     = $env:SQL_SERVER
$database   = $env:DATABASE
$baseFolder = $env:SQL_FOLDER

Write-Host "Server      : $server"
Write-Host "Database    : $database"
Write-Host "Backup Path : $baseFolder"

# =====================================
# CHECK FOLDER
# =====================================
if (!(Test-Path $baseFolder)) {
    Write-Host "❌ Backup folder not found"
    exit 1
}

# =====================================
# GET LATEST .BAK FILE
# =====================================
$bakFile = Get-ChildItem -Path $baseFolder -Filter *.bak |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

if (!$bakFile) {
    Write-Host "❌ No .bak file found"
    exit 1
}

$backupPath = $bakFile.FullName
Write-Host "Using Backup File: $backupPath"

# =====================================
# FORCE DISCONNECT USERS
# =====================================
sqlcmd -S $server -E -C -Q "
IF DB_ID('$database') IS NOT NULL
BEGIN
    ALTER DATABASE [$database]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
"

# =====================================
# SIMPLE RESTORE (NO MOVE)
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
# SET MULTI USER
# =====================================
sqlcmd -S $server -E -C -Q "
ALTER DATABASE [$database] SET MULTI_USER;
"

# =====================================
# VERIFY DATA
# =====================================
Write-Host "Verifying data..."

$tableCount = sqlcmd -S $server -E -C -h -1 -Q "
SET NOCOUNT ON;
SELECT COUNT(*) FROM sys.tables;
"

Write-Host "Tables Count: $tableCount"

# =====================================
# DONE
# =====================================
Write-Host "====================================="
Write-Host " Database Restored WITH DATA ✅"
Write-Host "====================================="
