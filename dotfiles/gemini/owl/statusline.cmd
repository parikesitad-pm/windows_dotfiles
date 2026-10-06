@echo off
if exist "%USERPROFILE%\.gemini\owl\statusline.js" (
    node "%USERPROFILE%\.gemini\owl\statusline.js" %*
) else (
    node "%~dp0statusline.js" %*
)
