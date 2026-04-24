Write-Host "====================================="
Write-Host "   RESTORE QA DATABASES STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server     = "localhost"
$baseFolder = "C:\SQLBackups"

# ✅ SQL DATA PATH
$dataPath = "C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\"

Write-Host "Server      : $server"
Write-Host "Backup Path : $baseFolder"
Write-Host "Data Path   : $dataPath"

# =====================================
# CHECK FOLDER
# =====================================
if (!(Test-Path $baseFolder)) {
    Write-Host "❌ Backup folder not found"
    exit 1
}

# =====================================
# GET QA BACKUPS
# =====================================
$bakFiles = Get-ChildItem -Path $baseFolder -Filter "*_QA_*.bak"

if (!$bakFiles) {
    Write-Host "❌ No QA backup files found"
    exit 1
}

Write-Host "Found $($bakFiles.Count) QA backup files"

# =====================================
# LOOP
# =====================================
foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    $dbName = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $dbName"

    # =====================================
    # GET LOGICAL FILE NAMES (CORRECT WAY)
    # =====================================
    $query = @"
SET NOCOUNT ON;
SELECT name, type_desc
FROM sys.master_files
WHERE database_id = DB_ID('$dbName');
"@

    # If DB doesn't exist, use FILELISTONLY
    $fileList = sqlcmd -S $server -E -h -1 -W -Q "
    SET NOCOUNT ON;
    RESTORE FILELISTONLY FROM DISK = N'$backupPath';
    " | Where-Object { $_ -and $_ -notmatch "----" }

    $dataLogical = ($fileList | Where-Object { $_ -match "D" })[0].Split()[0]
    $logLogical  = ($fileList | Where-Object { $_ -match "L" })[0].Split()[0]

    Write-Host "Data Logical: $dataLogical"
    Write-Host "Log Logical : $logLogical"

    # =====================================
    # FORCE DISCONNECT
    # =====================================
    sqlcmd -S $server -E -Q "
    IF DB_ID('$dbName') IS NOT NULL
    BEGIN
        ALTER DATABASE [$dbName]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    "

    # =====================================
    # RESTORE
    # =====================================
    $mdf = "$dataPath$dbName.mdf"
    $ldf = "$dataPath$dbName.ldf"

    sqlcmd -S $server -E -b -Q "
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

    sqlcmd -S $server -E -Q "
    ALTER DATABASE [$dbName] SET MULTI_USER;
    "

    Write-Host "✅ Restored: $dbName"
}

Write-Host "====================================="
Write-Host " QA DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
