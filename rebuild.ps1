# 强力清理并重新构建
$ErrorActionPreference = "Stop"
$env:PATH = "c:/newapi/tools/go/bin;c:/newapi/tools/node;" + $env:PATH
$env:GOPROXY = "https://goproxy.cn,direct"
$env:GO111MODULE = "on"

# 1. 清理前端构建产物和依赖
Write-Host "=== 清理前端 ===" -ForegroundColor Yellow

$paths = @(
    "c:/newapi/new-api-main/web/default/node_modules",
    "c:/newapi/new-api-main/web/default/package-lock.json",
    "c:/newapi/new-api-main/web/default/dist",
    "c:/newapi/new-api-main/web/classic/node_modules",
    "c:/newapi/new-api-main/web/classic/package-lock.json",
    "c:/newapi/new-api-main/web/classic/dist"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        if ((Get-Item $p) -is [System.IO.DirectoryInfo]) {
            Remove-Item -Recurse -Force $p
        } else {
            Remove-Item -Force $p
        }
        Write-Host "  已删除: $p"
    }
}

# 2. 清理 npm 缓存
Write-Host "=== 清理 npm 缓存 ===" -ForegroundColor Yellow
npm cache clean --force 2>$null

# 3. 构建 default 前端
Write-Host "=== 构建 default 前端 ===" -ForegroundColor Cyan
Set-Location "c:/newapi/new-api-main/web/default"

# 使用 --prefer-offline 避免网络卡死
npm install --legacy-peer-deps --prefer-offline 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] npm install 失败，重试一次..." -ForegroundColor Yellow
    npm install --legacy-peer-deps --no-optional 2>&1 | ForEach-Object { Write-Host $_ }
}

npm run build 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] default build 失败" -ForegroundColor Red
    exit 1
}

# 4. 构建 classic 前端
Write-Host "=== 构建 classic 前端 ===" -ForegroundColor Cyan
Set-Location "c:/newapi/new-api-main/web/classic"

npm install --legacy-peer-deps --prefer-offline 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    npm install --legacy-peer-deps --no-optional 2>&1 | ForEach-Object { Write-Host $_ }
}

npm run build 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] classic build 失败" -ForegroundColor Red
    exit 1
}

# 5. 下载 Go 依赖
Write-Host "=== 下载 Go 依赖 ===" -ForegroundColor Cyan
Set-Location "c:/newapi/new-api-main"
go mod download 2>&1 | ForEach-Object { Write-Host $_ }

# 6. 启动服务
Write-Host "=== 启动 New-API 服务 ===" -ForegroundColor Green
Write-Host "访问地址: http://localhost:3000"
Write-Host "默认账号: root / 123456"
go run main.go
