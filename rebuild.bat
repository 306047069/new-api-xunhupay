@echo off
chcp 65001 >nul
echo ==========================================
echo  New-API 重建脚本
echo ==========================================

set PATH=c:\newapi\tools\go\bin;c:\newapi\tools\node;%PATH%
set GOPROXY=https://goproxy.cn,direct
set GO111MODULE=on

echo [1/8] 清理 default 前端依赖...
if exist "web\default\node_modules" (
    echo   正在删除 node_modules，请等待...
    rmdir /s /q "web\default\node_modules"
)
del /f /q "web\default\package-lock.json" 2>nul
if exist "web\default\dist" rmdir /s /q "web\default\dist"

echo [2/8] 清理 classic 前端依赖...
if exist "web\classic\node_modules" (
    echo   正在删除 node_modules，请等待...
    rmdir /s /q "web\classic\node_modules"
)
del /f /q "web\classic\package-lock.json" 2>nul
if exist "web\classic\dist" rmdir /s /q "web\classic\dist"

echo [3/8] 清理 npm 缓存...
npm cache clean --force 2>nul

echo [4/8] 构建 default 前端...
cd /d "%~dp0web\default"
echo   正在安装依赖（约需 3-5 分钟）...
npm install --legacy-peer-deps 2>&1
if errorlevel 1 (
    echo [WARN] 安装失败，尝试跳过可选依赖...
    npm install --legacy-peer-deps --no-optional 2>&1
)
echo   正在构建...
npm run build 2>&1
if errorlevel 1 (
    echo [ERROR] default 构建失败
    pause
    exit /b 1
)

echo [5/8] 构建 classic 前端...
cd /d "%~dp0web\classic"
echo   正在安装依赖...
npm install --legacy-peer-deps 2>&1
if errorlevel 1 (
    npm install --legacy-peer-deps --no-optional 2>&1
)
echo   正在构建...
npm run build 2>&1
if errorlevel 1 (
    echo [ERROR] classic 构建失败
    pause
    exit /b 1
)

echo [6/8] 下载 Go 依赖...
cd /d "%~dp0"
go mod download 2>&1

echo [7/8] 编译 Go 后端...
go build -o new-api-local.exe main.go 2>&1
if errorlevel 1 (
    echo [ERROR] Go 编译失败
    pause
    exit /b 1
)

echo [8/8] 启动服务...
echo 访问地址: http://localhost:3000
echo 默认账号: root / 123456
new-api-local.exe
