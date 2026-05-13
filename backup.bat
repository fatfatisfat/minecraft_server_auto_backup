@echo off
setlocal enabledelayedexpansion

:: ===== [核心路徑設定] =====
set "WORLD_NAME=ChineseEmpire"
set "SOURCE_DIR=D:\中華帝國fabric\%WORLD_NAME%"
set "BACKUP_DIR=D:\中華帝國fabric\backups"
set "TEMP_DIR=D:\中華帝國fabric\temp_backup"
set "INTERVAL=600"
set "MIN_FREE_GB=5"
:: =====================

:loop
cls
echo [%time%] --- 玩家感應自動備份系統 ---

:: 檢查剩餘空間
for /f "usebackq" %%A in (`powershell -NoProfile -Command "[math]::Truncate((Get-PSDrive D).Free / 1GB)"`) do (set FREE_SPACE=%%A)
echo 目前磁碟剩餘空間: %FREE_SPACE% GB

if %FREE_SPACE% LSS %MIN_FREE_GB% (
    echo [警告] 剩餘空間低於 %MIN_FREE_GB% GB，將停止備份！
    goto wait_next
)

:: 檢測是否有玩家在線上
set "PLAYER_ONLINE=0"
for /f "tokens=*" %%a in ('netstat -an ^| findstr "25565" ^| findstr "ESTABLISHED"') do (
    set "PLAYER_ONLINE=1"
)

if "!PLAYER_ONLINE!"=="0" (
    echo [%time%] 目前沒有玩家在線上，跳過本次備份。
    goto wait_next
)

echo [%time%] 偵測到玩家在線上，準備開始備份...

:: 準備備份環境
for /f "usebackq" %%B in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmm'"`) do (set DT=%%B)
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo 正在建立 [%WORLD_NAME%] 的複製檔以避開鎖定...
robocopy "%SOURCE_DIR%" "%TEMP_DIR%" /MIR /R:0 /W:0 /NDL /NFL /NJH /NJS >nul

echo 正在執行壓縮: world_%DT%.zip...
powershell -command "Compress-Archive -Path '%TEMP_DIR%' -DestinationPath '%BACKUP_DIR%\world_%DT%.zip' -Force"

:: 清理暫存區
rd /s /q "%TEMP_DIR%" 2>nul

if exist "%BACKUP_DIR%\world_%DT%.zip" (
    echo [成功] 備份已存至 %BACKUP_DIR%
) else (
    echo [錯誤] 壓縮失敗！
)

:: 稀疏化處理 (由密而疏)
echo 執行稀疏化處理...
set "CUR_DATE=%date:~0,4%%date:~5,2%%date:~8,2%"
for /f "tokens=1 delims==" %%v in ('set KEEP_DATE_ 2^>nul') do set "%%v="

for /f "delims=" %%F in ('dir /b /o-d "%BACKUP_DIR%\world_*.zip"') do (
    set "FILE_NAME=%%F"
    set "F_DATE=!FILE_NAME:~6,8!"
    
    if "!F_DATE!"=="%CUR_DATE%" (
        echo [保留] 近期備份: %%F
    ) else (
        if not defined KEEP_DATE_!F_DATE! (
            set "KEEP_DATE_!F_DATE!=1"
            echo [保留] 每日存檔: %%F
        ) else (
            echo [刪除] 稀疏化處理: %%F
            del "%BACKUP_DIR%\%%F"
        )
    )
)

:: 5. 刪除超過 7 天的檔案
forfiles /p "%BACKUP_DIR%" /m *.zip /d -7 /c "cmd /c del @path" 2>nul

:wait_next
echo.
echo 程序完成。預計 %INTERVAL% 秒後進行下一次檢查...
timeout /t %INTERVAL% /nobreak
goto loop