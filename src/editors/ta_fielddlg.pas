unit ta_fielddlg;
{ Dialogs for field properties and for designing a new table. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ZDataset, ta_types, ta_meta, ta_catalogdlg, ta_i18n, ta_i18n_hr, StrUtils;

{ Edits one field. AMeta carries type/format/default/decimals and is updated
  in place; AName, APk and ANotNull are in/out. }
function EditField(AOwner: TComponent; ADb: TAppDb; var AName: string; AMeta: TaFieldMeta;
  var APk, ANotNull: Boolean; var ARefTable, ARefField, AOnDelete: string;
  AAllowName: Boolean): Boolean;

{ Designs a whole new table. Metas of the returned fields are owned by the caller. }
function DesignTableDialog(AOwner: TComponent; ADb: TAppDb; out AName: string;
  out AFields: TFieldDefs2): Boolean;

implementation

type
  TFieldDlgHelper = class
  public
    TypeBox: TComboBox;
    FormatBox: TComboBox;
    DecEdit: TEdit;
    DefEdit, CapEdit, DescEdit, WidthEdit, ValEdit, ValMsgEdit: TEdit;
    RefBox, RefFieldBox, DelBox: TComboBox;
    ReqBox, RoBox: TCheckBox;
    AlignBox, VariantBox: TComboBox;
    RowSrcEdit, LovEdit, LovMapEdit, AutoValEdit, MaskEdit, EvtEdit: TEdit;
    AutoBox: TComboBox;
    YearBox: TCheckBox;
    Db: TAppDb;
    PrevType: TaLogicalType;
    procedure TypeChanged(Sender: TObject);
    procedure RefChanged(Sender: TObject);
    procedure FillPresets;
  end;

procedure TFieldDlgHelper.FillPresets;
var
  T: TaLogicalType;
begin
  T := LogicalFromName(TypeBox.Text);
  FormatBox.Items.Clear;
  case T of
    ltDate: FormatBox.Items.CommaText := '"dd.mm.yyyy","yyyy-mm-dd","dd/mm/yyyy","d. mmmm yyyy"';
    ltTime: FormatBox.Items.CommaText := '"hh:nn","hh:nn:ss"';
    ltDateTime: FormatBox.Items.CommaText := '"dd.mm.yyyy hh:nn","dd.mm.yyyy hh:nn:ss","yyyy-mm-dd hh:nn"';
    ltDecimal: FormatBox.Items.CommaText := '"0.00","0.000","#,##0.00","0.0"';
    ltCurrency: FormatBox.Items.CommaText := '"#,##0.00 ""€""","#,##0.00 ""kn""","""$""#,##0.00"';
    ltInteger: FormatBox.Items.CommaText := '"","#,##0"';
  end;
end;

procedure TFieldDlgHelper.RefChanged(Sender: TObject);
var
  Q: TZQuery;
  Pk: string;
begin
  RefFieldBox.Items.Clear;
  if (RefBox.Text = '') or (Db = nil) then begin RefFieldBox.Text := ''; Exit; end;
  Q := Db.TableInfo(RefBox.Text);
  try
    while not Q.EOF do
    begin
      RefFieldBox.Items.Add(Q.FieldByName('name').AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Pk := Db.PrimaryKeyOf(RefBox.Text);
  if Pk <> '' then RefFieldBox.Text := Pk
  else if RefFieldBox.Items.Count > 0 then RefFieldBox.Text := RefFieldBox.Items[0];
end;

procedure TFieldDlgHelper.TypeChanged(Sender: TObject);
var
  T: TaLogicalType;
  Dec: Integer;
begin
  T := LogicalFromName(TypeBox.Text);
  Dec := StrToIntDef(DecEdit.Text, 2);
  if (FormatBox.Text = '') or (FormatBox.Text = DefaultFormat(PrevType, Dec)) then
  begin
    if T in [ltDecimal, ltCurrency] then Dec := 2 else Dec := 0;
    DecEdit.Text := IntToStr(Dec);
    FormatBox.Text := DefaultFormat(T, Dec);
  end;
  if DefEdit.Text = '' then
    case T of
      ltDate: DefEdit.TextHint := Tr('e.g. Today()');
      ltDateTime: DefEdit.TextHint := Tr('e.g. Now()');
      ltTime: DefEdit.TextHint := Tr('e.g. Time()');
      ltYesNo: DefEdit.TextHint := Tr('e.g. 1');
      ltDecimal, ltCurrency, ltInteger: DefEdit.TextHint := Tr('e.g. 0');
    else DefEdit.TextHint := Tr('e.g. ''''text''''');
    end;
  PrevType := T;
  FillPresets;
end;

function EditField(AOwner: TComponent; ADb: TAppDb; var AName: string; AMeta: TaFieldMeta;
  var APk, ANotNull: Boolean; var ARefTable, ARefField, AOnDelete: string;
  AAllowName: Boolean): Boolean;
var
  Tl, EvList: TStringList;
  K: Integer;
  F: TForm;
  H: TFieldDlgHelper;
  NameEdit: TEdit;
  PkBox, NnBox: TCheckBox;
  T: TaLogicalType;
  Y: Integer;

  procedure Lbl(const ACap: string);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := ACap;
    L.SetBounds(12, Y + 4, 110, 18);
  end;

begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  H := TFieldDlgHelper.Create;
  try
    F.Caption := Tr('Field properties');
    F.SetBounds(0, 0, 460, 952);
    F.Position := poOwnerFormCenter;
    Y := 12;
    Lbl(Tr('Name:'));
    NameEdit := TEdit.Create(F); NameEdit.Parent := F; NameEdit.SetBounds(130, Y, 310, 26);
    NameEdit.Text := AName; NameEdit.Enabled := AAllowName;
    Inc(Y, 36);
    Lbl(Tr('Type:'));
    H.TypeBox := TComboBox.Create(F); H.TypeBox.Parent := F; H.TypeBox.SetBounds(130, Y, 200, 26);
    H.TypeBox.Style := csDropDownList;
    for T := Low(T) to High(T) do H.TypeBox.Items.Add(LogicalNames[T]);
    H.TypeBox.ItemIndex := Ord(AMeta.LType);
    Inc(Y, 36);
    Lbl(Tr('Decimals:'));
    H.DecEdit := TEdit.Create(F); H.DecEdit.Parent := F; H.DecEdit.SetBounds(130, Y, 60, 26);
    H.DecEdit.Text := IntToStr(AMeta.Decimals);
    Inc(Y, 36);
    Lbl(Tr('Format:'));
    H.FormatBox := TComboBox.Create(F); H.FormatBox.Parent := F; H.FormatBox.SetBounds(130, Y, 310, 26);
    H.FormatBox.Text := AMeta.Format;
    Inc(Y, 36);
    Lbl(Tr('Default value:'));
    H.DefEdit := TEdit.Create(F); H.DefEdit.Parent := F; H.DefEdit.SetBounds(130, Y, 310, 26);
    H.DefEdit.Text := AMeta.DefaultExpr;
    Inc(Y, 36);
    Lbl(Tr('Label in forms:'));
    H.CapEdit := TEdit.Create(F); H.CapEdit.Parent := F; H.CapEdit.SetBounds(130, Y, 310, 26);
    H.CapEdit.Text := AMeta.Caption;
    H.CapEdit.TextHint := Tr('empty = field name');
    Inc(Y, 36);
    Lbl(Tr('Description (hint):'));
    H.DescEdit := TEdit.Create(F); H.DescEdit.Parent := F; H.DescEdit.SetBounds(130, Y, 310, 26);
    H.DescEdit.Text := AMeta.Description;
    Inc(Y, 36);
    Lbl(Tr('Input check:'));
    H.ValEdit := TEdit.Create(F); H.ValEdit.Parent := F; H.ValEdit.SetBounds(130, Y, 310, 26);
    H.ValEdit.Text := AMeta.Validation;
    H.ValEdit.TextHint := Tr('expression, e.g. [value] > 0');
    Inc(Y, 36);
    Lbl(Tr('Error message:'));
    H.ValMsgEdit := TEdit.Create(F); H.ValMsgEdit.Parent := F; H.ValMsgEdit.SetBounds(130, Y, 310, 26);
    H.ValMsgEdit.Text := AMeta.ValidationMsg;
    H.ValMsgEdit.TextHint := Tr('shown when the input fails the check');
    Inc(Y, 36);
    Lbl(Tr('Width in grid:'));
    H.WidthEdit := TEdit.Create(F); H.WidthEdit.Parent := F; H.WidthEdit.SetBounds(130, Y, 80, 26);
    if AMeta.ColWidth > 0 then H.WidthEdit.Text := IntToStr(AMeta.ColWidth);
    H.WidthEdit.TextHint := Tr('auto');
    Inc(Y, 36);
    PkBox := TCheckBox.Create(F); PkBox.Parent := F; PkBox.Caption := Tr('Primary key');
    PkBox.SetBounds(130, Y, 150, 22); PkBox.Checked := APk; PkBox.Enabled := AAllowName;
    NnBox := TCheckBox.Create(F); NnBox.Parent := F; NnBox.Caption := Tr('Required (NOT NULL)');
    NnBox.SetBounds(290, Y, 160, 22); NnBox.Checked := ANotNull; NnBox.Enabled := AAllowName;
    Inc(Y, 36);
    H.Db := ADb;
    { rjecnik podataka: svaka forma koja koristi polje nasljeduje ove postavke }
    H.ReqBox := TCheckBox.Create(F); H.ReqBox.Parent := F; H.ReqBox.Caption := Tr('Required');
    H.ReqBox.SetBounds(130, Y, 150, 22); H.ReqBox.Checked := AMeta.GetX('required') = '1';
    H.RoBox := TCheckBox.Create(F); H.RoBox.Parent := F; H.RoBox.Caption := Tr('Read only');
    H.RoBox.SetBounds(290, Y, 150, 22); H.RoBox.Checked := AMeta.GetX('readonly') = '1';
    Inc(Y, 36);
    Lbl(Tr('Alignment') + ':');
    H.AlignBox := TComboBox.Create(F); H.AlignBox.Parent := F; H.AlignBox.SetBounds(130, Y, 100, 26);
    H.AlignBox.Style := csDropDownList;
    H.AlignBox.Items.CommaText := ',left,center,right';
    H.AlignBox.ItemIndex := H.AlignBox.Items.IndexOf(AMeta.GetX('align'));
    if H.AlignBox.ItemIndex < 0 then H.AlignBox.ItemIndex := 0;
    H.VariantBox := TComboBox.Create(F); H.VariantBox.Parent := F; H.VariantBox.SetBounds(240, Y, 200, 26);
    H.VariantBox.Items.CommaText := ',combo,droplist,spin,date,currency,password,lov,switch,radio,tristate,segmented';
    H.VariantBox.Text := AMeta.GetX('variant');
    H.VariantBox.TextHint := Tr('Control type');
    Inc(Y, 36);
    Lbl(Tr('Input mask') + ':');
    H.MaskEdit := TEdit.Create(F); H.MaskEdit.Parent := F; H.MaskEdit.SetBounds(130, Y, 310, 26);
    H.MaskEdit.Text := AMeta.GetX('mask');
    H.MaskEdit.TextHint := '99999999999  |  HR99 9999 9999 9999 9999 9  |  99/99/9999';
    Inc(Y, 36);
    Lbl(Tr('Field events') + ':');
    H.EvtEdit := TEdit.Create(F); H.EvtEdit.Parent := F; H.EvtEdit.SetBounds(130, Y, 310, 26);
    H.EvtEdit.Text := Trim(StringReplace(
      IfThen(AMeta.GetX('onEnter') <> '', 'onEnter=' + AMeta.GetX('onEnter') + ';', '') +
      IfThen(AMeta.GetX('onExit') <> '', 'onExit=' + AMeta.GetX('onExit') + ';', '') +
      IfThen(AMeta.GetX('onValidate') <> '', 'onValidate=' + AMeta.GetX('onValidate') + ';', '') +
      IfThen(AMeta.GetX('onKey') <> '', 'onKey=' + AMeta.GetX('onKey') + ';', ''), ';;', ';', [rfReplaceAll]));
    H.EvtEdit.TextHint := 'onValidate=RejectNegative;onExit=Format';
    Inc(Y, 36);
    Lbl(Tr('List of values') + ':');
    H.RowSrcEdit := TEdit.Create(F); H.RowSrcEdit.Parent := F; H.RowSrcEdit.SetBounds(130, Y, 310, 26);
    H.RowSrcEdit.Text := AMeta.GetX('rowsource');
    H.RowSrcEdit.TextHint := 'list:A;B  |  sql:SELECT id, name FROM t';
    Inc(Y, 36);
    Lbl(Tr('Lookup source') + ':');
    H.LovEdit := TEdit.Create(F); H.LovEdit.Parent := F; H.LovEdit.SetBounds(130, Y, 310, 26);
    H.LovEdit.Text := AMeta.GetX('lov');
    Inc(Y, 36);
    Lbl(Tr('Lookup map') + ':');
    H.LovMapEdit := TEdit.Create(F); H.LovMapEdit.Parent := F; H.LovMapEdit.SetBounds(130, Y, 310, 26);
    H.LovMapEdit.Text := AMeta.GetX('lovmap');
    Inc(Y, 36);
    Lbl(Tr('Auto-enter') + ':');
    H.AutoBox := TComboBox.Create(F); H.AutoBox.Parent := F; H.AutoBox.SetBounds(130, Y, 120, 26);
    H.AutoBox.Style := csDropDownList;
    H.AutoBox.Items.CommaText := ',serial,created,modified,user,expr,const,copy';
    H.AutoBox.ItemIndex := H.AutoBox.Items.IndexOf(AMeta.GetX('autoenter'));
    if H.AutoBox.ItemIndex < 0 then H.AutoBox.ItemIndex := 0;
    H.YearBox := TCheckBox.Create(F); H.YearBox.Parent := F; H.YearBox.Caption := Tr('Restart yearly');
    H.YearBox.SetBounds(260, Y, 180, 22); H.YearBox.Checked := AMeta.GetX('serialyear') = '1';
    Inc(Y, 36);
    Lbl(Tr('Template / value') + ':');
    H.AutoValEdit := TEdit.Create(F); H.AutoValEdit.Parent := F; H.AutoValEdit.SetBounds(130, Y, 310, 26);
    if AMeta.GetX('autoenter') = 'serial' then H.AutoValEdit.Text := AMeta.GetX('serial')
    else if AMeta.GetX('autoenter') = 'expr' then H.AutoValEdit.Text := AMeta.GetX('autoexpr')
    else if AMeta.GetX('autoenter') = 'copy' then H.AutoValEdit.Text := AMeta.GetX('autocopy') + ' < ' + AMeta.GetX('autocopykey')
    else H.AutoValEdit.Text := AMeta.GetX('autoconst');
    H.AutoValEdit.TextHint := '{seq}/{pp}/{nu}  |  {nu}{seq:6}  |  Today()  |  kupci.adresa < kupac_id';
    Inc(Y, 36);
    Lbl(Tr('Link to table:'));
    H.RefBox := TComboBox.Create(F); H.RefBox.Parent := F; H.RefBox.SetBounds(130, Y, 310, 26);
    H.RefBox.Style := csDropDownList;
    H.RefBox.Items.Add('');
    if ADb <> nil then
    begin
      Tl := ADb.UserTables;
      try
        for K := 0 to Tl.Count - 1 do H.RefBox.Items.Add(Tl[K]);
      finally
        Tl.Free;
      end;
    end;
    H.RefBox.ItemIndex := H.RefBox.Items.IndexOf(ARefTable);
    if H.RefBox.ItemIndex < 0 then H.RefBox.ItemIndex := 0;
    H.RefBox.Enabled := ADb <> nil;
    Inc(Y, 36);
    Lbl(Tr('Field:'));
    H.RefFieldBox := TComboBox.Create(F); H.RefFieldBox.Parent := F; H.RefFieldBox.SetBounds(130, Y, 310, 26);
    H.RefFieldBox.Style := csDropDownList;
    H.RefBox.OnChange := @H.RefChanged;
    H.RefChanged(nil);
    if ARefField <> '' then H.RefFieldBox.ItemIndex := H.RefFieldBox.Items.IndexOf(ARefField);
    Inc(Y, 36);
    Lbl(Tr('On delete:'));
    H.DelBox := TComboBox.Create(F); H.DelBox.Parent := F; H.DelBox.SetBounds(130, Y, 310, 26);
    H.DelBox.Style := csDropDownList;
    H.DelBox.Items.CommaText := 'NO ACTION,CASCADE,SET NULL,RESTRICT';
    H.DelBox.ItemIndex := H.DelBox.Items.IndexOf(AOnDelete);
    if H.DelBox.ItemIndex < 0 then H.DelBox.ItemIndex := 0;
    Inc(Y, 44);
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(250, Y, 90, 28); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(350, Y, 90, 28); end;
    H.PrevType := AMeta.LType;
    H.TypeBox.OnChange := @H.TypeChanged;
    H.FillPresets;
    if F.ShowModal <> mrOk then Exit;
    AName := Trim(NameEdit.Text);
    if AName = '' then Exit;
    AMeta.LType := LogicalFromName(H.TypeBox.Text);
    AMeta.Decimals := StrToIntDef(H.DecEdit.Text, 2);
    AMeta.Format := H.FormatBox.Text;
    AMeta.DefaultExpr := Trim(H.DefEdit.Text);
    AMeta.Caption := Trim(H.CapEdit.Text);
    AMeta.Description := Trim(H.DescEdit.Text);
    AMeta.Validation := Trim(H.ValEdit.Text);
    AMeta.ValidationMsg := Trim(H.ValMsgEdit.Text);
    AMeta.ColWidth := StrToIntDef(Trim(H.WidthEdit.Text), 0);
    if H.ReqBox.Checked then AMeta.SetX('required', '1') else AMeta.SetX('required', '');
    if H.RoBox.Checked then AMeta.SetX('readonly', '1') else AMeta.SetX('readonly', '');
    AMeta.SetX('align', H.AlignBox.Text);
    AMeta.SetX('variant', Trim(H.VariantBox.Text));
    AMeta.SetX('rowsource', Trim(H.RowSrcEdit.Text));
    AMeta.SetX('mask', Trim(H.MaskEdit.Text));
    AMeta.SetX('onEnter', ''); AMeta.SetX('onExit', ''); AMeta.SetX('onValidate', ''); AMeta.SetX('onKey', '');
    begin
      EvList := TStringList.Create;
      try
        EvList.Delimiter := ';';
        EvList.StrictDelimiter := True;
        EvList.DelimitedText := H.EvtEdit.Text;
        for K := 0 to EvList.Count - 1 do
          if Pos('=', EvList[K]) > 1 then AMeta.SetX(Trim(Copy(EvList[K], 1, Pos('=', EvList[K]) - 1)), Trim(Copy(EvList[K], Pos('=', EvList[K]) + 1, MaxInt)));
      finally
        EvList.Free;
      end;
    end;
    AMeta.SetX('lov', Trim(H.LovEdit.Text));
    AMeta.SetX('lovmap', Trim(H.LovMapEdit.Text));
    AMeta.SetX('autoenter', H.AutoBox.Text);
    AMeta.SetX('serial', ''); AMeta.SetX('autoexpr', ''); AMeta.SetX('autoconst', ''); AMeta.SetX('autocopy', ''); AMeta.SetX('autocopykey', '');
    if (H.AutoBox.Text = 'copy') and (Pos('<', H.AutoValEdit.Text) > 0) then
    begin
      AMeta.SetX('autocopy', Trim(Copy(H.AutoValEdit.Text, 1, Pos('<', H.AutoValEdit.Text) - 1)));
      AMeta.SetX('autocopykey', Trim(Copy(H.AutoValEdit.Text, Pos('<', H.AutoValEdit.Text) + 1, MaxInt)));
    end;
    if H.AutoBox.Text = 'serial' then AMeta.SetX('serial', Trim(H.AutoValEdit.Text))
    else if H.AutoBox.Text = 'expr' then AMeta.SetX('autoexpr', Trim(H.AutoValEdit.Text))
    else if H.AutoBox.Text = 'const' then AMeta.SetX('autoconst', Trim(H.AutoValEdit.Text));
    if (H.AutoBox.Text = 'serial') and H.YearBox.Checked then AMeta.SetX('serialyear', '1') else AMeta.SetX('serialyear', '');
    APk := PkBox.Checked or (AMeta.LType = ltAutoNumber);
    ANotNull := NnBox.Checked;
    ARefTable := H.RefBox.Text;
    if ARefTable = '' then ARefField := '' else ARefField := H.RefFieldBox.Text;
    AOnDelete := H.DelBox.Text;
    Result := True;
  finally
    H.Free;
    F.Free;
  end;
end;

type
  { Holds the state of the table design dialog. }
  TTableDlg = class
  public
    Form: TForm;
    List: TListBox;
    Names: TStringList;
    Specs: array of TFieldDef;
    Owner: TComponent;
    Db: TAppDb;
    NameEdit: TEdit;
    procedure Refresh;
    procedure CatFieldsClick(Sender: TObject);
    procedure CatTableClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
  end;

procedure TTableDlg.Refresh;
var
  I: Integer;
  S: string;
begin
  List.Items.Clear;
  for I := 0 to High(Specs) do
  begin
    S := Specs[I].Name + '   [' + LogicalNames[Specs[I].Meta.LType] + ']';
    if Specs[I].Meta.Format <> '' then S := S + '  ' + Specs[I].Meta.Format;
    if Specs[I].Meta.DefaultExpr <> '' then S := S + '  = ' + Specs[I].Meta.DefaultExpr;
    if Specs[I].RefTable <> '' then S := S + '  -> ' + Specs[I].RefTable;
    if Specs[I].PrimaryKey then S := S + '  PK';
    if Specs[I].NotNull then S := S + '  NOT NULL';
    List.Items.Add(S);
  end;
end;

procedure TTableDlg.CatFieldsClick(Sender: TObject);
var
  F: TFieldDefs2;
  I, J, L: Integer;
  Dup: Boolean;
begin
  if not PickCatalogFields(Form, F) then Exit;
  for I := 0 to High(F) do
  begin
    Dup := False;
    for J := 0 to High(Specs) do
      if SameText(Specs[J].Name, F[I].Name) then Dup := True;
    if Dup then begin F[I].Meta.Free; Continue; end;
    L := Length(Specs);
    SetLength(Specs, L + 1);
    Specs[L] := F[I];
  end;
  Refresh;
end;

procedure TTableDlg.CatTableClick(Sender: TObject);
var
  F: TFieldDefs2;
  N: string;
  I: Integer;
begin
  if not PickCatalogTable(Form, Db, N, F) then Exit;
  for I := 0 to High(Specs) do Specs[I].Meta.Free;
  SetLength(Specs, Length(F));
  for I := 0 to High(F) do Specs[I] := F[I];
  NameEdit.Text := N;
  Refresh;
end;

procedure TTableDlg.AddClick(Sender: TObject);
var
  M: TaFieldMeta;
  N: string;
  Pk, Nn: Boolean;
  L: Integer;
  RT, RF, RD: string;
begin
  M := TaFieldMeta.Create;
  N := '';
  Pk := False;
  Nn := False;
  RT := ''; RF := ''; RD := '';
  if EditField(Form, Db, N, M, Pk, Nn, RT, RF, RD, True) then
  begin
    L := Length(Specs);
    SetLength(Specs, L + 1);
    Specs[L].RefTable := RT;
    Specs[L].RefField := RF;
    Specs[L].OnDelete := RD;
    Specs[L].Name := N;
    Specs[L].Meta := M;
    Specs[L].PrimaryKey := Pk;
    Specs[L].NotNull := Nn;
    Specs[L].SqlType := PhysicalType(M.LType);
    Refresh;
  end
  else M.Free;
end;

procedure TTableDlg.EditClick(Sender: TObject);
var
  I: Integer;
  N: string;
  Pk, Nn: Boolean;
  RT, RF, RD: string;
begin
  I := List.ItemIndex;
  if I < 0 then Exit;
  N := Specs[I].Name;
  Pk := Specs[I].PrimaryKey;
  Nn := Specs[I].NotNull;
  RT := Specs[I].RefTable; RF := Specs[I].RefField; RD := Specs[I].OnDelete;
  if EditField(Form, Db, N, Specs[I].Meta, Pk, Nn, RT, RF, RD, True) then
  begin
    Specs[I].RefTable := RT;
    Specs[I].RefField := RF;
    Specs[I].OnDelete := RD;
    Specs[I].Name := N;
    Specs[I].PrimaryKey := Pk;
    Specs[I].NotNull := Nn;
    Specs[I].SqlType := PhysicalType(Specs[I].Meta.LType);
    Refresh;
    List.ItemIndex := I;
  end;
end;

procedure TTableDlg.DelClick(Sender: TObject);
var
  I, J: Integer;
begin
  I := List.ItemIndex;
  if I < 0 then Exit;
  Specs[I].Meta.Free;
  for J := I to High(Specs) - 1 do Specs[J] := Specs[J + 1];
  SetLength(Specs, Length(Specs) - 1);
  Refresh;
end;

procedure TTableDlg.UpClick(Sender: TObject);
var
  I: Integer;
  T: TFieldDef;
begin
  I := List.ItemIndex;
  if I < 1 then Exit;
  T := Specs[I]; Specs[I] := Specs[I - 1]; Specs[I - 1] := T;
  Refresh;
  List.ItemIndex := I - 1;
end;

procedure TTableDlg.DownClick(Sender: TObject);
var
  I: Integer;
  T: TFieldDef;
begin
  I := List.ItemIndex;
  if (I < 0) or (I >= High(Specs)) then Exit;
  T := Specs[I]; Specs[I] := Specs[I + 1]; Specs[I + 1] := T;
  Refresh;
  List.ItemIndex := I + 1;
end;

function DesignTableDialog(AOwner: TComponent; ADb: TAppDb; out AName: string;
  out AFields: TFieldDefs2): Boolean;
var
  D: TTableDlg;
  NameEdit: TEdit;
  Pn: TPanel;
  I: Integer;

  procedure Btn(const ACap: string; AX: Integer; AHandler: TNotifyEvent);
  var
    B: TButton;
  begin
    B := TButton.Create(D.Form);
    B.Parent := Pn;
    B.Caption := ACap;
    B.SetBounds(AX, 6, 86, 26);
    B.OnClick := AHandler;
  end;

begin
  Result := False;
  AName := '';
  SetLength(AFields, 0);
  D := TTableDlg.Create;
  D.Owner := AOwner;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('New table');
    D.Form.SetBounds(0, 0, 780, 460);
    D.Form.Position := poOwnerFormCenter;
    Pn := TPanel.Create(D.Form); Pn.Parent := D.Form; Pn.Align := alTop; Pn.Height := 38; Pn.BevelOuter := bvNone;
    with TLabel.Create(D.Form) do begin Parent := Pn; Caption := Tr('Name:'); SetBounds(8, 12, 50, 18); end;
    NameEdit := TEdit.Create(D.Form); NameEdit.Parent := Pn; NameEdit.SetBounds(62, 6, 300, 26);
    D.NameEdit := NameEdit;
    with TButton.Create(D.Form) do begin Parent := Pn; Caption := Tr('Field from the catalog'); SetBounds(360, 6, 190, 26); OnClick := @D.CatFieldsClick; end;
    with TButton.Create(D.Form) do begin Parent := Pn; Caption := Tr('Table from the catalog'); SetBounds(556, 6, 190, 26); OnClick := @D.CatTableClick; end;
    Pn := TPanel.Create(D.Form); Pn.Parent := D.Form; Pn.Align := alBottom; Pn.Height := 40; Pn.BevelOuter := bvNone;
    with TButton.Create(D.Form) do begin Parent := Pn; Caption := Tr('Create'); ModalResult := mrOk; SetBounds(500, 6, 90, 28); end;
    with TButton.Create(D.Form) do begin Parent := Pn; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(596, 6, 90, 28); end;
    Btn(Tr('Add'), 6, @D.AddClick);
    Btn(Tr('Edit'), 98, @D.EditClick);
    Btn(Tr('Delete'), 190, @D.DelClick);
    Btn(Tr('Up'), 282, @D.UpClick);
    Btn(Tr('Down'), 374, @D.DownClick);
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.Align := alClient;
    D.List.OnDblClick := @D.EditClick;
    { suggested first field }
    SetLength(D.Specs, 1);
    D.Specs[0].Name := 'id';
    D.Specs[0].Meta := TaFieldMeta.Create;
    D.Specs[0].Meta.LType := ltAutoNumber;
    D.Specs[0].Meta.Decimals := 0;
    D.Specs[0].PrimaryKey := True;
    D.Specs[0].SqlType := 'INTEGER';
    D.Refresh;
    if D.Form.ShowModal <> mrOk then
    begin
      for I := 0 to High(D.Specs) do D.Specs[I].Meta.Free;
      Exit;
    end;
    AName := Trim(NameEdit.Text);
    if (AName = '') or (Length(D.Specs) = 0) then
    begin
      for I := 0 to High(D.Specs) do D.Specs[I].Meta.Free;
      Exit;
    end;
    SetLength(AFields, Length(D.Specs));
    for I := 0 to High(D.Specs) do AFields[I] := D.Specs[I];
    Result := True;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
