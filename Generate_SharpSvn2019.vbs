' VB Script Document
option explicit

Const ForReading = 1
Const BaseOutputDirectory = "C:\SharpSvn2019Builds"

'-------------------------------------------------------------------------------
'Global variables
'-------------------------------------------------------------------------------

'Utility objects
Dim fso
Dim TextStream
Dim FileText
Dim re
Dim WshShell

'Values to patch into the files 
Dim Build_Version
Dim Assembly_Version
Dim Vsix_Version
Dim RootDir

Dim OutputDirectory
Dim ExitCode

'-------------------------------------------------------------------------------
'Function: PatchNuspecVersion
'-------------------------------------------------------------------------------
Private Sub PatchNuspecVersion ( ConfigFile, AssemblyVersion )

  Set TextStream  = fso.OpenTextFile ( ConfigFile, ForReading )
  FileText = TextStream.ReadAll
  TextStream.Close
  Set TextStream = Nothing
         
  re.Pattern = "<version>.*</version>"
  FileText = re.Replace ( FileText, "<version>" & AssemblyVersion & "</version>" )

  set TextStream = fso.CreateTextFile ( ConfigFile, True, False )
  TextStream.Write FileText
  TextStream.Close
  Set TextStream = Nothing

End Sub

'-------------------------------------------------------------------------------
'Function: PatchAssemblyFileVersion_cpp
'-------------------------------------------------------------------------------
Private Sub PatchAssemblyFileVersion_cpp ( ConfigFile, AssemblyVersion )

  Set TextStream  = fso.OpenTextFile ( ConfigFile, ForReading )
  FileText = TextStream.ReadAll
  TextStream.Close
  Set TextStream = Nothing
         
  re.Pattern = "AssemblyVersionAttribute\s*\(\s*""[^""]*""\s*\)"
  FileText = re.Replace ( FileText, "AssemblyVersionAttribute(""" & AssemblyVersion & """)" )

  set TextStream = fso.CreateTextFile ( ConfigFile, True, False )
  TextStream.Write FileText
  TextStream.Close
  Set TextStream = Nothing

End Sub

'-------------------------------------------------------------------------------
'Function: PatchRcFileVersion
'-------------------------------------------------------------------------------
Private Sub PatchRcFileVersion ( ConfigFile, AssemblyVersion )

  Set TextStream  = fso.OpenTextFile ( ConfigFile, ForReading )
  FileText = TextStream.ReadAll
  TextStream.Close
  Set TextStream = Nothing
         
  re.Pattern = "FILEVERSION\s*[,0-9]*"
  FileText = re.Replace ( FileText, "FILEVERSION " & Replace(AssemblyVersion,".",",") )

  re.Pattern = "PRODUCTVERSION\s*[,0-9]*"
  FileText = re.Replace ( FileText, "PRODUCTVERSION " & Replace(AssemblyVersion,".",",") )

  re.Pattern = "VALUE\s*""FileVersion""\s*,\s*""[^""]*"""
  FileText = re.Replace ( FileText, "VALUE ""FileVersion"", """ & AssemblyVersion & """" )

  re.Pattern = "VALUE\s*""ProductVersion""\s*,\s*""[^""]*"""
  FileText = re.Replace ( FileText, "VALUE ""ProductVersion"", """ & AssemblyVersion & """" )

  set TextStream = fso.CreateTextFile ( ConfigFile, True, False )
  TextStream.Write FileText
  TextStream.Close
  Set TextStream = Nothing

End Sub

'-------------------------------------------------------------------------------
'Function: PatchAssemblyFileVersion
'-------------------------------------------------------------------------------
Private Sub PatchAssemblyFileVersion ( ConfigFile, AssemblyVersion )

  Set TextStream  = fso.OpenTextFile ( ConfigFile, ForReading )
  FileText = TextStream.ReadAll
  TextStream.Close
  Set TextStream = Nothing
         
  re.Pattern = "AssemblyFileVersion\s*\(\s*""[^""]*""\s*\)"
  FileText = re.Replace ( FileText, "AssemblyFileVersion(""" & AssemblyVersion & """)" )

  re.Pattern = "AssemblyVersion\s*\(\s*""[^""]*""\s*\)"
  FileText = re.Replace ( FileText, "AssemblyVersion(""" & AssemblyVersion & """)" )

  set TextStream = fso.CreateTextFile ( ConfigFile, True, False )
  TextStream.Write FileText
  TextStream.Close
  Set TextStream = Nothing

End Sub

'-------------------------------------------------------------------------------
'Function: BuildSolution
'-------------------------------------------------------------------------------
Private Sub BuildSolution ( SolutionFile )

  Dim MSBuildCommand
  
  MSBuildCommand = """C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"" " & SolutionFile & " /t:Build /p:Configuration=Release /p:Platform=x86 /p:TargetFramework=v4 /fl /flp:logfile=SharpSvn2019Build.log /nodeReuse:false"
  
  ExitCode = WshShell.Run ( MSBuildCommand, 1, True )
  If ExitCode <> 0 Then
    MsgBox "Build error in " & SolutionFile
    WScript.Quit
  End if  
  
End Sub

'-------------------------------------------------------------------------------
'Function: GenerateNuget
'-------------------------------------------------------------------------------
Private Sub GenerateNuget ( NuspecFile )

  Dim NugetCommand
  
  NugetCommand = "C:\nuget\nuget.exe pack """ & NuspecFile & """ -OutputDirectory """ & OutputDirectory & """ -NonInteractive" 
  
  ExitCode = WshShell.Run ( NugetCommand, 1, True )
  If ExitCode <> 0 Then
    MsgBox "Build error in " & NuspecFile
    WScript.Quit
  End if  
  
End Sub

'===============================================================================
'MAIN CODE
'===============================================================================

'-------------------------------------------------------------------------------
'Get some objects
'-------------------------------------------------------------------------------
set re = New RegExp
Set fso = CreateObject("Scripting.FileSystemObject")
Set WshShell = WScript.CreateObject("WScript.Shell")

'-------------------------------------------------------------------------------
'Get some values for patching
'-------------------------------------------------------------------------------

Build_Version     = InputBox ( "Enter the build version" )
Build_Version     = Right ( "0000" & Build_Version, 4 )
Assembly_Version  = "1.12.0." & Build_Version

RootDir = fso.GetParentFolderName(WScript.ScriptFullName)
'MsgBox RootDir

'-------------------------------------------------------------------------------
'Create the output directory
'-------------------------------------------------------------------------------
OutputDirectory = BaseOutputDirectory & "\1_12_" & Build_Version
if Not fso.FolderExists ( OutputDirectory ) Then
  fso.CreateFolder OutputDirectory 
End If

'Patch the assembly config files
PatchAssemblyFileVersion_cpp "src\SharpSvn\AssemblyInfo.cpp", Assembly_Version
PatchRcFileVersion "src\SharpSvn\SharpSvn.rc", Assembly_Version

'Pathc the nuget version
PatchNuspecVersion "src\nuget\SharpSvn.1.9-x86.nuspec", Assembly_Version

'Compile the projects
BuildSolution "src\SharpSvn.sln" 

'Generate the nuget package in the output directory
GenerateNuget "src\nuget\SharpSvn.1.9-x86.nuspec" 

MsgBox "Done"
 