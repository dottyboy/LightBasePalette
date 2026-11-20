program dzshot;
{ Snimka dizajnera formi s kontrolama obitelji: dzshot <izlaz.png> }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, SysUtils, Classes, Graphics, qt6, qt6widgets,
  ta_meta, ta_formdef, ta_controls, ta_famctl, ta_formdesign, ta_theme, ta_tokens;

function Grab(AForm: TForm; const AFile: string): Boolean;
var
  Pix: QPixmapH;
  WS: WideString;
  R: TRect;
begin
  Pix := QPixmap_Create();
  try
    R := Rect(0, 0, AForm.Width, AForm.Height);
    QWidget_grab(TQtWidget(AForm.Handle).Widget, Pix, @R);
    WS := UTF8Decode(AFile);
    Result := QPixmap_save(Pix, @WS, 'PNG');
  finally
    QPixmap_Destroy(Pix);
  end;
end;

var
  Db: TAppDb;
  D: TaFormDef;
  Dz: TaFormDesigner;
  C: TControl;
  Kinds: array[0..15] of string = ('Rectangle', 'Line', 'TextBox', 'ComboBox', 'CheckBox', 'OptionGroup', 'ListBox', 'Calendar', 'Label', 'Hyperlink', 'Image', 'Chart', 'Barcode', 'Progress', 'Button', 'MemoBox');
  I, X, Y: Integer;
begin
  Application.Initialize;
  Db := TAppDb.Create;
  DeleteFile('/tmp/ta_dzshot.db');
  Db.Open('/tmp/ta_dzshot.db');
  Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, naziv VARCHAR(20))');
  D := TaFormDef.Create;
  D.Name := 'Snimka'; D.RecordSource := 't'; D.Width := 700; D.Height := 520;
  Dz := TaFormDesigner.CreateDesigner(nil, Db, D);
  Dz.SetBounds(0, 0, 1100, 720);
  for I := 0 to High(Kinds) do
  begin
    X := 20 + (I mod 3) * 215;
    Y := 20 + (I div 3) * 95;
    C := Dz.AddForTest(Kinds[I], X, Y);
    if Kinds[I] = 'TextBox' then Dz.SetPropForTest('ControlSource', 'naziv');
  end;
  Dz.Show;
  Application.ProcessMessages;
  Sleep(300);
  Application.ProcessMessages;
  Grab(Dz, ParamStr(1));
  Dz.Free;
  Db.Free;
end.
