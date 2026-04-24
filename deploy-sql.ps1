Write-Host "====================================="
Write-Host "   RESTORE ALL DATABASES STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server     = $env:SQL_SERVER
$baseFolder = $env:SQL_FOLDER

# 🔥 SET YOUR SQL DATA PATH HERE (IMPORTANT)
$dataPath = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\"

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
# GET ALL .BAK FILES
# =====================================
$bakFiles = Get-ChildItem -Path $baseFolder -Filter *.bak

foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    # Extract DB name
    $dbName = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $dbName"

    # =====================================
    # GET LOGICAL FILE NAMES (CORRECT WAY)
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
    # SET SINGLE USER
    # =====================================
    sqlcmd -S $server -E -C -Q "
    IF DB_ID('$dbName') IS NOT NULL
    BEGIN
        ALTER DATABASE [$dbName]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    "

    # =====================================
    # RESTORE WITH MOVE (FIX)
    # =====================================
    $mdf = "$dataPath$dbName.mdf"
    $ldf = "$dataPath$dbName.ldf"

    Write-Host "Restoring to:"
    Write-Host $mdf
    Write-Host $ldf

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

Write-Host "====================================="
Write-Host " ALL DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
