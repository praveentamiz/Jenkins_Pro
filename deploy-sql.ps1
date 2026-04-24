Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# CONFIGURATION
# =====================================
$server    = "CICD-SERVER"
$backupDir = "C:\SQLBackups"

Write-Host "Server      : $server"
Write-Host "Backup Path : $backupDir"

# =====================================
# CHECK BACKUP FOLDER
# =====================================
if (!(Test-Path $backupDir)) {
    Write-Host "❌ Backup folder not found: $backupDir"
    exit 1
}

# =====================================
# GET QA BACKUP FILES ONLY
# =====================================
$bakFiles = Get-ChildItem -Path $backupDir -Filter "*_QA_*.bak"

if (!$bakFiles) {
    Write-Host "❌ No QA backup files found"
    exit 1
}

Write-Host "====================================="
Write-Host "QA Backup Files Found:"
$bakFiles | ForEach-Object { Write-Host $_.Name }
Write-Host "====================================="

# =====================================
# LOOP AND RESTORE
# =====================================
foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    # Extract DB name
    $database = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $database"

    # =====================================
    # FORCE DISCONNECT USERS
    # =====================================
    sqlcmd -S $server -E -TrustServerCertificate -Q "
    IF DB_ID('$database') IS NOT NULL
    BEGIN
        ALTER DATABASE [$database]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    "

    # =====================================
    # SIMPLE RESTORE (LIKE YOUR OLD STYLE)
    # =====================================
    Write-Host "Restoring database..."

    sqlcmd -S $server -E -TrustServerCertificate -b -Q "
    RESTORE DATABASE [$database]
    FROM DISK = N'$backupPath'
    WITH REPLACE, RECOVERY, STATS = 5;
    "

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Restore failed for $database"
        exit 1
    }

    # =====================================
    # SET MULTI USER
    # =====================================
    sqlcmd -S $server -E -TrustServerCertificate -Q "
    ALTER DATABASE [$database] SET MULTI_USER;
    "

    Write-Host "✅ Restored: $database"
}

# =====================================
# DONE
# =====================================
Write-Host "====================================="
Write-Host "   ALL QA DATABASES RESTORED ✅"
Write-Host "====================================="
