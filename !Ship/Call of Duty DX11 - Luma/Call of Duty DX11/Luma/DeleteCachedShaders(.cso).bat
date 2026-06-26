:: Search and delete files.
set
for /f "delims=" %%F in ('dir /s /b /a-d *.cso') do (
    DEL /F /S /Q "%%F"
)
echo Done!
pause