Attribute VB_Name = "Module1"
'Microsoft VBA
'this module contains four main submodules:
'   1. RBD, to do Randomized Block Design and assign the design to 12-well plates
'   2. PntMelt, to sort penetration counting result
'   3. InfMelt, to sort 14 dpi and 30 dpi cyst counting result
'   4. Reset, to restore the file to original status. for developing version only
'   5. Summarize(), to summarize sorted data
'
'2016-11-07, Created
'2016-11-26, function getGT() added
'2017-05-01, function DictMerge() added
'2017-05-02, function CountParse() added to catogorize cyst count
'2017-05-02, function getGT() modified to getfactorlvls() to generalize factor analysis
'2017-05-02, function trtparse() added to parse genotype - treatment pairs
'2017-05-31, sub-module PntMelt added to sort penetration data
'2017-06-01, function SortData() added (from InfMelt() sub-module)
'2017-06-01, function WriteData() added (from InfMelt() sub-module)
'2017-06-01, RBD sub-module incorperated with InfMelt() sub-module
'2017-06-01, a safty feature added to RBD sub-module to prevent overwrite of exist experiment design
'2017-06-01, Reset() sub-module incorperated to reset the workbook to original status; for developing only
'2017-06-01, function SaveCSV() added to save sorted data as .csv file
'2017-06-02, function Addbutton() to add app button in sorted "Infection" and "Penetration" sheets; the button will be linked to a macro to summary data later
'2017-06-04, function RBDfill() modified to add a simulation function
'2017-06-04, sub-module summarize() added to summarize "infection" and "Penetration" data
'2017-06-04, genotype and treatment changed to public variants; thus can be directed used in various functions/sub-modules
'Last modified on June 4, 2017

'Xunliang Liu
'xlliu88@gmail.com


Public genotype As New Scripting.Dictionary
Public treatment As New Scripting.Dictionary

Sub Summarize()
    Dim title As New Scripting.Dictionary
    Dim sh As Worksheet
    Dim sumTables As New Scripting.Dictionary
    Dim dstatsTables As New Scripting.Dictionary
       
    ThisWorkbook.Worksheets("Infection").Select
    
    SetFactors
    
    nrep = repcount()
    ngt = genotype.count
    ntrt = treatment.count
    nblock = nrep * ngt * ntrt
    ncol = ActiveSheet.UsedRange.Columns.count
    nrow = ActiveSheet.UsedRange.Rows.count

    For c = 1 To ncol
        title(Cells(1, c).Value) = c
    Next
    
    ndats = ncol - title("Note")
        
    Dim reshaped As New Scripting.Dictionary
    Dim dstats As New Scripting.Dictionary
    Dim sumarr(1 To 4) As Variant   ' has to set to variant to store empty values
    Dim datarr(1 To 36) As Variant  ' Empty value will turn into 0 if use Double

    For d = 1 To ndats ' d: sub-data group. ie, 14dpi, 30 dpi
        Set reshaped = Nothing
        Set dstats = Nothing
        For rep = 1 To nrep
            For gt = 1 To ngt
                For trt = 1 To ntrt
                    idt = rep & "," & gt & "," & trt
                    x = 1
                    For rw = 2 To nrow
                        If Cells(rw, title("Rep")).Value = CInt(rep) And Cells(rw, title("gtCode")).Value = CInt(gt) And Cells(rw, title("trtCode")).Value = CInt(trt) Then
                            If Not IsEmpty(Cells(rw, title("Note") + d).Value) Then
                                datarr(x) = Cells(rw, title("Note") + d).Value
                            Else
                                datarr(x) = Empty
                            End If
                            x = x + 1
                        End If
                    Next
                    
                    For i = 1 To UBound(datarr)
                        Debug.Print "IDT: " & idt & "---"
                        Debug.Print "i: " & i
                        Debug.Print datarr(i)
                        Debug.Print IsEmpty(datarr(i))
                    Next
                    
                        
                    sumarr(1) = nObs(datarr)
                    sumarr(2) = Application.WorksheetFunction.Average(datarr)
                    sumarr(3) = Application.WorksheetFunction.StDev(datarr)
                    sumarr(4) = sumarr(3) / Sqr(sumarr(1))

                    reshaped(idt) = datarr
                    dstats(idt) = sumarr
                Next
            Next
        Next
        Set sumTables(Cells(1, title("Note") + d).Value) = reshaped
        Set dstatsTables(Cells(1, title("Note") + d).Value) = dstats
    Next

    'SumDataOutput2 Worksheets("Infection"), sumTables
    SumDataOutput2 Worksheets("Infection"), dstatsTables, "sum"
    
End Sub

Sub InfMelt()
    ' to sort infcetion data
    
    Dim infdata As New Collection
    Dim sh As Worksheet
    
    If shtexist("Infection") Then
        resort = MsgBox("Infection data already sorted" & vbCrLf & "Do you want to overwrite exist data?", vbYesNo + vbInformation)
        If Not resort = vbYes Then
            Exit Sub
        End If
    End If
    
    SetFactors

    Set infdata = SortData("Infection", 4)
    
    If infdata.count > 0 Then
        WriteData "Infection", infdata
        AddButton Worksheets("Infection")
        SaveCsv ActiveSheet
    Else
        MsgBox ("No data found")
    End If
    
End Sub

Sub PntMelt()
    ' to sort penetration data
    
    'Dim genotype As New Scripting.Dictionary
    'Dim treatment As New Scripting.Dictionary
    Dim pntdata As New Collection
    Dim sh As Worksheet
    
    If shtexist("Penetration") Then
        resort = MsgBox("Penetration data already sorted" & vbCrLf & "Do you want to overwrite exist data?", vbYesNo + vbInformation)
        If Not resort = vbYes Then
            Exit Sub
        End If
    End If
    SetFactors
    
    Set pntdata = SortData("Penetration", 3)
    
    If pntdata.count > 0 Then
        WriteData "Penetration", pntdata
        AddButton Worksheets("Penetration")
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
    
    SetFactors
    ngt = genotype.count
    ntrt = treatment.count

    For i = 0 To ngt * ntrt - 1
        trt = (i Mod ntrt) + 1
        gt = Int(i / ntrt) + 1
        If ngt = 1 Then
            pair = trt
        ElseIf ntrt = 1 Then
            pair = gt
        Else
            pair = gt & " ~ " & trt
        End If
        pairs.Add (pair)
    Next i
    
    Dim trts As New Collection
    For rep = 1 To 36
        Set trts = collmerge(trts, shuffle(pairs))
    Next rep

    For Each sh In ThisWorkbook.Worksheets
        If (InStr(sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet2
        End If
        
        sh.Activate
        welldesignation trts, sh, 1, simu:=True   ' last parameter: optional; 0 will not delete existing plates; 1 will delete existing plates

skipsheet2:
    Next
    
    RDBlayout trts
    pntsht trts, repcount(), simu:=True
    
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
    
    For i = 1 To n
      testcoll.Add i
    Next i
    
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
    For i = 0 To n - 1
        r = Int(Rnd(1) * (n - i)) + 1   ' generate a random number between 1 and tempcoll.count
        shufcoll.Add tempColl(r)
        tempColl.Remove (r)
    Next i
    
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

Function printDict(dict As Scripting.Dictionary)
    
    Debug.Print "=== Start ==="
    For Each k In dict.Keys
        Debug.Print "Key: " & k
        Debug.Print "Value:" & dict(k)
    Next
    Debug.Print "=== End ==="
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
            factlvls(sh.Cells(r, c).Value) = sh.Cells(r, c + 1).Value
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

Sub SetFactors()
    Dim sht As Worksheet
    
    For Each sht In ThisWorkbook.Worksheets
        If (InStr(sht.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo continue
        End If
        
        If genotype.count < getfactorlevels(sht, "Genotypes").count Then              'read genotype setting;
            Set genotype = DictMerge(genotype, getfactorlevels(sht, "Genotypes"))
        End If
        
        If treatment.count < getfactorlevels(sht, "Treatments").count Then              'read treatment setting;
            Set treatment = DictMerge(treatment, getfactorlevels(sht, "Treatments"))
        End If
continue:
    Next sht
End Sub

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
    For i = 1 To 4
        Cells(r + 1, c + i).Value = i
        Cells(r + 1, c + i).HorizontalAlignment = xlCenter
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
        For i = 0 To UBound(csplit)
            k = Key & "-c" & i + 1
            
            If Not IsNumeric(csplit(i)) Then
                res(k) = 0
            Else
                res(k) = csplit(i)
            End If
            res(Key) = res(Key) + res(k)
        Next i
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
        res("gtCode") = CInt(trtpair(0))
        res("trtCode") = CInt(trtpair(1))
    Else
        If gt.count = 1 Then
            res("trtCode") = CInt(v)
            res("gtCode") = 1
        Else
            res("trtCode") = 1
            res("gtCode") = CInt(v)
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

Sub pntsht(coll As Collection, nrep, Optional simu As Boolean = False)
    ' to make sheets for penetration assay;
    ' default replicates are half of infection assay
    ' it will copy experiment infomation from Rep sheet
    
    Dim halfcoll As New Collection
    Dim shtname As String
    
    For i = 1 To coll.count / 2
        halfcoll.Add coll(i)
    Next

    For rep = 1 To nrep
        shtname = "Pnt" & rep
        makesht shtname, 1
        Worksheets(shtname).Activate
        Range(Cells(1, 1), Cells(9, 1)).RowHeight = 12
        Cells(1, 1).Value = "Penetration Assay"
        Cells(1, 1).Font.Bold = True
        Range("$A$2", "$Z$9").Value = Worksheets("Rep" & rep).Range("$A$2", "$Z$9").Value
        RDBfill halfcoll, "Penetration", simu
    Next
End Sub

Sub welldesignation(trts As Collection, sht As Worksheet, Optional clearplts As Boolean = False, Optional simu As Boolean = False)
    ' to designate radomrized (genotype - treatment) pairs to each well

    Dim n As Integer

    If clearplts = True Then
        sht.Rows(10 & ":" & Rows.count).Delete
    End If
    
    RDBfill trts, "Infection", simu
End Sub

Sub RDBlayout(coll As Collection, Optional simu As Boolean = False)
    ' to layout the overall view of RBD design
    
    Dim pltLoc As Range
    
    makesht "RBDlayout", 1
    Worksheets("RBDlayout").Activate
    Cells(1, 1).Value = "Randomized Block Design Layout"
    Cells(1, 1).Font.Bold = True

    RDBfill coll
End Sub

Sub RDBfill(coll As Collection, Optional asdatasheet As String = "Simple", Optional simu As Boolean = False)
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
            
            Cells(pltrow + (wr - 1) * nrow + 2, wc + pltcol).Value = coll(itm)
            Cells(pltrow + (wr - 1) * nrow + 2, wc + pltcol).HorizontalAlignment = xlCenter
            
            ' add simulated data
            If simu = True And asdatasheet = "Infection" Then
                Cells(pltrow + (wr - 1) * nrow + 3, wc + pltcol).Value = Int(Rnd(1) * (20 - 5)) + 6
                Cells(pltrow + (wr - 1) * nrow + 4, wc + pltcol).Value = Int(Rnd(1) * (25 - 8)) + 9
                
            ElseIf simu = True And asdatasheet = "Penetration" Then
                Cells(pltrow + (wr - 1) * nrow + 3, wc + pltcol).Value = Int(Rnd(1) * (92 - 25)) + 26
            End If
            
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

Function SortData(datatype As String, NoR As Integer)
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
                        Set welldata = DictMerge(welldata, trtparse(gttrtpair, genotype, treatment))
                        If datatype = "Infection" Then
                            welldata("Note") = sh.Cells(welly + y + 3, wellx + x).Value
                            Set welldata = DictMerge(welldata, CountParse(sh.Cells(welly + y + 1, wellx + x).Value, 14))
                            Set welldata = DictMerge(welldata, CountParse(sh.Cells(welly + y + 2, wellx + x).Value, 30))
                        ElseIf datatype = "Penetration" Then
                            welldata("Note") = sh.Cells(welly + y + 2, wellx + x).Value
                            welldata("Penetration") = sh.Cells(welly + y + 1, wellx + x)
                        End If

                        dat.Add welldata 'add individule data to a collection
                    Next x
                Next y
            End If
            Set Loc = sh.Cells.FindNext(Loc)                                'reset Loc to the next cell with "Plate "
        Loop While Not Loc Is Nothing And Loc.Address <> FirstPlate         'end of one plate; exit loop when the location of next found cells is the same as the first found cell
        Set Loc = Nothing
skipsheet:
    Next        'Go to next sheet

    Set SortData = dat
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

Sub AddButton(sht As Worksheet)
    
    'Set sht = Sheets("Infection")
    sht.Select
    ncol = sht.UsedRange.Columns.count
    colwth = sht.Cells(1, ncol).Width
    RowHeight = sht.Cells(1, 1).Height
    
    ActiveSheet.Buttons.Add((ncol + 2) * colwth, RowHeight, colwth * 2, RowHeight * 2).Select
    Selection.Characters.Text = "Summarize data"
    Selection.OnAction = "summarize"
    
    With Selection.Characters(start:=1, Length:=8).Font
        .Name = "Lucida Console"
        .FontStyle = "Regular"
        .Size = 10
        .Strikethrough = False
        .Superscript = False
        .Subscript = False
        .OutlineFont = False
        .Shadow = False
        .Underline = xlUnderlineStyleNone
        .ColorIndex = 1
    End With
    
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

Sub SumDataOutput(sht As Worksheet, datDict As Scripting.Dictionary, Optional outtype As String = "Pivot")
    ' to write a reshaped table or a summarized table to a new sheet
    
    Dim sumsht As String
    sumsht = Left(sht.Name, 3) & "_" & outtype
    makesht sumsht, 1
    Sheets(sumsht).Select
    
    nrep = repcount()
    ngt = genotype.count
    ntrt = treatment.count
    nblock = nrep * ngt * ntrt
    
    t = 0
    For Each k In datDict
        start_row = t * (nblock + 3) + 1
        Cells(start_row, 1).Value = k
        Range(Cells(start_row + 1, 1), Cells(start_row + 1, 3)).Value = Array("Rep", "Genotype", "Treatment")
        
        If outtype = "sum" Then
            Range(Cells(start_row + 1, 4), Cells(start_row + 1, 6)) = Array("N", "Avearge", "Stderr")
        End If
    
        For y = 1 To UBound(datDict(k), 2)
            For x = 1 To UBound(datDict(k), 1)
                Cells(start_row + 1 + y, 1).Value = Int((y - 1) / (ngt * ntrt)) + 1
                Cells(start_row + 1 + y, 2).Value = genotype(Int((y - 1) Mod (ngt * ntrt) / ntrt) + 1)
                Cells(start_row + 1 + y, 3).Value = treatment(((y - 1) Mod ntrt) + 1)
                Cells(start_row + 1 + y, x + 4).Value = datDict(k)(x, y)
            Next
        Next
        t = t + 1
    Next
End Sub

Sub SumDataOutput2(sht As Worksheet, datDict As Scripting.Dictionary, Optional outtype As String = "Pivot")
    ' to write a reshaped table or a summarized table to a new sheet
    
    Dim sumsht As String
    Dim SubSumDict As New Scripting.Dictionary
    
    sumsht = Left(sht.Name, 3) & "2_" & outtype
    makesht sumsht, 1
    Sheets(sumsht).Select
    
    nrep = repcount()
    ngt = genotype.count
    ntrt = treatment.count
    nblk = nrep * ngt * ntrt
    
    t = 0

    For Each k In datDict
        firstrow = t * (nblk + 3) + 1
        Cells(firstrow, 1).Value = k
        Range(Cells(firstrow + 1, 1), Cells(firstrow + 1, 3)).Value = Array("Rep", "Genotype", "Treatment")
        
        If outtype = "sum" Then
            Range(Cells(firstrow + 1, 4), Cells(firstrow + 1, 7)) = Array("#Obs", "Avearge", "Stdev", "Stderr")
        End If
        y = 1   ' y: for each block
        For Each bk In datDict(k) 'bk: block key
            blkidt = Split(bk, ",")
            Range(Cells(firstrow + 1 + y, 1), Cells(firstrow + 1 + y, 3)) = Array(blkidt(0), genotype(CInt(blkidt(1))), treatment(CInt(blkidt(2))))
            Range(Cells(firstrow + 1 + y, 4), Cells(firstrow + 1 + y, 3 + UBound(datDict(k)(bk)))) = datDict(k)(bk)
            y = y + 1
        Next
        t = t + 1
    Next
End Sub

Function ArrDim(var As Variant) As Long
    'return the dimension of an array
    
    On Error GoTo Err
    Dim i As Long
    Dim tmp As Long
    i = 0
    Do While True
        i = i + 1
        tmp = UBound(var, i)
    Loop
Err:
    ArrDim = i - 1
End Function

Function nObs(arr) As Long
    cnt = 0
    For i = LBound(arr) To UBound(arr)
        If Not IsEmpty(arr(i)) Then
            cnt = cnt + 1
        End If
    Next
    
    nObs = cnt
End Function
