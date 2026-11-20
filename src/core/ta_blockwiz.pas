unit ta_blockwiz;
{ Blok-carobnjak (poglavlje 19.2 plana): odaberes tablicu i raspored, a dobijes formu s poljima prema tipu stupca
  (datum -> datumsko polje, strani kljuc -> padajuci popis iz povezane tablice, da/ne -> kvacica, memo -> vise redaka),
  s podformama za tablice koje na nju pokazuju stranim kljucem. Bez sucelja, da radi isto u dijalogu i testovima.
  Sve sto nastane je obicna definicija forme (JSON); nista skriveno. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta, ta_types, ta_formdef, ta_wizardgen;

type
  TaBlockLayout = (blForm, blTwoColumns, blTable, blFormAndTable, blContinuous, blFormContinuousSub);

  TaBlockWizard = class
  private
    FDb: TAppDb;
    FTable: string;
    FLayout: TaBlockLayout;
    FWithDetails: Boolean;
    FDetails: TStringList;
    FExtras: TStringList;      { dodatne forme (neprekidne podforme): naziv=JSON }
    procedure SetTable(const AValue: string);
  public
    constructor Create(ADb: TAppDb);
    destructor Destroy; override;
    { opis onoga sto ce nastati: "polje -> vrsta kontrole", redak po stupcu, pa podforme }
    procedure Describe(AList: TStrings);
    function SuggestName: string;
    { sama definicija forme; pozivatelj je oslobada }
    function Build(const AName: string): TaFormDef;
    function Save(const AName: string; out AErr: string): Boolean;
    property Table: string read FTable write SetTable;
    property Layout: TaBlockLayout read FLayout write FLayout;
    property WithDetails: Boolean read FWithDetails write FWithDetails;
    { tablice s kljucem prema glavnoj (zadano sve), mogu se maknuti }
    property Details: TStringList read FDetails;
    { forme koje je zadnji Build uz glavnu stvorio (naziv=JSON), Save ih sprema }
    property Extras: TStringList read FExtras;
  end;

implementation

{ neprekidna forma nad tablicom: zaglavlje s naslovima (sort) i filtrima, detalj s kontrolama po tipu stupca, podnozje sa zbrojevima }
function BuildContinuousDef(ADb: TAppDb; const ATable, AName, AExcludeFk: string): TaFormDef;
var
  All: TaSourceFields;
  Fks, Parts: TStringList;
  I, K, X, W, N: Integer;
  Kind, Src, Pk: string;
  Lb, Ct, Fl, Ft: TaControlDef;
  Numeric, FirstFooter: Boolean;
begin
  Result := TaFormDef.Create;
  Result.Name := AName;
  Result.Caption := PrettyName(ATable);
  Result.RecordSource := ATable;
  Result.ViewMode := 'continuous';
  Result.AllowEdits := True;
  Result.AllowAdds := True;
  Result.AllowDeletes := True;
  Result.NavButtons := False;
  Result.HeaderHeight := 54;
  Result.RowHeight := 34;
  Result.FooterHeight := 34;
  All := SourceFieldList(ADb, ATable);
  Pk := ADb.PrimaryKeyOf(ATable);
  Fks := ADb.ForeignKeys(ATable);
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    X := 4;
    N := 0;
    FirstFooter := True;
    for I := 0 to High(All) do
    begin
      if (All[I].LType = ltAutoNumber) or SameText(All[I].Name, AExcludeFk) or SameText(All[I].Name, Pk) then Continue;
      Kind := 'TextBox';
      W := 150;
      Src := '';
      for K := 0 to Fks.Count - 1 do
      begin
        Parts.DelimitedText := Fks[K];
        if (Parts.Count = 3) and SameText(Parts[0], All[I].Name) then
        begin
          Kind := 'ComboBox';
          Src := LookupQuerySql(ADb, Parts[1], Parts[2]);
          W := 170;
        end;
      end;
      Numeric := False;
      if Kind = 'TextBox' then
        case All[I].LType of
          ltYesNo: begin Kind := 'CheckBox'; W := 40; end;
          ltDate: W := 100;
          ltTime: W := 80;
          ltDateTime: W := 150;
          ltInteger: begin W := 90; Numeric := True; end;
          ltDecimal, ltCurrency: begin W := 110; Numeric := True; end;
          ltMemo: W := 220;
        else
          W := 180;
        end;
      { zaglavlje: naslov (sortiranje) + filtar }
      Lb := TaControlDef.Create;
      Lb.Kind := 'Label'; Lb.Name := 'h_' + All[I].Name; Lb.Caption := CaptionOf(All[I]); Lb.Section := 'header';
      Lb.Left := X; Lb.Top := 4; Lb.Width := W; Lb.Height := 20; Lb.Bold := True;
      Lb.SetX('sort', All[I].Name);
      Result.Add(Lb);
      if Kind <> 'CheckBox' then
      begin
        Fl := TaControlDef.Create;
        Fl.Kind := 'TextBox'; Fl.Name := 'f_' + All[I].Name; Fl.Section := 'header';
        Fl.Left := X; Fl.Top := 26; Fl.Width := W; Fl.Height := 24;
        Fl.SetX('filter', All[I].Name);
        Result.Add(Fl);
      end;
      { detalj }
      Ct := TaControlDef.Create;
      Ct.Kind := Kind; Ct.Name := 'c_' + All[I].Name; Ct.ControlSource := All[I].Name; Ct.Section := 'detail';
      Ct.Left := X; Ct.Top := 4; Ct.Width := W; Ct.Height := 26;
      Ct.RowSource := Src;
      if All[I].LType = ltDate then Ct.Format := 'dd.mm.yyyy'
      else if All[I].LType in [ltDecimal, ltCurrency] then Ct.Format := '#,##0.00';
      if Numeric then Ct.Align := 'right';
      Result.Add(Ct);
      { podnozje: broj redaka pod prvim stupcem, zbroj pod brojcanim }
      if FirstFooter then
      begin
        Ft := TaControlDef.Create;
        Ft.Kind := 'TextBox'; Ft.Name := 'z_broj'; Ft.ControlSource := '=Count()'; Ft.Section := 'footer'; Ft.Format := '#,##0';
        Ft.Left := X; Ft.Top := 4; Ft.Width := W; Ft.Height := 24;
        Result.Add(Ft);
        FirstFooter := False;
      end
      else if All[I].LType in [ltDecimal, ltCurrency] then
      begin
        Ft := TaControlDef.Create;
        Ft.Kind := 'TextBox'; Ft.Name := 'z_' + All[I].Name; Ft.ControlSource := '=Sum(' + All[I].Name + ')'; Ft.Section := 'footer';
        Ft.Format := '#,##0.00'; Ft.Left := X; Ft.Top := 4; Ft.Width := W; Ft.Height := 24;
        Result.Add(Ft);
      end;
      Inc(X, W + 6);
      Inc(N);
    end;
    Result.Width := X + 40;
    Result.Height := 54 + 34 * 8 + 34;
  finally
    Parts.Free;
    Fks.Free;
  end;
end;

constructor TaBlockWizard.Create(ADb: TAppDb);
begin
  FDb := ADb;
  FLayout := blForm;
  FWithDetails := True;
  FDetails := TStringList.Create;
  FExtras := TStringList.Create;
end;

destructor TaBlockWizard.Destroy;
begin
  FDetails.Free;
  FExtras.Free;
  inherited Destroy;
end;

procedure TaBlockWizard.SetTable(const AValue: string);
var
  Rels, Parts: TStringList;
  I: Integer;
begin
  FTable := AValue;
  FDetails.Clear;
  if AValue = '' then Exit;
  Rels := ChildRelations(FDb, AValue);
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    for I := 0 to Rels.Count - 1 do
    begin
      Parts.DelimitedText := Rels[I];
      if (Parts.Count = 3) and (FDetails.IndexOf(Parts[0]) < 0) then FDetails.Add(Parts[0]);
    end;
  finally
    Parts.Free;
    Rels.Free;
  end;
end;

procedure TaBlockWizard.Describe(AList: TStrings);
var
  All: TaSourceFields;
  Fks, Parts: TStringList;
  I, K: Integer;
  Kind: string;
begin
  AList.Clear;
  if FTable = '' then Exit;
  if FLayout = blTable then
  begin
    AList.Add('Tablica: svi stupci tablice ' + FTable + ' u mrezi');
    Exit;
  end;
  if FLayout = blContinuous then
  begin
    AList.Add('Neprekidna forma: zaglavlje (naslovi za sortiranje i filtri), redovi s kontrolom po stupcu, podnozje sa zbrojevima');
  end;
  All := SourceFieldList(FDb, FTable);
  Fks := FDb.ForeignKeys(FTable);
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    for I := 0 to High(All) do
    begin
      case All[I].LType of
        ltYesNo: Kind := 'kvacica';
        ltDate, ltDateTime: Kind := 'datum';
        ltTime: Kind := 'vrijeme';
        ltInteger: Kind := 'cijeli broj';
        ltDecimal, ltCurrency: Kind := 'iznos';
        ltAutoNumber: Kind := 'kljuc (samo za citanje)';
        ltMemo: Kind := 'tekst u vise redaka';
        ltPicture: Kind := 'slika';
      else
        Kind := 'tekst';
      end;
      for K := 0 to Fks.Count - 1 do
      begin
        Parts.DelimitedText := Fks[K];
        if (Parts.Count = 3) and SameText(Parts[0], All[I].Name) then
          Kind := 'padajuci popis iz tablice ' + Parts[1];
      end;
      AList.Add(All[I].Name + ' -> ' + Kind);
    end;
  finally
    Parts.Free;
    Fks.Free;
  end;
  if FWithDetails and (FLayout <> blTable) and (FLayout <> blContinuous) then
    for I := 0 to FDetails.Count - 1 do
      if FLayout = blFormContinuousSub then AList.Add('neprekidna podforma: ' + FDetails[I])
      else AList.Add('podforma: ' + FDetails[I]);
end;

function TaBlockWizard.SuggestName: string;
var
  Base: string;
  N: Integer;
begin
  Base := 'Blok_' + FTable;
  Result := Base;
  N := 1;
  while FDb.LoadObject('_sys_forms', Result) <> '' do
  begin
    Inc(N);
    Result := Base + '_' + IntToStr(N);
  end;
end;

function TaBlockWizard.Build(const AName: string): TaFormDef;
var
  O: TaFormOptions;
  All: TaSourceFields;
  F, Sub, Rels, Parts: TStringList;
  I, J, K, Bottom: Integer;
  Child: TaFormDef;
  Sc: TaControlDef;
  ChildName, Pk: string;
begin
  FExtras.Clear;
  if FLayout = blContinuous then
  begin
    Result := BuildContinuousDef(FDb, FTable, AName, '');
    Exit;
  end;
  F := TStringList.Create;
  Sub := TStringList.Create;
  try
    All := SourceFieldList(FDb, FTable);
    for I := 0 to High(All) do F.Add(All[I].Name);
    if FWithDetails and (FLayout in [blForm, blTwoColumns, blFormAndTable]) then Sub.Assign(FDetails);
    O.Source := FTable;
    O.Name := AName;
    O.Title := PrettyName(FTable);
    O.Fields := F;
    O.SubTables := Sub;
    O.FilterFields := nil;
    O.AddRefreshButton := False;
    O.AddClearButton := False;
    case FLayout of
      blTwoColumns: O.Layout := flTwoColumns;
      blTable: O.Layout := flDatasheet;
      blFormAndTable: O.Layout := flSplit;
    else
      O.Layout := flOneColumn;
    end;
    Result := BuildFormEx(FDb, O);
  finally
    F.Free;
    Sub.Free;
  end;
  { obrazac + neprekidne podforme: za svaku tablicu s kljucem prema glavnoj nastaje neprekidna forma stavki }
  if (FLayout = blFormContinuousSub) and FWithDetails then
  begin
    Rels := ChildRelations(FDb, FTable);
    Parts := TStringList.Create;
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    try
      Bottom := 0;
      for I := 0 to Result.Count - 1 do
        if Result[I].Top + Result[I].Height > Bottom then Bottom := Result[I].Top + Result[I].Height;
      Pk := FDb.PrimaryKeyOf(FTable);
      for I := 0 to FDetails.Count - 1 do
        for J := 0 to Rels.Count - 1 do
        begin
          Parts.DelimitedText := Rels[J];
          if (Parts.Count <> 3) or not SameText(Parts[0], FDetails[I]) then Continue;
          ChildName := AName + '_' + FDetails[I];
          Child := BuildContinuousDef(FDb, FDetails[I], ChildName, Parts[1]);
          try
            FExtras.Add(ChildName + '=' + StringReplace(StringReplace(Child.ToJson, #13, '', [rfReplaceAll]), #10, #1, [rfReplaceAll]));
            Inc(Bottom, 14);
            Sc := TaControlDef.Create;
            Sc.Kind := 'Subform';
            Sc.Name := 'sub_' + FDetails[I];
            Sc.Caption := PrettyName(FDetails[I]);
            Sc.RowSource := ChildName;
            if Pk = '' then Pk := Parts[2];
            Sc.LinkMaster := Parts[2];
            Sc.LinkChild := Parts[1];
            Sc.Left := 16;
            Sc.Top := Bottom;
            Sc.Width := Child.Width;
            Sc.Height := 240;
            Result.Add(Sc);
            if Child.Width + 40 > Result.Width then Result.Width := Child.Width + 40;
            Inc(Bottom, Sc.Height);
          finally
            Child.Free;
          end;
          Break;
        end;
      Result.Height := Bottom + 24;
    finally
      Parts.Free;
      Rels.Free;
    end;
  end;
end;

function TaBlockWizard.Save(const AName: string; out AErr: string): Boolean;
var
  D: TaFormDef;
  I: Integer;
begin
  Result := False;
  AErr := '';
  if (FTable = '') or (Trim(AName) = '') then begin AErr := 'Odaberi tablicu i naziv forme'; Exit; end;
  try
    D := Build(Trim(AName));
    try
      FDb.SaveObject('_sys_forms', D.Name, D.ToJson);
      for I := 0 to FExtras.Count - 1 do
        FDb.SaveObject('_sys_forms', FExtras.Names[I], StringReplace(FExtras.ValueFromIndex[I], #1, #10, [rfReplaceAll]));
    finally
      D.Free;
    end;
    Result := True;
  except
    on E: Exception do AErr := E.Message;
  end;
end;

end.
