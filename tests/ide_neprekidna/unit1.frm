object Form1: TForm1
  Left = 300
  Height = 360
  Top = 200
  Width = 560
  Caption = 'Neprekidna forma iz IDE-a'
  ClientHeight = 360
  ClientWidth = 560
  object aDatabase1: TaDatabase
    FileName = '/tmp/ide_check/test.db'
    Active = True
    Left = 520
    Top = 4
  end
  object aCont: TaContinuousForm
    Left = 8
    Height = 340
    Top = 8
    Width = 540
    Database = aDatabase1
    RecordSource = 'partneri'
    Bindings.Strings = (
      'lblNaziv=sort:naziv'
      'edtFilter=filter:grad'
    )
    object lblNaziv: TLabel
      Left = 8
      Height = 20
      Top = 4
      Width = 160
      Caption = 'Naziv'
      Font.Style = [fsBold]
    end
    object edtFilter: TaEdit
      Left = 180
      Height = 24
      Top = 26
      Width = 120
    end
    object eNaziv: TaEdit
      Left = 8
      Height = 26
      Top = 60
      Width = 160
      ControlSource = 'naziv'
    end
    object eGrad: TaEdit
      Left = 180
      Height = 26
      Top = 60
      Width = 120
      ControlSource = 'grad'
    end
    object eIznos: TaEdit
      Left = 310
      Height = 26
      Top = 60
      Width = 100
      Format = '#,##0.00'
      ControlSource = 'id'
    end
    object zBroj: TaEdit
      Left = 180
      Height = 24
      Top = 310
      Width = 120
      ControlSource = '=Count()'
    end
  end
end
