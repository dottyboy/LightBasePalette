unit ta_formdef;
{ Form definition model. Serialised as JSON into _sys_forms.definition. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, fpjson, jsonparser;

type
  TaControlDef = class
  public
    Kind, Name, Caption, ControlSource, RowSource, OnClick: string;
    LinkMaster, LinkChild: string;
    { report items only }
    Section, Align, Format: string;
    Bold: Boolean;
    Left, Top, Width, Height: Integer;
    { less common properties as key=value lines: VisibleIf, EnabledIf, Tip,
      Locked, Italic, FontName, FontSize, ForeColor, BackColor, ChartType,
      Container, Page, Picture ... }
    Extra: string;
    function GetX(const AKey: string): string;
    procedure SetX(const AKey, AValue: string);
  end;

  { TaFormDef }

  TaFormDef = class
  private
    FControls: TFPObjectList;
    function GetCount: Integer;
    function GetControl(I: Integer): TaControlDef;
  public
    Name, Caption, RecordSource: string;
    Filter, OrderBy: string;
    { OnOpen, OnCurrent, BeforeUpdate, AfterUpdate, BeforeDelete, OnClose as key=value lines }
    Events: string;
    { '' = one record at a time, 'datasheet' = grid only, 'split' = form on top + grid below }
    ViewMode: string;
    { calculated columns: "Alias=expression ;; Alias2=expression2" }
    CalcFields: string;
    { uvjetno oblikovanje redaka mreze: "[iznos] > 100 => #C00000 #FFE9E9 bold ;; ..." }
    GridFormat: string;
    { when a field changes, copy values from the row it points at: "artikl_id>artikli.id:cijena=cijena,opis=naziv" }
    AutoFill: string;
    CalcRules: string;
    { LOV po celiji tablice (F9): "polje | izvor | izvor_polje=polje_tablice;..." odvojeno s ;; }
    GridLov: string;
    { potkartice u tablici (poput Accessa): "podtablica|stupac_veze|polje_roditelja" ili "auto" (prva podredjena tablica po stranom kljucu) }
    SubDatasheet: string;
    { kanban (ViewMode = board): "polje stupaca | naslov kartice | polje, polje | forma za uredjivanje" }
    Board: string;
    { nadzorna ploca (ViewMode = dash): vidi ta_formdash }
    Dash: string;
    { raspored (ViewMode = timeline): vidi ta_formtimeline }
    Timeline: string;
    AllowEdits, AllowAdds, AllowDeletes, NavButtons: Boolean;
    Width, Height: Integer;
    { neprekidna forma: visine odjeljaka u dizajnu (0 = iz kontrola) }
    HeaderHeight, RowHeight, FooterHeight: Integer;
    { prozor forme u radu: moze li mu se mijenjati velicina, minimizirati, maksimizirati; otvara li se maksimiziran }
    Resizable, CanMinimize, CanMaximize, StartMaximized: Boolean;
    { radni prostor aplikacije: od forma iste skupine moze biti otvorena samo jedna (npr. "Skladisni dokumenti") }
    ExclusiveGroup: string;
    { objedinjena forma dokumenta: polje s vrstom dokumenta i polje s brojem (vidi ta_doctypes); izbornik otvara formu s #vrsta=otp }
    DocTypeField, DocNumberField: string;
    constructor Create;
    destructor Destroy; override;
    function GetEv(const AKey: string): string;
    procedure SetEv(const AKey, AValue: string);
    function Add(ADef: TaControlDef): TaControlDef;
    procedure Delete(ADef: TaControlDef);
    { redoslijed = z-redoslijed: kasnije je iznad }
    procedure MoveItem(ADef: TaControlDef; ANewIndex: Integer);
    function IndexOfName(const AName: string): Integer;
    function UniqueName(const AKind: string): string;
    function ToJson: string;
    procedure FromJson(const S: string);
    property Count: Integer read GetCount;
    property Controls[I: Integer]: TaControlDef read GetControl; default;
  end;

implementation

function TaControlDef.GetX(const AKey: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Extra;
    Result := L.Values[AKey];
  finally
    L.Free;
  end;
end;

procedure TaControlDef.SetX(const AKey, AValue: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Extra;
    if AValue = '' then
    begin
      if L.IndexOfName(AKey) >= 0 then L.Delete(L.IndexOfName(AKey));
    end
    else L.Values[AKey] := AValue;
    Extra := Trim(L.Text);
  finally
    L.Free;
  end;
end;

constructor TaFormDef.Create;
begin
  FControls := TFPObjectList.Create(True);
  AllowEdits := True;
  AllowAdds := True;
  AllowDeletes := True;
  NavButtons := True;
  Resizable := True;
  CanMinimize := True;
  CanMaximize := True;
  StartMaximized := False;
  Width := 640;
  Height := 480;
end;

destructor TaFormDef.Destroy;
begin
  FControls.Free;
  inherited Destroy;
end;

function TaFormDef.GetEv(const AKey: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Events;
    Result := L.Values[AKey];
  finally
    L.Free;
  end;
end;

procedure TaFormDef.SetEv(const AKey, AValue: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Events;
    if AValue = '' then
    begin
      if L.IndexOfName(AKey) >= 0 then L.Delete(L.IndexOfName(AKey));
    end
    else L.Values[AKey] := AValue;
    Events := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function TaFormDef.GetCount: Integer;
begin
  Result := FControls.Count;
end;

function TaFormDef.GetControl(I: Integer): TaControlDef;
begin
  Result := TaControlDef(FControls[I]);
end;

function TaFormDef.Add(ADef: TaControlDef): TaControlDef;
begin
  FControls.Add(ADef);
  Result := ADef;
end;

procedure TaFormDef.Delete(ADef: TaControlDef);
begin
  FControls.Remove(ADef);
end;

procedure TaFormDef.MoveItem(ADef: TaControlDef; ANewIndex: Integer);
var
  I: Integer;
begin
  I := FControls.IndexOf(ADef);
  if I < 0 then Exit;
  if ANewIndex < 0 then ANewIndex := 0;
  if ANewIndex > FControls.Count - 1 then ANewIndex := FControls.Count - 1;
  FControls.Move(I, ANewIndex);
end;

function TaFormDef.IndexOfName(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Controls[I].Name, AName) then Exit(I);
  Result := -1;
end;

function TaFormDef.UniqueName(const AKind: string): string;
var
  N: Integer;
begin
  N := 1;
  repeat
    Result := AKind + IntToStr(N);
    Inc(N);
  until IndexOfName(Result) < 0;
end;

function TaFormDef.ToJson: string;
var
  O, CO: TJSONObject;
  A: TJSONArray;
  I: Integer;
  D: TaControlDef;
begin
  O := TJSONObject.Create;
  try
    O.Add('name', Name);
    O.Add('caption', Caption);
    O.Add('recordSource', RecordSource);
    O.Add('filter', Filter);
    O.Add('orderBy', OrderBy);
    O.Add('events', Events);
    O.Add('viewMode', ViewMode);
    O.Add('calcFields', CalcFields);
    O.Add('gridFormat', GridFormat);
    O.Add('autoFill', AutoFill);
    O.Add('calcRules', CalcRules);
    O.Add('gridLov', GridLov);
    O.Add('subDatasheet', SubDatasheet);
    O.Add('board', Board);
    O.Add('dash', Dash);
    O.Add('timeline', Timeline);
    O.Add('allowEdits', AllowEdits);
    O.Add('allowAdds', AllowAdds);
    O.Add('allowDeletes', AllowDeletes);
    O.Add('navButtons', NavButtons);
    O.Add('resizable', Resizable);
    O.Add('canMinimize', CanMinimize);
    O.Add('canMaximize', CanMaximize);
    O.Add('startMaximized', StartMaximized);
    O.Add('exclusiveGroup', ExclusiveGroup);
    O.Add('docTypeField', DocTypeField);
    O.Add('docNumberField', DocNumberField);
    O.Add('width', Width);
    O.Add('height', Height);
    O.Add('headerHeight', HeaderHeight);
    O.Add('rowHeight', RowHeight);
    O.Add('footerHeight', FooterHeight);
    A := TJSONArray.Create;
    for I := 0 to Count - 1 do
    begin
      D := Controls[I];
      CO := TJSONObject.Create;
      CO.Add('kind', D.Kind);
      CO.Add('name', D.Name);
      CO.Add('caption', D.Caption);
      CO.Add('controlSource', D.ControlSource);
      CO.Add('rowSource', D.RowSource);
      CO.Add('onClick', D.OnClick);
      CO.Add('linkMaster', D.LinkMaster);
      CO.Add('linkChild', D.LinkChild);
      CO.Add('section', D.Section);
      CO.Add('align', D.Align);
      CO.Add('format', D.Format);
      CO.Add('bold', D.Bold);
      CO.Add('extra', D.Extra);
      CO.Add('left', D.Left);
      CO.Add('top', D.Top);
      CO.Add('width', D.Width);
      CO.Add('height', D.Height);
      A.Add(CO);
    end;
    O.Add('controls', A);
    Result := O.FormatJSON;
  finally
    O.Free;
  end;
end;

procedure TaFormDef.FromJson(const S: string);
var
  J: TJSONData;
  O, CO: TJSONObject;
  A: TJSONData;
  I: Integer;
  D: TaControlDef;
begin
  FControls.Clear;
  if Trim(S) = '' then Exit;
  J := GetJSON(S);
  try
    O := J as TJSONObject;
    Name := O.Get('name', '');
    Caption := O.Get('caption', '');
    RecordSource := O.Get('recordSource', '');
    Filter := O.Get('filter', '');
    OrderBy := O.Get('orderBy', '');
    Events := O.Get('events', '');
    ViewMode := O.Get('viewMode', '');
    CalcFields := O.Get('calcFields', '');
    GridFormat := O.Get('gridFormat', '');
    AutoFill := O.Get('autoFill', '');
    CalcRules := O.Get('calcRules', '');
    GridLov := O.Get('gridLov', '');
    SubDatasheet := O.Get('subDatasheet', '');
    Board := O.Get('board', '');
    Dash := O.Get('dash', '');
    Timeline := O.Get('timeline', '');
    AllowEdits := O.Get('allowEdits', True);
    AllowAdds := O.Get('allowAdds', True);
    AllowDeletes := O.Get('allowDeletes', True);
    NavButtons := O.Get('navButtons', True);
    Resizable := O.Get('resizable', True);
    CanMinimize := O.Get('canMinimize', True);
    CanMaximize := O.Get('canMaximize', True);
    StartMaximized := O.Get('startMaximized', False);
    ExclusiveGroup := O.Get('exclusiveGroup', '');
    DocTypeField := O.Get('docTypeField', '');
    DocNumberField := O.Get('docNumberField', '');
    Width := O.Get('width', 640);
    Height := O.Get('height', 480);
    HeaderHeight := O.Get('headerHeight', 0);
    RowHeight := O.Get('rowHeight', 0);
    FooterHeight := O.Get('footerHeight', 0);
    A := O.Find('controls');
    if A is TJSONArray then
      for I := 0 to TJSONArray(A).Count - 1 do
      begin
        CO := TJSONArray(A).Objects[I];
        D := TaControlDef.Create;
        D.Kind := CO.Get('kind', '');
        D.Name := CO.Get('name', '');
        D.Caption := CO.Get('caption', '');
        D.ControlSource := CO.Get('controlSource', '');
        D.RowSource := CO.Get('rowSource', '');
        D.OnClick := CO.Get('onClick', '');
        D.LinkMaster := CO.Get('linkMaster', '');
        D.LinkChild := CO.Get('linkChild', '');
        D.Section := CO.Get('section', '');
        D.Align := CO.Get('align', '');
        D.Format := CO.Get('format', '');
        D.Bold := CO.Get('bold', False);
        D.Extra := CO.Get('extra', '');
        D.Left := CO.Get('left', 0);
        D.Top := CO.Get('top', 0);
        D.Width := CO.Get('width', 100);
        D.Height := CO.Get('height', 24);
        FControls.Add(D);
      end;
  finally
    J.Free;
  end;
end;

end.
