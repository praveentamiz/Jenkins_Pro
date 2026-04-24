Write-Host "====================================="
Write-Host "   RESTORE ALL DATABASES STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server     = $env:SQL_SERVER
$baseFolder = $env:SQL_FOLDER

Write-Host "Server      : $server"
Write-Host "Backup Path : $baseFolder"

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

if (!$bakFiles) {
    Write-Host "❌ No .bak files found"
    exit 1
}

Write-Host "Found $($bakFiles.Count) backup files"

# =====================================
# LOOP THROUGH EACH BACKUP
# =====================================
foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    # =====================================
    # EXTRACT DATABASE NAME
    # =====================================
    # Example:
    # ADPL_QMS_QA_20260424.bak → ADPL_QMS_QA
    $dbName = ($bak.BaseName -replace "_\d{8}.*", "")

    Write-Host "Target DB: $dbName"

    $backupPath = $bak.FullName

    # =====================================
    # SET SINGLE USER (IF EXISTS)
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
    Write-Host "Restoring $dbName..."

    sqlcmd -S $server -E -C -b -Q "
    RESTORE DATABASE [$dbName]
    FROM DISK = N'$backupPath'
    WITH REPLACE, RECOVERY, STATS = 5;
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
Write-Host " ALL DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
