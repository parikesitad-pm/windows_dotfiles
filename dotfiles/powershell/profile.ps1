# DOTMOD - PowerShell Profile
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -BellStyle None

# Aliases
Set-Alias -Name ll -Value Get-ChildItem
function which ($name) { Get-Command $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }
