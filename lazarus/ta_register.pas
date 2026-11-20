unit ta_register;
{ Registracija komponenti TyphAccess u paletu Lazarusa i CodeTyphona (stranica "TyphAccess").
  Uključuje desni klik (Component Editor) na TaDatabase za pokretanje pametnog čarobnjaka. }

{$mode objfpc}{$H+}

interface

procedure Register;

implementation

{$R ta_register.res}

uses
  Classes, SysUtils, StrUtils, Dialogs, ComponentEditors, PropEdits, ta_editdlg, ta_skelwizard, ta_blockdlg,
  ta_sidemenu, ta_components, ta_binder, ta_wizards, ta_wizardframework, ta_meta, ta_edit, ta_editor, ta_templates, ta_contcomp, ta_check, ta_button, ta_label, ta_memo, ta_choice, ta_list, ta_grid, ta_panel, ta_pages, ta_progress, ta_calendar, ta_image, ta_barcodebox, ta_chartbox, ta_menu;

type
  TTaDatabaseEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  { Uredjivaci svojstava (gumb ...): zovu iste funkcije sloja B kao dizajner (ta_editdlg) }
  TTaDialogPropEditor = class(TStringPropertyEditor)
  protected
    function MakeContext: TaEditContext;
    function DoEdit(ACtx: TaEditContext; var AValue: string): Boolean; virtual; abstract;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

  TTaRowSourceEditor = class(TTaDialogPropEditor)
  protected
    function DoEdit(ACtx: TaEditContext; var AValue: string): Boolean; override;
  end;

  TTaExprPropEditor = class(TTaDialogPropEditor)
  protected
    function DoEdit(ACtx: TaEditContext; var AValue: string): Boolean; override;
  end;

  TTaCondFormatEditor = class(TTaDialogPropEditor)
  protected
    function DoEdit(ACtx: TaEditContext; var AValue: string): Boolean; override;
  end;

  TTaFormatEditor = class(TTaDialogPropEditor)
  protected
    function DoEdit(ACtx: TaEditContext; var AValue: string): Boolean; override;
  end;

function TTaDatabaseEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

function TTaDatabaseEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Pokreni pametni čarobnjak (forme / izvješća / 4GL)...';
    1: Result := 'Novi 4GL program iz kostura...';
    2: Result := 'Predloži 4GL programe za tablicu...';
    3: Result := 'Nova forma nad tablicom (blok)...';
  else
    Result := '';
  end;
end;

procedure TTaDatabaseEditor.ExecuteVerb(Index: Integer);
var
  DbComp: TaDatabase;
  R: TaWizardResult;
  N: string;
begin
  if Index = 0 then
  begin
    if Component is TaDatabase then
    begin
      DbComp := TaDatabase(Component);
      R := RunSmartWizard(nil, DbComp.Db);
      if R.SavedName <> '' then
        ShowMessage('Čarobnjak je uspješno izradio objekt: ' + R.SavedName);
    end;
  end
  else if (Index = 3) and (Component is TaDatabase) then
  begin
    N := RunBlockWizard(nil, TaDatabase(Component).Db);
    if N <> '' then ShowMessage('Forma je spremljena: ' + N);
  end
  else if (Index in [1, 2]) and (Component is TaDatabase) then
  begin
    N := RunSkeletonWizard(nil, TaDatabase(Component).Db, IfThen(Index = 2, '*', ''));
    if N <> '' then ShowMessage('Program je spremljen: ' + N);
  end;
end;

function TTaDialogPropEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paRevertable];
end;

function TTaDialogPropEditor.MakeContext: TaEditContext;
var
  C: TPersistent;
  Own: TComponent;
  I: Integer;
  Db: TAppDb;
begin
  Db := nil;
  C := GetComponent(0);
  if C is TComponent then
  begin
    Own := TComponent(C).Owner;
    if Own <> nil then
      for I := 0 to Own.ComponentCount - 1 do
        if Own.Components[I] is TaDatabase then
        begin
          { u vrijeme dizajna baza se ne otvara sama; dijalozima treba otvorena, pa je otvori ovdje }
          if not TaDatabase(Own.Components[I]).Connected then
            try
              TaDatabase(Own.Components[I]).Open;
            except
              on E: Exception do ShowMessage('Baza se ne može otvoriti: ' + E.Message);
            end;
          if TaDatabase(Own.Components[I]).Connected then Db := TaDatabase(Own.Components[I]).Db;
        end;
  end;
  Result := TaEditContext.Create(Db, nil);
end;

procedure TTaDialogPropEditor.Edit;
var
  Ctx: TaEditContext;
  V: string;
begin
  Ctx := MakeContext;
  try
    if Ctx.Db = nil then begin ShowMessage('Na formu stavi TaDatabase s postavljenim FileName (bazom koja se može otvoriti).'); Exit; end;
    V := GetStrValue;
    if DoEdit(Ctx, V) then SetStrValue(V);
  finally
    Ctx.Free;
  end;
end;

function TTaRowSourceEditor.DoEdit(ACtx: TaEditContext; var AValue: string): Boolean;
begin
  Result := EditSource(ACtx, 'ComboBox', AValue);
end;

function TTaExprPropEditor.DoEdit(ACtx: TaEditContext; var AValue: string): Boolean;
begin
  Result := EditExpr(ACtx, AValue, GetName);
end;

function TTaCondFormatEditor.DoEdit(ACtx: TaEditContext; var AValue: string): Boolean;
begin
  Result := EditCondFormat(ACtx, AValue);
end;

function TTaFormatEditor.DoEdit(ACtx: TaEditContext; var AValue: string): Boolean;
var
  K: string;
  C: TPersistent;
begin
  K := 'broj';
  C := GetComponent(0);
  if C is TaEdit then
    case TaEdit(C).Variant of
      evDate: K := 'datum';
      evCurrency: K := 'iznos';
      evText, evPassword, evCombo, evDropList, evLov: K := 'tekst';
    end;
  Result := EditFormat(ACtx, AValue, K);
end;

procedure Register;
begin
  { jedna stranica palete: unos, prikaz, razmjestaj, logika, pa nevizualne }
  RegisterComponents('TyphAccess', [TaEdit, TaMemo, TaCheck, TaChoice, TaList, TaGrid, TaCalendar, TaContinuousForm,
    TaLabel, ta_image.TaImage, ta_chartbox.TaChart, ta_barcodebox.TaBarcode, TaProgress,
    TaButton, TaPanel, TaPages, TaMenu, TaEditor,
    TaSideMenu, TaDatabase, TaExpression, TaReport, TaProgram, TaFormBinder]);
  RegisterTemplates;
  RegisterComponentEditor(TaDatabase, TTaDatabaseEditor);
  RegisterPropertyEditor(TypeInfo(string), TaEdit, 'RowSource', TTaRowSourceEditor);
  RegisterPropertyEditor(TypeInfo(string), TaEdit, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaEdit, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaEdit, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaEdit, 'Format', TTaFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaButton, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaButton, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaButton, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaLabel, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaLabel, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaLabel, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaMemo, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaMemo, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaMemo, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaChoice, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaChoice, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaChoice, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaList, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaList, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaList, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), TaGrid, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaGrid, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaPanel, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaPanel, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaPages, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaPages, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaGrid, 'CondFormat', TTaCondFormatEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_image.TaImage, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_image.TaImage, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_chartbox.TaChart, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_chartbox.TaChart, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_barcodebox.TaBarcode, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), ta_barcodebox.TaBarcode, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaProgress, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaProgress, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaCalendar, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaCalendar, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaMenu, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaMenu, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaCheck, 'VisibleIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaCheck, 'EnabledIf', TTaExprPropEditor);
  RegisterPropertyEditor(TypeInfo(string), TaCheck, 'CondFormat', TTaCondFormatEditor);
end;

end.
