Write-Host "====================================="
Write-Host "   RESTORE QA DATABASES STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server     = "localhost"
$baseFolder = "C:\SQLBackups"

# ✅ Your SQL DATA path (correct)
$dataPath = "C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\"

Write-Host "Server      : $server"
Write-Host "Backup Path : $baseFolder"
Write-Host "Data Path   : $dataPath"

# =====================================
# CHECK FOLDER
# =====================================
if (!(Test-Path $baseFolder)) {
    Write-Host "❌ Backup folder not found: $baseFolder"
    exit 1
}

# =====================================
# GET ONLY QA BACKUPS
# =====================================
$bakFiles = Get-ChildItem -Path $baseFolder -Filter "*_QA_*.bak"

if (!$bakFiles) {
    Write-Host "❌ No QA backup files found in $baseFolder"
    exit 1
}

Write-Host "Found $($bakFiles.Count) QA backup files"

# =====================================
# LOOP THROUGH QA FILES
# =====================================
foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    # Extract DB name
    $dbName = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $dbName"

    # =====================================
    # GET LOGICAL FILE NAMES
    # =====================================
    $fileList = sqlcmd -S $server -E -C -s "," -W -Q "
    SET NOCOUNT ON;
    RESTORE FILELISTONLY FROM DISK = N'$backupPath'
    "

    $lines = $fileList | Where-Object { $_ -and $_ -notmatch "LogicalName" }

    $dataLogical = ($lines[0] -split ",")[0]
    $logLogical  = ($lines[1] -split ",")[0]

    Write-Host "Data Logical: $dataLogical"
    Write-Host "Log Logical : $logLogical"

    # =====================================
    # FORCE DISCONNECT USERS
    # =====================================
    sqlcmd -S $server -E -C -Q "
    IF DB_ID('$dbName') IS NOT NULL
    BEGIN
        ALTER DATABASE [$dbName]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    "

    # =====================================
    # RESTORE DATABASE
    # =====================================
    $mdf = "$dataPath$dbName.mdf"
    $ldf = "$dataPath$dbName.ldf"

    Write-Host "Restoring database..."

    sqlcmd -S $server -E -C -b -Q "
    RESTORE DATABASE [$dbName]
    FROM DISK = N'$backupPath'
    WITH REPLACE,
    MOVE '$dataLogical' TO '$mdf',
    MOVE '$logLogical'  TO '$ldf',
    RECOVERY, STATS = 5;
    "

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Restore failed for $dbName"
        exit 1
    }

    # =====================================
    # SET MULTI USER
    # =====================================
    sqlcmd -S $server -E -C -Q "
    ALTER DATABASE [$dbName] SET MULTI_USER;
    "

    Write-Host "✅ Restored: $dbName"
}

# =====================================
# DONE
# =====================================
Write-Host "====================================="
Write-Host " QA DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
