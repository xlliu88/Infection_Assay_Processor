Attribute VB_Name = "Module1"
'Microsoft VBA
'to sort cyst counting sheets
'Created on Nov 7th, 2016
'function getGT() added on Nov 26, 2016
'function DictMerge() added on May 1, 2017
'function CountParse() added on May 2, 2017
'main sub re-structured on May 2,2017
'Last modified on May 2, 2017

'Xunliang Liu
'xlliu88@gmail.com

Sub Melt2()
Attribute Melt2.VB_ProcData.VB_Invoke_Func = "m\n14"
    Dim welldata As New Scripting.Dictionary
    Dim genotype As New Scripting.Dictionary
    Dim treatment As New Scripting.Dictionary
    'Dim gttrt(2)
    Dim table As New Collection
    Dim gttrtpair As String

    Dim Sh As Worksheet
    Dim loc As Range
    Dim FirstFound As String
    
    For Each Sh In ThisWorkbook.Worksheets
        If (InStr(Sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo continue
        End If
        
        If genotype.count < getGT(Sh).count Then
            Set genotype = DictMerge(genotype, getGT(Sh)) 'read genotype setting;
        End If
        
        If treatment.count < gettrt(Sh).count Then
            Set treatment = DictMerge(treatment, gettrt(Sh))
        End If
continue:
    Next Sh
    
    For Each Sh In ThisWorkbook.Worksheets
        
        If (InStr(Sh.Range("A1").Value, "Infection Assay") = 0) Then
            GoTo skipsheet
        End If
        
        Sh.Activate
        Set loc = Sh.Cells.Find(what:="Plate ")
        
        If loc Is Nothing Then
            MsgBox ("No Plate Found on Sheet: " & ActiveSheet.Name)
            GoTo skipsheet
        End If
        
        FirstPlate = loc.Address
        Do
            If UBound(Split(loc.Value)) > 0 Then
                wellx = loc.Column + 1
                welly = loc.Row + 2
                
                For y = 0 To 11 Step 4
                    For x = 0 To 3
                        gttrtpair = Sh.Cells(welly + y, wellx + x).Value

                        If gttrtpair = "na" Then
                            GoTo skipsheet
                        End If
                        
                        Set welldata = expInfo(Sh)
                        welldata("Plate#") = CInt(Split(loc.Value)(1)) 'get plate number
                        welldata("Well#") = Sh.Cells(welly + y, loc.Column).Value & Sh.Cells(welly - 1, wellx + x).Value
                        Set welldata = DictMerge(welldata, trtparse(gttrtpair, genotype, treatment))
                        welldata("Note") = Sh.Cells(welly + y + 3, wellx + x).Value
                        Set welldata = DictMerge(welldata, CountParse(Sh.Cells(welly + y + 1, wellx + x).Value, 14))
                        Set welldata = DictMerge(welldata, CountParse(Sh.Cells(welly + y + 2, wellx + x).Value, 30))

                        table.Add welldata 'add individule data to a collection
                    Next x
                    'Exit Sub
                Next y
            End If
            Set loc = Sh.Cells.FindNext(loc)                                'reset Loc to the next cell with "Plate "
        Loop While Not loc Is Nothing And loc.Address <> FirstPlate         'end of one plate; exit loop when the location of next found cells is the same as the first found cell
        Set loc = Nothing
skipsheet:
    Next        'Go to next sheet

    
    'to write melted data to a new sheet (Melted)
    If Evaluate("ISREF('Melted'!A1)") Then  'to evaluate if 'Melted'!A1 is a reference. aka. to check if sheet "Melted" exist
        ReMelt = MsgBox("Melted data found. Do you want to OVERWRITE the melted data?", vbYesNo, "Melted data found") 'to decide if redo melting
        If ReMelt = vbYes Then
            Worksheets("Melted").Activate
            ActiveSheet.Cells.ClearContents
        End If
    Else                                    ' if sheet "Melted" not exist, add the "Melted" sheet
        ReMelt = vbYes
        Worksheets.Add.Name = "Melted"
    End If
              
    'Write data
    If ReMelt = vbYes Then
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
    End If
    
End Sub


Function expInfo(Sh As Worksheet)
    Dim info As New Scripting.Dictionary

    info("Rep") = Sh.Cells(2, 4).Value
    info("Ecotype") = Sh.Cells(4, 4).Value
    info("ppJ2No") = Sh.Cells(7, 4).Value
    info("plate_date") = Sh.Cells(5, 4).Value
    info("inoc_date") = Sh.Cells(6, 4).Value
    info("c14date") = Sh.Cells(8, 4).Value
    info("c30date") = Sh.Cells(9, 4).Value

    Set expInfo = info 'return experiment info as a dictionary
    
End Function

Function getGT(Sh As Worksheet, Optional test As String)
    Dim gtLoc As Range
    Dim code As New Scripting.Dictionary
    'Set gtCode = Nothing
    
    Set gtLoc = Sh.Cells.Find(what:="Genotypes")
    If (Not gtLoc Is Nothing) Then
        r = gtLoc.Row + 1 'row number
        col = gtLoc.Column 'column number

        
        Do While Not IsEmpty(Sh.Cells(r, col + 1).Value)
            code(Sh.Cells(r, col).Value) = Sh.Cells(r, col + 1).Value
            r = r + 1
        Loop
    Else
        Debug.Print "Genotype setting not found"
        MsgBox "Genotype setting not found in sheet: " & ActiveSheet.Name
    End If
    Set getGT = code
    
    If test = "TEST" Then
        Debug.Print "Sheet: " & Sh.Name
        Debug.Print "genotype location: " & gtLoc.Address
        Debug.Print "total genotypes found:" & code.count
        Debug.Print "---------"
        For Each Key In code.Keys()
            Debug.Print "  " & Key & ":" & code(Key)
        Next Key
        Debug.Print "---------"
    End If
End Function

Function gettrt(Sh As Worksheet, Optional test As String)
    Dim trtLoc As Range
    Dim trts As New Scripting.Dictionary
    'Set gtCode = Nothing
    
    Set trtLoc = Sh.Cells.Find(what:="Treatments")
    If (Not trtLoc Is Nothing) Then
        r = trtLoc.Row + 1 'row number
        c = trtLoc.Column 'column number

        
        Do While Not IsEmpty(Sh.Cells(r, c + 1).Value)
            trts(Sh.Cells(r, c).Value) = Sh.Cells(r, c + 1).Value
            r = r + 1
        Loop
    Else
        Debug.Print "Treatment setting not found"
    End If
    Set gettrt = trts
    
    If test = "TEST" Then
        Debug.Print "Sheet: " & Sh.Name
        Debug.Print "Treatments location: " & trtLoc.Address
        Debug.Print "total Treatments found:" & trts.count
        Debug.Print "---------"
        For Each Key In trts.Keys()
            Debug.Print "  " & Key & ":" & trts(Key)
        Next Key
        Debug.Print "---------"
    End If
End Function

Function DictMerge(dicta As Scripting.Dictionary, dictb As Scripting.Dictionary, Optional test As String)
    ' to merge to dictionaries
    
    Dim merged As New Scripting.Dictionary

    For Each ka In dicta.Keys()
        merged(ka) = dicta(ka)
    Next ka
    
    For Each kb In dictb.Keys()
        merged(kb) = dictb(kb)
    Next kb
    Set DictMerge = merged
    
    If test = "TEST" Then
        Debug.Print "====== Meger testing ==="
        Debug.Print "Dictionaries before merge:"
        Debug.Print "     Dict a    dict b    Merged"
        Debug.Print "Total  " & dicta.count & "...." & dictb.count & "...." & merged.count
        Debug.Print " -- Before Merge --"
        Debug.Print " -- Dict a --------"
        For Each Key In dicta.Keys()
            Debug.Print "  " & Key & dicta(Key)
        Next
        
        Debug.Print " -- Dict b --------"
        For Each Key In dicta.Keys()
            Debug.Print "  " & Key & dictb(Key)
        Next
        
        Debug.Print " == After Merge =="
        For Each Key In dicta.Keys()
            Debug.Print "  " & Key & merged(Key)
        Next
        Debug.Print "|||||||||||||||||||||||"
    End If
End Function

Function CountParse(count As String, d As String)
    ' to catagrize counts
    ' each catagory was determined by "," and the total count will be add up in another catagory
    ' if the count is not catagorized, return the original data
    
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
    'Dim trtpair(2)
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
