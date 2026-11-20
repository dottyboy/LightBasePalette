unit ta_reportview;
{ Report preview window, plus the exporters (HTML, PDF) and printing. All of
  them draw the same rendered item list produced by the engine. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics,
  Printers, fppdf, FPReadPNG, base64, ta_reportengine, ta_controls, ta_svg, ta_svgpdf, ta_tokens;

type

  { TaReportPreview }

  { prikaz izvjesca u zadanom poretku; poziva se pri promjeni poretka u pregledu }
  TSortRender = function(const AOption: string): TaRenderedReport of object;

  TaReportPreview = class(TForm)
  private
    FRep: TaRenderedReport;
    FPageNo: Integer;
    FZoom: Double;
    FBox: TPaintBox;
    FInfo: TLabel;
    FSortBox: TComboBox;
    FToolbar: TPanel;
    FSortRender: TSortRender;
    procedure SortChange(Sender: TObject);
    procedure BoxPaint(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure PreviewKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ExportClick(Sender: TObject);
    procedure UpdateInfo;
  public
    constructor CreatePreview(AOwner: TComponent; ARep: TaRenderedReport; const ATitle: string);
    destructor Destroy; override;
    { ponudeni poredci: popis u traci alata; promjena ponovo slaze izvjesce kroz ARender }
    procedure SetSortChoices(AChoices: TStrings; ASelected: Integer; ARender: TSortRender);
    function SortBoxForTest: TComboBox;
    function RenderedForTest: TaRenderedReport;
  end;

procedure PaintPage(ACanvas: TCanvas; APage: TaRPage; AScale: Double; AOffX, AOffY: Integer);
function ExportHtml(ARep: TaRenderedReport; const AFile: string): Boolean;
function ExportPdf(ARep: TaRenderedReport; const AFile: string; out AErr: string): Boolean;
procedure PrintReport(ARep: TaRenderedReport);

implementation

uses
  ta_i18n;




{ monospace u izvjescima: JetBrains Mono (isto slovo kao u programu; sirina znaka 0,6 em kao DejaVu Sans Mono) ako je dostupan }
function MonoFontName: string;
begin
  if FindThemeFontFile('JetBrainsMono-Regular.ttf') <> '' then Result := 'JetBrains Mono'
  else Result := 'DejaVu Sans Mono';
end;

const
  FontPx = 13;

function FontStyleOf(It: TaRItem): TFontStyles;
begin
  Result := [];
  if It.Bold then Include(Result, fsBold);
  if It.Italic then Include(Result, fsItalic);
  if It.Underline then Include(Result, fsUnderline);
end;

function ItemPx(It: TaRItem): Integer;
begin
  if It.FontPx > 0 then Result := It.FontPx else Result := FontPx;
end;

procedure PaintPage(ACanvas: TCanvas; APage: TaRPage; AScale: Double; AOffX, AOffY: Integer);
var
  I: Integer;
  It: TaRItem;
  R: TRect;
  St: TTextStyle;
  Pic: TPicture;
  Bw: Integer;
  PlainName: string;
begin
  PlainName := ACanvas.Font.Name;
  for I := 0 to APage.Items.Count - 1 do
  begin
    It := TaRItem(APage.Items[I]);
    R := Rect(AOffX + Round(It.X * AScale), AOffY + Round(It.Y * AScale),
      AOffX + Round((It.X + It.W) * AScale), AOffY + Round((It.Y + It.H) * AScale));
    if It.Kind = 'Line' then
    begin
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := TColor(It.Color);
      ACanvas.FillRect(R.Left, R.Top, R.Right, R.Bottom + 1);
    end
    else if It.Kind = 'Frame' then
    begin
      if It.Fill >= 0 then
      begin
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Brush.Color := TColor(It.Fill);
        ACanvas.FillRect(R.Left, R.Top, R.Right, R.Bottom);
      end;
      if It.Border > 0 then
      begin
        Bw := Max(1, Round(It.Border * AScale));
        ACanvas.Brush.Style := bsClear;
        ACanvas.Pen.Style := psSolid;
        ACanvas.Pen.Color := TColor(It.Color);
        ACanvas.Pen.Width := Bw;
        ACanvas.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
        ACanvas.Pen.Width := 1;
      end;
    end
    else if It.Kind = 'Image' then
    begin
      if It.PicBytes = '' then Continue;
      Pic := TPicture.Create;
      try
        if LoadPictureSized(Pic, It.PicBytes, Max(16, R.Right - R.Left)) then
        begin
          if SameText(It.Fmt, 'stretch') then ACanvas.StretchDraw(R, Pic.Graphic)
          else if SameText(It.Fmt, 'clip') then ACanvas.Draw(R.Left, R.Top, Pic.Graphic)
          else
          begin
            { zoom: keep the proportions inside the box }
            Bw := Round(Min((R.Right - R.Left) / Max(1, Pic.Width), (R.Bottom - R.Top) / Max(1, Pic.Height)) * Pic.Width);
            ACanvas.StretchDraw(Rect(R.Left, R.Top, R.Left + Bw,
              R.Top + Round(Bw * Pic.Height / Max(1, Pic.Width))), Pic.Graphic);
          end;
        end;
      finally
        Pic.Free;
      end;
    end
    else if It.Text <> '' then
    begin
      if It.Fill >= 0 then
      begin
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Brush.Color := TColor(It.Fill);
        ACanvas.FillRect(R.Left, R.Top, R.Right, R.Bottom);
      end;
      ACanvas.Brush.Style := bsClear;
      if It.Mono then ACanvas.Font.Name := MonoFontName
      else if It.FontName <> '' then ACanvas.Font.Name := It.FontName
      else ACanvas.Font.Name := PlainName;
      ACanvas.Font.Color := TColor(It.Color);
      ACanvas.Font.Height := -Round(ItemPx(It) * AScale);
      ACanvas.Font.Style := FontStyleOf(It);
      FillChar(St, SizeOf(St), 0);
      St.SingleLine := True;
      St.Clipping := True;
      St.Layout := tlCenter;
      if SameText(It.Align, 'right') then St.Alignment := taRightJustify
      else if SameText(It.Align, 'center') then St.Alignment := taCenter
      else St.Alignment := taLeftJustify;
      ACanvas.TextRect(R, R.Left, R.Top, It.Text, St);
    end;
  end;
end;

{ ---- HTML ---- }

function HtmlEsc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function Rgb(C: Integer): string;
var
  V: Integer;
begin
  V := ColorToRGB(TColor(C));
  Result := '#' + IntToHex(V and $FF, 2) + IntToHex((V shr 8) and $FF, 2) + IntToHex((V shr 16) and $FF, 2);
end;

function MimeOf(const B: string): string;
begin
  if IsSvgBytes(B) then Result := 'image/svg+xml'
  else if Copy(B, 1, 4) = #137'PNG' then Result := 'image/png'
  else if Copy(B, 1, 2) = #255#216 then Result := 'image/jpeg'
  else if Copy(B, 1, 3) = 'GIF' then Result := 'image/gif'
  else Result := 'image/bmp';
end;

function ExportHtml(ARep: TaRenderedReport; const AFile: string): Boolean;
var
  L: TStringList;
  P, I: Integer;
  It: TaRItem;
  A, Style, Txt, Fit: string;
begin
  L := TStringList.Create;
  try
    L.Add('<!doctype html><html><head><meta charset="utf-8"><style>');
    L.Add('body{margin:0;background:#888}.pg{position:relative;width:'+IntToStr(ARep.PageW)+'px;height:'+IntToStr(ARep.PageH)+'px;background:#fff;');
    L.Add('margin:12px auto;font:13px "DejaVu Sans",Arial,sans-serif;page-break-after:always;overflow:hidden}');
    L.Add('.t{position:absolute;white-space:nowrap;overflow:hidden;display:flex;align-items:center}');
    L.Add('.l{position:absolute}.t a{color:inherit}');
    L.Add('@media print{body{background:#fff}.pg{margin:0}}</style></head><body>');
    for P := 0 to ARep.PageCount - 1 do
    begin
      L.Add('<div class="pg">');
      for I := 0 to ARep.Page(P).Items.Count - 1 do
      begin
        It := TaRItem(ARep.Page(P).Items[I]);
        Style := Format('left:%dpx;top:%dpx;width:%dpx;height:%dpx', [It.X, It.Y, It.W, It.H]);
        if It.Kind = 'Line' then
          L.Add(Format('<div class="l" style="%s;background:%s"></div>', [Style, Rgb(It.Color)]))
        else if It.Kind = 'Frame' then
        begin
          A := '';
          if It.Fill >= 0 then A := ';background:' + Rgb(It.Fill);
          if It.Border > 0 then A := A + Format(';border:%dpx solid %s;box-sizing:border-box', [It.Border, Rgb(It.Color)]);
          L.Add(Format('<div class="l" style="%s%s"></div>', [Style, A]));
        end
        else if It.Kind = 'Image' then
        begin
          if It.PicBytes <> '' then
          begin
            if SameText(It.Fmt, 'stretch') then Fit := 'fill'
            else if SameText(It.Fmt, 'clip') then Fit := 'none'
            else Fit := 'contain';
            L.Add(Format('<img class="l" style="%s;object-fit:%s" src="data:%s;base64,%s">',
              [Style, Fit, MimeOf(It.PicBytes), EncodeStringBase64(It.PicBytes)]));
          end;
        end
        else if It.Text <> '' then
        begin
          if SameText(It.Align, 'right') then A := 'justify-content:flex-end'
          else if SameText(It.Align, 'center') then A := 'justify-content:center'
          else A := 'justify-content:flex-start';
          if It.Bold then A := A + ';font-weight:bold';
          if It.Italic then A := A + ';font-style:italic';
          if It.Underline then A := A + ';text-decoration:underline';
          if It.Fill >= 0 then A := A + ';background:' + Rgb(It.Fill);
          if It.FontPx > 0 then A := A + ';font-size:' + IntToStr(It.FontPx) + 'px';
          A := A + ';color:' + Rgb(It.Color);
          Txt := HtmlEsc(It.Text);
          if It.Address <> '' then Txt := '<a href="' + HtmlEsc(It.Address) + '">' + Txt + '</a>';
          L.Add(Format('<div class="t" style="%s;%s">%s</div>', [Style, A, Txt]));
        end;
      end;
      L.Add('</div>');
    end;
    L.Add('</body></html>');
    L.SaveToFile(AFile);
    Result := True;
  finally
    L.Free;
  end;
end;

{ ---- PDF ---- }

function FindFontDir: string;
const
  Dirs: array[0..2] of string = (
    '/usr/share/fonts/truetype/dejavu/', '/usr/share/fonts/dejavu/', '/usr/share/fonts/TTF/');
var
  D: string;
begin
  for D in Dirs do
    if FileExists(D + 'DejaVuSans.ttf') and FileExists(D + 'DejaVuSans-Bold.ttf') then Exit(D);
  Result := '';
end;

function PdfColor(C: Integer): TARGBColor;
var
  V: Integer;
begin
  V := ColorToRGB(TColor(C));
  Result := ((V and $FF) shl 16) or (V and $FF00) or ((V shr 16) and $FF);
end;

function ExportPdf(ARep: TaRenderedReport; const AFile: string; out AErr: string): Boolean;
const
  Mm = 25.4 / 96;
var
  Doc: TPDFDocument;
  Sec: TPDFSection;
  Pg: TPDFPage;
  Pp: TPDFPaper;
  Dir, MonoFile: string;
  FReg, FBold, FObl, FBoldObl, FMono, FSel, P, I, Img: Integer;
  It: TaRItem;
  Bmp: TBitmap;
  X, Y, W, Hh, Px, Sc: Double;
  Pic: TPicture;
  Png: TPortableNetworkGraphic;
  Ms: TMemoryStream;
begin
  Result := False;
  AErr := '';
  Dir := FindFontDir;
  if Dir = '' then begin AErr := Tr('The DejaVu Sans font was not found.'); Exit; end;
  Doc := TPDFDocument.Create(nil);
  Bmp := TBitmap.Create;
  try
    try
      Bmp.Canvas.Font.Name := 'DejaVu Sans';
      Doc.Options := [poPageOriginAtTop, poSubsetFont, poCompressFonts];
      Doc.StartDocument;
      FReg := Doc.AddFont(Dir + 'DejaVuSans.ttf', 'DejaVuSans');
      FBold := Doc.AddFont(Dir + 'DejaVuSans-Bold.ttf', 'DejaVuSans-Bold');
      FObl := FReg;
      FBoldObl := FBold;
      if FileExists(Dir + 'DejaVuSans-Oblique.ttf') then FObl := Doc.AddFont(Dir + 'DejaVuSans-Oblique.ttf', 'DejaVuSans-Oblique');
      if FileExists(Dir + 'DejaVuSans-BoldOblique.ttf') then FBoldObl := Doc.AddFont(Dir + 'DejaVuSans-BoldOblique.ttf', 'DejaVuSans-BoldOblique');
      FMono := -1;
      MonoFile := FindThemeFontFile('JetBrainsMono-Regular.ttf');
      if MonoFile <> '' then FMono := Doc.AddFont(MonoFile, 'JetBrainsMono')
      else if FileExists(Dir + 'DejaVuSansMono.ttf') then FMono := Doc.AddFont(Dir + 'DejaVuSansMono.ttf', 'DejaVuSansMono');
      Sec := Doc.Sections.AddSection;
      for P := 0 to ARep.PageCount - 1 do
      begin
        Pg := Doc.Pages.AddPage;
        if (ARep.PageW = DefPageW) and (ARep.PageH = DefPageH) then Pg.PaperType := ptA4
        else
        begin
          Pp := Pg.Paper;
          Pp.W := Round(ARep.PageW * 0.75);   { papir je u tockama (1 px = 0,75 pt) }
          Pp.H := Round(ARep.PageH * 0.75);
          Pp.Printable.L := 0; Pp.Printable.T := 0; Pp.Printable.R := 0; Pp.Printable.B := 0;
          Pg.PaperType := ptCustom;
          Pg.Paper := Pp;
        end;
        Pg.UnitOfMeasure := uomMillimeters;
        Sec.AddPage(Pg);
        for I := 0 to ARep.Page(P).Items.Count - 1 do
        begin
          It := TaRItem(ARep.Page(P).Items[I]);
          if It.Kind = 'Line' then
          begin
            Pg.SetColor(PdfColor(It.Color), True);
            Y := (It.Y + It.H / 2) * Mm;
            Pg.DrawLine(It.X * Mm, Y, (It.X + It.W) * Mm, Y, Max(It.H * Mm, 0.1));
          end
          else if It.Kind = 'Frame' then
          begin
            if It.Fill >= 0 then Pg.SetColor(PdfColor(It.Fill), False);
            Pg.SetColor(PdfColor(It.Color), True);
            Pg.DrawRect(It.X * Mm, (It.Y + It.H) * Mm, It.W * Mm, It.H * Mm,
              Max(It.Border * Mm, 0.1), It.Fill >= 0, It.Border > 0);
          end
          else if It.Kind = 'Image' then
          begin
            if It.PicBytes = '' then Continue;
            { vektor ostaje vektor; sto se ne moze prevesti, ide kao slika od 300 tocaka }
            if IsSvgBytes(It.PicBytes) and PdfDrawSvg(Pg, It.PicBytes, It.X * Mm, It.Y * Mm, It.W * Mm, It.H * Mm, SameText(It.Fmt, 'stretch')) then Continue;
            Pic := TPicture.Create;
            Png := TPortableNetworkGraphic.Create;
            Ms := TMemoryStream.Create;
            try
              if LoadPictureSized(Pic, It.PicBytes, Round(It.W * 300 / 96)) then
              begin
                Png.Assign(Pic.Graphic);
                Png.SaveToStream(Ms);
                Ms.Position := 0;
                Img := Doc.Images.AddFromStream(Ms, TFPReaderPNG, False);
                W := It.W; Hh := It.H;
                if not (SameText(It.Fmt, 'stretch') or SameText(It.Fmt, 'clip')) then
                begin
                  Sc := Min(It.W / Max(1, Pic.Width), It.H / Max(1, Pic.Height));
                  W := Pic.Width * Sc;
                  Hh := Pic.Height * Sc;
                end;
                Pg.DrawImage(It.X * Mm, (It.Y + Hh) * Mm, W * Mm, Hh * Mm, Img);
              end;
            finally
              Ms.Free;
              Png.Free;
              Pic.Free;
            end;
          end
          else if It.Text <> '' then
          begin
            if It.Fill >= 0 then
            begin
              Pg.SetColor(PdfColor(It.Fill), False);
              Pg.DrawRect(It.X * Mm, (It.Y + It.H) * Mm, It.W * Mm, It.H * Mm, 0.1, True, False);
            end;
            if It.Bold and It.Italic then FSel := FBoldObl
            else if It.Bold then FSel := FBold
            else if It.Italic then FSel := FObl
            else FSel := FReg;
            if It.Mono and (FMono >= 0) then FSel := FMono;
            Px := ItemPx(It);
            Pg.SetFont(FSel, Px * 0.75);
            Pg.SetColor(PdfColor(It.Color), False);
            Bmp.Canvas.Font.Height := -Round(Px);
            Bmp.Canvas.Font.Style := FontStyleOf(It);
            W := Bmp.Canvas.TextWidth(It.Text) * Mm;
            X := It.X * Mm;
            if SameText(It.Align, 'right') then X := (It.X + It.W) * Mm - W
            else if SameText(It.Align, 'center') then X := (It.X + It.W / 2) * Mm - W / 2;
            Y := (It.Y + It.H / 2 + Px * 0.35) * Mm;
            Pg.WriteText(X, Y, It.Text, 0, It.Underline);
          end;
        end;
      end;
      Doc.SaveToFile(AFile);
      Result := True;
    except
      on E: Exception do AErr := E.Message;
    end;
  finally
    Bmp.Free;
    Doc.Free;
  end;
end;

{ ---- printing ---- }

procedure PrintReport(ARep: TaRenderedReport);
var
  P: Integer;
  Sc: Double;
begin
  Printer.BeginDoc;
  try
    Sc := Printer.PageWidth / ARep.PageW;
    for P := 0 to ARep.PageCount - 1 do
    begin
      if P > 0 then Printer.NewPage;
      PaintPage(Printer.Canvas, ARep.Page(P), Sc, 0, 0);
    end;
  finally
    Printer.EndDoc;
  end;
end;

{ ---- preview window ---- }

procedure TaReportPreview.PreviewKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 27) and (Shift = []) then begin Key := 0; Close; end;
end;

constructor TaReportPreview.CreatePreview(AOwner: TComponent; ARep: TaRenderedReport; const ATitle: string);
var
  Tb: TPanel;
  Sb: TScrollBox;
  X, I: Integer;
  B: TButton;
const
  Caps: array[0..8] of string = ('|<', '<', '>', '>|', '-', '+', 'PDF', 'HTML', 'Ispis');
begin
  inherited CreateNew(AOwner);
  FRep := ARep;
  FZoom := 1.0;
  Caption := Tr('Preview: ') + ATitle;
  KeyPreview := True;
  OnKeyDown := @PreviewKey;
  SetBounds(0, 0, 900, 760);
  Position := poScreenCenter;
  Tb := TPanel.Create(Self);
  Tb.Parent := Self;
  Tb.Align := alTop;
  Tb.Height := 38;
  Tb.BevelOuter := bvNone;
  FToolbar := Tb;
  X := 6;
  for I := 0 to High(Caps) do
  begin
    B := TButton.Create(Self);
    B.Parent := Tb;
    B.Caption := Caps[I];
    B.Tag := I;
    B.SetBounds(X, 6, 58, 26);
    if I < 6 then B.OnClick := @NavClick else B.OnClick := @ExportClick;
    Inc(X, 62);
  end;
  FInfo := TLabel.Create(Self);
  FInfo.Parent := Tb;
  FInfo.SetBounds(X + 10, 12, 200, 18);
  Sb := TScrollBox.Create(Self);
  Sb.Parent := Self;
  Sb.Align := alClient;
  Sb.Color := clGray;
  FBox := TPaintBox.Create(Self);
  FBox.Parent := Sb;
  FBox.OnPaint := @BoxPaint;
  UpdateInfo;
end;

destructor TaReportPreview.Destroy;
begin
  FRep.Free;
  inherited Destroy;
end;

procedure TaReportPreview.SetSortChoices(AChoices: TStrings; ASelected: Integer; ARender: TSortRender);
var
  L: TLabel;
begin
  if (AChoices = nil) or (AChoices.Count = 0) or not Assigned(ARender) then Exit;
  FSortRender := ARender;
  L := TLabel.Create(Self);
  L.Parent := FToolbar;
  L.Caption := Tr('Order:');
  L.SetBounds(FInfo.Left + 215, 12, 60, 18);
  FSortBox := TComboBox.Create(Self);
  FSortBox.Parent := FToolbar;
  FSortBox.Style := csDropDownList;
  FSortBox.SetBounds(FInfo.Left + 275, 6, 190, 26);
  FSortBox.Items.Assign(AChoices);
  if (ASelected >= 0) and (ASelected < AChoices.Count) then FSortBox.ItemIndex := ASelected else FSortBox.ItemIndex := -1;
  FSortBox.OnChange := @SortChange;
end;

function TaReportPreview.RenderedForTest: TaRenderedReport;
begin
  Result := FRep;
end;

function TaReportPreview.SortBoxForTest: TComboBox;
begin
  Result := FSortBox;
end;

procedure TaReportPreview.SortChange(Sender: TObject);
var
  Rep: TaRenderedReport;
begin
  if not Assigned(FSortRender) then Exit;
  Rep := FSortRender(FSortBox.Text);
  if Rep = nil then Exit;
  FRep.Free;
  FRep := Rep;
  FPageNo := 0;
  UpdateInfo;
end;

procedure TaReportPreview.UpdateInfo;
begin
  FBox.SetBounds(12, 12, Round(FRep.PageW * FZoom), Round(FRep.PageH * FZoom));
  FInfo.Caption := Format(Tr('Page %d / %d   (%d%%)'), [FPageNo + 1, FRep.PageCount, Round(FZoom * 100)]);
  FBox.Invalidate;
end;

procedure TaReportPreview.BoxPaint(Sender: TObject);
begin
  FBox.Canvas.Brush.Color := clWhite;
  FBox.Canvas.FillRect(0, 0, FBox.Width, FBox.Height);
  if FRep.PageCount > 0 then PaintPage(FBox.Canvas, FRep.Page(FPageNo), FZoom, 0, 0);
end;

procedure TaReportPreview.NavClick(Sender: TObject);
begin
  case TButton(Sender).Tag of
    0: FPageNo := 0;
    1: if FPageNo > 0 then Dec(FPageNo);
    2: if FPageNo < FRep.PageCount - 1 then Inc(FPageNo);
    3: FPageNo := FRep.PageCount - 1;
    4: if FZoom > 0.5 then FZoom := FZoom - 0.25;
    5: if FZoom < 2.0 then FZoom := FZoom + 0.25;
  end;
  UpdateInfo;
end;

procedure TaReportPreview.ExportClick(Sender: TObject);
var
  D: TSaveDialog;
  Err: string;
begin
  case TButton(Sender).Tag of
    6, 7:
      begin
        D := TSaveDialog.Create(nil);
        try
          if TButton(Sender).Tag = 6 then
          begin
            D.Filter := 'PDF (*.pdf)|*.pdf'; D.DefaultExt := 'pdf';
          end
          else
          begin
            D.Filter := 'HTML (*.html)|*.html'; D.DefaultExt := 'html';
          end;
          if not D.Execute then Exit;
          if TButton(Sender).Tag = 6 then
          begin
            if ExportPdf(FRep, D.FileName, Err) then ShowMessage(Tr('Saved: ') + D.FileName)
            else ShowMessage(Tr('PDF failed: ') + Err);
          end
          else if ExportHtml(FRep, D.FileName) then ShowMessage(Tr('Saved: ') + D.FileName);
        finally
          D.Free;
        end;
      end;
    8:
      try
        PrintReport(FRep);
      except
        on E: Exception do ShowMessage(Tr('Printing failed: ') + E.Message);
      end;
  end;
end;

end.
