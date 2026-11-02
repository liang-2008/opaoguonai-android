<#
    一键构建 DSH手机版.apk（不需要 Gradle / Android Studio）
    用法：
        .\build.ps1
        .\build.ps1 -Sdk "F:\Android\Sdk" -Jdk "C:\Program Files\Java\jdk-21"
#>
param(
    [string]$Sdk = "F:\Android\Sdk",
    [string]$Jdk = "C:\Program Files\Java\jdk-21"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$env:JAVA_HOME = $Jdk

if (-not (Test-Path $Sdk)) { throw "找不到 SDK: $Sdk" }
if (-not (Test-Path $Jdk)) { throw "找不到 JDK: $Jdk" }

$btDir = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$platDir = Get-ChildItem (Join-Path $Sdk "platforms") -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $btDir) { throw "SDK 里没有 build-tools" }
if (-not $platDir) { throw "SDK 里没有 platforms" }

$bt = $btDir.FullName
$jar = Join-Path $platDir.FullName "android.jar"

Write-Host "build-tools : $bt"
Write-Host "android.jar : $jar"

# aapt2 不认带中文的绝对路径，所以全部在项目目录里用相对路径跑
Push-Location $root
[Environment]::CurrentDirectory = $root   # 原生工具靠这个确定工作目录
try {
    foreach ($d in @("build\gen", "build\obj", "build\dex")) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    }
    Remove-Item "build\obj\*", "build\dex\*", "build\gen\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[1/6] aapt2 compile"
    & "$bt\aapt2.exe" compile --dir res -o build\res.zip
    if ($LASTEXITCODE -ne 0) { throw "aapt2 compile 失败" }

    Write-Host "[2/6] aapt2 link"
    & "$bt\aapt2.exe" link -o build\app.apk -I $jar --manifest AndroidManifest.xml -R build\res.zip --java build\gen --min-sdk-version 26 --target-sdk-version 34 --version-code 2 --version-name 1.1 --auto-add-overlay
    if ($LASTEXITCODE -ne 0) { throw "aapt2 link 失败" }

    Write-Host "[3/6] javac"
    & "$Jdk\bin\javac.exe" -encoding UTF-8 -source 8 -target 8 -nowarn -classpath $jar -d build\obj build\gen\com\edu\math\R.java java\com\edu\math\MainActivity.java java\com\edu\math\PrankService.java java\com\edu\math\Taunts.java
    if ($LASTEXITCODE -ne 0) { throw "javac 失败" }

    Write-Host "[4/6] d8"
    & "$Jdk\bin\jar.exe" cf build\classes.jar -C build\obj .
    & "$bt\d8.bat" --release --min-api 26 --lib $jar --output build\dex build\classes.jar
    if ($LASTEXITCODE -ne 0) { throw "d8 失败" }

    Write-Host "[5/6] 打包 + 对齐"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $apkPath = Join-Path $root "build\app.apk"
    $zip = [System.IO.Compression.ZipFile]::Open($apkPath, 'Update')
    $old = $zip.Entries | Where-Object { $_.FullName -eq 'classes.dex' }
    if ($old) { $old.Delete() }
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root "build\dex\classes.dex"), "classes.dex", [System.IO.Compression.CompressionLevel]::Optimal)
    $zip.Dispose()

    & "$bt\zipalign.exe" -p -f 4 build\app.apk build\app-aligned.apk
    if ($LASTEXITCODE -ne 0) { throw "zipalign 失败" }

    Write-Host "[6/6] 签名"
    if (-not (Test-Path "build\debug.keystore")) {
        & "$Jdk\bin\keytool.exe" -genkeypair -keystore build\debug.keystore -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" | Out-Null
    }
    # 参数一律 ASCII，签完再改中文名（apksigner 处理中文路径会报 Bad pathname）
    & "$bt\apksigner.bat" sign --ks build\debug.keystore --ks-pass pass:android --key-pass pass:android --ks-key-alias androiddebugkey --out build\signed.apk build\app-aligned.apk
    if ($LASTEXITCODE -ne 0) { throw "签名失败" }
    Move-Item -Force build\signed.apk "build\DSH手机版.apk"

    Write-Host ""
    Write-Host "OK -> $root\build\DSH手机版.apk"
    Write-Host ("size = " + [math]::Round((Get-Item "build\DSH手机版.apk").Length / 1MB, 2) + " MB")
}
finally {
    Pop-Location
}