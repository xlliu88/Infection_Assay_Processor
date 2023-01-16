Attribute VB_Name = "Module2"
Sub Macro1()
Attribute Macro1.VB_ProcData.VB_Invoke_Func = " \n14"
'
' Macro1 Macro
'

'
    Sheets.Add
    ActiveWorkbook.Worksheets("PntSummary").PivotTables("PivotTable1").PivotCache. _
        CreatePivotTable TableDestination:="Sheet6!R3C1", TableName:="PivotTable7" _
        , DefaultVersion:=xlPivotTableVersion15
    Sheets("Sheet6").Select
    Cells(3, 1).Select
    ActiveSheet.PivotTables("PivotTable7").AddDataField ActiveSheet.PivotTables( _
        "PivotTable7").PivotFields("Rep"), "Sum of Rep", xlSum
    With ActiveSheet.PivotTables("PivotTable7").PivotFields("Treatment")
        .Orientation = xlRowField
        .Position = 1
    End With
    With ActiveSheet.PivotTables("PivotTable7").PivotFields("Penetration")
        .Orientation = xlRowField
        .Position = 2
    End With
    With ActiveSheet.PivotTables("PivotTable7").PivotFields("Sum of Rep")
        .Orientation = xlRowField
        .Position = 1
    End With
    ActiveSheet.PivotTables("PivotTable7").AddDataField ActiveSheet.PivotTables( _
        "PivotTable7").PivotFields("Penetration"), "Count of Penetration", xlCount
    With ActiveSheet.PivotTables("PivotTable7").PivotFields("Count of Penetration")
        .Caption = "Average of Penetration"
        .Function = xlAverage
    End With
End Sub
