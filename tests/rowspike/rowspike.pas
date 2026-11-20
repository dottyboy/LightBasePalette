program rowspike;

{ Korak 0 plana 20.9: koliko traje stvaranje i "klizanje" bazena redova s pravim TaEdit kontrolama pod Qt6.
  Mjeri: stvaranje N redova x M kontrola, zatim K ponovnih punjenja (klizanje za 1 red) s prikazom i obradom poruka. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, ExtCtrls, StdCtrls, Graphics, Classes, SysUtils, DateUtils,
  ta_tokens, ta_theme, ta_family, ta_edit;

const
  Rows = 30;
  Cols = 8;

type
  TPaintHost = class(TCustomControl)
  public
    Offset: Integer;
    procedure Paint; override;
  end;

procedure TPaintHost.Paint;
var
  I, J, Y: Integer;
begin
  Canvas.Brush.Color := clWindow;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Color := clSilver;
  for I := 0 to Rows do
  begin
    Y := I * 30 - Offset;
    for J := 0 to Cols - 1 do
    begin
      Canvas.Rectangle(J * 140 + 4, Y + 2, J * 140 + 138, Y + 28);
      Canvas.TextOut(J * 140 + 8, Y + 6, 'r' + IntToStr(I + Offset) + 'c' + IntToStr(J));
    end;
  end;
end;

var
  F: TForm;
  PH: TPaintHost;
  Cells: array[0..Rows - 1, 0..Cols - 1] of TaEdit;
  Pn: array[0..Rows - 1] of TPanel;
  Holder: TPanel;
  R, C, K, Base: Integer;
  T0: QWord;
  Ms: array[0..5] of QWord;
  Plain: array[0..Rows - 1, 0..Cols - 1] of TEdit;

procedure Fill(ABase: Integer);
var
  I, J: Integer;
begin
  for I := 0 to Rows - 1 do
    for J := 0 to Cols - 1 do
      Cells[I, J].Text := 'r' + IntToStr(ABase + I) + 'c' + IntToStr(J);
end;

begin
  Application.Initialize;
  Application.Scaled := False;
  ApplySavedTheme;
  F := TForm.CreateNew(nil);
  F.SetBounds(0, 0, 1200, Rows * 30 + 20);
  T0 := GetTickCount64;
  for R := 0 to Rows - 1 do
  begin
    Pn[R] := TPanel.Create(F);
    Pn[R].Parent := F;
    Pn[R].SetBounds(0, R * 30, 1180, 30);
    Pn[R].BevelOuter := bvNone;
    for C := 0 to Cols - 1 do
    begin
      Cells[R, C] := TaEdit.Create(F);
      Cells[R, C].Parent := Pn[R];
      Cells[R, C].SetBounds(C * 140 + 4, 2, 134, 26);
      case C of
        2: Cells[R, C].Variant := evCombo;
        3: Cells[R, C].Variant := evDate;
        5: Cells[R, C].Variant := evCurrency;
      end;
    end;
  end;
  Ms[0] := GetTickCount64 - T0;
  F.Show;
  Application.ProcessMessages;
  Ms[1] := GetTickCount64 - T0 - Ms[0];
  T0 := GetTickCount64;
  K := 50;
  for Base := 1 to K do
  begin
    Fill(Base);
    Application.ProcessMessages;
  end;
  Ms[2] := GetTickCount64 - T0;
  T0 := GetTickCount64;
  for Base := 1 to K do Fill(Base);
  Ms[3] := GetTickCount64 - T0;
  { C: klizanje recikliranjem: svi paneli se pomaknu za 1 red, samo jedan red (onaj koji ulazi) se ponovno puni }
  T0 := GetTickCount64;
  for Base := 1 to 100 do
  begin
    for R := 0 to Rows - 1 do Pn[R].Top := ((R - Base) mod Rows + Rows) mod Rows * 30;
    R := (Base - 1) mod Rows;
    for C := 0 to Cols - 1 do Cells[R, C].Text := 'n' + IntToStr(Base) + 'c' + IntToStr(C);
    Application.ProcessMessages;
  end;
  Ms[5] := GetTickCount64 - T0;
  WriteLn('recikliranje (pomak panela + 1 red): ', Ms[5] / 100:0:2, ' ms po koraku');
  { D: pomak po pikselima (kotacic), bez ponovnog punjenja }
  T0 := GetTickCount64;
  for Base := 1 to 100 do
  begin
    for R := 0 to Rows - 1 do Pn[R].Top := R * 30 - (Base mod 30);
    Application.ProcessMessages;
  end;
  WriteLn('pomak po pikselima (samo Top): ', (GetTickCount64 - T0) / 100:0:2, ' ms po koraku');
  { E: svi redovi u jednom spremniku, pomak spremnika za piksel (kotacic) }
  Holder := TPanel.Create(F);
  Holder.Parent := F;
  Holder.BevelOuter := bvNone;
  Holder.SetBounds(0, 0, 1180, Rows * 30 + 60);
  for R := 0 to Rows - 1 do Pn[R].Parent := Holder;
  for R := 0 to Rows - 1 do Pn[R].Top := R * 30;
  Application.ProcessMessages;
  T0 := GetTickCount64;
  for Base := 1 to 100 do
  begin
    Holder.Top := -(Base mod 30);
    Application.ProcessMessages;
  end;
  WriteLn('pomak spremnika (1 SetBounds): ', (GetTickCount64 - T0) / 100:0:2, ' ms po koraku');
  for R := 0 to Rows - 1 do
    for C := 0 to Cols - 1 do
    begin
      Plain[R, C] := TEdit.Create(F);
      Plain[R, C].Parent := F;
      Plain[R, C].SetBounds(C * 140 + 4, R * 30 + 2, 134, 26);
    end;
  Application.ProcessMessages;
  T0 := GetTickCount64;
  for Base := 1 to 50 do
  begin
    for R := 0 to Rows - 1 do
      for C := 0 to Cols - 1 do Plain[R, C].Text := 'r' + IntToStr(Base + R) + 'c' + IntToStr(C);
    Application.ProcessMessages;
  end;
  Ms[4] := GetTickCount64 - T0;
  { F: jedan vlastiti prikaz crta sve redove (neaktivni redovi nisu kontrole) }
  for R := 0 to Rows - 1 do Pn[R].Visible := False;
  Holder.Visible := False;
  for R := 0 to Rows * 8 - 1 do Plain[R div 8, R mod 8].Visible := False;
  PH := TPaintHost.Create(F);
  PH.Parent := F;
  PH.SetBounds(0, 0, 1180, Rows * 30);
  Application.ProcessMessages;
  T0 := GetTickCount64;
  for Base := 1 to 100 do
  begin
    PH.Offset := Base mod 30;
    PH.Invalidate;
    Application.ProcessMessages;
  end;
  WriteLn('crtani redovi (1 kontrola, 240 celija): ', (GetTickCount64 - T0) / 100:0:2, ' ms po koraku');
  WriteLn('TaEdit samo punjenje: ', Ms[3] / K:0:2, ' ms po koraku; obicni TEdit s prikazom: ', Ms[4] / 50:0:2, ' ms po koraku');
  WriteLn('stvaranje ', Rows, 'x', Cols, ' kontrola: ', Ms[0], ' ms; prvi prikaz: ', Ms[1], ' ms');
  WriteLn('klizanje za 1 red (', K, ' puta): ukupno ', Ms[2], ' ms, po koraku ', Ms[2] / K:0:1, ' ms');
  F.Free;
end.
