unit ta_calcdlg;
{ Calculated field wizard: pick a template, fill its parameters from dropdowns,
  see the expression, the SQL it becomes and the first values it produces. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics, DB, ZDataset,
  ta_meta, ta_types, ta_expr, ta_exprsql, ta_qbe, ta_calcgen, ta_wizardgen, ta_exprbuilder;

{ ATables: the tables/queries the fields come from. InQuery restricts the
  templates to the ones that can run inside a query. Returns the new column's
  name and its expression (fields written [name] or [table.name]). }
function RunCalcWizard(AOwner: TComponent; ADb: TAppDb; ATables: TStrings; AInQuery: Boolean;
  out AAlias, AExpr: string): Boolean;

implementation

uses
  ta_i18n;


type
  TFieldChoice = record
    Display, Value: string;
    LType: TaLogicalType;
  end;

  TCalcDlg = class
  public
    Db: TAppDb;
    Tables: TStrings;
    InQuery: Boolean;
    Form: TForm;
    Cats, Tpls: TListBox;
    ParamPanel: TPanel;
    AliasEdit: TEdit;
    ExprMemo: TMemo;
    SqlLbl, Status: TLabel;
    Preview: TListBox;
    Templates: TaCalcTemplates;
    Shown: array of Integer;       { template index per row of Tpls }
    Choices: array of TFieldChoice;
    ParamCtl: array of TControl;
    Updating, Manual: Boolean;
    procedure LoadChoices;
    procedure CatChange(Sender: TObject);
    procedure TplChange(Sender: TObject);
    procedure ParamChange(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure BuilderClick(Sender: TObject);
    procedure Rebuild;
    procedure UpdatePreview;
    function Current: Integer;
  end;

procedure TCalcDlg.LoadChoices;
var
  I, J: Integer;
  L: TaSourceFields;
  Q: string;
begin
  SetLength(Choices, 0);
  for I := 0 to Tables.Count - 1 do
  begin
    try
      L := SourceFieldList(Db, Tables[I]);
    except
      Continue;
    end;
    for J := 0 to High(L) do
    begin
      SetLength(Choices, Length(Choices) + 1);
      if Tables.Count > 1 then Q := Tables[I] + '.' + L[J].Name else Q := L[J].Name;
      Choices[High(Choices)].Display := Q;
      Choices[High(Choices)].Value := Q;
      Choices[High(Choices)].LType := L[J].LType;
    end;
  end;
end;

function TCalcDlg.Current: Integer;
begin
  Result := -1;
  if (Tpls.ItemIndex >= 0) and (Tpls.ItemIndex < Length(Shown)) then Result := Shown[Tpls.ItemIndex];
end;

procedure TCalcDlg.CatChange(Sender: TObject);
var
  I: Integer;
  Cat: string;
begin
  Tpls.Items.Clear;
  SetLength(Shown, 0);
  if Cats.ItemIndex < 0 then Exit;
  Cat := Cats.Items[Cats.ItemIndex];
  for I := 0 to High(Templates) do
  begin
    if Templates[I].Category <> Cat then Continue;
    if InQuery and not CalcWorksInQuery(Templates[I]) then Continue;
    Tpls.Items.Add(Templates[I].Title);
    SetLength(Shown, Length(Shown) + 1);
    Shown[High(Shown)] := I;
  end;
  if Tpls.Items.Count > 0 then
  begin
    Tpls.ItemIndex := 0;
    TplChange(nil);
  end;
end;

procedure TCalcDlg.TplChange(Sender: TObject);
var
  T: TaCalcTemplate;
  I, J, Y: Integer;
  Cb: TComboBox;
  Ed: TEdit;
  Ok: Boolean;
  Opts: TStringList;
begin
  { rebuild the parameter editors }
  for I := ParamPanel.ControlCount - 1 downto 0 do ParamPanel.Controls[I].Free;
  SetLength(ParamCtl, 0);
  if Current < 0 then Exit;
  T := Templates[Current];
  SetLength(ParamCtl, Length(T.Params));
  Y := 6;
  for I := 0 to High(T.Params) do
  begin
    with TLabel.Create(ParamPanel) do begin Parent := ParamPanel; Caption := T.Params[I].Caption + ':'; SetBounds(8, Y + 4, 200, 18); end;
    if (T.Params[I].Kind = 'field') or (T.Params[I].Kind = 'choice') then
    begin
      Cb := TComboBox.Create(ParamPanel);
      Cb.Parent := ParamPanel;
      Cb.SetBounds(210, Y, 230, 26);
      Cb.Style := csDropDownList;
      if T.Params[I].Kind = 'field' then
      begin
        for J := 0 to High(Choices) do
        begin
          Ok := True;
          if T.Params[I].FType = 'num' then Ok := Choices[J].LType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber]
          else if T.Params[I].FType = 'date' then Ok := Choices[J].LType in [ltDate, ltDateTime, ltText, ltMemo]
          else if T.Params[I].FType = 'text' then Ok := Choices[J].LType in [ltText, ltMemo, ltInteger, ltDecimal, ltCurrency, ltAutoNumber];
          if Ok then Cb.Items.AddObject(Choices[J].Display, TObject(PtrInt(J)));
        end;
        if Cb.Items.Count = 0 then
          for J := 0 to High(Choices) do Cb.Items.AddObject(Choices[J].Display, TObject(PtrInt(J)));
        if Cb.Items.Count > 0 then Cb.ItemIndex := 0;
      end
      else
      begin
        Opts := TStringList.Create;
        try
          Opts.CommaText := T.Params[I].Options;
          Cb.Items.Assign(Opts);
        finally
          Opts.Free;
        end;
        Cb.ItemIndex := Cb.Items.IndexOf(T.Params[I].Default);
        if (Cb.ItemIndex < 0) and (Cb.Items.Count > 0) then Cb.ItemIndex := 0;
      end;
      Cb.OnChange := @ParamChange;
      ParamCtl[I] := Cb;
    end
    else
    begin
      Ed := TEdit.Create(ParamPanel);
      Ed.Parent := ParamPanel;
      Ed.SetBounds(210, Y, 230, 26);
      Ed.Text := T.Params[I].Default;
      Ed.OnChange := @ParamChange;
      ParamCtl[I] := Ed;
    end;
    Inc(Y, 32);
  end;
  Updating := True;
  try
    AliasEdit.Text := T.DefaultAlias;
  finally
    Updating := False;
  end;
  Manual := False;
  Rebuild;
end;

procedure TCalcDlg.ParamChange(Sender: TObject);
begin
  if not Updating then
  begin
    Manual := False;
    Rebuild;
  end;
end;

procedure TCalcDlg.Rebuild;
var
  T: TaCalcTemplate;
  V: TStringList;
  I: Integer;
  S: string;
begin
  if Current < 0 then Exit;
  T := Templates[Current];
  V := TStringList.Create;
  try
    for I := 0 to High(T.Params) do
    begin
      if ParamCtl[I] is TComboBox then
      begin
        S := TComboBox(ParamCtl[I]).Text;
        if (T.Params[I].Kind = 'field') and (TComboBox(ParamCtl[I]).ItemIndex >= 0) then
          S := Choices[PtrInt(TComboBox(ParamCtl[I]).Items.Objects[TComboBox(ParamCtl[I]).ItemIndex])].Value;
        V.Values[T.Params[I].Key] := S;
      end
      else V.Values[T.Params[I].Key] := TEdit(ParamCtl[I]).Text;
    end;
    Updating := True;
    try
      ExprMemo.Text := ExpandCalc(T, V);
    finally
      Updating := False;
    end;
  finally
    V.Free;
  end;
  UpdatePreview;
end;

procedure TCalcDlg.MemoChange(Sender: TObject);
begin
  if Updating then Exit;
  Manual := True;
  UpdatePreview;
end;

procedure TCalcDlg.BuilderClick(Sender: TObject);
var
  E: string;
begin
  E := ExprMemo.Text;
  if EditExpression(Form, Db, '', 'izraz', E) then
  begin
    ExprMemo.Text := E;
    Manual := True;
  end;
end;

procedure TCalcDlg.UpdatePreview;
var
  E, Sql, Err, Info: string;
  Des: TaQbeDesign;
  Q: TZQuery;
begin
  Preview.Items.Clear;
  SqlLbl.Caption := '';
  E := Trim(ExprMemo.Text);
  Status.Font.Color := clMaroon;
  if E = '' then begin Status.Caption := ''; Exit; end;
  Info := CheckExpr(E);
  if Info <> '' then begin Status.Caption := Tr('Expression: ') + Info; Exit; end;
  if not InQuery then
  begin
    Status.Font.Color := clGreen;
    Status.Caption := Tr('The expression is valid.');
    Exit;
  end;
  Des := TaQbeDesign.Create;
  try
    Des.Tables.Assign(Tables);
    Des.AddColumn(E, 'v');
    Des.Top := 6;
    if not BuildQbeSql(Db, Des, Sql, Err) then
    begin
      Status.Caption := Err;
      Exit;
    end;
    SqlLbl.Caption := StringReplace(Sql, LineEnding, ' ', [rfReplaceAll]);
    Q := Db.NewQuery(Sql);
    try
      try
        Q.Open;
        while not Q.EOF do
        begin
          if Q.Fields[0].IsNull then Preview.Items.Add('(prazno)') else Preview.Items.Add(Q.Fields[0].AsString);
          Q.Next;
        end;
        Status.Font.Color := clGreen;
        Status.Caption := Tr('The expression is valid; the first results are on the right.');
      except
        on Ex: Exception do Status.Caption := Tr('SQL: ') + Ex.Message;
      end;
    finally
      Q.Free;
    end;
  finally
    Des.Free;
  end;
end;

function RunCalcWizard(AOwner: TComponent; ADb: TAppDb; ATables: TStrings; AInQuery: Boolean;
  out AAlias, AExpr: string): Boolean;
var
  D: TCalcDlg;
  Seen: TStringList;
  I: Integer;

  procedure Lbl(const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := ACap; SetBounds(X, Y, 300, 18); end;
  end;

begin
  Result := False;
  AAlias := '';
  AExpr := '';
  D := TCalcDlg.Create;
  D.Db := ADb;
  D.Tables := ATables;
  D.InQuery := AInQuery;
  D.Templates := CalcTemplates;
  D.LoadChoices;
  Seen := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Calculated field wizard');
    D.Form.SetBounds(0, 0, 980, 660);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('Group'), 12, 10);
    D.Cats := TListBox.Create(D.Form); D.Cats.Parent := D.Form; D.Cats.SetBounds(12, 30, 140, 270);
    D.Cats.OnClick := @D.CatChange;
    Lbl(Tr('What do you want to calculate'), 164, 10);
    D.Tpls := TListBox.Create(D.Form); D.Tpls.Parent := D.Form; D.Tpls.SetBounds(164, 30, 270, 270);
    D.Tpls.OnClick := @D.TplChange;
    Lbl(Tr('Parameters'), 446, 10);
    D.ParamPanel := TPanel.Create(D.Form); D.ParamPanel.Parent := D.Form; D.ParamPanel.SetBounds(446, 30, 520, 270);
    D.ParamPanel.BevelOuter := bvLowered;
    Lbl(Tr('New field name:'), 12, 316);
    D.AliasEdit := TEdit.Create(D.Form); D.AliasEdit.Parent := D.Form; D.AliasEdit.SetBounds(12, 336, 240, 26);
    Lbl(Tr('Expression (you can edit it by hand):'), 12, 376);
    D.ExprMemo := TMemo.Create(D.Form); D.ExprMemo.Parent := D.Form; D.ExprMemo.SetBounds(12, 396, 700, 90);
    D.ExprMemo.OnChange := @D.MemoChange;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Expression builder...'); SetBounds(724, 396, 160, 28); OnClick := @D.BuilderClick; end;
    D.Status := TLabel.Create(D.Form); D.Status.Parent := D.Form; D.Status.SetBounds(12, 492, 700, 20);
    D.Status.Font.Style := [fsBold];
    if AInQuery then
    begin
      Lbl(Tr('Becomes SQL:'), 12, 518);
      D.SqlLbl := TLabel.Create(D.Form); D.SqlLbl.Parent := D.Form; D.SqlLbl.SetBounds(12, 538, 700, 60);
      D.SqlLbl.WordWrap := True; D.SqlLbl.Font.Name := 'DejaVu Sans Mono'; D.SqlLbl.Font.Size := 8;
      Lbl(Tr('First results:'), 724, 436);
      D.Preview := TListBox.Create(D.Form); D.Preview.Parent := D.Form; D.Preview.SetBounds(724, 456, 242, 140);
    end
    else
    begin
      D.SqlLbl := TLabel.Create(D.Form); D.SqlLbl.Parent := D.Form; D.SqlLbl.SetBounds(12, 538, 10, 10);
      D.Preview := TListBox.Create(D.Form); D.Preview.Parent := D.Form; D.Preview.SetBounds(724, 456, 10, 10);
      D.Preview.Visible := False;
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Add field'); ModalResult := mrOk; SetBounds(764, 612, 100, 32); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(870, 612, 96, 32); end;
    for I := 0 to High(D.Templates) do
      if (not AInQuery) or CalcWorksInQuery(D.Templates[I]) then
        if Seen.IndexOf(D.Templates[I].Category) < 0 then
        begin
          Seen.Add(D.Templates[I].Category);
          D.Cats.Items.Add(D.Templates[I].Category);
        end;
    if D.Cats.Items.Count > 0 then
    begin
      D.Cats.ItemIndex := 0;
      D.CatChange(nil);
    end;
    repeat
      if D.Form.ShowModal <> mrOk then Exit;
      AExpr := Trim(D.ExprMemo.Text);
      AAlias := Trim(D.AliasEdit.Text);
      if (AExpr = '') or (CheckExpr(AExpr) <> '') then
      begin
        ShowMessage(Tr('The expression is not valid: ') + CheckExpr(AExpr));
        Continue;
      end;
      if AAlias = '' then AAlias := 'Izracun';
      Result := True;
      Break;
    until False;
  finally
    Seen.Free;
    D.Form.Free;
    D.Free;
  end;
end;

end.
