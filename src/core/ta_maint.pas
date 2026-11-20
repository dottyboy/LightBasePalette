unit ta_maint;
{ Održavanje baze: sigurnosna kopija, provjera i sažimanje, te dokumentacija
  (opis tablica, polja, veza, upita, formi i izvješća kao HTML). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta;

{ Kopija cijele baze u jednu datoteku (VACUUM INTO). Prepisuje postojeću. }
function BackupDatabase(ADb: TAppDb; const ADest: string; out AError: string): Boolean;
{ Provjera cjelovitosti i sažimanje; AReport je opis za korisnika. }
function CheckAndCompact(ADb: TAppDb; ACompact: Boolean; out AReport: string): Boolean;
{ Cijela dokumentacija baze kao HTML. }
function DocumentDatabase(ADb: TAppDb): string;

implementation

uses
  contnrs, ta_types, ta_formdef, ta_reportdef, ta_tasks, ta_audit;

function FileBytes(const AFile: string): Int64;
var
  F: TFileStream;
begin
  Result := 0;
  if not FileExists(AFile) then Exit;
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    Result := F.Size;
  finally
    F.Free;
  end;
end;

function BackupDatabase(ADb: TAppDb; const ADest: string; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if Trim(ADest) = '' then begin AError := 'Nije zadana datoteka.'; Exit; end;
  if SameText(ExpandFileName(ADest), ExpandFileName(ADb.Conn.Database)) then
  begin AError := 'Kopija ne može prepisati otvorenu bazu.'; Exit; end;
  try
    ForceDirectories(ExtractFilePath(ExpandFileName(ADest)));
    if FileExists(ADest) then DeleteFile(ADest);
    ADb.Conn.ExecuteDirect('VACUUM INTO ' + ADb.QuoteLit(ADest));
    Result := True;
  except
    on E: Exception do AError := E.Message;
  end;
end;

function CheckAndCompact(ADb: TAppDb; ACompact: Boolean; out AReport: string): Boolean;
var
  Q: TZQuery;
  Msg, Fk: string;
  Before, After: Int64;
  N: Integer;
begin
  Result := False;
  AReport := '';
  if ADb.Kind = dkMaria then
  begin
    AReport := 'MariaDB: cjelovitost i veze među tablicama provjerava sam poslužitelj.';
    Exit(True);
  end;
  if ADb.Kind = dkPostgres then
  begin
    AReport := 'Postgres: cjelovitost i veze među tablicama provjerava sam poslužitelj.';
    if ACompact then
    begin
      ADb.Conn.ExecuteDirect('VACUUM ANALYZE');
      AReport := AReport + LineEnding + 'VACUUM ANALYZE izvršen.';
    end;
    Exit(True);
  end;
  Q := ADb.NewQuery('PRAGMA integrity_check');
  try
    Q.Open;
    Msg := '';
    while not Q.EOF do
    begin
      if Msg <> '' then Msg := Msg + '; ';
      Msg := Msg + Q.Fields[0].AsString;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  AReport := 'Cjelovitost: ' + Msg;
  Q := ADb.NewQuery('PRAGMA foreign_key_check');
  try
    Q.Open;
    N := 0;
    Fk := '';
    while not Q.EOF do
    begin
      Inc(N);
      if N <= 5 then Fk := Fk + LineEnding + '  ' + Q.Fields[0].AsString + ' redak ' + Q.Fields[1].AsString +
        ' -> ' + Q.Fields[2].AsString;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if N = 0 then AReport := AReport + LineEnding + 'Veze među tablicama: u redu.'
  else AReport := AReport + LineEnding + 'Veze među tablicama: ' + IntToStr(N) + ' redaka bez roditelja.' + Fk;
  if Msg <> 'ok' then Exit;
  if ACompact then
  begin
    Before := FileBytes(ADb.Conn.Database);
    try
      ADb.Conn.ExecuteDirect('VACUUM');
    except
      on E: Exception do begin AReport := AReport + LineEnding + 'Sažimanje nije uspjelo: ' + E.Message; Exit; end;
    end;
    After := FileBytes(ADb.Conn.Database);
    AReport := AReport + LineEnding + Format('Sažimanje: %d KB -> %d KB.', [Before div 1024, After div 1024]);
  end;
  Result := True;
end;

function IfThen2(ACond: Boolean; const AYes, ANo: string): string;
begin
  if ACond then Result := AYes else Result := ANo;
end;

function H(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function Cell(const S: string): string;
begin
  Result := '<td>' + H(S) + '</td>';
end;

function Head(const AItems: array of string): string;
var
  I: Integer;
begin
  Result := '<tr>';
  for I := 0 to High(AItems) do Result := Result + '<th>' + H(AItems[I]) + '</th>';
  Result := Result + '</tr>' + LineEnding;
end;

function DocumentDatabase(ADb: TAppDb): string;
var
  B: TStringList;
  Tables, Parts, Fks, Names: TStringList;
  Metas: TFPObjectList;
  T, I, J, K: Integer;
  Q: TZQuery;
  M: TaFieldMeta;
  Typ, Extra, Fk, Cap, Dflt: string;
  Rels: TaRelations;
  Fd: TaFormDef;
  Rd: TaReportDef;
  Tasks: TaTasks;
  Js: string;
begin
  B := TStringList.Create;
  try
    B.Add('<!doctype html><html><head><meta charset="utf-8"><title>Dokumentacija baze</title>');
    B.Add('<style>body{font-family:sans-serif;margin:24px;color:#222}h1{border-bottom:2px solid #1F4E9C}' +
      'h2{margin-top:32px;color:#1F4E9C}table{border-collapse:collapse;margin:8px 0}' +
      'th,td{border:1px solid #bbb;padding:3px 8px;text-align:left;font-size:13px}th{background:#eef3fa}' +
      'pre{background:#f6f6f6;padding:8px;font-size:12px;overflow:auto}.muted{color:#777}</style></head><body>');
    B.Add('<h1>Dokumentacija baze</h1>');
    B.Add('<p class="muted">' + H(ExtractFileName(ADb.Conn.Database)) + ' &middot; izrađeno ' +
      FormatDateTime('dd.mm.yyyy hh:nn', Now) + '</p>');
    Tables := ADb.UserTables;
    try
      B.Add('<h2>Tablice (' + IntToStr(Tables.Count) + ')</h2>');
      for T := 0 to Tables.Count - 1 do
      begin
        B.Add('<h3>' + H(Tables[T]) + '</h3>');
        Metas := ADb.LoadFieldMetas(Tables[T]);
        Fks := ADb.ForeignKeys(Tables[T]);
        Parts := TStringList.Create;
        Parts.Delimiter := '|';
        Parts.StrictDelimiter := True;
        try
          B.Add('<table>' + Head(['Polje', 'Tip', 'Ključ', 'Obavezno', 'Zadano', 'Veza', 'Oznaka', 'Opis / pravilo']));
          Q := ADb.TableInfo(Tables[T]);
          try
            while not Q.EOF do
            begin
              Typ := Q.FieldByName('type').AsString;
              M := nil;
              for J := 0 to Metas.Count - 1 do
                if SameText(TaFieldMeta(Metas[J]).FieldName, Q.FieldByName('name').AsString) then M := TaFieldMeta(Metas[J]);
              if M <> nil then
              begin
                Typ := LogicalNames[M.LType];
                if M.Format <> '' then Typ := Typ + ' (' + M.Format + ')';
              end;
              Fk := '';
              for K := 0 to Fks.Count - 1 do
              begin
                Parts.DelimitedText := Fks[K];
                if (Parts.Count >= 3) and SameText(Parts[0], Q.FieldByName('name').AsString) then
                  Fk := Parts[1] + '.' + Parts[2];
              end;
              Extra := '';
              Cap := '';
              Dflt := Q.FieldByName('dflt_value').AsString;
              if M <> nil then
              begin
                Cap := M.Caption;
                if M.DefaultExpr <> '' then Dflt := Dflt + M.DefaultExpr;
                if M.Description <> '' then Extra := M.Description;
                if M.Validation <> '' then
                begin
                  if Extra <> '' then Extra := Extra + ' | ';
                  Extra := Extra + 'pravilo: ' + M.Validation;
                end;
              end;
              B.Add('<tr>' + Cell(Q.FieldByName('name').AsString) + Cell(Typ) +
                Cell(IfThen2(Q.FieldByName('pk').AsInteger > 0, 'PK', '')) +
                Cell(IfThen2(Q.FieldByName('notnull').AsInteger > 0, 'da', '')) +
                Cell(Dflt) + Cell(Fk) + Cell(Cap) + Cell(Extra) + '</tr>');
              Q.Next;
            end;
          finally
            Q.Free;
          end;
          B.Add('</table>');
          Q := ADb.NewQuery('SELECT COUNT(*) FROM ' + ADb.QuoteId(Tables[T]));
          try
            Q.Open;
            B.Add('<p class="muted">Redaka: ' + Q.Fields[0].AsString + IfThen2(AuditEnabled(ADb, Tables[T]), ' &middot; prati se revizijskim tragom', '') + '</p>');
          finally
            Q.Free;
          end;
        finally
          Parts.Free;
          Fks.Free;
          Metas.Free;
        end;
      end;
      Rels := ADb.AllRelations;
      B.Add('<h2>Relacije (' + IntToStr(Length(Rels)) + ')</h2>');
      if Length(Rels) > 0 then
      begin
        B.Add('<table>' + Head(['Podređena tablica', 'Polje', 'Nadređena tablica', 'Polje', 'Pri brisanju']));
        for I := 0 to High(Rels) do
          B.Add('<tr>' + Cell(Rels[I].Child) + Cell(Rels[I].ChildCol) + Cell(Rels[I].Parent) + Cell(Rels[I].ParentCol) +
            Cell(Rels[I].OnDelete) + '</tr>');
        B.Add('</table>');
      end;
    finally
      Tables.Free;
    end;
    Names := ADb.ListObjects('_sys_queries');
    try
      B.Add('<h2>Upiti (' + IntToStr(Names.Count) + ')</h2>');
      for I := 0 to Names.Count - 1 do
      begin
        Js := ADb.LoadObject('_sys_queries', Names[I]);
        if Pos('/*QBE', Js) > 0 then Js := Trim(Copy(Js, 1, Pos('/*QBE', Js) - 1));
        B.Add('<h3>' + H(Names[I]) + '</h3><pre>' + H(Js) + '</pre>');
      end;
    finally
      Names.Free;
    end;
    Names := ADb.ListObjects('_sys_forms');
    try
      B.Add('<h2>Forme (' + IntToStr(Names.Count) + ')</h2>');
      if Names.Count > 0 then B.Add('<table>' + Head(['Forma', 'Izvor', 'Prikaz', 'Kontrola']));
      for I := 0 to Names.Count - 1 do
      begin
        Fd := TaFormDef.Create;
        try
          Fd.FromJson(ADb.LoadObject('_sys_forms', Names[I]));
          B.Add('<tr>' + Cell(Names[I]) + Cell(Fd.RecordSource) + Cell(Fd.ViewMode) + Cell(IntToStr(Fd.Count)) + '</tr>');
        finally
          Fd.Free;
        end;
      end;
      if Names.Count > 0 then B.Add('</table>');
    finally
      Names.Free;
    end;
    Names := ADb.ListObjects('_sys_reports');
    try
      B.Add('<h2>Izvješća (' + IntToStr(Names.Count) + ')</h2>');
      if Names.Count > 0 then B.Add('<table>' + Head(['Izvješće', 'Izvor', 'Grupira po', 'Elemenata']));
      for I := 0 to Names.Count - 1 do
      begin
        Rd := TaReportDef.Create;
        try
          Rd.FromJson(ADb.LoadObject('_sys_reports', Names[I]));
          B.Add('<tr>' + Cell(Names[I]) + Cell(Rd.RecordSource) + Cell(Rd.GroupField) + Cell(IntToStr(Rd.Count)) + '</tr>');
        finally
          Rd.Free;
        end;
      end;
      if Names.Count > 0 then B.Add('</table>');
    finally
      Names.Free;
    end;
    Names := ADb.ListObjects('_sys_macros');
    try
      B.Add('<h2>Makroi (' + IntToStr(Names.Count) + ')</h2><p>' + H(Names.CommaText) + '</p>');
    finally
      Names.Free;
    end;
    Names := ADb.ListObjects('_sys_modules');
    try
      B.Add('<h2>Moduli (' + IntToStr(Names.Count) + ')</h2><p>' + H(Names.CommaText) + '</p>');
    finally
      Names.Free;
    end;
    Tasks := LoadTasks(ADb);
    B.Add('<h2>Zadaci (' + IntToStr(Length(Tasks)) + ')</h2>');
    if Length(Tasks) > 0 then
    begin
      B.Add('<table>' + Head(['Zadatak', 'Vrsta', 'Raspored', 'Uključen']));
      for I := 0 to High(Tasks) do
        B.Add('<tr>' + Cell(Tasks[I].Name) + Cell(Tasks[I].Kind) + Cell(Tasks[I].Schedule) +
          Cell(IfThen2(Tasks[I].Enabled, 'da', 'ne')) + '</tr>');
      B.Add('</table>');
    end;
    B.Add('</body></html>');
    Result := B.Text;
  finally
    B.Free;
  end;
end;

end.
