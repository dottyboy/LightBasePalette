unit ta_owncalendar;
{ Vlastiti kalendar na formi (pruzatelj 'own', obitelj Calendar): mjesec (jedan datum), razdoblje (dva klika daju "od..do") i
  agenda (popis iducih dana). Kalendar se crta sam i zauzima prostor domacina (celije se razvuku); tipke: strelice dan/tjedan,
  PgUp/PgDn mjesec (uz Ctrl godina), kotacic mijenja mjesec, klik na "Danas" bira danasnji datum. Vrijednost je ISO datum
  yyyy-mm-dd, razdoblje "a..b". }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ta_family, ta_calendar, ta_owndate, ta_ownlist;

type
  TaOwnCalMonthEngine = class(TaEngine)
  private
    FCal: TaOwnCalendar;
    FSetting: Boolean;
    procedure Picked(ADate: TDateTime);
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaOwnCalRangeEngine = class(TaEngine)
  private
    FCal: TaOwnCalendar;
    FFrom, FTo: TDateTime;
    FWaitEnd: Boolean;
    procedure Picked(ADate: TDateTime);
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaOwnCalAgendaEngine = class(TaEngine)
  private
    FList: TaOwnList;
    FDates: array of TDateTime;
    FDays: Integer;
    procedure Rebuild;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

implementation

uses
  ta_i18n;

function IsoOf(ADate: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

function ParseIso(const AText: string; out ADate: TDateTime): Boolean;
var
  F: TFormatSettings;
begin
  F := DefaultFormatSettings;
  F.ShortDateFormat := 'yyyy-mm-dd';
  F.DateSeparator := '-';
  Result := (Length(Trim(AText)) >= 10) and TryStrToDate(Copy(Trim(AText), 1, 10), ADate, F);
end;

{ ---------------- mjesec ---------------- }

constructor TaOwnCalMonthEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCal := TaOwnCalendar.Create(nil);
  FCal.Inline := True;
  FCal.OnPick := @Picked;
  AttachInner(FCal);
end;

class function TaOwnCalMonthEngine.Provider: string;
begin
  Result := 'own';
end;

procedure TaOwnCalMonthEngine.Picked(ADate: TDateTime);
begin
  FCal.SetDate(ADate);
  if not FSetting then InnerChanged(FCal);
end;

function TaOwnCalMonthEngine.GetText: string;
begin
  Result := IsoOf(FCal.Selected);
end;

procedure TaOwnCalMonthEngine.SetText(const AValue: string);
var
  D: TDateTime;
begin
  if not ParseIso(AValue, D) then Exit;
  FSetting := True;
  try
    FCal.SetDate(D);
  finally
    FSetting := False;
  end;
end;

{ ---------------- razdoblje ---------------- }

constructor TaOwnCalRangeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCal := TaOwnCalendar.Create(nil);
  FCal.Inline := True;
  FCal.OnPick := @Picked;
  AttachInner(FCal);
end;

class function TaOwnCalRangeEngine.Provider: string;
begin
  Result := 'own';
end;

procedure TaOwnCalRangeEngine.Picked(ADate: TDateTime);
var
  D: TDateTime;
begin
  D := Int(ADate);
  FCal.SetDate(D);
  if not FWaitEnd then
  begin
    FFrom := D;
    FTo := D;
    FWaitEnd := True;
  end
  else
  begin
    if D < FFrom then begin FTo := FFrom; FFrom := D; end else FTo := D;
    FWaitEnd := False;
  end;
  FCal.SetRange(FFrom, FTo);
  InnerChanged(FCal);
end;

function TaOwnCalRangeEngine.GetText: string;
begin
  if FFrom = 0 then Exit('');
  Result := IsoOf(FFrom) + '..' + IsoOf(FTo);
end;

procedure TaOwnCalRangeEngine.SetText(const AValue: string);
var
  P: Integer;
  A, B: TDateTime;
begin
  P := Pos('..', AValue);
  if P > 0 then
  begin
    if not (ParseIso(Copy(AValue, 1, P - 1), A) and ParseIso(Copy(AValue, P + 2, MaxInt), B)) then Exit;
  end
  else if ParseIso(AValue, A) then B := A
  else
  begin
    FFrom := 0;
    FTo := 0;
    FWaitEnd := False;
    FCal.SetRange(0, 0);
    Exit;
  end;
  FFrom := Int(A);
  FTo := Int(B);
  FWaitEnd := False;
  FCal.SetDate(A);
  FCal.SetRange(FFrom, FTo);
end;

{ ---------------- agenda ---------------- }

constructor TaOwnCalAgendaEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDays := 14;
  FList := TaOwnList.Create(nil);
  FList.OnChange := @InnerChanged;
  AttachInner(FList);
  Rebuild;
end;

class function TaOwnCalAgendaEngine.Provider: string;
begin
  Result := 'own';
end;

procedure TaOwnCalAgendaEngine.Rebuild;
const
  Names: array[1..7] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
var
  I: Integer;
  D: TDateTime;
begin
  SetLength(FDates, FDays);
  FList.Items.Clear;
  for I := 0 to FDays - 1 do
  begin
    D := Int(Now) + I;
    FDates[I] := D;
    FList.Items.Add(Tr(Names[DayOfWeek(D)]) + ' ' + FormatDateTime('dd.mm.yyyy', D));
  end;
end;

function TaOwnCalAgendaEngine.GetText: string;
var
  I: Integer;
begin
  I := FList.ItemIndex;
  if (I >= 0) and (I < Length(FDates)) then Result := IsoOf(FDates[I]) else Result := '';
end;

procedure TaOwnCalAgendaEngine.SetText(const AValue: string);
var
  D: TDateTime;
  I, Found: Integer;
begin
  Found := -1;
  if ParseIso(AValue, D) then
    for I := 0 to High(FDates) do
      if Int(FDates[I]) = Int(D) then Found := I;
  FList.ItemIndex := Found;
end;

procedure TaOwnCalAgendaEngine.ApplyOptions(AOptions: TPersistent);
var
  Keep: string;
begin
  if (AOptions is TaCalendarOptions) and (TaCalendarOptions(AOptions).Days > 0) and (TaCalendarOptions(AOptions).Days <> FDays) then
  begin
    Keep := GetText;
    FDays := TaCalendarOptions(AOptions).Days;
    Rebuild;
    SetText(Keep);
  end;
end;

initialization
  RegisterEngine(CalendarFamily, 'month', TaOwnCalMonthEngine);
  RegisterEngine(CalendarFamily, 'range', TaOwnCalRangeEngine);
  RegisterEngine(CalendarFamily, 'agenda', TaOwnCalAgendaEngine);

end.
