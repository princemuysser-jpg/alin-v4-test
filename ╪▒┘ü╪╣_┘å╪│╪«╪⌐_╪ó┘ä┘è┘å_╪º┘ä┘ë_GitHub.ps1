$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Text) {
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Resolve-GitExe {
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) { return $git.Source }

    $desktopGit = Get-ChildItem -Path "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($desktopGit) { return $desktopGit.FullName }

    throw 'لم يتم العثور على Git أو GitHub Desktop في هذا الجهاز.'
}

function Run-Git {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$false)][string]$WorkingDirectory
    )
    $old = Get-Location
    try {
        if ($WorkingDirectory) { Set-Location $WorkingDirectory }
        & $script:GitExe @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "فشل أمر Git: git $($Arguments -join ' ')"
        }
    }
    finally {
        Set-Location $old
    }
}

try {
    $source = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:GitExe = Resolve-GitExe
    $repoUrl = 'https://github.com/princemuysser-jpg/alin-v4-test.git'
    $tempRoot = Join-Path $env:TEMP ('alin-upload-' + [guid]::NewGuid().ToString('N'))
    $repoDir = Join-Path $tempRoot 'alin-v4-test'

    Write-Step 'تجهيز نسخة GitHub حديثة'
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Run-Git -Arguments @('clone','--depth','1',$repoUrl,$repoDir)

    Write-Step 'نسخ إصدار آلين v4.1.1 إلى المستودع'
    Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
        if ($_.Name -in @('رفع_نسخة_آلين_الى_GitHub.ps1','رفع_نسخة_آلين_الى_GitHub_بنقرة_واحدة.cmd')) { return }
        Copy-Item -LiteralPath $_.FullName -Destination $repoDir -Recurse -Force
    }

    # إزالة ملفات الإصلاحات القديمة التي لم تعد مستخدمة.
    $oldPaths = @(
        'hotfixes\courier-workflow-v4.0.2.js',
        'RUN_ON_SUPABASE_v4_0_2_COURIER_WORKFLOW.sql',
        'DEPLOY_COURIER_ASSIGNMENT_FIX.cmd',
        'ابدأ_تحديث_المندوب_v4_0_2.cmd',
        'تحديث_المندوب_v4_0_2.txt'
    )
    foreach ($relative in $oldPaths) {
        $target = Join-Path $repoDir $relative
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force -Recurse }
    }

    Write-Step 'تسجيل التحديث'
    Run-Git -Arguments @('config','user.name','princemuysser-jpg') -WorkingDirectory $repoDir
    Run-Git -Arguments @('config','user.email','princemuysser-jpg@users.noreply.github.com') -WorkingDirectory $repoDir
    Run-Git -Arguments @('add','-A') -WorkingDirectory $repoDir

    & $script:GitExe -C $repoDir diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'النسخة نفسها موجودة على GitHub، لا توجد ملفات جديدة للرفع.' -ForegroundColor Yellow
    }
    else {
        Run-Git -Arguments @('commit','-m','4.1.1 boot connection fix') -WorkingDirectory $repoDir
        Write-Step 'رفع الملفات إلى GitHub'
        Write-Host 'قد تظهر نافذة تسجيل دخول GitHub مرة واحدة. وافق عليها فقط.' -ForegroundColor Yellow
        Run-Git -Arguments @('push','origin','main') -WorkingDirectory $repoDir
        Write-Host 'تم رفع النسخة إلى GitHub بنجاح.' -ForegroundColor Green
    }

    Write-Step 'فتح الموقع بعد التحديث'
    Start-Sleep -Seconds 5
    Start-Process 'https://princemuysser-jpg.github.io/alin-v4-test/?v=4.1.1'

    Write-Host "`nاكتمل العمل. انتظر دقيقة أو دقيقتين ثم حدّث الموقع." -ForegroundColor Green
}
catch {
    Write-Host "`nفشل الرفع: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'لم يتم تنفيذ أي SQL ولم تُحذف بيانات Supabase.' -ForegroundColor Yellow
    exit 1
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
