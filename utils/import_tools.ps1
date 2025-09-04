$devenv = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
$settingsPath = "D:\GIT\score-provisioners\utils\Score_Compose_Tool_Debug.vssettings"

$visualStudio = New-Object -ComObject "VisualStudio.DTE.17.0"
$visualStudio.Solution.Create("C:\temp\dummy.sln")
$visualStudio.ExecuteCommand("Tools.ImportandExportSettings", "/import:`"$settingsPath`"")
$visualStudio.Quit()