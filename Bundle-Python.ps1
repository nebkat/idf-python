
param (
    [string]$PythonVersion="3.11.2",
    [bool]$InstallVirtualenv=$False
)

# Creates custom build of Python Embedded and apply changes so that it works with virtualenv

$ProgressPreference = 'SilentlyContinue'

# Transform version name to short form used in file names 3.8.6 -> 38
$VersionItems = $PythonVersion.Split(".")
$ShortPythonVersion = $VersionItems[0] + $VersionItems[1]
#$PythonDirectory = "Python${ShortPythonVersion}"
$PythonDirectory = "python"

# Prepare Embedded Python
Invoke-WebRequest -Uri "https://www.python.org/ftp/python/${PythonVersion}/python-${PythonVersion}-embed-amd64.zip" -OutFile python.zip
Expand-Archive -LiteralPath "python.zip" -DestinationPath "${PythonDirectory}"
Expand-Archive -LiteralPath "${PythonDirectory}\python${ShortPythonVersion}.zip" -DestinationPath "${PythonDirectory}\Lib"
Remove-Item "${PythonDirectory}\python${ShortPythonVersion}.zip"
Remove-Item "${PythonDirectory}\python${ShortPythonVersion}._pth"
Remove-Item "python.zip"

if ($True -eq $InstallVirtualenv) {
    & .\${PythonDirectory}\python.exe -m pip install virtualenv
}

# Venv helper files must be extracted from main python.
# Embedded version does not contain working copy for virtualenv.
# If Python is not available then install one
if ($null -eq (Get-Command "python.exe" -ErrorAction SilentlyContinue))  {
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/${PythonVersion}/python-${PythonVersion}-amd64.exe" -Out "python-amd64.exe"
    .\python-amd64.exe /quiet /passive TargetDir=${pwd}\temp-python3
    $InstallerProcess = Get-Process python-amd64
    Wait-Process -Id $InstallerProcess.id
    $PythonVenvScripts = "temp-python3\Lib\venv\scripts\nt"
    $VenvScripts = "temp-python3\Lib\venv"
    $EnsurepipScripts = "temp-python3\Lib\ensurepip"
} else {
    if ($True -eq $InstallVirtualenv) {
        python -m pip install virtualenv
        python -m virtualenv temp-python3
    }
    $SystemPythonPath = (Get-Command python).path
    $PythonVenvScripts = Join-Path -Path (Split-Path $SystemPythonPath -Parent) -ChildPath Lib\venv\scripts\nt
    $VenvScripts = Join-Path -Path (Split-Path $SystemPythonPath -Parent) -ChildPath Lib\venv
    $EnsurepipScripts = Join-Path -Path (Split-Path $SystemPythonPath -Parent) -ChildPath Lib\ensurepip
}

mkdir ${PythonDirectory}\Lib\venv\scripts\nt
Copy-Item ${PythonVenvScripts}\activate.bat ${PythonDirectory}\Lib\venv\scripts\nt
Copy-Item ${PythonVenvScripts}\deactivate.bat ${PythonDirectory}\Lib\venv\scripts\nt
Copy-Item ${PythonVenvScripts}\python.exe ${PythonDirectory}\Lib\venv\scripts\nt
Copy-Item ${PythonVenvScripts}\pythonw.exe ${PythonDirectory}\Lib\venv\scripts\nt
Copy-Item ${VenvScripts}\__init__.py ${PythonDirectory}\Lib\venv\
Copy-Item ${VenvScripts}\__main__.py ${PythonDirectory}\Lib\venv\

mkdir ${PythonDirectory}\Lib\ensurepip
Copy-Item ${EnsurepipScripts}\__init__.py ${PythonDirectory}\Lib\ensurepip\
Copy-Item ${EnsurepipScripts}\__main__.py ${PythonDirectory}\Lib\ensurepip\
Copy-Item -Recurse ${EnsurepipScripts}\_bundled ${PythonDirectory}\Lib\ensurepip\

# Create final zip - GitHub performs compression of artifacts automatically
Compress-Archive -Path "python\*" -DestinationPath "python.zip"
