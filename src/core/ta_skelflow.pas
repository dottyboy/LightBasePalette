unit ta_skelflow;
{ Tok izrade programa iz kostura (poglavlje 11 plana), bez sucelja da radi isto u IDE-u, dizajneru i testovima.

  Dva ulaza:
    Od kostura:   biraj kostur -> utori se popune zadanim vrijednostima iz baze -> pregled 4GL-a -> spremi.
    Od podataka:  biraj tablicu -> kosturi poredani po prikladnosti -> biraj -> pregled -> spremi.
  Svaki korak koji korisnik napravi (izbor tablice, izbor kostura, promjena utora, spremanje) broji se kao "klik"
  (Clicks), pa se kriterij "od prazne baze do 5 programa u najvise 15 klikova" moze provjeriti u testu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta, ta_fgl, ta_skeleton;

type
  TaSkelFlow = class
  private
    FDb: TAppDb;
    FLib: TaSkeletonLibrary;
    FTable: string;
    FSkeleton: TaSkeleton;
    FValues: TStringList;
    FText, FError: string;
    FClicks: Integer;
    procedure Rebuild;
  public
    constructor Create(ADb: TAppDb; ALib: TaSkeletonLibrary);
    destructor Destroy; override;
    { ulaz "od podataka": tablica; AList dobiva "ocjena|naziv" od najprikladnijeg }
    procedure StartFromData(const ATable: string; AList: TStrings);
    { ulaz "od kostura": svi kosturi, "kategorija|naziv" }
    procedure ListAll(AList: TStrings);
    { izbor kostura: utori se pune (tablica iz ulaza "od podataka" je vec postavljena) }
    procedure Choose(ASk: TaSkeleton);
    procedure SetValue(const ASlot, AValue: string);
    { 0 = u redu; inace broj problema (poruke u ALog) }
    function Check(ALog: TStrings): Integer;
    { predlozeni naziv programa: jedinstven u bazi }
    function SuggestName: string;
    { sprema u bazu (_sys_programs) i/ili u datoteku; False + AErr kad ne uspije }
    function Save(const AName: string; AToDb: Boolean; const AFile: string; out AErr: string): Boolean;
    property Skeleton: TaSkeleton read FSkeleton;
    property Values: TStringList read FValues;
    property Text: string read FText;
    property Error: string read FError;
    property Table: string read FTable;
    property Clicks: Integer read FClicks;
  end;

implementation

uses
  StrUtils;

constructor TaSkelFlow.Create(ADb: TAppDb; ALib: TaSkeletonLibrary);
begin
  FDb := ADb;
  FLib := ALib;
  FValues := TStringList.Create;
end;

destructor TaSkelFlow.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

procedure TaSkelFlow.StartFromData(const ATable: string; AList: TStrings);
var
  I, J, N: Integer;
  Sc: array of Integer;
  Names: array of string;
  Ti: Integer;
  Tn: string;
begin
  Inc(FClicks);
  FTable := ATable;
  FSkeleton := nil;
  FText := '';
  FError := '';
  AList.Clear;
  N := FLib.Count;
  SetLength(Sc, N);
  SetLength(Names, N);
  for I := 0 to N - 1 do
  begin
    Sc[I] := SkeletonScore(FDb, FLib[I], ATable);
    Names[I] := FLib[I].Name;
  end;
  { padajuce po ocjeni, pa po nazivu }
  for I := 0 to N - 2 do
    for J := I + 1 to N - 1 do
      if (Sc[J] > Sc[I]) or ((Sc[J] = Sc[I]) and (CompareText(Names[J], Names[I]) < 0)) then
      begin
        Ti := Sc[I]; Sc[I] := Sc[J]; Sc[J] := Ti;
        Tn := Names[I]; Names[I] := Names[J]; Names[J] := Tn;
      end;
  for I := 0 to N - 1 do
    if Sc[I] > 0 then AList.Add(IntToStr(Sc[I]) + '|' + Names[I]);
end;

procedure TaSkelFlow.ListAll(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FLib.Count - 1 do AList.Add(FLib[I].Category + '|' + FLib[I].Name);
end;

procedure TaSkelFlow.Choose(ASk: TaSkeleton);
begin
  Inc(FClicks);
  FSkeleton := ASk;
  FValues.Clear;
  if (FTable <> '') and (ASk.SlotIndex('tablica') >= 0) then FValues.Values['tablica'] := FTable;
  Rebuild;
end;

procedure TaSkelFlow.Rebuild;
var
  Txt, Err: string;
begin
  FText := '';
  FError := '';
  if FSkeleton = nil then Exit;
  SkeletonDefaults(FDb, FSkeleton, FValues);
  if RenderSkeleton(FDb, FSkeleton, FValues, Txt, Err) then FText := Txt else FError := Err;
end;

procedure TaSkelFlow.SetValue(const ASlot, AValue: string);
var
  I, K: Integer;
begin
  Inc(FClicks);
  FValues.Values[ASlot] := AValue;
  { utori koji ovise o promijenjenom (npr. stupci o tablici) vracaju se na zadano }
  if FSkeleton <> nil then
    for I := 0 to High(FSkeleton.Slots) do
    begin
      K := I;
      if SameText(FSkeleton.Slots[K].Ref1, ASlot) or SameText(FSkeleton.Slots[K].Ref2, ASlot) then
        FValues.Values[FSkeleton.Slots[K].Name] := '';
    end;
  Rebuild;
end;

function TaSkelFlow.Check(ALog: TStrings): Integer;
var
  P: TaFglProgram;
begin
  ALog.Clear;
  if FText = '' then
  begin
    if FError <> '' then ALog.Add(FError);
    Exit(1);
  end;
  P := TaFglProgram.Create;
  try
    try
      P.LoadText(FText, 'program');
      Result := P.CheckProgram(ALog);
    except
      on E: Exception do begin ALog.Add(E.Message); Result := 1; end;
    end;
  finally
    P.Free;
  end;
end;

function TaSkelFlow.SuggestName: string;
var
  Base, N: string;
  I: Integer;
begin
  if FSkeleton = nil then Exit('Program');
  Base := StringReplace(FSkeleton.Name, ' ', '', [rfReplaceAll]);
  if FValues.Values['naziv'] <> '' then Base := FValues.Values['naziv']
  else if FTable <> '' then Base := Base + '_' + FTable
  else if FValues.Values['tablica'] <> '' then Base := Base + '_' + FValues.Values['tablica'];
  Result := Base;
  I := 1;
  while FDb.LoadObject('_sys_programs', Result) <> '' do
  begin
    Inc(I);
    N := IntToStr(I);
    Result := Base + '_' + N;
  end;
end;

function TaSkelFlow.Save(const AName: string; AToDb: Boolean; const AFile: string; out AErr: string): Boolean;
var
  L: TStringList;
begin
  Result := False;
  AErr := '';
  if FText = '' then begin AErr := 'Nema programa za spremanje' + IfThen(FError <> '', ': ' + FError, ''); Exit; end;
  Inc(FClicks);
  try
    if AToDb then
    begin
      if Trim(AName) = '' then begin AErr := 'Naziv programa je prazan'; Exit; end;
      FDb.SaveObject('_sys_programs', Trim(AName), FText);
    end;
    if AFile <> '' then
    begin
      L := TStringList.Create;
      try
        L.Text := FText;
        L.SaveToFile(AFile);
      finally
        L.Free;
      end;
    end;
    Result := True;
  except
    on E: Exception do AErr := E.Message;
  end;
end;

end.
