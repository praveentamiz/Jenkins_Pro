Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# 🔧 CONFIG
# =====================================
$server     = $env:SQL_SERVER
$database   = $env:DATABASE
$baseFolder = $env:SQL_FOLDER

Write-Host "Server      : $server"
Write-Host "Database    : $database"
Write-Host "Backup Path : $baseFolder"

# =====================================
# ✅ CHECK FOLDER
# =====================================
if (!(Test-Path $baseFolder)) {
    Write-Host "❌ Backup folder not found"
    exit 1
}

# =====================================
# ✅ GET LATEST BAK FILE
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
# ✅ GET LOGICAL FILE NAMES (IMPORTANT)
# =====================================
Write-Host "Reading logical file names..."

$logicalFiles = sqlcmd -S $server -E -C -Q "RESTORE FILELISTONLY FROM DISK = N'$backupPath'" | Out-String

if (!$logicalFiles) {
    Write-Host "❌ Unable to read backup file"
    exit 1
}

# Extract logical names (simple parsing)
$dataLogical = ($logicalFiles | Select-String "ROWS").ToString().Split()[0]
$logLogical  = ($logicalFiles | Select-String "LOG").ToString().Split()[0]

Write-Host "Data Logical File : $dataLogical"
Write-Host "Log Logical File  : $logLogical"

# =====================================
# ✅ SET SINGLE USER
# =====================================
sqlcmd -S $server -E -C -Q "
IF DB_ID('$database') IS NOT NULL
BEGIN
    ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
"

# =====================================
# ✅ RESTORE DATABASE WITH MOVE (CRITICAL)
# =====================================
Write-Host "Restoring database with data..."

$sqlRestore = @"
RESTORE DATABASE [$database]
FROM DISK = N'$backupPath'
WITH REPLACE,
MOVE '$dataLogical' TO 'C:\Program Files\Microsoft SQL Server\MSSQL\Data\$database.mdf',
MOVE '$logLogical'  TO 'C:\Program Files\Microsoft SQL Server\MSSQL\Data\$database.ldf',
RECOVERY,
STATS = 10;
"@

sqlcmd -S $server -E -C -b -Q $sqlRestore

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Restore failed"
    exit 1
}

# =====================================
# ✅ SET MULTI USER
# =====================================
sqlcmd -S $server -E -C -Q "
ALTER DATABASE [$database] SET MULTI_USER;
"

# =====================================
# ✅ VERIFY DATA EXISTS
# =====================================
Write-Host "Verifying data..."

$tableCheck = sqlcmd -S $server -E -C -h -1 -Q "
SET NOCOUNT ON;
SELECT TOP 1 name FROM sys.tables;
"

if (-not $tableCheck) {
    Write-Host "⚠️ Database restored but no tables found"
}
else {
    Write-Host "✅ Data verified: Tables exist"
}

# =====================================
# ✅ DONE
# =====================================
Write-Host "====================================="
Write-Host " Database Restored WITH DATA ✅"
Write-Host "====================================="
