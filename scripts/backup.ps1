# Backs up both databases and the uploaded photos.
#
# There is no automatic backup anywhere in this project, and the two things
# that cannot be recreated are the databases (grades, attendance, a term's
# worth of marks) and the face photos in backend/uploads. Everything else --
# code, models, the app -- can be rebuilt from the repository.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\backup.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\backup.ps1 -Destination D:\smartschool-backups
#
# Restore (careful -- this overwrites):
#   psql -U postgres -d smartschool -f <file>.sql

param(
    [string]$Destination = "$PSScriptRoot\..\backups",
    # How many dated folders to keep. Old ones are removed after a
    # successful run, never before -- a failed backup must not be the thing
    # that deletes the last good one.
    [int]$Keep = 14
)

$ErrorActionPreference = 'Stop'

# The PostgreSQL installer does not put its bin directory on PATH on
# Windows, so pg_dump is usually not callable by name even though it is
# installed. Find it rather than making the caller fix their PATH.
if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
    $candidate = Get-ChildItem 'C:\Program Files\PostgreSQL' -Recurse -Filter pg_dump.exe -ErrorAction SilentlyContinue |
                 Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $candidate) { throw "pg_dump topilmadi -- PostgreSQL o'rnatilganini tekshiring" }
    $env:PATH = "$($candidate.DirectoryName);$env:PATH"
}

$stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$outDir = Join-Path $Destination $stamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Read the database names from each server's own .env so this can't drift
# from what the servers actually use.
function Get-DatabaseUrl([string]$envFile) {
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*DATABASE_URL\s*=\s*(.+)$') { return $Matches[1].Trim() }
    }
    return $null
}

function Backup-Database([string]$label, [string]$url, [string]$outFile) {
    if (-not $url) { Write-Warning "$label : DATABASE_URL topilmadi, o'tkazib yuborildi"; return }
    # postgresql://user:password@host/dbname
    if ($url -notmatch '^postgres(ql)?://([^:]+):([^@]*)@([^/:]+)(?::(\d+))?/(.+)$') {
        Write-Warning "$label : DATABASE_URL o'qib bo'lmadi"; return
    }
    $user = $Matches[2]; $pass = $Matches[3]; $dbHost = $Matches[4]
    $port = if ($Matches[5]) { $Matches[5] } else { '5432' }
    $name = $Matches[6]

    $env:PGPASSWORD = $pass
    try {
        & pg_dump --host=$dbHost --port=$port --username=$user --format=plain --file=$outFile $name
        if ($LASTEXITCODE -ne 0) { throw "pg_dump $label uchun $LASTEXITCODE qaytardi" }
        $size = [math]::Round((Get-Item $outFile).Length / 1MB, 2)
        Write-Host ("  {0,-16} {1} MB" -f $label, $size)
    } finally {
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}

Write-Host "Zaxira nusxa -> $outDir"

Backup-Database 'maktab serveri' (Get-DatabaseUrl "$PSScriptRoot\..\backend\.env")       (Join-Path $outDir 'school.sql')
Backup-Database 'ochiq server'   (Get-DatabaseUrl "$PSScriptRoot\..\public_server\.env") (Join-Path $outDir 'public.sql')

# Face photos: recreating these means re-photographing every pupil.
$uploads = "$PSScriptRoot\..\backend\uploads"
if (Test-Path $uploads) {
    $zip = Join-Path $outDir 'uploads.zip'
    Compress-Archive -Path "$uploads\*" -DestinationPath $zip -Force
    $size = [math]::Round((Get-Item $zip).Length / 1MB, 2)
    Write-Host ("  {0,-16} {1} MB" -f 'suratlar', $size)
}

# Only now that this run has succeeded.
$old = Get-ChildItem $Destination -Directory |
       Sort-Object Name -Descending |
       Select-Object -Skip $Keep
foreach ($dir in $old) {
    Remove-Item $dir.FullName -Recurse -Force
    Write-Host "  eski nusxa o'chirildi: $($dir.Name)"
}

Write-Host "Tayyor."
