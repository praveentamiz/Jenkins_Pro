Write-Host "====================================="
Write-Host "      SQL RESTORE STARTED"
Write-Host "====================================="

# =====================================
# CONFIG
# =====================================
$server    = "CICD-SERVER"
$backupDir = "C:\SQLBackups"

# ✅ FIX: Proper connection string
$connectionString = "Server=$server;Database=master;Integrated Security=True;TrustServerCertificate=True"

Write-Host "Server      : $server"
Write-Host "Backup Path : $backupDir"

# =====================================
# CHECK FOLDER
# =====================================
if (!(Test-Path $backupDir)) {
    Write-Host "❌ Backup folder not found"
    exit 1
}

# =====================================
# GET QA BACKUPS
# =====================================
$bakFiles = Get-ChildItem -Path $backupDir -Filter "*_QA_*.bak"

if (!$bakFiles) {
    Write-Host "❌ No QA backup files found"
    exit 1
}

Write-Host "====================================="
$bakFiles | ForEach-Object { Write-Host $_.Name }
Write-Host "====================================="

# =====================================
# LOOP
# =====================================
foreach ($bak in $bakFiles) {

    Write-Host "-------------------------------------"
    Write-Host "Processing: $($bak.Name)"

    $database   = ($bak.BaseName -replace "_\d{8}.*", "")
    $backupPath = $bak.FullName

    Write-Host "Target DB: $database"

    try {

        # =====================================
        # DISCONNECT USERS
        # =====================================
        Invoke-Sqlcmd -ConnectionString $connectionString -Query "
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

        Invoke-Sqlcmd -ConnectionString $connectionString -Query "
        RESTORE DATABASE [$database]
        FROM DISK = N'$backupPath'
        WITH REPLACE, RECOVERY, STATS = 5;
        "

        # =====================================
        # MULTI USER
        # =====================================
        Invoke-Sqlcmd -ConnectionString $connectionString -Query "
        ALTER DATABASE [$database] SET MULTI_USER;
        "

        Write-Host "✅ Restored: $database"

    } catch {
        Write-Host "❌ Restore failed for $database"
        Write-Host $_.Exception.Message
        exit 1
    }
}

Write-Host "====================================="
Write-Host "   ALL QA DATABASES RESTORED SUCCESSFULLY ✅"
Write-Host "====================================="
