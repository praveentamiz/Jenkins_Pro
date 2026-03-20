Write-Host "====================================="
Write-Host "      SQL Deployment Started"
Write-Host "====================================="

# 🔧 Configuration
$server = "localhost"
$database = "TEST_DB"

# 📁 Path to SQL files (inside cloned repo)
$sqlPath = ".\repo\SQLFiles\*.sql"

# =====================================
# ✅ Step 1: Create Database if not exists
# =====================================
Write-Host "Checking/Creating Database..."

sqlcmd -S $server -E -Q "IF DB_ID('$database') IS NULL BEGIN CREATE DATABASE [$database]; PRINT 'DB Created'; END ELSE PRINT 'DB Already Exists';" -Encrypt Yes -TrustServerCertificate Yes

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create or verify database"
    exit 1
}

# =====================================
# ✅ Step 2: Verify Database
# =====================================
Write-Host "Verifying Database..."

sqlcmd -S $server -E -Q "SELECT name FROM sys.databases WHERE name='$database'" -Encrypt Yes -TrustServerCertificate Yes

# =====================================
# ✅ Step 3: Check SQL ملفات
# =====================================
Write-Host "Looking for SQL files in: $sqlPath"

$files = Get-ChildItem -Path $sqlPath -ErrorAction SilentlyContinue

if (!$files -or $files.Count -eq 0) {
    Write-Host "❌ No SQL files found in path: $sqlPath"
    exit 1
}

Write-Host "Found $($files.Count) SQL file(s)"

# =====================================
# ✅ Step 4: Execute SQL Files
# =====================================
foreach ($file in $files) {

    Write-Host "-------------------------------------"
    Write-Host "Executing: $($file.Name)"

    sqlcmd -S $server -d $database -E -i "$($file.FullName)" -Encrypt Yes -TrustServerCertificate Yes

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error executing: $($file.Name)"
        exit 1
    } else {
        Write-Host "✅ Successfully executed: $($file.Name)"
    }
}

# =====================================
# ✅ Completed
# =====================================
Write-Host "====================================="
Write-Host "   SQL Deployment Completed ✅"
Write-Host "====================================="
