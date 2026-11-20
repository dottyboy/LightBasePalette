unit ta_family;
{ Okvir obitelji kontrola (poglavlje 3.4 plana): obitelj je jedna komponenta u paleti (domacin) koja
  drzi stvarnu kontrolu (pokretac) kao dijete. Varijanta bira pokretac iz registra; promjena varijante
  zamjenjuje pokretac, a zajednicka svojstva, tekst i stavke ostaju.

  Pokretac (TaEngine) je tanka ljuska oko LCL kontrole (ili RX/JVCL kontrole u neobaveznom paketu):
  zna dati i primiti tekst/vrijednost, stavke, samo-citanje, poravnanje i oblik, i javlja promjenu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Variants, ta_formdef;

type
  TaFamilyHost = class;

  { ---------------- pokretac ---------------- }

  TaEngine = class
  private
    FHost: TaFamilyHost;
    FInner: TWinControl;
  protected
    { pokretac poziva jednom nakon sto stvori kontrolu }
    procedure AttachInner(AControl: TWinControl);
    procedure InnerChanged(Sender: TObject);
    procedure InnerEnter(Sender: TObject);
    procedure InnerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InnerExit(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); virtual;
    destructor Destroy; override;
    { naziv pruzatelja ('lcl', 'rx', 'jvcl') }
    class function Provider: string; virtual;
    function GetText: string; virtual; abstract;
    procedure SetText(const AValue: string); virtual; abstract;
    function GetValue: Variant; virtual;
    procedure SetValue(const AValue: Variant); virtual;
    procedure SetItems(AItems: TStrings); virtual;
    procedure SetReadOnly(AValue: Boolean); virtual;
    procedure SetAlignment(AValue: TAlignment); virtual;
    procedure SetMaxLength(AValue: Integer); virtual;
    { maska unosa (ta_mask); prazno = bez maske }
    procedure SetMask(const AValue: string); virtual;
    procedure SetFormat(const AValue: string); virtual;
    procedure ApplyOptions(AOptions: TPersistent); virtual;
    { zove se kad kontrola gubi fokus (npr. oblikovanje iznosa) }
    procedure Commit; virtual;
    property Host: TaFamilyHost read FHost;
    property Inner: TWinControl read FInner;
  end;

  TaEngineClass = class of TaEngine;

  { ---------------- domacin ---------------- }

  TaFamilyHost = class(TWinControl)
  private
    FEngine: TaEngine;
    FOnChange: TNotifyEvent;
    FOnInnerKeyDown: TKeyEvent;
    FDef: TaControlDef;
  protected
    procedure SetEngine(AEngine: TaEngine);
    { obitelj odlucuje koju varijantu stvara }
    function CreateEngine: TaEngine; virtual; abstract;
    { poziva pokretac }
    procedure EngineChanged; virtual;
    procedure EngineEnter; virtual;
    procedure EngineExit; virtual;
    { dijete (stvarna kontrola) se ne sprema u .lfm; sprema se samo domacin sa svojstvima }
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure ReplaceEngine;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetFocus; override;
    { isto sto se dogodi kad polje izgubi fokus: potvrda unosa i upis u izvor podataka }
    procedure LeaveField;
    property Engine: TaEngine read FEngine;
    { definicija kontrole kad domacina stvara izvrsitelj formi (ta_famctl); inace nil }
    property Def: TaControlDef read FDef write FDef;
    { tipke stvarne kontrole unutar domacina (za neprekidnu formu i tipkovnicke mape); Sender je domacin }
    property OnInnerKeyDown: TKeyEvent read FOnInnerKeyDown write FOnInnerKeyDown;
  published
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

{ ---------------- registar pokretaca ---------------- }

{ AFamily npr. 'Edit', AVariant npr. 'combo'; AProvider je naziv pruzatelja }
procedure RegisterEngine(const AFamily, AVariant: string; AClass: TaEngineClass);
{ pokretac za varijantu; APreferred ('rx', 'jvcl') ako postoji, inace prvi registrirani (LCL) }
function FindEngine(const AFamily, AVariant: string; const APreferred: string = ''): TaEngineClass;
{ varijante koje obitelj ima (registrirane) }
function EngineVariants(const AFamily: string): TStringList;
{ zadani pruzatelj kojeg obitelji biraju ('' = LCL) }
procedure SetPreferredProvider(const AProvider: string);
function PreferredProvider: string;

implementation

type
  TWinCrack = class(TWinControl)
  public
    property OnKeyDown;
  end;

type
  TEngineEntry = record
    Family, Variant: string;
    EngineClass: TaEngineClass;
  end;

var
  GEngines: array of TEngineEntry;
  GPreferred: string = '';

procedure RegisterEngine(const AFamily, AVariant: string; AClass: TaEngineClass);
begin
  SetLength(GEngines, Length(GEngines) + 1);
  with GEngines[High(GEngines)] do
  begin
    Family := LowerCase(AFamily);
    Variant := LowerCase(AVariant);
    EngineClass := AClass;
  end;
end;

function FindEngine(const AFamily, AVariant: string; const APreferred: string): TaEngineClass;
var
  I: Integer;
  F, V, Want: string;
begin
  Result := nil;
  F := LowerCase(AFamily);
  V := LowerCase(AVariant);
  Want := LowerCase(APreferred);
  if Want = '' then Want := LowerCase(GPreferred);
  for I := 0 to High(GEngines) do
    if (GEngines[I].Family = F) and (GEngines[I].Variant = V) then
    begin
      if (Want <> '') and (LowerCase(GEngines[I].EngineClass.Provider) = Want) then Exit(GEngines[I].EngineClass);
      if Result = nil then Result := GEngines[I].EngineClass;
    end;
end;

function EngineVariants(const AFamily: string): TStringList;
var
  I: Integer;
  F: string;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  F := LowerCase(AFamily);
  for I := 0 to High(GEngines) do
    if GEngines[I].Family = F then Result.Add(GEngines[I].Variant);
end;

procedure SetPreferredProvider(const AProvider: string);
begin
  GPreferred := AProvider;
end;

function PreferredProvider: string;
begin
  Result := GPreferred;
end;

{ ---------------- TaEngine ---------------- }

constructor TaEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create;
  FHost := AHost;
end;

destructor TaEngine.Destroy;
begin
  if FInner <> nil then
  begin
    FInner.OnEnter := nil;
    FInner.OnExit := nil;
    TWinCrack(FInner).OnKeyDown := nil;
    FInner.Free;
  end;
  inherited Destroy;
end;

class function TaEngine.Provider: string;
begin
  Result := 'lcl';
end;

procedure TaEngine.AttachInner(AControl: TWinControl);
begin
  FInner := AControl;
  FInner.Parent := FHost;
  FInner.Align := alClient;
  { IDE imenuje i ovu kontrolu pri izradi komponente; bez csSetCaption ime ne postaje natpis (RadioGroup1, CheckBox1...) }
  FInner.ControlStyle := FInner.ControlStyle + [csNoDesignSelectable] - [csSetCaption];
  FInner.OnEnter := @InnerEnter;
  FInner.OnExit := @InnerExit;
  TWinCrack(FInner).OnKeyDown := @InnerKeyDown;
end;

procedure TaEngine.InnerChanged(Sender: TObject);
begin
  if FHost <> nil then FHost.EngineChanged;
end;

procedure TaEngine.InnerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (FHost <> nil) and Assigned(FHost.FOnInnerKeyDown) then FHost.FOnInnerKeyDown(FHost, Key, Shift);
end;

procedure TaEngine.InnerEnter(Sender: TObject);
begin
  if FHost <> nil then FHost.EngineEnter;
end;

procedure TaEngine.InnerExit(Sender: TObject);
begin
  Commit;
  if FHost <> nil then FHost.EngineExit;
end;

function TaEngine.GetValue: Variant;
begin
  Result := GetText;
end;

procedure TaEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then SetText('') else SetText(VarToStr(AValue));
end;

procedure TaEngine.SetItems(AItems: TStrings);
begin
end;

procedure TaEngine.SetReadOnly(AValue: Boolean);
begin
end;

procedure TaEngine.SetAlignment(AValue: TAlignment);
begin
end;

procedure TaEngine.SetMask(const AValue: string);
begin
end;

procedure TaEngine.SetMaxLength(AValue: Integer);
begin
end;

procedure TaEngine.SetFormat(const AValue: string);
begin
end;

procedure TaEngine.ApplyOptions(AOptions: TPersistent);
begin
end;

procedure TaEngine.Commit;
begin
end;

{ ---------------- TaFamilyHost ---------------- }

constructor TaFamilyHost.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption] + [csOpaque];
  TabStop := False;
  SetInitialBounds(0, 0, 160, 28);
end;

destructor TaFamilyHost.Destroy;
begin
  FEngine.Free;
  FEngine := nil;
  inherited Destroy;
end;

procedure TaFamilyHost.SetEngine(AEngine: TaEngine);
var
  Old: TaEngine;
begin
  Old := FEngine;
  FEngine := AEngine;
  Old.Free;
end;

procedure TaFamilyHost.ReplaceEngine;
begin
  SetEngine(CreateEngine);
end;

procedure TaFamilyHost.EngineChanged;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TaFamilyHost.EngineEnter;
begin
  DoEnter;
end;

procedure TaFamilyHost.EngineExit;
begin
  DoExit;
end;

procedure TaFamilyHost.GetChildren(Proc: TGetChildProc; Root: TComponent);
begin
  { nista: stvarna kontrola je dio domacina i ne sprema se zasebno }
end;

procedure TaFamilyHost.LeaveField;
begin
  if FEngine <> nil then FEngine.Commit;
  EngineExit;
end;

procedure TaFamilyHost.SetFocus;
begin
  if (FEngine <> nil) and (FEngine.Inner <> nil) and FEngine.Inner.CanFocus then FEngine.Inner.SetFocus
  else inherited SetFocus;
end;

end.
