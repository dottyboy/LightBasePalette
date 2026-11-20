unit ta_formboard;
{ Kanban prikaz forme (ViewMode = board): stupci su vrijednosti jednog polja s vezom na sifrarnik, kartice su retci izvora.
  Postavka forme (TaFormDef.Board): "polje stupaca | naslov kartice | polje, polje | forma za uredjivanje".
  Povlacenje kartice upisuje novu vrijednost polja u bazu; dvoklik otvara karticu u formi za uredjivanje (ako je navedena). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, DB, ta_meta, ta_formdef, ta_types, ta_ownboard;

type
  TaBoardRequest = procedure(Sender: TObject; const AId, AColumnField, AColumnKey: string) of object;

  TaBoardBody = class(TPanel)
  private
    FDb: TAppDb;
    FDef: TaFormDef;
    FBoard: TaOwnBoard;
    FColField, FTitleField, FEditForm: string;
    FLineFields: TStringList;
    FOnOpen, FOnNew: TaBoardRequest;
    FMetaCache: TStringList;
    procedure ParseSetting(const AValue: string);
    procedure CardMove(Sender: TObject; const ACardId, ANewColKey: string; var AAllow: Boolean);
    procedure CardOpen(Sender: TObject; const ACardId: string);
    procedure CardAdd(Sender: TObject; const AColKey: string);
    function LookupMap(const AField: string): TStringList;
    function ValueText(F: TField; AMap: TStringList): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(ADb: TAppDb; ADef: TaFormDef);
    procedure Reload;
    property Board: TaOwnBoard read FBoard;
    property ColumnField: string read FColField;
    property EditForm: string read FEditForm;
    property OnOpenRequest: TaBoardRequest read FOnOpen write FOnOpen;
    property OnNewRequest: TaBoardRequest read FOnNew write FOnNew;
  end;

{ je li postavka kanbana ispravna za izvor: vraca poruku pogreske ili '' }
function CheckBoardSetting(ADb: TAppDb; const ASource, ASetting: string): string;

implementation

uses
  ta_wizardgen, ta_i18n, ZDataset;

function FkOf(ADb: TAppDb; const ASource, AField: string; out ARefTable, ARefKey: string): Boolean;
var
  L: TStringList;
  I: Integer;
  P: TStringList;
begin
  Result := False;
  L := ADb.ForeignKeys(ASource);
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    for I := 0 to L.Count - 1 do
    begin
      P.DelimitedText := L[I];
      if (P.Count >= 3) and SameText(P[0], AField) then
      begin
        ARefTable := P[1];
        ARefKey := P[2];
        if ARefKey = '' then ARefKey := 'id';
        Exit(True);
      end;
    end;
  finally
    P.Free;
    L.Free;
  end;
end;

function CheckBoardSetting(ADb: TAppDb; const ASource, ASetting: string): string;
var
  P: TStringList;
  Rt, Rk: string;
begin
  Result := '';
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    P.DelimitedText := ASetting;
    if (P.Count = 0) or (Trim(P[0]) = '') then Exit(Tr('The board needs the field that makes the columns.'));
    if not FkOf(ADb, ASource, Trim(P[0]), Rt, Rk) then
      Result := Tr('The column field must be linked to a lookup table: ') + Trim(P[0]);
  finally
    P.Free;
  end;
end;

constructor TaBoardBody.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FLineFields := TStringList.Create;
  FMetaCache := TStringList.Create;
  FBoard := TaOwnBoard.Create(Self);
  FBoard.Parent := Self;
  FBoard.Align := alClient;
  FBoard.OnMoveCard := @CardMove;
  FBoard.OnOpenCard := @CardOpen;
  FBoard.OnAddCard := @CardAdd;
end;

destructor TaBoardBody.Destroy;
var
  I: Integer;
begin
  for I := 0 to FMetaCache.Count - 1 do FMetaCache.Objects[I].Free;
  FMetaCache.Free;
  FLineFields.Free;
  inherited Destroy;
end;

procedure TaBoardBody.ParseSetting(const AValue: string);
var
  P: TStringList;
begin
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    P.DelimitedText := AValue;
    FColField := ''; FTitleField := ''; FEditForm := '';
    FLineFields.Clear;
    if P.Count > 0 then FColField := Trim(P[0]);
    if P.Count > 1 then FTitleField := Trim(P[1]);
    if P.Count > 2 then
    begin
      FLineFields.Delimiter := ',';
      FLineFields.StrictDelimiter := True;
      FLineFields.DelimitedText := P[2];
    end;
    if P.Count > 3 then FEditForm := Trim(P[3]);
  finally
    P.Free;
  end;
end;

procedure TaBoardBody.Setup(ADb: TAppDb; ADef: TaFormDef);
begin
  FDb := ADb;
  FDef := ADef;
  ParseSetting(ADef.Board);
  FBoard.ReadOnly := not ADef.AllowEdits;
  FBoard.AllowAdd := ADef.AllowAdds and (FEditForm <> '');
  Reload;
end;

{ kljuc -> naziv za polje s vezom; nil ako polje nije veza }
function TaBoardBody.LookupMap(const AField: string): TStringList;
var
  K: Integer;
  Rt, Rk, Disp: string;
  Q: TZQuery;
begin
  K := FMetaCache.IndexOf(AField);
  if K >= 0 then Exit(TStringList(FMetaCache.Objects[K]));
  Result := nil;
  if (AField <> '') and FkOf(FDb, FDef.RecordSource, AField, Rt, Rk) then
  begin
    Result := TStringList.Create;
    Disp := DisplayColumn(FDb, Rt, Rk);
    Q := FDb.NewQuery('SELECT ' + FDb.QuoteId(Rk) + ' AS k, ' + FDb.QuoteId(Disp) + ' AS d FROM ' + FDb.QuoteId(Rt));
    try
      Q.Open;
      while not Q.EOF do
      begin
        Result.Values[Q.FieldByName('k').AsString] := Q.FieldByName('d').AsString;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  end;
  FMetaCache.AddObject(AField, Result);
end;

function TaBoardBody.ValueText(F: TField; AMap: TStringList): string;
var
  M: TaFieldMeta;
begin
  if F.IsNull then Exit('');
  if AMap <> nil then
  begin
    Result := AMap.Values[F.AsString];
    if Result = '' then Result := F.AsString;
    Exit;
  end;
  M := FDb.FindFieldMeta(FDef.RecordSource, F.FieldName);
  try
    if M <> nil then Result := StoredToDisplay(M, FieldStored(F)) else Result := F.AsString;
  finally
    M.Free;
  end;
end;

procedure TaBoardBody.Reload;
var
  Rt, Rk, Disp, Sql, Id, Lines, Cap, V: string;
  Q, C: TZQuery;
  I: Integer;
  Cols: TStringList;
  HasNone: Boolean;
  M: TaFieldMeta;
  Map: TStringList;
  FKey: TField;
  SelKeep: string;
begin
  if (FDb = nil) or (FColField = '') then Exit;
  SelKeep := FBoard.SelectedId;
  FBoard.Clear;
  for I := 0 to FMetaCache.Count - 1 do FMetaCache.Objects[I].Free;
  FMetaCache.Clear;
  if not FkOf(FDb, FDef.RecordSource, FColField, Rt, Rk) then Exit;
  Disp := DisplayColumn(FDb, Rt, Rk);
  { stupci: redni (ako postoji) pa kljuc }
  Cols := TStringList.Create;
  try
    C := FDb.NewQuery('SELECT * FROM ' + FDb.QuoteId(Rt));
    try
      C.Open;
      Sql := FDb.QuoteId(Rk);
      if C.FindField('redni') <> nil then Sql := FDb.QuoteId('redni') + ', ' + Sql
      else if C.FindField('sort') <> nil then Sql := FDb.QuoteId('sort') + ', ' + Sql;
    finally
      C.Free;
    end;
    C := FDb.NewQuery('SELECT ' + FDb.QuoteId(Rk) + ' AS k, ' + FDb.QuoteId(Disp) + ' AS d FROM ' + FDb.QuoteId(Rt) + ' ORDER BY ' + Sql);
    try
      C.Open;
      while not C.EOF do
      begin
        FBoard.AddColumn(C.FieldByName('k').AsString, C.FieldByName('d').AsString);
        C.Next;
      end;
    finally
      C.Free;
    end;
  finally
    Cols.Free;
  end;
  { kartice }
  Sql := 'SELECT * FROM (' + FDb.SourceSql(FDef.RecordSource) + ')';
  if Trim(FDef.Filter) <> '' then Sql := Sql + ' WHERE (' + Trim(FDef.Filter) + ')';
  if Trim(FDef.OrderBy) <> '' then Sql := Sql + ' ORDER BY ' + Trim(FDef.OrderBy);
  Q := FDb.NewQuery(Sql);
  try
    Q.Open;
    HasNone := False;
    while not Q.EOF do
    begin
      FKey := Q.FieldByName(FColField);
      if FKey.IsNull then HasNone := True;
      Q.Next;
    end;
    if HasNone then FBoard.AddColumn('', Tr('(none)'));
    Q.First;
    while not Q.EOF do
    begin
      if Q.FindField('id') <> nil then Id := Q.FieldByName('id').AsString else Id := IntToStr(Q.RecNo);
      if (FTitleField <> '') and (Q.FindField(FTitleField) <> nil) then
        V := ValueText(Q.FieldByName(FTitleField), LookupMap(FTitleField))
      else V := Id;
      Lines := '';
      for I := 0 to FLineFields.Count - 1 do
        if (Trim(FLineFields[I]) <> '') and (Q.FindField(Trim(FLineFields[I])) <> nil) then
        begin
          Cap := '';
          Map := LookupMap(Trim(FLineFields[I]));
          Cap := ValueText(Q.FieldByName(Trim(FLineFields[I])), Map);
          if Cap = '' then Continue;
          if Map = nil then
          begin
            M := FDb.FindFieldMeta(FDef.RecordSource, Trim(FLineFields[I]));
            try
              if (M <> nil) and (M.LType in [ltDate, ltTime, ltDateTime]) then Cap := Cap
              else if (M <> nil) and (M.Caption <> '') then Cap := M.Caption + ': ' + Cap
              else Cap := PrettyName(Trim(FLineFields[I])) + ': ' + Cap;
            finally
              M.Free;
            end;
          end;
          if Lines <> '' then Lines := Lines + LineEnding;
          Lines := Lines + Cap;
        end;
      if Q.FieldByName(FColField).IsNull then FBoard.AddCard(Id, '', V, Lines)
      else FBoard.AddCard(Id, Q.FieldByName(FColField).AsString, V, Lines);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  FBoard.EndUpdate;
  if SelKeep <> '' then FBoard.SelectedId := SelKeep;
end;

procedure TaBoardBody.CardMove(Sender: TObject; const ACardId, ANewColKey: string; var AAllow: Boolean);
var
  Q: TZQuery;
begin
  AAllow := False;
  Q := FDb.NewQuery('UPDATE ' + FDb.QuoteId(FDef.RecordSource) + ' SET ' + FDb.QuoteId(FColField) + ' = :v WHERE id = :i');
  try
    if ANewColKey = '' then
    begin
      Q.ParamByName('v').DataType := ftString;
      Q.ParamByName('v').Clear;
    end
    else Q.ParamByName('v').AsString := ANewColKey;
    Q.ParamByName('i').AsString := ACardId;
    try
      Q.ExecSQL;
      AAllow := True;
    except
      on E: Exception do ;
    end;
  finally
    Q.Free;
  end;
end;

procedure TaBoardBody.CardOpen(Sender: TObject; const ACardId: string);
begin
  if Assigned(FOnOpen) and (FEditForm <> '') then FOnOpen(Self, ACardId, FColField, '');
end;

procedure TaBoardBody.CardAdd(Sender: TObject; const AColKey: string);
begin
  if Assigned(FOnNew) and (FEditForm <> '') then FOnNew(Self, '', FColField, AColKey);
end;

end.
