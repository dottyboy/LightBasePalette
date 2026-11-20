unit ta_switchgen;
{ Builds a switchboard: a form with a title and one button per menu item.
  Items are "caption|action" lines; the actions are the ones buttons and
  macros already understand (openform:X, openreport:X, macro:X, run:X, close). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, ta_formdef, ta_iconmap;

function BuildSwitchboard(const AName, ATitle: string; AItems: TStrings): TaFormDef;
{ isti redci ("Natpis|akcija", "# Skupina"), ali kao bocni izbornik: skupine se sklapaju, otvorena je jedna, program pamti zadnju stavku }
function BuildSideBoard(const AName, ATitle: string; AItems: TStrings): TaFormDef;
{ predlozak glavne forme: zaglavlje gore, bocni izbornik lijevo, radno podrucje, statusna traka dolje; sve preko Dock/sidra }
function BuildMainForm(const AName, ATitle: string; AItems: TStrings): TaFormDef;

implementation

function BuildSwitchboard(const AName, ATitle: string; AItems: TStrings): TaFormDef;
var
  I, P, Y, X, Cols, PerCol, ColW, Row, MaxY, ColIdx, GLen, K: Integer;
  D, LineDef: TaControlDef;
  Line: string;
  Grouped: Boolean;
begin
  Result := TaFormDef.Create;
  Result.Name := AName;
  Result.Caption := ATitle;
  Result.NavButtons := False;
  Result.Width := 420;

  D := TaControlDef.Create;
  D.Kind := 'Label';
  D.Name := 'lblNaslov';
  D.Caption := ATitle;
  D.Bold := True;
  D.SetX('fontSize', '18');
  D.Left := 30; D.Top := 16; D.Width := 360; D.Height := 32;
  Result.Add(D);

  D := TaControlDef.Create;
  D.Kind := 'Line';
  D.Name := 'lnNaslov';
  D.Left := 30; D.Top := 54; D.Width := 360; D.Height := 2;
  Result.Add(D);
  LineDef := D;

  { vise od 12 redaka: stupci; redak "# Naslov" je naslov skupine }
  Cols := 1;
  if AItems.Count > 12 then Cols := (AItems.Count + 11) div 12;
  Grouped := False;
  for I := 0 to AItems.Count - 1 do
    if Copy(AItems[I], 1, 1) = '#' then Grouped := True;
  { skupine: najvise 5 uskih stupaca da izbornik stane na zaslon }
  if Grouped and (Cols > 5) then Cols := 5;
  PerCol := (AItems.Count + Cols - 1) div Cols;
  if Cols > 1 then
  begin
    if Grouped then ColW := 220 else ColW := 300;
    Result.Width := 30 + Cols * (ColW + 20);
  end
  else ColW := 360;
  Y := 76;
  Row := 0;
  ColIdx := 0;
  MaxY := Y;
  for I := 0 to AItems.Count - 1 do
  begin
    Line := AItems[I];
    { skupina (naslov + stavke) se ne lomi izmedju stupaca }
    if (Cols > 1) and (Copy(Line, 1, 1) = '#') and (Row > 0) then
    begin
      GLen := 1;
      K := I + 1;
      while (K < AItems.Count) and (Copy(AItems[K], 1, 1) <> '#') do begin Inc(GLen); Inc(K); end;
      if Row + GLen > PerCol then
      begin
        Row := 0;
        Y := 76;
        Inc(ColIdx);
      end;
    end;
    if (Cols > 1) and (Row >= PerCol) then
    begin
      Row := 0;
      Y := 76;
      Inc(ColIdx);
    end;
    X := 30 + ColIdx * (ColW + 20);
    if (Copy(Line, 1, 1) = '#') then
    begin
      D := TaControlDef.Create;
      D.Kind := 'Label';
      D.Name := Result.UniqueName('lblGrupa');
      D.Caption := Trim(Copy(Line, 2, MaxInt));
      D.Bold := True;
      D.Left := X; D.Top := Y + 6; D.Width := ColW; D.Height := 24;
      Result.Add(D);
      Inc(Y, 36);
      Inc(Row);
      if Y > MaxY then MaxY := Y;
      Continue;
    end;
    P := Pos('|', Line);
    if P = 0 then Continue;
    D := TaControlDef.Create;
    D.Kind := 'Button';
    D.Name := Result.UniqueName('btn');
    D.Caption := Trim(Copy(Line, 1, P - 1));
    D.OnClick := Trim(Copy(Line, P + 1, MaxInt));
    AutoButtonIcon(D);
    D.Left := X; D.Top := Y; D.Width := ColW; D.Height := 36;
    D.SetX('fontSize', '11');
    Result.Add(D);
    Inc(Y, 48);
    Inc(Row);
    if Y > MaxY then MaxY := Y;
  end;
  Y := MaxY;
  if Cols > 1 then Result.Width := 30 + (ColIdx + 1) * (ColW + 20);
  LineDef.Width := Result.Width - 60;
  Result.Height := Y + 16;
end;

function BuildSideBoard(const AName, ATitle: string; AItems: TStrings): TaFormDef;
var
  D: TaControlDef;
begin
  Result := TaFormDef.Create;
  Result.Name := AName;
  Result.Caption := ATitle;
  Result.NavButtons := False;
  Result.Width := 300;
  Result.Height := 520;
  D := TaControlDef.Create;
  D.Kind := 'Label';
  D.Name := 'lblNaslov';
  D.Caption := ATitle;
  D.Bold := True;
  D.SetX('fontSize', '16');
  D.Left := 16; D.Top := 12; D.Width := 268; D.Height := 28;
  Result.Add(D);
  D := TaControlDef.Create;
  D.Kind := 'SideMenu';
  D.Name := 'mnuBocni';
  D.RowSource := AItems.Text;
  D.Left := 12; D.Top := 48; D.Width := 276; D.Height := 460;
  D.SetX('anchors', 'LTRB');
  Result.Add(D);
end;

function BuildMainForm(const AName, ATitle: string; AItems: TStrings): TaFormDef;
var
  D: TaControlDef;
begin
  Result := TaFormDef.Create;
  Result.Name := AName;
  Result.Caption := ATitle;
  Result.NavButtons := False;
  Result.Width := 960;
  Result.Height := 640;
  { zaglavlje }
  D := TaControlDef.Create;
  D.Kind := 'Rectangle'; D.Name := 'pnlZaglavlje';
  D.Left := 0; D.Top := 0; D.Width := 960; D.Height := 52;
  D.SetX('backColor', '#1F4E79');
  D.SetX('dock', 'top');
  Result.Add(D);
  D := TaControlDef.Create;
  D.Kind := 'Label'; D.Name := 'lblNaslov'; D.Caption := ATitle; D.Bold := True;
  D.SetX('fontSize', '18'); D.SetX('foreColor', '#FFFFFF');
  D.Left := 16; D.Top := 12; D.Width := 600; D.Height := 30;
  Result.Add(D);
  { bocni izbornik }
  D := TaControlDef.Create;
  D.Kind := 'SideMenu'; D.Name := 'mnuBocni';
  D.RowSource := AItems.Text;
  D.Left := 0; D.Top := 52; D.Width := 240; D.Height := 540;
  D.SetX('dock', 'left');
  Result.Add(D);
  { statusna traka }
  D := TaControlDef.Create;
  D.Kind := 'Label'; D.Name := 'lblStatus'; D.Caption := ' ';
  D.SetX('backColor', '#E8EDF2');
  D.Left := 0; D.Top := 616; D.Width := 960; D.Height := 24;
  D.SetX('dock', 'bottom');
  Result.Add(D);
  { radno podrucje: ispunjava ostatak }
  D := TaControlDef.Create;
  D.Kind := 'Rectangle'; D.Name := 'pnlRadno';
  D.Left := 240; D.Top := 52; D.Width := 720; D.Height := 564;
  D.SetX('backColor', '#FFFFFF');
  D.SetX('dock', 'client');
  Result.Add(D);
end;

end.
