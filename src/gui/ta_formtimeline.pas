unit ta_formtimeline;
{ Prikaz forme "raspored" (ViewMode = timeline): gore izbor rasporeda, ispod tjedna vremenska crta (ta_owntimeline). Promjene se odmah
  upisuju u tablicu stavki. Postavka (TaFormDef.Timeline), dijelovi odvojeni s " ;; ":
    glavni=SELECT r.id, u.naziv || ' - ' || r.naziv FROM rasporedi r JOIN uredjaji u ON u.id = r.uredjaj_id ORDER BY 2
    ;; stavke=rasporedi_stavke ;; veza=raspored_id ;; dani=dani ;; od=od ;; do=do ;; svakih=svakih_min ;; trajanje=trajanje_s }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, ta_meta, ta_formdef, ta_owncombo, ta_owntimeline;

type
  TaTimelineBody = class(TPanel)
  private
    FDb: TAppDb;
    FDef: TaFormDef;
    FCombo: TaOwnCombo;
    FLine: TaOwnTimeline;
    FKeys: TStringList;
    FMaster, FTable, FLink, FDays, FFrom, FTo, FEvery, FDur: string;
    procedure Parse(const AValue: string);
    procedure MasterPicked(Sender: TObject);
    procedure LineCreate(Sender: TObject; ADay, AStartMin, AEndMin: Integer; out AId: string);
    procedure LineChange(Sender: TObject; AItem: TaTimeItem);
    procedure LineDelete(Sender: TObject; AItem: TaTimeItem);
    function CurrentKey: string;
    procedure Exec(const ASql: string; const AParams: array of string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(ADb: TAppDb; ADef: TaFormDef);
    procedure Reload;
    procedure LoadMasters;
    procedure LoadItems;
    property Line: TaOwnTimeline read FLine;
    property Combo: TaOwnCombo read FCombo;
  end;

function CheckTimelineSetting(const ASetting: string): string;

implementation

uses
  ZDataset, ta_i18n;

function ValOf(const ASetting, AKey: string): string;
var
  L: TStringList;
  I, P: Integer;
  S: string;
begin
  Result := '';
  L := TStringList.Create;
  try
    S := StringReplace(ASetting, ';;', #1, [rfReplaceAll]);
    L.Delimiter := #1;
    L.StrictDelimiter := True;
    L.DelimitedText := S;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      P := Pos('=', S);
      if (P > 0) and SameText(Trim(Copy(S, 1, P - 1)), AKey) then Exit(Trim(Copy(S, P + 1, MaxInt)));
    end;
  finally
    L.Free;
  end;
end;

function CheckTimelineSetting(const ASetting: string): string;
begin
  Result := '';
  if (ValOf(ASetting, 'glavni') = '') or (ValOf(ASetting, 'stavke') = '') or (ValOf(ASetting, 'veza') = '') or
     (ValOf(ASetting, 'dani') = '') or (ValOf(ASetting, 'od') = '') or (ValOf(ASetting, 'do') = '') then
    Result := Tr('The schedule view needs the master list, the items table, the link, days, from and to fields.');
end;

constructor TaTimelineBody.Create(AOwner: TComponent);
var
  Pn: TPanel;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FKeys := TStringList.Create;
  Pn := TPanel.Create(Self);
  Pn.Parent := Self;
  Pn.Align := alTop;
  Pn.Height := 40;
  Pn.BevelOuter := bvNone;
  Pn.Caption := '';
  FCombo := TaOwnCombo.Create(Self);
  FCombo.Parent := Pn;
  FCombo.SetBounds(8, 7, 420, 28);
  FCombo.Droplist := True;
  FCombo.OnSelect := @MasterPicked;
  FLine := TaOwnTimeline.Create(Self);
  FLine.Parent := Self;
  FLine.Align := alClient;
  FLine.OnCreateItem := @LineCreate;
  FLine.OnItemChange := @LineChange;
  FLine.OnItemDelete := @LineDelete;
end;

destructor TaTimelineBody.Destroy;
begin
  FKeys.Free;
  inherited Destroy;
end;

procedure TaTimelineBody.Parse(const AValue: string);
begin
  FMaster := ValOf(AValue, 'glavni');
  FTable := ValOf(AValue, 'stavke');
  FLink := ValOf(AValue, 'veza');
  FDays := ValOf(AValue, 'dani');
  FFrom := ValOf(AValue, 'od');
  FTo := ValOf(AValue, 'do');
  FEvery := ValOf(AValue, 'svakih');
  FDur := ValOf(AValue, 'trajanje');
end;

procedure TaTimelineBody.Setup(ADb: TAppDb; ADef: TaFormDef);
begin
  FDb := ADb;
  FDef := ADef;
  Parse(ADef.Timeline);
  FLine.ReadOnly := not ADef.AllowEdits;
  Reload;
end;

procedure TaTimelineBody.Reload;
begin
  LoadMasters;
  LoadItems;
end;

function TaTimelineBody.CurrentKey: string;
begin
  if (FCombo.ItemIndex >= 0) and (FCombo.ItemIndex < FKeys.Count) then Result := FKeys[FCombo.ItemIndex] else Result := '';
end;

procedure TaTimelineBody.LoadMasters;
var
  Q: TZQuery;
  Keep: string;
  I: Integer;
begin
  Keep := CurrentKey;
  FKeys.Clear;
  FCombo.Items.Clear;
  Q := FDb.NewQuery(FMaster);
  try
    Q.Open;
    while not Q.EOF do
    begin
      FKeys.Add(Q.Fields[0].AsString);
      FCombo.Items.Add(Q.Fields[1].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  I := FKeys.IndexOf(Keep);
  if (I < 0) and (FKeys.Count > 0) then I := 0;
  FCombo.ItemIndex := I;
end;

procedure TaTimelineBody.MasterPicked(Sender: TObject);
begin
  LoadItems;
end;

procedure TaTimelineBody.LoadItems;
var
  Q: TZQuery;
  Sql: string;
  Ev, Du: Integer;
begin
  FLine.Clear;
  if CurrentKey <> '' then
  begin
    Sql := 'SELECT id, ' + FDb.QuoteId(FDays) + ' AS d, ' + FDb.QuoteId(FFrom) + ' AS f, ' + FDb.QuoteId(FTo) + ' AS t';
    if FEvery <> '' then Sql := Sql + ', ' + FDb.QuoteId(FEvery) + ' AS e' else Sql := Sql + ', 0 AS e';
    if FDur <> '' then Sql := Sql + ', ' + FDb.QuoteId(FDur) + ' AS u' else Sql := Sql + ', 0 AS u';
    Sql := Sql + ' FROM ' + FDb.QuoteId(FTable) + ' WHERE ' + FDb.QuoteId(FLink) + ' = :m ORDER BY id';
    Q := FDb.NewQuery(Sql);
    try
      Q.ParamByName('m').AsString := CurrentKey;
      Q.Open;
      while not Q.EOF do
      begin
        Ev := Q.FieldByName('e').AsInteger;
        Du := Q.FieldByName('u').AsInteger;
        FLine.AddItem(Q.FieldByName('id').AsString, Q.FieldByName('d').AsString,
          TextToMin(Q.FieldByName('f').AsString, 0), TextToMin(Q.FieldByName('t').AsString, 1440), Ev, Du);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  end;
  FLine.EndUpdate;
end;

procedure TaTimelineBody.Exec(const ASql: string; const AParams: array of string);
var
  Q: TZQuery;
  I: Integer;
begin
  Q := FDb.NewQuery(ASql);
  try
    for I := 0 to High(AParams) do Q.Params[I].AsString := AParams[I];
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TaTimelineBody.LineCreate(Sender: TObject; ADay, AStartMin, AEndMin: Integer; out AId: string);
var
  Q: TZQuery;
  Cols, Vals: string;
begin
  AId := '';
  if CurrentKey = '' then Exit;
  Cols := FDb.QuoteId(FLink) + ', ' + FDb.QuoteId(FDays) + ', ' + FDb.QuoteId(FFrom) + ', ' + FDb.QuoteId(FTo);
  Vals := ':a, :b, :c, :d';
  if FEvery <> '' then begin Cols := Cols + ', ' + FDb.QuoteId(FEvery); Vals := Vals + ', 0'; end;
  if FDur <> '' then begin Cols := Cols + ', ' + FDb.QuoteId(FDur); Vals := Vals + ', 0'; end;
  Exec('INSERT INTO ' + FDb.QuoteId(FTable) + ' (' + Cols + ') VALUES (' + Vals + ')',
    [CurrentKey, IntToStr(ADay), MinToText(AStartMin), MinToText(AEndMin)]);
  Q := FDb.NewQuery('SELECT MAX(id) FROM ' + FDb.QuoteId(FTable) + ' WHERE ' + FDb.QuoteId(FLink) + ' = :m');
  try
    Q.ParamByName('m').AsString := CurrentKey;
    Q.Open;
    AId := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

procedure TaTimelineBody.LineChange(Sender: TObject; AItem: TaTimeItem);
var
  ToText: string;
begin
  if AItem.EndMin >= 1440 then ToText := '24:00' else ToText := MinToText(AItem.EndMin);
  Exec('UPDATE ' + FDb.QuoteId(FTable) + ' SET ' + FDb.QuoteId(FDays) + ' = :a, ' + FDb.QuoteId(FFrom) + ' = :b, ' +
    FDb.QuoteId(FTo) + ' = :c WHERE id = :i', [AItem.Days, MinToText(AItem.StartMin), ToText, AItem.Id]);
end;

procedure TaTimelineBody.LineDelete(Sender: TObject; AItem: TaTimeItem);
begin
  Exec('DELETE FROM ' + FDb.QuoteId(FTable) + ' WHERE id = :i', [AItem.Id]);
end;

end.
