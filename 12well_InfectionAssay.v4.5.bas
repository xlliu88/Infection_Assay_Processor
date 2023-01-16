Attribute VB_Name = "Module1"
'Microsoft VBA
'this module contains four main submodules:
'   1. RBD, to do Randomized Block Design and assign the design to 12-well plates
'   2. PntMelt, to sort penetration counting result
'   3. InfMelt, to sort 14 dpi and 30 dpi cyst counting result
'   4. reset, to restore the file to original status. for developing version only
'
'Created on Nov 7th, 2016
'function getGT() added on Nov 26, 2016
'function DictMerge() added on May 1, 2017
'function CountParse() added on May 2, 2017
'PntMelt sub-module added on May 31, 2017
'ReadData function added on June 1, 2017
'WriteData function added on June 1, 2017
'RBD sub-module incorperated on June 1, 2017
'a safty feature added to RBD sub-module to prevent overwrite of exist experiment design
'Reset sub-module incorperated on June 1, 2017
'add a function to save sorted data as .csv file on June 1, 2017
'Last modified on June 1, 2017

'Xunliang Liu
'xlliu88@gmail.com

Sub InfMelt()
Attribute InfMelt.VB_ProcData.VB_Invoke_Func = "m\n14"
    ' to sort infection data
    
    Dim genotype As New Scripting.Dictionary
    Dim treatment As New Scripting.Dictionary
    Dim infdata As New Collection
    Dim sh As Worksheet
    
    If shtexist("Infection") Then
        resort = MsgBox("Infection data already sorted" & vbCrLf & "Do you want to overwrite exist data?", vbYesNo + vbInformation)
        If Not resort = vbYes Then
            Exit Sub
        End If
    End If
    
    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo continue
        End If
        
        If genotype.count < getfactorlevels(sh, "Genotypes").count Then              'read genotype setting;
            Set genotype = DictMerge(genotype, getfactorlevels(sh, "Genotypes"))
        End If
        
        If treatment.count < getfactorlevels(sh, "Treatments").count Then              'read treatment setting;
            Set treatment = DictMerge(treatment, getfactorlevels(sh, "Treatments"))
        End If
continue:
    Next sh

    Set infdata = ReadData("Infection", 4, genotype, treatment)
    
    If infdata.count > 0 Then
        WriteData "Infection", infdata
        SaveCsv ActiveSheet
    Else
        MsgBox ("No data found")
    End If
    
End Sub

Sub PntMelt()
    ' to sort penetration data
    
    Dim genotype As New Scripting.Dictionary
    Dim treatment As New Scripting.Dictionary
    Dim pntdata As New Collection
    Dim sh As Worksheet
    
    If shtexist("Penetration") Then
        resort = MsgBox("Penetration data already sorted" & vbCrLf & "Do you want to overwrite exist data?", vbYesNo + vbInformation)
        If Not resort = vbYes Then
            Exit Sub
        End If
    End If
    
    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo continue
        End If
        
        If genotype.count < getfactorlevels(sh, "Genotypes").count Then
            Set genotype = DictMerge(genotype, getfactorlevels(sh, "Genotypes")) 'read genotype setting;
        End If
        
        If treatment.count < getfactorlevels(sh, "Treatments").count Then
            Set treatment = DictMerge(treatment, getfactorlevels(sh, "Treatments"))
        End If
continue:
    Next sh
    
    Set pntdata = ReadData("Penetration", 3, genotype, treatment)
    
    If pntdata.count > 0 Then
        WriteData "Penetration", pntdata
        SaveCsv ActiveSheet
    Else
        MsgBox ("No data found")
    End If
    
End Sub

Sub RBD()
    ' to do Randomized Block Design and assign the design to 12-well plates
    ' the design will have 36 replication in default
    
    Dim pairs As New Collection
    Dim sh As Worksheet
    
    If shtexist("RBDlayout") Then
        x = MsgBox("The Experiment Design already exist in this file" & vbCrLf & "Please start another file for new Experiment Design", vbOKOnly + vbCritical)
        Exit Sub
    End If
    
    ngt = 0
    ntrt = 0
    
    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet1
        End If

        If getfactorlevels(sh, "Genotypes").count > ngt Then
            ngt = getfactorlevels(sh, "Genotypes").count
        End If
        If getfactorlevels(sh, "Treatments").count > ntrt Then
            ntrt = getfactorlevels(sh, "Treatments").count
        End If
skipsheet1:
    Next
 
    For I = 0 To ngt * ntrt - 1
        trt = (I Mod ntrt) + 1
        gt = Int(I / ntrt) + 1
        If ngt = 1 Then
            pair = trt
        ElseIf ntrt = 1 Then
            pair = gt
        Else
            pair = gt & " ~ " & trt
        End If
        pairs.Add (pair)
    Next I
    
    Dim trts As New Collection
    For Rep = 1 To 36
        Set trts = collmerge(trts, shuffle(pairs))
    Next Rep

    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet2
        End If
        
        sh.Activate
        welldesignation trts, sh, 1 ' last parameter: optional; 0 will not delete existing plates; 1 will delete existing plates

skipsheet2:
    Next
    
    RDBlayout trts
    pntsht trts, repcount()
    
End Sub

Sub reset()
    ' to restore the file to original status
    ' only for developing version

    Dim sht As Worksheet
    
    userinput = MsgBox("Warning!" & vbCrLf & vbCrLf & "This Operation Will Delete ALL Data" & vbCrLf & "Press OK to continue...", vbOKCancel + vbCritical, "Warning")
    
    If Not userinput = vbOK Then
        GoTo cancel
    End If
    
    For Each sht In ThisWorkbook.Worksheets
        If InStr(sht.Name, "Rep") = 0 Then
            Application.DisplayAlerts = False
            sht.Delete
        Else
            sht.Rows(10 & ":" & sht.Rows.count).clear
        End If
    Next
cancel:
End Sub

Sub shuftest(n As Integer, r As Integer, Optional coll As Collection)
    ' to test the collection shuffle function
    
    Dim testcoll As New Collection
    Dim newcoll As New Collection
    
    Debug.Print "== collection shuffle test =="
    makesht "shuffled"
    
    For I = 1 To n
      testcoll.Add I
    Next I
    
    For j = 1 To r
        Set newcoll = shuffle(testcoll)
        Debug.Print "shuffle # " & j
        Debug.Print " shuffled: "
        For k = 1 To newcoll.count
            Cells(j, k).Value = newcoll(k)
            Debug.Print "  " & newcoll(k)
        Next k
        
        Set newcoll = New Collection
    Next j
End Sub

Function shtexist(shtname As String)
    ' to test if a sheet is exist
    
    shtexist = Evaluate("ISREF('" & shtname & "'!A1)")
End Function

Sub makesht(shtname As String, Optional clear As Boolean)
    ' to make a new sheet, shtname as sheet name
    ' clear: wether to clear the content if the sheet already exists
    
    If shtexist(shtname) Then
        Worksheets(shtname).Activate
        If clear Then
            Worksheets(shtname).Cells.clear
        End If
    Else
        Worksheets.Add(after:=Sheets(Sheets.count)).Name = shtname
        Worksheets(shtname).Activate
    End If
End Sub

Function collett(col) As String
    ' to convert column number to letter
    
    collett = Split(Cells(1, col).Address, "$")(1)
End Function

Function shuffle(coll As Collection, Optional test As String) As Collection
    ' to randomly shuffle a collection
    
    Dim shufcoll As New Collection
    Dim tempColl As New Collection
    
    For icoll = 1 To coll.count     ' to make a tempary collection identical to input collection;
        tempColl.Add coll(icoll)    ' simply use Set will modify the input collection
    Next
    
    n = tempColl.count
    For I = 0 To n - 1
        r = Int(Rnd(1) * (n - I)) + 1   ' generate a random number between 1 and tempcoll.count
        shufcoll.Add tempColl(r)
        tempColl.Remove (r)
    Next I
    
    Set shuffle = shufcoll
End Function

Function collmerge(colla As Collection, collb As Collection) As Collection
    ' to merge two collections
    ' collb will added to the end of colla
    
    Dim merged As New Collection
    
    For Each Item In colla
        merged.Add Item
    Next Item
    
    For Each Item In collb
        merged.Add Item
    Next Item
    
    Set collmerge = merged
End Function

Function DictMerge(dicta As Scripting.Dictionary, dictb As Scripting.Dictionary) As Scripting.Dictionary
    ' to merge to dictionaries
    
    Dim merged As New Scripting.Dictionary

    For Each ka In dicta.Keys()
        merged(ka) = dicta(ka)
    Next ka
    
    For Each kb In dictb.Keys()
        merged(kb) = dictb(kb)
    Next kb
    
    Set DictMerge = merged
End Function

Function repcount()
    Dim sht As Worksheet
    
    count = 0
    For Each sht In ThisWorkbook.Worksheets
        If InStr(sht.Name, "Rep") Then
            count = count + 1
        End If
    Next

    repcount = count
End Function

Function getfactorlevels(sh As Worksheet, factor As String, Optional test As String) As Scripting.Dictionary
    ' to read factor levels and return as a dictionary
    
    Dim Loc As Range
    Dim factlvls As New Scripting.Dictionary
    
    Set Loc = sh.Cells.Find(what:=factor)
    If (Not Loc Is Nothing) Then
        r = Loc.Row + 1 'row number
        c = Loc.Column 'column number

        Do While Not IsEmpty(sh.Cells(r, c + 1).Value)
            factlvls(CStr(sh.Cells(r, c).Value)) = CStr(sh.Cells(r, c + 1).Value)
            r = r + 1
        Loop
    Else
        Debug.Print factor & " setting not found"
    End If
    
    Set getfactorlevels = factlvls
    
    If test = "TEST" Then
        Debug.Print "Sheet: " & sh.Name
        Debug.Print factor & " location: " & Loc.Address
        Debug.Print "total " & factor & " found:" & factlvls.count
        Debug.Print "---------"
        For Each Key In factlvls.Keys()
            Debug.Print "  " & Key & ":" & factlvls(Key)
        Next Key
        Debug.Print "---------"
    End If
End Function

Sub drawplt(r, c, num, Optional nrow As Integer = 1)
    'this function draws a plate diagrame on excel sheet
    'r as the row# of plate
    'c as the column of plate
    'num as the plate#
    'nrow as the number of lines you need for each row on 12 well
    
    Dim Loc As Range
    Dim first As Range
    Dim last As Range
    
    Dim pltrange As Range
    
    Set Loc = Cells(r, c)
    Set first = Cells(r + 2, c + 1)
    Set last = Cells(r + 1 + 3 * nrow, c + 4)
    
    firstcol = Chr(Asc("A") + c - 1)
    lastcol = Chr(Asc("A") + c + 4)
    Columns(collett(c) & ":" & collett(c)).ColumnWidth = 2          'set column width
    Columns(collett(c + 5) & ":" & collett(c + 5)).ColumnWidth = 2
    
    Range(first, last).Borders.LineStyle = xlContinuous ' set well borders
    Range(Loc, last).RowHeight = 12                     ' set row height
    
    Loc.Value = "Plate " & num
    Loc.Font.Bold = True
    For I = 1 To 4
        Cells(r + 1, c + I).Value = I
        Cells(r + 1, c + I).HorizontalAlignment = xlCenter
    Next
    For j = 1 To 3
        Cells(r + 2 + (j - 1) * nrow, c).Value = Chr(Asc("A") + j - 1)
        Cells(r + 2 + (j - 1) * nrow, c).HorizontalAlignment = xlCenter
    Next
End Sub

Function CountParse(count As String, d As String)
    ' to categorize counts
    ' each catagory was determined by "," and the total count will be add up in another catagory
    ' if the count is not catagorized, the return will be the original data
    
    Dim res As New Scripting.Dictionary
    
    Key = "C" & d & "dpi"
    
    If InStr(count, ",") Then     'if the count has different catagories
        csplit = Split(count, ",")
        res(Key) = 0
        For I = 0 To UBound(csplit)
            k = Key & "-c" & I + 1
            
            If Not IsNumeric(csplit(I)) Then
                res(k) = 0
            Else
                res(k) = csplit(I)
            End If
            res(Key) = res(Key) + res(k)
        Next I
    Else
        res(Key) = count
    End If
    Set CountParse = res
End Function

Function trtparse(v As String, gt As Scripting.Dictionary, trt As Scripting.Dictionary, Optional test As String) As Scripting.Dictionary
    ' to parse the genotype ~ treatment pairs from RBD
    
    Dim res As New Scripting.Dictionary

    If InStr(v, "~") Then
        trtpair = Split(v, " ~ ")
        'res("gtCode") = CInt(trtpair(0))
        'res("trtCode") = CInt(trtpair(1))
        res("gtCode") = CStr(trtpair(0))
        res("trtCode") = CStr(trtpair(1))
    Else
        If gt.count = 1 Then
            res("trtCode") = v
            res("gtCode") = "1"
        Else
            res("trtCode") = "1"
            res("gtCode") = v
        End If
    End If
    res("Genotype") = gt(res("gtCode"))
    res("Treatment") = trt(res("trtCode"))
    
    Set trtparse = res
    
    If test = "TEST" Then
        Debug.Print "== Input settings =="
        Debug.Print "Genotypes"
        For Each Key In gt.Keys()
            Debug.Print "  " & Key & ":" & gt(Key)
        Next
        Debug.Print "Treatments"
        For Each Key In trt.Keys()
            Debug.Print "  " & Key & ":" & trt(Key)
        Next
        Debug.Print "Genotype: " & res("gtCode") & "-" & res("Genotype")
        Debug.Print "Treatment:" & res("trtCode") & "-" & res("Treatment")
    End If
End Function

Sub pntsht(coll As Collection, reps)
    ' to make sheets for penetration assay;
    ' default replicates are half of infection assay
    ' it will copy experiment infomation from Rep sheet
    
    Dim halfcoll As New Collection
    Dim shtname As String
    
    For I = 1 To coll.count / 2
        halfcoll.Add coll(I)
    Next

    For Rep = 1 To reps
        shtname = "Pnt" & Rep
        makesht shtname, 1
        Worksheets(shtname).Activate
        Range(Cells(1, 1), Cells(9, 1)).RowHeight = 12
        Cells(1, 1).Value = "Penetration Assay"
        Cells(1, 1).Font.Bold = True
        Range("$A$2", "$Z$9").Value = Worksheets("Rep" & Rep).Range("$A$2", "$Z$9").Value
        RDBfill halfcoll, "Penetration"
    Next
End Sub

Sub welldesignation(trts As Collection, sht As Worksheet, Optional clearplts As Boolean = False)
    ' to designate radomrized (genotype - treatment) pairs to each well

    Dim n As Integer

    If clearplts = True Then
        sht.Rows(10 & ":" & Rows.count).Delete
    End If
    
    RDBfill trts, "Infection"
End Sub

Sub RDBlayout(coll As Collection)
    ' to layout the overall view of RBD design
    
    Dim pltLoc As Range
    
    makesht "RBDlayout", 1
    Worksheets("RBDlayout").Activate
    Cells(1, 1).Value = "Randomized Block Design Layout"
    Cells(1, 1).Font.Bold = True

    RDBfill coll
End Sub

Sub RDBfill(coll As Collection, Optional asdatasheet As String = "Simple")
    ' to fill the RDB design to wells
    ' it has 3 modes:
    '   1. "Simple" as default, just to lay out the overall design
    '   2. "Penetration", for penetration
    '   3. "Infection", for infection assay
    
    Dim startrow As Integer
    Dim nrow As Integer

    If asdatasheet = "Infection" Then
        startrow = 10
        nrow = 4
    ElseIf asdatasheet = "Penetration" Then
        startrow = 10
        nrow = 3
    Else
        startrow = 3
        nrow = 1
    End If
    
    nplt = coll.count / 12 + 1
    spacer = 0
    itm = 1
    For p = 1 To nplt
        For wr = 1 To 3
          For wc = 1 To 4
            If itm > coll.count Then
                Exit Sub
            End If
            
            If ((itm - 1) Mod 12) = 0 Then
                pltnum = Int(itm / 12) + 1
                If asdatasheet = "Infection" And pltnum > 2 And (Int((pltnum - 1) / 2) Mod 3) = 0 Then
                    spacer = 10 * Int((pltnum - 1) / 2) / 3
                    'spacer = 10
                Else
                    spacer = spacer
                End If
                
                pltrow = Int((pltnum - 1) / 2) * (3 + 3 * nrow) + startrow + spacer
                'pltrow = pltrow + ((3 + 3 * nrow) + spacer) * (pltnum Mod 2)
                pltcol = ((pltnum - 1) Mod 2) * 6 + 1
                drawplt pltrow, pltcol, pltnum, nrow
            End If
            
            Cells(pltrow + (wr - 1) * nrow + 2, wc + pltcol) = coll(itm)
            Cells(pltrow + (wr - 1) * nrow + 2, wc + pltcol).HorizontalAlignment = xlCenter
            itm = itm + 1
          Next
        Next
    Next
End Sub

Function expInfo(sh As Worksheet)
    ' to read basic experiment information; from row 2 to 9 of each sheet

    Dim info As New Scripting.Dictionary

    info("Rep") = sh.Cells(2, 4).Value
    info("Ecotype") = sh.Cells(4, 4).Value
    info("ppJ2No") = sh.Cells(7, 4).Value
    info("plate_date") = sh.Cells(5, 4).Value
    info("inoc_date") = sh.Cells(6, 4).Value
    info("c14date") = sh.Cells(8, 4).Value
    info("c30date") = sh.Cells(9, 4).Value

    Set expInfo = info 'return experiment info as a dictionary
End Function

Function ReadData(datatype As String, NoR As Integer, Optional fact1 As Scripting.Dictionary, Optional fact2 As Scripting.Dictionary) As Collection
    ' to read data from sheets
    ' datatype: "Infection" or "Penetration"
    ' NoR:  number of rows in each plate setting
    
    Dim Loc As Range
    Dim FirstFound As String
    Dim gttrtpair As String
    Dim dat As New Collection
    Dim welldata As New Scripting.Dictionary
    Dim sh As Worksheet
    
    searchkey = datatype & " Assay"
    
    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, searchkey) = 0) Then
            GoTo skipsheet
        End If
        
        'Sh.Activate
        Set Loc = sh.Cells.Find(what:="Plate ")
        
        If Loc Is Nothing Then
            MsgBox ("No Plate Found on Sheet: " & sh.Name)
            GoTo skipsheet
        End If
        
        FirstPlate = Loc.Address
        Do
            If UBound(Split(Loc.Value)) > 0 Then
                wellx = Loc.Column + 1
                welly = Loc.Row + 2
                
                For y = 0 To (3 * NoR - 1) Step NoR
                    For x = 0 To 3
                        gttrtpair = sh.Cells(welly + y, wellx + x).Value

                        If gttrtpair = "na" Then
                            GoTo skipsheet
                        End If
                        
                        Set welldata = expInfo(sh)
                        welldata("Plate#") = CInt(Split(Loc.Value)(1)) 'get plate number
                        welldata("Well#") = sh.Cells(welly + y, Loc.Column).Value & sh.Cells(welly - 1, wellx + x).Value
                        Set welldata = DictMerge(welldata, trtparse(gttrtpair, fact1, fact2))
                        If datatype = "Infection" Then
                            welldata("Note") = sh.Cells(welly + y + 3, wellx + x).Value
                            Set welldata = DictMerge(welldata, CountParse(sh.Cells(welly + y + 1, wellx + x).Value, 14))
                            Set welldata = DictMerge(welldata, CountParse(sh.Cells(welly + y + 2, wellx + x).Value, 30))
                        ElseIf datatype = "Penetration" Then
                            welldata("Note") = sh.Cells(welly + y + 2, wellx + x).Value
                            welldata("Penetration") = sh.Cells(welly + y + 1, wellx + x)
                        End If
                        
                        For Each k In welldata.Keys():
                            Debug.Print "   " & k & ": " & welldata(k)
                        Next k
                        
                        dat.Add welldata 'add individule data to a collection
                    Next x
                Next y
            End If
            Set Loc = sh.Cells.FindNext(Loc)                                'reset Loc to the next cell with "Plate "
        Loop While Not Loc Is Nothing And Loc.Address <> FirstPlate         'end of one plate; exit loop when the location of next found cells is the same as the first found cell
        Set Loc = Nothing
skipsheet:
    Next        'Go to next sheet

    Set ReadData = dat
End Function

Sub WriteData(shtname As String, table As Collection)
    ' to write a collection of data to sheet named shtname
    ' data in the collection should be Dictionaries
    ' key of the first Dictionary will be used as the title

    makesht shtname, True
    
    'Write data
    Dim dat As New Scripting.Dictionary
    For y = 1 To table.count
        Set dat = table(y)
        If y = 1 Then                      'for the first line, write the title
            For x = 0 To dat.count - 1
                Cells(y, x + 1).Value = dat.Keys(x)
            Next x
        End If

        For x = 0 To dat.count - 1        'write the data
            Cells(y + 1, x + 1).Value = dat.Items(x)
        Next x
    Next y

End Sub

Sub SaveCsv(sht As Worksheet)
    ' to save sht as a .csv file
    ' use the "workbookname_shtname.csv" as file name
    ' if file exist, it will prompt to enter a new file name
    
    Path = ThisWorkbook.Path
    wbname = Split(ThisWorkbook.Name, ".")(0)
    filename = wbname & "_" & sht.Name

    Do While Dir(Path & "\" & filename & ".csv") <> ""  ' loop while file exist
        overwrite = MsgBox("File " & vbCrLf & "'" & filename & ".csv'" & " Exists in this location" & vbCrLf & "Do you want to overwrite this file?", vbYesNoCancel + vbQuestion)
        
        If overwrite = vbNo Then
            filename = InputBox("Please Enter a new Name: ", Default:=wbname & "_" & sht.Name & "_")
            
            If filename = "" Then
                filename = wbname & "_" & sht.Name
            End If
        ElseIf overwrite = vbYes Then
            Exit Do
        ElseIf overwrite = vbCancel Then
            Exit Sub
        End If
    Loop
    
    Set wbExport = Application.Workbooks.Add
    sht.Copy before:=wbExport.Worksheets(wbExport.Worksheets.count)
    
    Application.DisplayAlerts = False
    wbExport.SaveAs Path & "\" & filename, xlCSV
    wbExport.Close SaveChanges:=False
    Application.DisplayAlerts = True
End Sub
