Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# CONFIGURATION
# =====================================
$server    = "CICD-SERVER"
$backupDir = "C:\SQLBackups"

# ✅ Stable connection (fixes SSL + session issue)
$conn = "$server;TrustServerCertificate=True"

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
# GET QA BACKUP FILES
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

    $database   = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $database"

    # =====================================
    # FORCE DISCONNECT
    # =====================================
    sqlcmd -S $conn -E -Q "
    IF DB_ID('$database') IS NOT NULL
    BEGIN
        ALTER DATABASE [$database]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    "

    # =====================================
    # RESTORE
    # =====================================
    Write-Host "Restoring database..."

    sqlcmd -S $conn -E -b -Q "
    RESTORE DATABASE [$database]
    FROM DISK = N'$backupPath'
    WITH REPLACE, RECOVERY, STATS = 5;
    "

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Restore failed for $database"
        exit 1
    }

    # =====================================
    # MULTI USER
    # =====================================
    sqlcmd -S $conn -E -Q "
    ALTER DATABASE [$database] SET MULTI_USER;
    "

    Write-Host "✅ Restored: $database"
}

# =====================================
# DONE
# =====================================
Write-Host "====================================="
Write-Host "   ALL QA DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
