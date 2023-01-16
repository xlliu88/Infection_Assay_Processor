Attribute VB_Name = "Module2"
'A script for Randomized Block Design
'First created on May 1, 2017
'Last modified on May 18, 2017
'Version 2
'   pntsht added for penetration sheet
'   genotype count and treatment count functions combined to level count function
'   several functions changed to subs

'Xunliang Liu
'xlliu88@gmail.com


Sub RBD()
Attribute RBD.VB_ProcData.VB_Invoke_Func = "r\n14"
    Dim pairs As New Collection
    Dim Sh As Worksheet
    
    ngt = 0
    ntrt = 0
    
    For Each Sh In ThisWorkbook.Worksheets
        If (InStr(Sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet1
        End If

        If levelcount("Genotypes") > ngt Then
            ngt = levelcount("Genotypes")
        End If
        If levelcount("Treatments") > ntrt Then
            ntrt = levelcount("Treatments")
        End If
skipsheet1:
    Next
 
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

    For Each Sh In ThisWorkbook.Worksheets
        If (InStr(Sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet2
        End If
        
        Sh.Activate
        welldesignation trts, Sh, 1 ' last parameter: optional; 0 will not delete existing plates; 1 will delete existing plates

skipsheet2:
    Next
    
    RDBlayout trts
    pntsht trts, repcount()
    
End Sub

Sub reset()
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
Function shtexist(shtname As String)
    shtexist = Evaluate("ISREF('" & shtname & "'!A1)")
End Function

Sub makesht(shtname As String, Optional clear As Boolean)
    If shtexist(shtname) Then
        Worksheets(shtname).Activate
        If clear Then
            Worksheets(shtname).Cells.clear
        End If
    Else
        Worksheets.Add(After:=Sheets(Sheets.count)).Name = shtname
    End If
End Sub

Function levelcount(factor As String, Optional test As String)
    Dim lvlLoc As Range
    Dim ngt As Integer
    
    Set lvlLoc = Cells.Find(what:=factor)
    If (Not lvlLoc Is Nothing) Then
        r = lvlLoc.Row + 1 'row number
        col = lvlLoc.Column 'column number

        lvl = 0
        Do While Not IsEmpty(Cells(r, col + 1).Value)
            lvl = lvl + 1
            r = r + 1
        Loop
    Else
        Debug.Print factor & " setting not found"
        MsgBox factor & " setting not found in sheet: " & ActiveSheet.Name
        lvl = 0
        Exit Function
    End If
    
    levelcount = lvl
    
    If (test = "TEST") And (Not lvlLoc Is Nothing) Then
        Debug.Print "Sheet: " & ActiveSheet.Name
        Debug.Print factor & " location: " & lvlLoc.Address
        Debug.Print "total genotypes found:" & lvl
    End If
End Function

Function repcount()
    Dim sht As Worksheet
    
    count = 0
    For Each sht In ThisWorkbook.Worksheets
        If InStr(sht.Name, "Rep") Then
            count = count + 1
        End If
    Next
    'MsgBox ("total reps: " & count)
    repcount = count
        
End Function

Function shuffle(coll As Collection, Optional test As String) As Collection
    Dim shufcoll As New Collection
    Dim tempColl As New Collection
    
    For icoll = 1 To coll.count
        tempColl.Add coll(icoll)
    Next
    
    n = tempColl.count
    For i = 0 To n - 1
        r = Int(Rnd(1) * (n - i)) + 1
        'Debug.Print r
        shufcoll.Add tempColl(r)
        tempColl.Remove (r)
    Next i
    
    Set shuffle = shufcoll
End Function

Function collmerge(colla As Collection, collb As Collection)
    ' to merge two collections
    
    Dim merged As New Collection
    
    For Each Item In colla
        merged.Add Item
    Next Item
    
    For Each Item In collb
        merged.Add Item
    Next Item
    
    Set collmerge = merged
End Function

Function collett(col) As String
    ' to convert column number to letter
    
    collett = Split(Cells(1, col).Address, "$")(1)

End Function

Function shuftest(n As Integer, r As Integer, Optional coll As Collection)
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
End Function

Sub welldesignation(trts As Collection, sht As Worksheet, Optional clearplts As Boolean = False)
    ' to designate radomrized (genotype - treatment) pairs to each well

    Dim n As Integer

    'sht.Activate
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

Sub pntsht(coll As Collection, reps)
    ' to make sheets for penetration assay;
    ' default replicates are half of infection assay
    ' it will copy experiment infomation from Rep sheet
    
    Dim halfcoll As New Collection
    Dim shtname As String
    
    For i = 1 To coll.count / 2
        halfcoll.Add coll(i)
    Next

    For rep = 1 To reps
        shtname = "Penetration" & rep
        makesht shtname, 1
        Worksheets(shtname).Activate
        Range(Cells(1, 1), Cells(9, 1)).RowHeight = 12
        Cells(1, 1).Value = "Penetration Assay"
        Cells(1, 1).Font.Bold = True
        Range("$A$2", "$Z$9").Value = Worksheets("Rep" & rep).Range("$A$2", "$Z$9").Value
        RDBfill halfcoll, "Penetration"
    Next
    
    
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


Sub drawplt(r, c, num, Optional nrow As Integer = 1)
    'this function draws a plate diagrame on excel sheet
    'r as the row# of plate
    'c as the column of plate
    'num as the plate#
    'nrow as the number of lines you need for each row on 12 well
    
    Dim loc As Range
    Dim first As Range
    Dim last As Range
    
    Dim pltrange As Range
    
    Set loc = Cells(r, c)
    Set first = Cells(r + 2, c + 1)
    Set last = Cells(r + 1 + 3 * nrow, c + 4)
    
    firstcol = Chr(Asc("A") + c - 1)
    lastcol = Chr(Asc("A") + c + 4)
    Columns(collett(c) & ":" & collett(c)).ColumnWidth = 2          'set column width
    Columns(collett(c + 5) & ":" & collett(c + 5)).ColumnWidth = 2
    
    Range(first, last).Borders.LineStyle = xlContinuous ' set well borders
    Range(loc, last).RowHeight = 12                     ' set row height
    
    loc.Value = "Plate " & num
    loc.Font.Bold = True
    For i = 1 To 4
        Cells(r + 1, c + i).Value = i
        Cells(r + 1, c + i).HorizontalAlignment = xlCenter
    Next
    For j = 1 To 3
        Cells(r + 2 + (j - 1) * nrow, c).Value = Chr(Asc("A") + j - 1)
        Cells(r + 2 + (j - 1) * nrow, c).HorizontalAlignment = xlCenter
    Next

End Sub


