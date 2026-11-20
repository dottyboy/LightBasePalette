unit ta_theme;
{ Izgled programa: moderna svijetla tema preko Qt stilske tablice (QSS). Radi samo uz Qt6; na drugim
  sucelima ne radi nista. Izbor teme pamti se po korisniku (konfiguracijska datoteka), ne po bazi. }

{$mode objfpc}{$H+}

interface

uses
  ta_tokens, ta_meta;

type
  TaTheme = (thSystem, thModern, thModernDark);

const
  ThemeNames: array[TaTheme] of string = ('Sustavni izgled', 'Moderno svijetlo', 'Moderno tamno');

var
  { okvir oko modalnih i sporednih prozora; ispitni skupovi koji usporedjuju snimke ga iskljucuju }
  WindowFrames: Boolean = True;

function CurrentTheme: TaTheme;
{ postavlja temu (odmah) i pamti izbor }
procedure SetTheme(ATheme: TaTheme; ASave: Boolean = True);
{ cita spremljeni izbor i primjenjuje ga; zove se pri pokretanju }
procedure ApplySavedTheme;
function ThemeSheet(ATheme: TaTheme): string;
{ QSS iz tokena (oblik, naglasak, font); isti sadrzaj za svijetlu i tamnu varijantu }
function TokensSheet(const T: TaThemeTokens): string;
{ trenutni tokeni teme (za kontrole koje same crtaju: ta_tokens.ActiveTokens) }
function CurrentTokens: TaThemeTokens;
{ postavlja temu iz tokena (odmah) i pamti izbor; ASave=False ne pamti }
procedure SetThemeTokens(const T: TaThemeTokens; ASave: Boolean = True);
{ ugradena tema po indeksu ('Plava', 'Zelena', ...) uz tamnu varijantu i oblik }
procedure SetBuiltinTheme(AIndex: Integer; ADark: Boolean; AShape: TaShape; ASave: Boolean = True);
{ ucitava temu iz JSON datoteke; AWarn dobiva upozorenja ili razlog neuspjeha }
function LoadThemeFromFile(const AFile: string; out AWarn: string; ASave: Boolean = True): Boolean;
{ registrira slova iz mape "fonts" (uz izvrsnu datoteku, uz mapu projekta ili po putanji); vraca broj registriranih }
function RegisterThemeFonts(const AExtraDir: string = ''): Integer;
{ True ako je korisnik sam birao temu (konfiguracijska datoteka); tema aplikacije tada ne nadjacava njegov izbor }
function UserChoseTheme: Boolean;
{ sprema trenutnu temu u bazu aplikacije (postavka 'tema.json'); prazna tema = uklanja }
function SaveThemeToApp(ADb: TAppDb): Boolean;
function ClearAppTheme(ADb: TAppDb): Boolean;
{ primjenjuje temu spremljenu u bazi aplikacije; bez AForce samo ako korisnik nije sam birao; True ako je primijenjena }
function ApplyThemeFromApp(ADb: TAppDb; AForce: Boolean = False): Boolean;
{ prebojava kontrole koje crta LCL (popisi, tablice, polja, ploce) u boje teme; boje koje je korisnik sam odabrao ostaju }
procedure RecolorForm(AForm: TObject);

implementation

uses
  Classes, SysUtils, IniFiles, Forms, Controls, Graphics, Grids, StdCtrls, ExtCtrls, ComCtrls, DBGrids, ta_icons,
  FPImage, FPWritePNG, Math, StrUtils, EditBtn
  {$IFDEF LCLQT6}, qt6{$ENDIF};

var
  Cur: TaTheme = thModern;
  Loaded: Boolean = False;
  CurTok: TaThemeTokens;
  CurTokSet: Boolean = False;
  GlyphDir: string = '';

function ConfigFile: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'theme.ini';
end;

{ ---- slicice (strelice i kvacica) za QSS: crtaju se jednom po boji u PNG ---- }

function GlyphFolder: string;
begin
  if GlyphDir <> '' then Exit(GlyphDir);
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'theme';
  try
    ForceDirectories(Result);
    if not DirectoryExists(Result) then Abort;
  except
    Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'typhaccess_theme';
    ForceDirectories(Result);
  end;
  GlyphDir := IncludeTrailingPathDelimiter(Result);
  Result := GlyphDir;
end;

function SegDist(Px, Py, X1, Y1, X2, Y2: Double): Double;
var
  Dx, Dy, T: Double;
begin
  Dx := X2 - X1; Dy := Y2 - Y1;
  T := ((Px - X1) * Dx + (Py - Y1) * Dy) / (Dx * Dx + Dy * Dy);
  T := Max(0, Min(1, T));
  Result := Sqrt(Sqr(Px - (X1 + T * Dx)) + Sqr(Py - (Y1 + T * Dy)));
end;

{ AKind: 'down', 'up', 'check'; vraca putanju PNG-a }
function GlyphFile(const AKind, AColorHex: string): string;
const
  N = 32;
  Pts: array[0..2, 0..5] of Double = (
    (8, 12, 16, 20, 24, 12),     { down }
    (8, 20, 16, 12, 24, 20),     { up }
    (7, 17, 13, 23, 25, 9));     { check }
var
  Img: TFPMemoryImage;
  W: TFPWriterPNG;
  K, X, Y, I: Integer;
  D, A: Double;
  C: TColor;
  Col: TFPColor;
  P: array[0..5] of Double;
begin
  if AKind = 'down' then K := 0 else if AKind = 'up' then K := 1 else K := 2;
  Result := GlyphFolder + 'g_' + AKind + '_' + Copy(AColorHex, 2, 6) + '.png';
  if FileExists(Result) then Exit;
  for I := 0 to 5 do P[I] := Pts[K, I];
  C := TokenColor(AColorHex);
  Img := TFPMemoryImage.Create(N, N);
  W := TFPWriterPNG.Create;
  try
    Img.UsePalette := False;
    W.UseAlpha := True;
    for Y := 0 to N - 1 do
      for X := 0 to N - 1 do
      begin
        D := Min(SegDist(X + 0.5, Y + 0.5, P[0], P[1], P[2], P[3]), SegDist(X + 0.5, Y + 0.5, P[2], P[3], P[4], P[5]));
        A := Max(0, Min(1, 1.9 + 0.5 - D));
        Col.Red := (C and $FF) * 257; Col.Green := ((C shr 8) and $FF) * 257; Col.Blue := ((C shr 16) and $FF) * 257;
        Col.Alpha := Round(A * 65535);
        Img.Colors[X, Y] := Col;
      end;
    Img.SaveToFile(Result, W);
  finally
    W.Free;
    Img.Free;
  end;
end;

function QssUrl(const AFile: string): string;
begin
  Result := 'url("' + StringReplace(AFile, '\', '/', [rfReplaceAll]) + '")';
end;

function Px(N: Integer): string;
begin
  Result := IntToStr(N) + 'px';
end;

function TokensSheet(const T: TaThemeTokens): string;
var
  Rb, Rf, Pad, Dd, Rd, Rs: string;
  Fam, Down, Up, Check: string;
  Pill: Boolean;
begin
  Pill := T.Shape = shPill;
  Rb := Px(T.RadiusButton);
  Rf := Px(T.RadiusField);
  Rs := Px(Max(T.RadiusField - 1, 0));
  if Pill then Pad := '2px 12px' else Pad := '2px 6px';
  Fam := '"' + T.FontFamily + '","Monospace"';
  Down := QssUrl(GlyphFile('down', T.OnAccent));
  Up := QssUrl(GlyphFile('up', T.OnAccent));
  Check := QssUrl(GlyphFile('check', T.OnAccent));
  { gumb padajuceg popisa: uz rub (square, rounded) ili okrugli unutar polja (pill) }
  if Pill then
  begin
    Dd := 'margin:3px 4px 3px 0;border-radius:' + Px(T.ControlHeight div 2 - 4) + ';width:' + Px(T.ControlHeight - 8) + ';';
    Rd := '';
  end
  else
  begin
    Dd := 'width:22px;';
    Rd := 'border-top-right-radius:' + Rs + ';border-bottom-right-radius:' + Rs + ';';
  end;
  Result :=
    'QWidget{color:' + T.Text + ';font-family:' + Fam + ';font-size:' + IntToStr(T.FontSize) + 'pt;}' +
    'QMainWindow,QDialog{background:' + T.Bg + ';}' +
    'QPushButton,QToolButton{background:' + T.Surface + ';border:1px solid ' + T.Border + ';border-radius:' + Rb + ';padding:3px ' + IfThen(Pill, '14px', '6px') + ';min-height:20px;}' +
    'QPushButton:hover,QToolButton:hover{background:' + T.AccentSoft + ';border-color:' + T.Accent + ';}' +
    'QPushButton:pressed,QToolButton:pressed{background:' + T.AccentSoft + ';border-color:' + T.Accent + ';}' +
    'QPushButton:default{background:' + T.Accent + ';color:' + T.OnAccent + ';border:1px solid ' + T.Accent + ';}' +
    'QPushButton:default:hover{background:' + T.AccentHover + ';border-color:' + T.AccentHover + ';}' +
    'QPushButton:disabled{color:' + T.TextSoft + ';background:' + T.Soft + ';}' +
    'QToolButton:checked{background:' + T.AccentSoft + ';border-color:' + T.Accent + ';}' +
    'QLineEdit,QTextEdit,QPlainTextEdit,QSpinBox,QDoubleSpinBox,QComboBox{background:' + T.Surface + ';border:1px solid ' + T.Border +
      ';border-radius:' + Rf + ';padding:' + Pad + ';selection-background-color:' + T.AccentSoft + ';selection-color:' + T.Text + ';}' +
    'QLineEdit:focus,QTextEdit:focus,QPlainTextEdit:focus,QComboBox:focus,QSpinBox:focus,QDoubleSpinBox:focus{border:1px solid ' + T.Accent + ';}' +
    'QLineEdit:disabled,QComboBox:disabled{background:' + T.Soft + ';color:' + T.TextSoft + ';}' +
    'QComboBox{padding-right:' + IfThen(Pill, '34px', '28px') + ';}' +
    'QComboBox::drop-down{subcontrol-origin:padding;subcontrol-position:top right;border:0;background:' + T.Accent + ';' + Dd + Rd + '}' +
    'QComboBox::drop-down:hover{background:' + T.AccentHover + ';}' +
    'QComboBox::down-arrow{image:' + Down + ';width:12px;height:12px;}' +
    'QComboBox QAbstractItemView{background:' + T.Surface + ';border:1px solid ' + T.Border + ';selection-background-color:' + T.AccentSoft + ';selection-color:' + T.Text + ';outline:0;}' +
    'QSpinBox,QDoubleSpinBox{padding-right:24px;}' +
    'QSpinBox::up-button,QDoubleSpinBox::up-button{subcontrol-origin:border;subcontrol-position:top right;width:18px;background:' + T.Accent + ';border:0;border-top-right-radius:' + Rs + ';}' +
    'QSpinBox::down-button,QDoubleSpinBox::down-button{subcontrol-origin:border;subcontrol-position:bottom right;width:18px;background:' + T.Accent + ';border:0;border-bottom-right-radius:' + Rs + ';}' +
    'QSpinBox::up-button:hover,QSpinBox::down-button:hover,QDoubleSpinBox::up-button:hover,QDoubleSpinBox::down-button:hover{background:' + T.AccentHover + ';}' +
    'QSpinBox::up-arrow,QDoubleSpinBox::up-arrow{image:' + Up + ';width:9px;height:9px;}' +
    'QSpinBox::down-arrow,QDoubleSpinBox::down-arrow{image:' + Down + ';width:9px;height:9px;}' +
    'QMenuBar{background:' + T.Soft + ';border-bottom:1px solid ' + T.Border + ';}' +
    'QMenuBar::item{padding:5px 10px;background:transparent;border-radius:4px;}' +
    'QMenuBar::item:selected{background:' + T.AccentSoft + ';}' +
    'QMenu{background:' + T.Surface + ';border:1px solid ' + T.Border + ';padding:4px;}' +
    'QMenu::item{padding:5px 26px 5px 8px;border-radius:4px;}' +
    'QMenu::item:selected{background:' + T.AccentSoft + ';color:' + T.Text + ';}' +
    'QMenu::separator{height:1px;background:' + T.Border + ';margin:4px 6px;}' +
    'QTabWidget::pane{border:1px solid ' + T.Border + ';top:-1px;}';
  if Pill then
    Result := Result +
      'QTabBar::tab{padding:4px 16px;margin:3px 3px;background:' + T.Soft + ';border:1px solid ' + T.Border + ';border-radius:' + Px(T.ControlHeight div 2 - 3) + ';color:' + T.TextSoft + ';}' +
      'QTabBar::tab:selected{color:' + T.OnAccent + ';background:' + T.Accent + ';border-color:' + T.Accent + ';}' +
      'QTabBar::tab:hover:!selected{background:' + T.AccentSoft + ';}'
  else
    Result := Result +
      'QTabBar::tab{padding:6px 14px;background:transparent;border:0;border-bottom:2px solid transparent;border-top-left-radius:' + Rb + ';border-top-right-radius:' + Rb + ';color:' + T.TextSoft + ';}' +
      'QTabBar::tab:selected{color:' + T.Accent + ';border-bottom:2px solid ' + T.Accent + ';background:' + T.Surface + ';}' +
      'QTabBar::tab:hover:!selected{background:' + T.Soft + ';}';
  Result := Result +
    'QHeaderView::section{background:' + T.Header + ';color:' + T.Text + ';border:0;border-right:1px solid ' + T.Border + ';border-bottom:1px solid ' + T.Border + ';padding:4px 6px;font-weight:600;}' +
    'QTableView,QListView,QTreeView,QTextEdit,QPlainTextEdit{border:1px solid ' + T.Border + ';gridline-color:' + T.Border + ';}' +
    'QTableView,QListView,QTreeView{selection-background-color:' + T.AccentSoft + ';selection-color:' + T.Text + ';alternate-background-color:' + T.Soft + ';}' +
    'QTableView,QListView,QTreeView,QAbstractItemView{color:' + T.Text + ';}' +
    'QListView::item,QTreeView::item{color:' + T.Text + ';}' +
    'QListView::item:selected,QTreeView::item:selected{background:' + T.AccentSoft + ';color:' + T.Text + ';}' +
    'QScrollBar:vertical{background:transparent;width:12px;margin:0;}' +
    'QScrollBar:horizontal{background:transparent;height:12px;margin:0;}' +
    'QScrollBar::handle:vertical{background:' + T.Border + ';border-radius:5px;min-height:28px;margin:2px;}' +
    'QScrollBar::handle:horizontal{background:' + T.Border + ';border-radius:5px;min-width:28px;margin:2px;}' +
    'QScrollBar::handle:hover{background:' + T.TextSoft + ';}' +
    'QScrollBar::add-line,QScrollBar::sub-line{width:0;height:0;}' +
    'QScrollBar::add-page,QScrollBar::sub-page{background:transparent;}' +
    'QCheckBox::indicator{width:16px;height:16px;border:1px solid ' + T.Border + ';border-radius:3px;background:' + T.Surface + ';}' +
    'QCheckBox::indicator:checked{background:' + T.Accent + ';border-color:' + T.Accent + ';image:' + Check + ';}' +
    'QCheckBox::indicator:hover{border-color:' + T.Accent + ';}' +
    'QRadioButton::indicator{width:16px;height:16px;border:1px solid ' + T.Border + ';border-radius:8px;background:' + T.Surface + ';}' +
    'QRadioButton::indicator:checked{border-color:' + T.Accent + ';background:qradialgradient(cx:0.5,cy:0.5,radius:0.5,fx:0.5,fy:0.5,stop:0 ' + T.Accent + ',stop:0.45 ' + T.Accent + ',stop:0.5 ' + T.Surface + ',stop:1 ' + T.Surface + ');}' +
    'QToolTip{background:' + T.Tip + ';color:#F8FAFC;border:0;padding:5px 8px;border-radius:4px;}' +
    'QStatusBar{background:' + T.Soft + ';border-top:1px solid ' + T.Border + ';}' +
    'QSplitter::handle{background:' + T.Border + ';}' +
    'QProgressBar{background:' + T.Surface + ';border:1px solid ' + T.Border + ';border-radius:' + Rf + ';text-align:center;}' +
    'QProgressBar::chunk{background:' + T.Accent + ';border-radius:' + Rs + ';}';
  if T.Dark then
    Result := Result + 'QListView,QTableView,QTreeView,QAbstractItemView{background:' + T.Surface + ';}QAbstractScrollArea::corner{background:' + T.Soft + ';}';
end;

function TokensForTheme(ATheme: TaTheme): TaThemeTokens;
var
  Sh: TaShape;
begin
  if CurTokSet then Sh := CurTok.Shape else Sh := shRounded;
  if ATheme = thModernDark then Result := BuiltinTokens(0, True, Sh)
  else Result := BuiltinTokens(0, False, Sh);
end;

function ThemeSheet(ATheme: TaTheme): string;
begin
  if ATheme = thSystem then Result := '' else Result := TokensSheet(TokensForTheme(ATheme));
end;

function CurrentTokens: TaThemeTokens;
begin
  if not CurTokSet then
  begin
    CurTok := BuiltinTokens(0, False, shRounded);
    CurTokSet := True;
  end;
  Result := CurTok;
end;

function RegisterThemeFonts(const AExtraDir: string = ''): Integer;
var
  Dirs: TStringList;
  D: Integer;
  SR: TSearchRec;
  Dir: string;
  {$IFDEF LCLQT6}WS: WideString;{$ENDIF}
begin
  Result := 0;
  Dirs := ThemeFontDirs(AExtraDir);
  try
    for D := 0 to Dirs.Count - 1 do
    begin
      Dir := Dirs[D];
      if not DirectoryExists(Dir) then Continue;
      if FindFirst(Dir + '*.ttf', faAnyFile, SR) = 0 then
      begin
        repeat
          if Pos('JetBrainsMono-', SR.Name) <> 1 then Continue;
          {$IFDEF LCLQT6}
          WS := UTF8Decode(Dir + SR.Name);
          if QFontDatabase_addApplicationFont(@WS) >= 0 then Inc(Result);
          {$ENDIF}
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
      if Result > 0 then Exit;
    end;
  finally
    Dirs.Free;
  end;
end;

var
  FontsDone: Boolean = False;

procedure Apply(const T: TaThemeTokens; ASystem: Boolean);
{$IFDEF LCLQT6}
var
  WS: WideString;
  F: QFontH;
begin
  SetIconDark(T.Dark and not ASystem);
  if not FontsDone then begin RegisterThemeFonts; FontsDone := True; end;
  if ASystem then WS := '' else WS := UTF8Decode(TokensSheet(T));
  { QCoreApplication_instance vraca isti objekt koji LCL koristi }
  QApplication_setStyleSheet(QApplicationH(QCoreApplication_instance()), @WS);
  if not ASystem then
  begin
    { osnovni font aplikacije za kontrole koje crta LCL (mreze, natpisi izvan QSS-a) }
    WS := UTF8Decode(T.FontFamily);
    F := QFont_Create(@WS, T.FontSize);
    try
      QApplication_setFont(F);
    finally
      QFont_Destroy(F);
    end;
  end;
{$ELSE}
begin
  SetIconDark(T.Dark and not ASystem);
{$ENDIF}
end;

function CurrentTheme: TaTheme;
begin
  Result := Cur;
end;

var
  { boje koje je tema upisala u kontrole; kad se tema promijeni, prepoznaju se kao "nase" i mijenjaju }
  DkBg, DkInput, DkFg, DkHead, DkLine, DkSel: TColor;
  Applied: array of TColor;

procedure RememberApplied;
  procedure Add(C: TColor);
  var
    I: Integer;
  begin
    for I := 0 to High(Applied) do if Applied[I] = C then Exit;
    SetLength(Applied, Length(Applied) + 1);
    Applied[High(Applied)] := C;
  end;
begin
  Add(DkBg); Add(DkInput); Add(DkFg); Add(DkHead); Add(DkLine); Add(DkSel);
end;

procedure LoadDarkColors(const T: TaThemeTokens);
begin
  DkBg := TokenColor(T.Bg);
  DkInput := TokenColor(T.Surface);
  DkFg := TokenColor(T.Text);
  DkHead := TokenColor(T.Header);
  DkLine := TokenColor(T.Border);
  DkSel := TokenColor(T.AccentSoft);
  RememberApplied;
end;

function IsStd(C: TColor): Boolean;
begin
  Result := (C = clDefault) or (C = clWindow) or (C = clBtnFace) or (C = clForm) or (C = clNone) or
    (C = clWindowText) or (C = clBtnText) or (C = clBlack) or (C = clWhite) or (C = clMenu);
end;

{ vraca standardnu boju kad je kontrola bila prebojana u tamnu }
function Back(C: TColor; AStd: TColor): TColor;
var
  I: Integer;
begin
  Result := C;
  for I := 0 to High(Applied) do
    if C = Applied[I] then begin Result := AStd; Exit; end;
end;

function GridSelColor: TColor;
begin
  if Cur = thSystem then Result := clHighlight else Result := TokenColor(CurrentTokens.AccentSoft);
end;

function GridFocusColor: TColor;
begin
  if Cur = thSystem then Result := clRed else Result := TokenColor(CurrentTokens.Accent);
end;

procedure Walk(AParent: TWinControl; ADark: Boolean);
var
  I: Integer;
  C: TControl;
  procedure Fill(var AColor: TColor; ADk, AStd: TColor);
  begin
    if ADark then begin if IsStd(AColor) or (Back(AColor, clNone) = clNone) then AColor := ADk; end
    else AColor := Back(AColor, AStd);
  end;
  procedure Ink(AFont: TFont);
  var
    K: TColor;
  begin
    K := AFont.Color;
    if ADark then begin if IsStd(K) or (Back(K, clNone) = clNone) then AFont.Color := DkFg; end
    else AFont.Color := Back(K, clWindowText);
  end;
var
  Cl: TColor;
begin
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if (C is TCustomGrid) then
    begin
      Cl := TCustomGrid(C).Color; Fill(Cl, DkInput, clWindow); TCustomGrid(C).Color := Cl;
      if C is TStringGrid then
      begin
        Cl := TStringGrid(C).FixedColor; Fill(Cl, DkHead, clBtnFace); TStringGrid(C).FixedColor := Cl;
        Cl := TStringGrid(C).GridLineColor; if ADark and (Cl = clSilver) then Cl := clNone; Fill(Cl, DkLine, clSilver); if Cl = clNone then Cl := DkLine; TStringGrid(C).GridLineColor := Cl;
      end
      else if C is TDBGrid then
      begin
        Cl := TDBGrid(C).FixedColor; Fill(Cl, DkHead, clBtnFace); TDBGrid(C).FixedColor := Cl;
        Cl := TDBGrid(C).GridLineColor; if ADark and (Cl = clSilver) then Cl := clNone; Fill(Cl, DkLine, clSilver); if Cl = clNone then Cl := DkLine; TDBGrid(C).GridLineColor := Cl;
        Ink(TDBGrid(C).TitleFont);
      end;
      Ink(TCustomGrid(C).Font);
      { oznaka celije: naglasak teme (u sustavnom izgledu zadane boje) }
      if C is TStringGrid then
      begin
        TStringGrid(C).SelectedColor := GridSelColor; TStringGrid(C).FocusColor := GridFocusColor;
      end
      else if C is TDBGrid then
      begin
        TDBGrid(C).SelectedColor := GridSelColor; TDBGrid(C).FocusColor := GridFocusColor;
      end;
    end
    else if C is TCustomEditButton then
    begin
      { polje s gumbom (datum, izbor datoteke): boje polja; ikona gumba ostaje zadana (promjena ikone zamrzavala je galeriju) }
      Cl := C.Color; Fill(Cl, DkInput, clWindow); C.Color := Cl;
      Ink(C.Font);
    end
    else if (C is TCustomEdit) or (C is TCustomListBox) or (C is TCustomComboBox) or (C is TCustomListView) or (C is TCustomTreeView) then
    begin
      Cl := C.Color; Fill(Cl, DkInput, clWindow); C.Color := Cl;
      Ink(C.Font);
    end
    else if (C is TCustomPanel) or (C is TTabSheet) or (C is TCustomGroupBox) or (C is TScrollBox) or
            (C is TCustomRadioGroup) or (C is TCustomCheckGroup) then
    begin
      Cl := C.Color; Fill(Cl, DkBg, clBtnFace); C.Color := Cl;
      Ink(C.Font);
    end
    else if C is TSplitter then
    begin
      Cl := C.Color; Fill(Cl, DkLine, clBtnFace); C.Color := Cl;
    end
    else if (C is TCustomLabel) or (C is TCustomCheckBox) or (C is TRadioButton) then
    begin
      if C is TCustomLabel then
      begin
        { zaglavlje popisa u glavnom prozoru ima vlastitu svijetlu pozadinu }
        if ADark and (C.Color = $F5F0EA) then C.Color := DkHead
        else if (not ADark) and (Back(C.Color, clNone) = clNone) then C.Color := $F5F0EA;
      end;
      Ink(C.Font);
    end;
    if C is TWinControl then Walk(TWinControl(C), ADark);
  end;
end;

procedure RecolorForm(AForm: TObject);
var
  F: TCustomForm;
  Cl: TColor;
  Dk: Boolean;
begin
  if not (AForm is TCustomForm) then Exit;
  F := TCustomForm(AForm);
  Dk := (Cur = thModernDark) or ((Cur <> thSystem) and CurrentTokens.Dark);
  Cl := F.Color;
  if Dk then begin if IsStd(Cl) or (Back(Cl, clNone) = clNone) then Cl := DkBg; end else Cl := Back(Cl, clBtnFace);
  F.Color := Cl;
  Walk(F, Dk);
  F.Invalidate;
end;

type
  TThemeHook = class
    procedure FormAdded(Sender: TObject; Form: TCustomForm);
    procedure FirstShow(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  end;

var
  Hook: TThemeHook;

procedure TThemeHook.FormAdded(Sender: TObject; Form: TCustomForm);
begin
  Form.AddHandlerFirstShow(@FirstShow);
end;

{ Okvir prozora: moderna tema nema vidljiv rub pa se modalni i skocni prozori ne razlikuju od forme ispod njih.
  Okvir od dva piksela crta se unutar prozora (BorderWidth ostavlja mjesto poravnatim kontrolama); modalni dobiva naglasak. }
procedure TThemeHook.FormPaint(Sender: TObject);
var
  F: TCustomForm;
  T: TaThemeTokens;
  W, H: Integer;
begin
  F := TCustomForm(Sender);
  T := CurrentTokens;
  W := F.ClientWidth;
  H := F.ClientHeight;
  F.Canvas.Brush.Style := bsClear;
  F.Canvas.Pen.Style := psSolid;
  F.Canvas.Pen.Width := 1;
  F.Canvas.Pen.Color := TokenColor(MixHex(T.Border, T.Text, 0.45));
  F.Canvas.Rectangle(0, 0, W, H);
  if fsModal in F.FormState then F.Canvas.Pen.Color := TokenColor(T.Accent)
  else F.Canvas.Pen.Color := TokenColor(T.Border);
  F.Canvas.Rectangle(1, 1, W - 1, H - 1);
end;

procedure TThemeHook.FirstShow(Sender: TObject);
begin
  RecolorForm(Sender);
  if WindowFrames and (Sender is TForm) and (TForm(Sender).Parent = nil) and (Sender <> Application.MainForm) and
     (TForm(Sender).BorderStyle <> bsNone) and not Assigned(TForm(Sender).OnPaint) then
  begin
    if TForm(Sender).BorderWidth < 2 then TForm(Sender).BorderWidth := 2;
    TForm(Sender).OnPaint := @FormPaint;
    TForm(Sender).Invalidate;
  end;
end;

procedure RecolorAll;
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do RecolorForm(Screen.Forms[I]);
end;

procedure InstallHook;
var
  I: Integer;
begin
  if Hook <> nil then Exit;
  Hook := TThemeHook.Create;
  Screen.AddHandlerFormAdded(@Hook.FormAdded);
  for I := 0 to Screen.FormCount - 1 do Screen.Forms[I].AddHandlerFirstShow(@Hook.FirstShow);
end;


procedure ApplyTokens(const T: TaThemeTokens; ASystem: Boolean);
begin
  CurTok := T;
  CurTokSet := True;
  LoadDarkColors(T);
  Apply(T, ASystem);
  SetActiveTokens(T);
  RecolorAll;
end;

procedure SaveChoice(const APalette, AFile: string; ATheme: TaTheme);
var
  F: TIniFile;
begin
  try
    ForceDirectories(ExtractFilePath(ConfigFile));
    F := TIniFile.Create(ConfigFile);
    try
      F.WriteInteger('izgled', 'tema', Ord(ATheme));
      F.WriteString('izgled', 'paleta', APalette);
      F.WriteString('izgled', 'datoteka', AFile);
      F.WriteString('izgled', 'oblik', ShapeNames[CurrentTokens.Shape]);
    finally
      F.Free;
    end;
  except
  end;
end;

procedure SetTheme(ATheme: TaTheme; ASave: Boolean = True);
begin
  Cur := ATheme;
  if ATheme = thSystem then ApplyTokens(TokensForTheme(thModern), True)
  else ApplyTokens(TokensForTheme(ATheme), False);
  if ASave then SaveChoice('Plava', '', ATheme);
end;

procedure SetThemeTokens(const T: TaThemeTokens; ASave: Boolean = True);
begin
  if T.Dark then Cur := thModernDark else Cur := thModern;
  ApplyTokens(T, False);
  if ASave then SaveChoice(T.Name, '', Cur);
end;

procedure SetBuiltinTheme(AIndex: Integer; ADark: Boolean; AShape: TaShape; ASave: Boolean = True);
begin
  SetThemeTokens(BuiltinTokens(AIndex, ADark, AShape), ASave);
end;

function LoadThemeFromFile(const AFile: string; out AWarn: string; ASave: Boolean = True): Boolean;
var
  T: TaThemeTokens;
begin
  Result := LoadThemeFile(AFile, T, AWarn);
  if not Result then Exit;
  if T.Dark then Cur := thModernDark else Cur := thModern;
  ApplyTokens(T, False);
  if ASave then SaveChoice(T.Name, AFile, Cur);
end;

function UserChoseTheme: Boolean;
var
  F: TIniFile;
begin
  Result := False;
  try
    if FileExists(ConfigFile) then
    begin
      F := TIniFile.Create(ConfigFile);
      try
        Result := F.ReadString('izgled', 'paleta', '') <> '';
      finally
        F.Free;
      end;
    end;
  except
  end;
end;

function SaveThemeToApp(ADb: TAppDb): Boolean;
begin
  Result := ADb.SaveSetting('tema.json', TokensToJson(CurrentTokens));
end;

function ClearAppTheme(ADb: TAppDb): Boolean;
begin
  Result := ADb.SaveSetting('tema.json', '');
end;

function ApplyThemeFromApp(ADb: TAppDb; AForce: Boolean = False): Boolean;
var
  J, W: string;
  T: TaThemeTokens;
begin
  Result := False;
  J := ADb.LoadSetting('tema.json');
  if J = '' then Exit;
  if (not AForce) and UserChoseTheme then Exit;
  if not TokensFromJson(J, T, W) then Exit;
  SetThemeTokens(T, False);
  Result := True;
end;

procedure ApplySavedTheme;
var
  F: TIniFile;
  Pal, Fl, Obl, Warn: string;
  Sh: TaShape;
  I, Idx: Integer;
  T: TaThemeTokens;
  Done: Boolean;
begin
  Cur := thModern;
  Pal := ''; Fl := ''; Obl := 'rounded';
  try
    if FileExists(ConfigFile) then
    begin
      F := TIniFile.Create(ConfigFile);
      try
        Cur := TaTheme(F.ReadInteger('izgled', 'tema', Ord(thModern)));
        Pal := F.ReadString('izgled', 'paleta', '');
        Fl := F.ReadString('izgled', 'datoteka', '');
        Obl := F.ReadString('izgled', 'oblik', 'rounded');
      finally
        F.Free;
      end;
    end;
  except
    Cur := thModern;
  end;
  Loaded := True;
  Sh := shRounded;
  for I := Ord(Low(TaShape)) to Ord(High(TaShape)) do
    if SameText(ShapeNames[TaShape(I)], Obl) then Sh := TaShape(I);
  CurTok := BuiltinTokens(0, False, Sh);
  CurTokSet := True;
  Done := False;
  if (Fl <> '') and LoadThemeFile(Fl, T, Warn) then
  begin
    if T.Dark then Cur := thModernDark else Cur := thModern;
    ApplyTokens(T, False);
    Done := True;
  end
  else if Cur <> thSystem then
  begin
    Idx := BuiltinThemeIndex(Pal);
    if Idx >= 0 then
    begin
      T := BuiltinTokens(Idx, Cur = thModernDark, Sh);
      ApplyTokens(T, False);
      Done := True;
    end;
  end;
  if not Done then
  begin
    if Cur = thSystem then ApplyTokens(TokensForTheme(thModern), True)
    else ApplyTokens(TokensForTheme(Cur), False);
  end;
  InstallHook;
end;

end.
