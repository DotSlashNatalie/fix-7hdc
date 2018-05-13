'*************************************************************************
'*
'* File:           Fix_7hdc.vbs
'* Created:        2011-01-03 by cdob
'* Version:        0.11
'*
'* http://www.911cd.net/forums//index.php?showtopic=24245
'*
'* Purpose:
'* enable installed, but disabled mass storage drivers, e.g. msahci.sys
'* install additional mass storage drivers
'*
'* Runtime environment:
'* Windows 7 installation DVD / USB
'* relating PE
'*
'* used external applications (default integrated at runtime environment)
'* reg.exe, dism.exe, notepad.exe
'*
'*************************************************************************

' ------------------------------------------------------------------------
'
' based on PNPDriverMatch.vbs
' http://technet.microsoft.com/en-us/magazine/2006.05.utilityspotlight.aspx
'
' I agree that Microsoft has no warranty, obligations or liability
' for any Sample Application Files.
'
'<header original file> ==================================================
'
' Windows Script Host Sample Script
'
' ------------------------------------------------------------------------
'               Copyright (C) 2006 Microsoft Corporation
'
' You have a royalty-free right to use, modify, reproduce and distribute
' the Sample Application Files (and/or any modified version) in any way
' you find useful, provided that you agree that Microsoft has no warranty,
' obligations or liability for any Sample Application Files.
' ------------------------------------------------------------------------

'********************************************************************
'*
'* File:           PNPDriverMatch.vbs
'* Created:        03/06/2006
'* Version:        1.0.2
'*
'* Main Function:  VBScipt to examine a folder of Plug & Play drivers,
'*                 find INF files that have PNP IDs found on the computer,
'*                 and optionally copy the matching drivers folders to a
'*                 specified destination folder.
'*
'* Usage:  cscript PNPDriverMatch.vbs /folder:folder path
'*         [/dest:folder path]  [/log:log file path]
'*         [/class:class filter] [/provider:provider filter]
'*         [/excludeclass] [/excludeprovider] [/q] [/?]
'*
'* Copyright (C) 2006 Microsoft Corporation
'*
'*
'* Revisions:
'*
'* 1.0.0 - 06/22/2005 - Created.
'* 1.0.1 - 03/06/2006 - Updated RegularExpression class.  Changed
'*                      Expang_objDriverFolderDictStringVariables function to use
'*                      updated MatchText method of the
'*                      RegularExpression class
'* 1.0.2 - 03/22/2006 - Added EscapeXmlMarkup method to RegularExpression
'*                      class.
'*
'********************************************************************
'
'</header original file> ============================================


'********************************************************************
' * Declare Variables
'********************************************************************

Option Explicit
'On Error Resume Next

Dim arrArguments()

Dim blnQuiet
Dim blnExcludeProvider
Dim blnExcludeClass
Dim blnClassOutput
Dim blnProviderOutput
Dim blnEnableDrivers
Dim blnInstallDrivers
Dim blnRestore
Dim blnGuiMode

Dim colItems
Dim colComputerSystem

Dim g_objWshShell
Dim g_objWshNetwork
Dim g_objFSO
Dim g_objINI
Dim g_objRegExp
Dim g_objWMIDefault
Dim g_objRegistry
Dim g_objWMIService
Dim g_objPnpIdDict
Dim g_objInfFileDict
Dim g_objFileDict
Dim g_objDriverFolderDict
Dim g_objComputerSystem
Dim g_objInfDismFileDict
Dim g_objShellApp
Dim objFolderItem
Dim objFolder 
    
Dim i
Dim intOpMode

Dim Key

Dim lRC

Dim objComputerSystem
Dim objItem
Dim objPNPFolder

Dim refLogFile

Dim strQuote
Dim strComputer
Dim strComputerName
Dim strPNPFolder
Dim strTargetDrive
Dim strSearchFile
Dim strPNPDeviceID
Dim strDriver
Dim strClass
Dim strClassFilter
Dim strProviderName
Dim strProviderFilter
Dim strLogFile
Dim strOptionsMessage
Dim strDriverParentFolder
Dim strDriverRelativePath
Dim strDriverDestFolder
Dim strDriverDestParentFolder

' Define constants
Const CONST_ERROR               = 0
Const CONST_WSCRIPT             = 1
Const CONST_CSCRIPT             = 2
Const CONST_SHOW_USAGE          = 3
Const CONST_PROCEED             = 4
Const CONST_STRING_NOT_FOUND    = -1
Const CONST_FOR_READING         = 1
Const CONST_FOR_WRITING         = 2
Const CONST_FOR_APPENDING       = 8
Const CONST_Success             = 0
Const CONST_Failure             = 1

Const wbemFlagReturnImmediately = &h10
Const wbemFlagForwardOnly = &h20
Const strEnumKey = "SYSTEM\CurrentControlSet\Enum\"
Const strClassKey = "SYSTEM\CurrentControlSet\Control\Class\"
Const strServicesKey = "SYSTEM\CurrentControlSet\Services\"

Const HKEY_CLASSES_ROOT   = &H80000000
Const HKEY_CURRENT_USER   = &H80000001
Const HKEY_LOCAL_MACHINE  = &H80000002
Const HKEY_USERS          = &H80000003
Const HKEY_CURRENT_CONFIG = &H80000005
Const HKEY_DYN_DATA       = &H80000006

Const REG_SZ        = 1
Const REG_EXPAND_SZ = 2
Const REG_BINARY    = 3
Const REG_DWORD     = 4
Const REG_MULTI_SZ  = 7

Const DICTIONARY_COMPAREMODE_BINARY = 0
Const DICTIONARY_COMPAREMODE_TEXT = 1
Const DICTIONARY_COMPAREMODE_DATABASE = 2

strQuote = chr(34)


'***** Initialize variables
strComputer = "."
strTargetDrive = ""
strSearchFile = ""
strProviderFilter = ""
strClassFilter = ""
blnExcludeProvider = False
blnExcludeClass = False
blnEnableDrivers = False
blnInstallDrivers = False
blnRestore = False
blnGuiMode = False

'********************************************************************
' * Create Objects
'********************************************************************


Set g_objFSO = CreateObject("Scripting.FileSystemObject")
Set g_objWshShell = CreateObject("Wscript.Shell")
Set g_objWshNetwork = CreateObject("Wscript.Network")
Set g_objShellApp = CreateObject("Shell.Application")

Set g_objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2")
Set g_objWMIDefault = GetObject("winmgmts:\\" & strComputer & "\root\Default")
Set g_objRegistry = g_objWMIDefault.Get ("StdRegProv")

Set g_objPnpIdDict = CreateObject("Scripting.Dictionary")
g_objPnpIdDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT

Set g_objInfFileDict = CreateObject("Scripting.Dictionary")
g_objInfFileDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT

Set g_objDriverFolderDict = CreateObject("Scripting.Dictionary")
g_objDriverFolderDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT

'my addon
'Set g_objFileDict = CreateObject("Scripting.Dictionary")
'g_objFileDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT

Set g_objInfDismFileDict = CreateObject("Scripting.Dictionary")
g_objInfDismFileDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT


'added
Dim dHwid, inf_count, objDiskDrives, objDrive
Set g_objDriverFolderDict = CreateObject("Scripting.Dictionary")
'g_objDriverFolderDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT
Set dHwid = CreateObject("Scripting.Dictionary")
dHWid.CompareMode = DICTIONARY_COMPAREMODE_TEXT
inf_count = 0

'strPNPFolder = g_objFSO.GetParentFolderName(WScript.ScriptFullName) & "\" & g_objWshShell.Environment("Process").Item("PROCESSOR_ARCHITECTURE")
strPNPFolder = g_objFSO.GetParentFolderName(WScript.ScriptFullName) & "\" &  g_objWshShell.ExpandEnvironmentStrings("%PROCESSOR_ARCHITECTURE%")



'********************************************************************
' * Check script host exe and parse command line
'********************************************************************
If Wscript.arguments.count = 0 Then
  blnQuiet = True
Else 
  'Get the command line arguments
  For i = 0 to Wscript.arguments.count - 1
    ReDim Preserve arrArguments(i)
    arrArguments(i) = Wscript.arguments.item(i)
  Next

  'Parse the command line
  Err.Clear()
  intOpMode = intParseCmdLine(arrArguments, strPNPFolder, strTargetDrive, strSearchFile, strLogFile, strClassFilter, strProviderFilter, blnExcludeClass, blnExcludeProvider, blnQuiet, blnEnableDrivers, blnInstallDrivers, blnRestore, strOptionsMessage)

  If Err.Number Then
    Wscript.Echo "Error 0X" & CStr(Hex(Err.Number)) & " occurred in parsing the command line."
    If Err.Description <> "" Then
        Wscript.Echo "Error description: " & Err.Description & "."
    End If
    WScript.quit
  End If

  Select Case intOpMode
    Case CONST_SHOW_USAGE
        Call ShowUsage()
        WScript.quit
    Case CONST_PROCEED
        'Do nothing.
    Case CONST_ERROR
        WScript.quit
    Case Else
        Wscript.Echo "Error occurred in passing parameters."
  End Select

  WScript.Echo strOptionsMessage
End If

'********************************************************************
'* Main Script
'********************************************************************
'no command line mode set: enable gui mode
If not blnEnableDrivers And not blnInstallDrivers Then
  'Wscript.Echo "no command line mode set: enable gui mode"
  blnGuiMode = True
  blnEnableDrivers  = True
  blnInstallDrivers = True
  'enable logging
  If strLogFile = "" Then strLogFile = g_objFSO.GetSpecialFolder(2) & "\fix_7hdc-" & g_objFSO.GetTempName  & ".log"
End If

'***** Open Log File
If strLogFile <> "" Then
  Err.Clear()
  Set refLogFile = g_objFSO.OpenTextFile(strLogFile, CONST_FOR_WRITING, True)
  If Err.Number Then
    Wscript.Echo "Error 0X" & CStr(Hex(Err.Number)) & " occurred when opening the log file."
    If Err.Description <> "" Then
      Wscript.Echo "Error description: " & Err.Description & "."
    End If
    WScript.quit
  End If

  AppendLog(strOptionsMessage)
End If

Print(Now)
Print("Computer System:")
Set colComputerSystem = g_objWMIService.ExecQuery("Select * from Win32_ComputerSystem",,48)
For Each objComputerSystem in colComputerSystem
  Print("Manufacturer: " & objComputerSystem.Manufacturer)
  Print("Model: " & objComputerSystem.Model)
Next
Print("")

'search target disk drive, use first match
If strTargetDrive = "" And strSearchFile <> "" Then
  For Each objDrive in g_objFSO.Drives
    If objDrive.IsReady And strTargetDrive = "" Then 
      If g_objFSO.FileExists(objDrive & strSearchFile) Then 
        strTargetDrive = objDrive
        Print("found windows drive: " & strTargetDrive)
      End If
    End If
  Next
End If

'debug
If strLogFile <> "" Then
  AppendLog("")
  AppendLog("strTargetDrive: " & strTargetDrive)
  AppendLog("strSearchFile: " & strSearchFile)
  AppendLog("blnEnableDrivers: " & blnEnableDrivers)
  AppendLog("blnInstallDrivers: " & blnInstallDrivers)
  AppendLog("blnRestore " & blnRestore)
  AppendLog("")
End If


If blnEnableDrivers Then
  If strTargetDrive = "" Then
    Set objFolder = g_objShellApp.BrowseForFolder(0, "Mode: Enable drivers." & vbCr & vbCr & "Select a Win 7 drive:", 1, &H11)
    If not objFolder Is Nothing Then
      Set objFolderItem = objFolder.Self
      strTargetDrive = objFolderItem.Path
      Print("strTargetDrive: " & strTargetDrive)
    End If
  End If

  If g_objFSO.FolderExists(strTargetDrive & "\windows\system32\config") Then 
    EnableDrivers
  Else
    Wscript.Echo "Error: " & strTargetDrive & "\windows\system32\config not found"
    If blnGuiMode Then g_objWshShell.Run "notepad.exe " & chr(34) & strLogFile & chr(34), 1, False    
    Wscript.Quit
  End If
End If

If blnInstallDrivers Then
  'Print ("Install mode")
  If strTargetDrive = "" Then
    Set objFolder = g_objShellApp.BrowseForFolder(0, "Mode: Install drivers." & vbCr & vbCr & "Select a Win 7 drive:", 1, &H11)
    If objFolder Is Nothing Then
      Wscript.Echo "no drive selected"
      If blnGuiMode Then g_objWshShell.Run "notepad.exe " & chr(34) & strLogFile & chr(34), 1, False
      WScript.Quit
    End If
    Set objFolderItem = objFolder.Self
    strTargetDrive = objFolderItem.Path
    Print("strTargetDrive: " & strTargetDrive)
  End If

  If not g_objFSO.FolderExists(strTargetDrive & "\windows\system32\config") Then
    Wscript.Echo "Error: " & strTargetDrive & "\windows\system32\config not found"
    If blnGuiMode Then g_objWshShell.Run "notepad.exe " & chr(34) & strLogFile & chr(34), 1, False
    WScript.Quit
  End If

  If not g_objFSO.FolderExists(strPNPFolder) Or blnGuiMode Then
    Set objFolder = g_objShellApp.BrowseForFolder(0, "Select a driver folder:", 1, &H11)
    If objFolder Is Nothing Then
      Wscript.Echo "no drive selected"
      If blnGuiMode Then g_objWshShell.Run "notepad.exe " & chr(34) & strLogFile & chr(34), 1, False
      WScript.Quit
    End If
    Set objFolderItem = objFolder.Self
    strPNPFolder = objFolderItem.Path
    Print("strPNPFolder: " & strPNPFolder)
  End If

  If not g_objFSO.FolderExists(strPNPFolder) Then
    WScript.Echo "The PNP folder path '" & strPNPFolder & "' does not exist." & vbCr & _
                 "Please check the input and try again."
    WScript.Quit
  End If

  InstallDrivers
End If

If blnRestore Then
  'todo 2525
End If


If strLogFile <> "" Then refLogFile.Close()
If blnGuiMode Then g_objWshShell.Run "notepad.exe " & chr(34) & strLogFile & chr(34), 1, False


'********************************************************************
'*
'* Function intChkProgram()
'*
'* Purpose:  Determines which program is used to run this script.
'*
'* Input:    None
'*
'* Returns:  intChkProgram is set to one of CONST_ERROR, CONST_WSCRIPT,
'*           and CONST_CSCRIPT.
'*
'********************************************************************
Private Function intChkProgram()

    ON ERROR RESUME NEXT

    Dim i
    Dim j
    Dim strFullName
    Dim strCommand

    'strFullName should be something like C:\WINDOWS\COMMAND\CSCRIPT.EXE
    strFullName = WScript.FullName
    If Err.Number Then
        Wscript.Echo "Error 0x" & CStr(Hex(Err.Number)) & " occurred."
        If Err.Description <> "" Then
            Wscript.Echo "Error description: " & Err.Description & "."
        End If
        intChkProgram =  CONST_ERROR
        Exit Function
    End If

    i = InStr(1, strFullName, ".exe", 1)
    If i = 0 Then
        intChkProgram =  CONST_ERROR
        Exit Function
    Else
        j = InStrRev(strFullName, "\", i, 1)
        If j = 0 Then
            intChkProgram =  CONST_ERROR
            Exit Function
        Else
            strCommand = Mid(strFullName, j+1, i-j-1)
            Select Case LCase(strCommand)
                Case "cscript"
                    intChkProgram = CONST_CSCRIPT
                Case "wscript"
                    intChkProgram = CONST_WSCRIPT
                Case Else       'should never happen
                    Wscript.Echo "An unexpected program is used to run this script."
                    Wscript.Echo "Only CScript.Exe or WScript.Exe can be used to run this script."
                    intChkProgram = CONST_ERROR
            End Select
        End If
    End If

End Function


'********************************************************************
'*
'* Function intParseCmdLine()
'*
'* Purpose:  Parses the command line.
'*
'* Input:    arrArguments        an array containing input from the command line
'*
'* Output:   strPNPFolder        Path to Plug & Play top folder
'*           strLogFile          Output file
'*           strClassFilter      Device Class used to filter output
'*           strProviderFilter   Device Provider used to filter output
'*           blnExcludeClass     Exclude filtered Class items from output
'*           blnExcludeProvider  Exclude filtered Provider items from output
'*           blnQuiet            Specifies whether to suppress messages
'*           strOptionsMessage   String containing options selected
'*
'* Returns:  intParseCmdLine is set to one of CONST_ERROR, CONST_SHOW_USAGE,
'*           and CONST_PROCEED.
'*
'********************************************************************
Private Function intParseCmdLine(arrArguments, strPNPFolder, strTargetDrive, strSearchFile, strLogFile, strClassFilter, strProviderFilter, blnExcludeClass, blnExcludeProvider, blnQuiet, blnEnableDrivers, blnInstallDrivers, blnRestore, strOptionsMessage)

    ON ERROR RESUME NEXT

    Dim i
    Dim strFlag
    Dim strSwitchValue
    
    strFlag = arrArguments(0)
    Err.Clear()

    'Help is needed
    If (strFlag = "") OR (strFlag="help") OR (strFlag="/h") OR (strFlag="\h") OR (strFlag="-h") _
        OR (strFlag = "\?") OR (strFlag = "/?") OR (strFlag = "?") OR (strFlag="h") Then
        intParseCmdLine = CONST_SHOW_USAGE
        Exit Function
    End If

    strOptionsMessage = strOptionsMessage & "Fix_7hdc.vbs"  & VbCrLf
    strOptionsMessage = strOptionsMessage & ""  & VbCrLf
    strOptionsMessage = strOptionsMessage & "Command Line Options:"  & vbCrLf
    strOptionsMessage = strOptionsMessage & "---------------------------------------"  & VbCrLf

    For i = 0 to UBound(arrArguments)
        strFlag = Left(arrArguments(i), InStr(1, arrArguments(i), ":")-1)
        If Err.Number Then            'An error occurs if there is no : in the string
            Err.Clear
            If LCase(arrArguments(i)) = "/q" Then
                blnQuiet = True
                strOptionsMessage = strOptionsMessage & "Supress Console Log Output: " & blnQuiet & VbCrLf
            Elseif LCase(arrArguments(i)) = "/search" Then
                strSearchFile = "\windows\system32\winload.exe"
                strOptionsMessage = strOptionsMessage & "Search folder: " & strSearchFile & VbCrLf
            Elseif LCase(arrArguments(i)) = "/enable" Then
                blnEnableDrivers  = True
                strOptionsMessage = strOptionsMessage & "Enable, disalbed drivers." & VbCrLf
            Elseif LCase(arrArguments(i)) = "/install" Then
                blnInstallDrivers  = True
                strOptionsMessage = strOptionsMessage & "Install Plug & Play drivers." & VbCrLf
            Elseif LCase(arrArguments(i)) = "/restore" Then
                blnRestore = True
                strOptionsMessage = strOptionsMessage & "restore mode" & VbCrLf
            Elseif LCase(arrArguments(i)) = "/excludeclass" Then
                blnExcludeClass = True
                strOptionsMessage = strOptionsMessage & "Output file excludes specified filtered Class: " & blnExcludeClass & VbCrLf
            Elseif LCase(arrArguments(i)) = "/excludeprovider" Then
                blnInstallDrivers = True
                strOptionsMessage = strOptionsMessage & "Output file excludes specified filtered Provider: " & blnExcludeProvider & VbCrLf
            Else
                Wscript.Echo arrArguments(i) & " is not recognized as a valid input.."
                intParseCmdLine = CONST_ERROR
                Exit Function
            End If
        Else
            strSwitchValue = Right(arrArguments(i), Len(arrArguments(i))-(Len(strFlag)+1))
            Select Case LCase(strFlag)
                Case "/install"
                    strPNPFolder = strSwitchValue
                    blnInstallDrivers = True
                    strOptionsMessage = strOptionsMessage & "Plug & Play drivers top folder: " & strPNPFolder & VbCrLf
                Case "/target"
                    strTargetDrive = strSwitchValue
                    strOptionsMessage = strOptionsMessage & "Target drive: " & strTargetDrive & VbCrLf
                Case "/search"
                    strSearchFile = strSwitchValue
                    strOptionsMessage = strOptionsMessage & "Search folder: " & strSearchFile & VbCrLf
                Case "/log"
                    strLogFile = strSwitchValue
                    strOptionsMessage = strOptionsMessage & "Output log file name: " & strLogFile & vbCrLf
                Case "/class"
                    strClassFilter = strSwitchValue
                    strOptionsMessage = strOptionsMessage & "Device Class filter: " & strClassFilter & vbCrLf
                Case "/provider"
                    strProviderFilter = strSwitchValue
                    strOptionsMessage = strOptionsMessage & "Device Provider filter: " & strProviderFilter & VbCrLf
                Case else
                    Wscript.Echo "Invalid flag " & strFlag & "."
                    Wscript.Echo "Please check the input and try again."
                    intParseCmdLine = CONST_ERROR
                    Exit Function
            End Select
        End If
    Next

    strOptionsMessage = strOptionsMessage & vbCrLf

    intParseCmdLine = CONST_PROCEED

End Function


'********************************************************************
'*
'* Sub MassStorageHardwareIdsDict()
'*
'* Purpose:       Output the properties of an item from the Win32_PnPEntity
'*                collection as well as associated Enum and Service Registry
'*                information.
'*
'* Input:         objItem             Item from the Win32_PnPEntity collection
'*                objPnpIdDict        PNP ID dictionary (ByRef)
'*                blnAllHardwareID    return all HardwareID (testing only, don't use)
'*
'* Dependencies:  objRegistry         WMI StdRegProv object
'*
'********************************************************************
Sub MassStorageHardwareIdsDict(objItem, ByRef objPnpIdDict, blnAllHardwareID)

  Dim arrHardwareID
  Dim arrCompatibleIDs
  Dim i
  Dim lRC
  Dim blnMassStorageID
  Dim blnGenericID

  'select mass storage controllers
  blnMassStorageID = blnAllHardwareID
  objPnpIdDict.RemoveAll
  
  'Print("MassStorageHardwareIdsDict: " & strEnumKey & "   "& objItem.PNPDeviceID)

  'HardwareID
  lRC = g_objRegistry.GetMultiStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "HardwareID", arrHardwareID)
  If IsArray(arrHardwareID) Then
    For i = LBound(arrHardwareID) To UBound(arrHardwareID)
      If arrHardwareID(i) <> "" Then objPnpIdDict.Add arrHardwareID(i), arrHardwareID(i)
      'special case nvrd32.inf
      If UCASE(Left(arrHardwareID(i), 11)) = "SCSI\NVIDIA" Then blnMassStorageID = True
      If UCASE(Left(arrHardwareID(i), 11)) = "*_NVRAIDBUS" Then blnMassStorageID = True
      If UCASE(Left(arrHardwareID(i),  7)) = "*NVRAID" Then blnMassStorageID = True
    Next
  End If
  'CompatibleIDs
  lRC = g_objRegistry.GetMultiStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "CompatibleIDs", arrCompatibleIDs)
  If IsArray(arrCompatibleIDs) Then
    For i = LBound(arrCompatibleIDs) To UBound(arrCompatibleIDs)
      blnGenericID = False
      If UCASE(Left(arrCompatibleIDs(i),8)) = "PCI\VEN_" Then  IF Mid(arrCompatibleIDs(i),13,5) <> "&DEV_" Then blnGenericID = True
      'If UCASE(Left(arrCompatibleIDs(i),7)) = "PCI\CC_" Then blnGenericID = True

      If not blnGenericID And arrCompatibleIDs(i) <> "" Then
        If not objPnpIdDict.Exists(arrCompatibleIDs(i)) Then objPnpIdDict.Add arrCompatibleIDs(i), arrCompatibleIDs(i)
      End If

      If UCASE(Left(arrCompatibleIDs(i),9)) = "PCI\CC_01" Then blnMassStorageID = True
      If UCASE(arrCompatibleIDs(i)) = "*PNP0600" Then blnMassStorageID = True
    Next
  End If

  If not blnMassStorageID Then objPnpIdDict.RemoveAll
End Sub


'********************************************************************
'*
'* Function  AppendLog()
'*
'* Purpose:   Appends a message to the log file
'*
'* Input:     strlInput      String writen to log file
'*
'* Output:    strMessage is appended to the log file.
'*
'********************************************************************
Function AppendLog(ByRef strlInput)
  refLogFile.Writeline strlInput
End Function


'********************************************************************
'*
'* Sub Print()
'*
'* Purpose:   Prints a message on screen if blnQuiet = False.
'*            Prints a message to the log file if strLogFile <> "".
'*
'* Input:     strMessage    the string to print
'*
'* Output:    strMessage is printed on screen if blnQuiet = False.
'*            strMessage is printed to the log file if strLogFile <> "".
'*
'********************************************************************
Sub Print(ByRef strMessage)
  If Not blnQuiet Then
    Wscript.Echo  strMessage
  End If
  If strLogFile <> "" Then
    AppendLog(strMessage)
  End If
End Sub


'********************************************************************
'*
'* Function IsWinNT()
'*
'* Purpose:       Tests for Windows NT/2000/XP/2003
'*
'* Dependencies:  g_objWshShell     WshShell object
'*
'* Returns:       True on Windows NT/2000/XP/2003, False otherwise
'*
'********************************************************************
Function IsWinNT
  Dim strlOS
  strlOS = g_objWshShell.Environment("Process").Item("OS")
  IsWinNT = CBool(strlOS = "Windows_NT")
End Function


'********************************************************************
'*
'* Sub ShowUsage()
'*
'* Purpose:   Shows the correct usage to the user.
'*
'* Input:     None
'*
'* Output:    Help messages are displayed on screen.
'*
'********************************************************************

Sub ShowUsage()
    WScript.Echo "Adjust mass storage controller driver at offline system"
    WScript.Echo "Fix for some Stop 0x0000007B Errors"
    WScript.Echo ""
    WScript.Echo "Enable installed, but disabled mass storage drivers, e.g. msahci.sys"
    WScript.Echo "Install mass storage drivers, dism.exe is used"
    WScript.Echo ""
    WScript.Echo "Usage: cscript Fix_7hdc.vbs [options]"
    WScript.Echo ""
    WScript.Echo "Options:"
    WScript.Echo ""
    WScript.Echo " /enable             enable, installed but disabled MassStorage drivers"
    WScript.Echo ""
    WScript.Echo " /target:<drive>     target Win7 drive"
    WScript.Echo ""
    WScript.Echo " /install:<folder>   Path to the folder that will be the top of the Plug"
    WScript.Echo "                     & Play folder tree."
    WScript.Echo "                     default folder " & strPNPFolder
    WScript.Echo ""
    WScript.Echo " /search:<file>      search flag file to find target Win7_drive"
    WScript.Echo "                     (default: \windows\system32\winload.exe)"
    WScript.Echo ""
    WScript.Echo " /restore            restore registry system file"
    WScript.Echo ""
    WScript.Echo " /log:<file>         (Optional)  Location of the output file"
'    WScript.Echo ""
'    WScript.Echo " /class:<class>      (Optional)  Filter the output by device Clase"
'   WScript.Echo ""
'    WScript.Echo " /provider:<vendor>  (Optional)  Filter the output by driver Provider"
'    WScript.Echo ""
'    Wscript.echo " /excludeclass       (Optional)  Filtering excludes Class filtered items"
'    WScript.Echo "                     from output.  Default filtering in inclusive"
'    WScript.Echo "                     (only the filtered items are output)."
'    WScript.Echo ""
'    Wscript.echo " /excludeprovider    (Optional)  Filtering excludes Provider filtered items"
'    WScript.Echo "                     from output.  Default filtering in inclusive"
'    WScript.Echo "                     (only the filtered items are output)."
    WScript.Echo ""
    Wscript.echo " /q                  (Optional)  Suppresses all data output to the console."
    WScript.Echo ""
    WScript.Echo " /?                  (Optional)  Displays this help text."
    WScript.Echo ""
    WScript.Echo "Examples:"
    WScript.Echo "Fix_7hdc.vbs /enable /search"
    WScript.Echo "Fix_7hdc.vbs /enable /search:\users"
    WScript.Echo "Fix_7hdc.vbs /enable /install:F:\x86 /search"
    WScript.Echo "Fix_7hdc.vbs /install:D:\amd64 /target:C:"
    WScript.Echo "Fix_7hdc.vbs /install /search:\label.txt"
    WScript.Echo "Fix_7hdc.vbs /restore /target:C:"
End Sub


'********************************************************************
'*
'* Sub EnableDrivers()
'*
'* Purpose:       Endable disabled mass storage drivers at offline windows
'*
'*
'* Dependencies:  g_objFSO          FileSystem object
'*
'********************************************************************
Sub EnableDrivers()
  Dim blnFoundCDDB
  Dim strClassKey
  Dim strRegistyFile
  Dim strService
  Dim strDeviceDesc
  Dim l_objPnpIdDict
  Dim strControlSet
  Dim strLoadedEnumKey
  Dim strLoadedClassKey
  Dim strLoadedCDDBKey
  Dim strLoadedServicesKey
  Dim strLoadedService
  Dim strLoadedCDDBService
  Dim strStartService

  Set l_objPnpIdDict = CreateObject("Scripting.Dictionary")
  l_objPnpIdDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT

  strRegistyFile=strTargetDrive & "\windows\system32\config\SYSTEM"
  Print("")
  Print ("Enable mode")
  Print("")
  g_objFSO.CopyFile strRegistyFile , strRegistyFile & g_objFSO.GetTempName & ".sav", True
  Print("load registy file " & strRegistyFile)
  g_objWshShell.Run "reg.exe UNLOAD HKLM\loaded_SYSTEM", &H20000000, True
  g_objWshShell.Run "reg.exe   LOAD HKLM\loaded_SYSTEM " & strQuote & strRegistyFile & strQuote, &H20000000, True
  
  lRC = g_objRegistry.GetDwordValue(HKEY_LOCAL_MACHINE, "loaded_SYSTEM\Select", "Current", strControlSet)
  strControlSet = "ControlSet" & Left("000",3-Len(strControlSet)) & strControlSet
  strLoadedEnumKey =     "loaded_SYSTEM\"  & strControlSet & "\Enum\"
  strLoadedClassKey =    "loaded_SYSTEM\"  & strControlSet & "\Control\Class\"
  strLoadedCDDBKey =     "loaded_SYSTEM\"  & strControlSet & "\Control\CriticalDeviceDatabase\"
  strLoadedServicesKey = "loaded_SYSTEM\"  & strControlSet & "\Services\"

  'Print strLoadedEnumKey
  'Print strLoadedClassKey
  'Print strLoadedCDDBKey
  'Print strLoadedServicesKey
  
  'Print  g_objWshShell.Environment("Process").Item("COMSPEC")  
  'objReg.SetStringValue HKEY_USERS,strKeyPath1,"Wallpaper","C:\WINDOWS\Web\Wallpaper\kiosk.bmp"
	'objReg.SetStringValue HKEY_USERS,strKeyPath1,"OriginalWallpaper","C:\WINDOWS\Web\Wallpaper\kiosk.bmp"
  'objReg.SetStringValue HKEY_USERS,strKeyPath2,"Background","26 98 4"

  Print("")
  Print("========================================================")
  Print("     Enable existing Mass Storage drivers in system")
  Print("========================================================")
  
  
  Set colItems = g_objWMIService.ExecQuery("SELECT * FROM Win32_PnPEntity", "WQL", _
                                      wbemFlagReturnImmediately + wbemFlagForwardOnly)
  For Each objItem In colItems
    MassStorageHardwareIdsDict objItem, l_objPnpIdDict, False
    
    If l_objPnpIdDict.Count > 0 Then 
      lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "DeviceDesc", strDeviceDesc)
      lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Service", strService)
      lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strLoadedEnumKey & objItem.PNPDeviceID, "Service", strLoadedService)
      lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Class", strClass)
      Print("")
      Print(objItem.PNPDeviceID)
      'Print(strDeviceDesc & " ")
      'Print(strEnumKey & "  " & strService & "  " & strClass)
      'Print(strLoadedEnumKey & "  " & strLoadedService)
    End If
    
    blnFoundCDDB = False
    For Each Key In l_objPnpIdDict.Keys
      'Print(Key & "   " &   strLoadedCDDBKey & Replace(Key,"\","#") )
      lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strLoadedCDDBKey & Replace(Key,"\","#"), "Service", strLoadedCDDBService)
      If not blnFoundCDDB And not IsNull(strLoadedCDDBService) Then
        'Print("offline Registry  CDDB: " & Key & "  " & strLoadedCDDBService)
        lRC = g_objRegistry.GetDWordValue(HKEY_LOCAL_MACHINE, strLoadedServicesKey & strLoadedCDDBService, "Start", strStartService)
        If Not IsNull(strStartService) Then 
          Print("offline Registry  CDDB: " & Key & "  " & strLoadedCDDBService)
          If strStartService = 0 Then
            Print("Start already " & strStartService & "  no change")
            blnFoundCDDB = True
          Else
            Print(strLoadedServicesKey & strLoadedCDDBService)
            Print("Start set " & strStartService & "  change to 0")
            lRC = g_objRegistry.SetDWordValue(HKEY_LOCAL_MACHINE, strLoadedServicesKey & strLoadedCDDBService,"Start",&H0)
            if lRC <> 0 then Print("Error: setting failed. result: " & lRC )
            blnFoundCDDB = True
          End If
        End If
      End If
      
      If not blnFoundCDDB Then
    
        '''''''''blnFoundCDDB = True
      End If
    Next
  Next

  Print("")
  Print("unload registy file " & strRegistyFile)
  g_objWshShell.Run "reg.exe UNLOAD HKLM\loaded_SYSTEM", &H20000000, True
End Sub 'EnableDrivers()
'********************************************************************


'********************************************************************
'*
'* Sub InstallDrivers()
'*
'* Purpose:       Install mass storage drivers at offline windows
'*
'*
'* Dependencies:  g_objFSO          FileSystem object
'*
'********************************************************************
Sub InstallDrivers()
  Dim m
  Dim blnFoung_objDriverFolderDictFile
  Dim strService
  Dim strDismRun
  Dim l_objPnpIdDict
  Set l_objPnpIdDict = CreateObject("Scripting.Dictionary")
  l_objPnpIdDict.CompareMode = DICTIONARY_COMPAREMODE_TEXT


  Print("Sub: Install drivers: " & strPNPFolder)

  Print("")
  Print("==========================================")
  Print(Now & " : parse inf files")
  Print("==========================================")
  
  MakeInfFileList g_objFSO.GetFolder(strPNPFolder)
  GetHWID

  Print("")
  Print("========================================================")
  Print("     Mass Storage Plug and Play Devices in system")
  Print("========================================================")

  Set colItems = g_objWMIService.ExecQuery("SELECT * FROM Win32_PnPEntity", "WQL", _
                                      wbemFlagReturnImmediately + wbemFlagForwardOnly)
  For Each objItem In colItems
    'strPNPDeviceID = objItem.PNPDeviceID
    'lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Driver", strDriver)
    'lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strClassKey & strDriver, "ProviderName", strProviderName)
    'lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Class", strClass)

    blnFoung_objDriverFolderDictFile = False
    MassStorageHardwareIdsDict objItem, l_objPnpIdDict, False

    For Each Key In l_objPnpIdDict.Keys
      If dHwid.Exists(Key) Then
        Print (Key & Space(abs(45 - Len(Key))) & dHwid.Item(Key))
      Else
        Print(Key)
      End If
      If not blnFoung_objDriverFolderDictFile And dHwid.Exists(Key) Then
        'lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Driver", strDriver)
        lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Service", strService)
        'lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strClassKey & strDriver, "ProviderName", strProviderName)
        lRC = g_objRegistry.GetStringValue(HKEY_LOCAL_MACHINE, strEnumKey & objItem.PNPDeviceID, "Class", strClass)
        Print("current service: " & strService & "  " & strClass)
        blnFoung_objDriverFolderDictFile = True
        g_objInfDismFileDict.Add Key, dHwid.Item(Key)
      End If
    Next
  Next

  Print("")
  Print("==========================================")
  Print("Unique inf files relating Mass Storage IDs")
  Print("==========================================")
  
  m = &H20000000
  If blnGuiMode Then m = 1

  For Each Key in g_objInfDismFileDict.Keys
    Print(g_objInfDismFileDict.Item(Key) & "  " & Key)
    'dism continues if log file writing fails
    strDismRun = "dism.exe /Image:" & strTargetDrive _ 
      & "\ /Add-Driver /Driver:" & strQuote & g_objInfDismFileDict.Item(Key) & strQuote _ 
      & " /LogLevel:4 /LogPath:" _
      & g_objFSO.GetParentFolderName(WScript.ScriptFullName) & "\dism.offline.log"
    Print(strDismRun)
    g_objWshShell.Run strDismRun, m, True
    Print("")
  Next

  If g_objFSO.FileExists(strTargetDrive & "\windows\inf\setupapi.offline.log") Then Print("compare setup log file " & strTargetDrive & "\windows\inf\setupapi.offline.log")
End Sub
'********************************************************************


'======================================================================================
'based on ListHWID.vbs by RogueSpear http://forum.driverpacks.net/viewtopic.php?id=3148 
'edited by cdob
'
'********************************************************************
'*
'* Sub MakeInfFileList()
'*
'* Purpose:       Recurses the subfolders of the a folder
'*                to find folder containing *.inf files
'*
'* Input:         objToplFolder     Folder object to recurse
'*
'* Dependencies:  g_objFSO          FileSystem object
'*
'* Restrictions:  list created by HardwareID
'*                last read files goes in, double driver conflicts not resolved
'*                todo: use ranking compare http://support.microsoft.com/kb/279112 
'*
'********************************************************************
Sub MakeInfFileList(objToplFolder)
  Dim Subfolder, a, aFiles, strFile
  For Each Subfolder in objToplFolder.SubFolders
    Set a = g_objFSO.GetFolder(Subfolder.Path)
    Set aFiles = a.Files
    For Each strFile In aFiles
      If LCase(Right(strFile,4)) = ".inf" Then
        inf_count = inf_count + 1
        g_objDriverFolderDict.Add inf_count, strFile
      End If
    Next 
    MakeInfFileList Subfolder
  Next
End Sub

Sub GetHWID
  Dim regEx, Match, Matches, strFileName, strFile, objFile, line, strHardwareID, strCSV, z
  z = 0

  Set regEx = New RegExp
  regEx.IgnoreCase = True
  'regEx.Pattern = "[A-Z0-9]{2,}(?!PARAMS)\\[A-Z0-9_]{2,}_[A-F0-9]{2,}(&[A-Z_]{2,}_[A-F0-9]{2,}(&[A-Z]{2,}_[A-F0-9]{2,}(&[A-Z]{2,}_[A-F0-9]{2,})?)?)?"
  regEx.Pattern = ",\s*?[A-Z0-9]{2,}\\[A-Z0-9_]{2,}_[A-F0-9]{2,}(&[A-Z_]{2,}_[A-F0-9]{2,}(&[A-Z]{2,}_[A-F0-9]{2,}(&[A-Z]{2,}_[A-F0-9]{2,})?)?)?"

  For each strFileName in g_objDriverFolderDict.Items
    'Print("GetHWID: Set strFile " & strFileName)
    'unicode .inf file
    Set strFile = g_objFSO.OpenTextFile(strFileName, 1, False, -2)

    Do While strFile.AtEndOfStream = False
      line = strFile.ReadLine
      If Left(line, 1) <> ";" Then
        Set Matches = regEx.Execute(line)
        For Each Match In Matches
          'On Error Resume Next
          strHardwareID = Trim(Right(Ucase(Match.Value),Len(Match.Value)-1))
          If dHwid.Exists(strHardwareID) Then
            z = z + 1
            dHwid.Item(strHardwareID) = strFileName
          Else
            dHwid.Add strHardwareID, strFileName
          End If
        Next
      End If
    Loop
    strFile.Close()
  Next

  Print(Now & " : Found " & dHwid.Count & " HWIDs")
  Print(Now & " : Found " & z & " duplicate HWIDs")
End Sub


'======================================================================================
'Sort directory?
'http://support.microsoft.com/kb/246067/