unit ta_svg;
{ SVG slika -> PNG (za slike u izvjescima i formama; motor izvjesca prikazuje rasterske slike).
  Crta Image32 (pl_Image32), vektor se pretvara u sliku zadane sirine. }

{$mode objfpc}{$H+}

interface

{ je li niz bajtova SVG tekst (vektorska slika) }
function IsSvgBytes(const ABytes: string): Boolean;
{ PNG bajtovi iz SVG teksta, nacrtani u zadanoj sirini (u tockama) - tako vektor ostaje oštar na svakoj velicini }
function SvgTextToPng(const ASvg: string; AWidth: Integer): string;
{ sadrzaj SVG datoteke kao tekst (prazno ako nije SVG) }
function SvgFileToText(const AFile: string): string;
{ PNG bajtovi iz SVG datoteke; prazno ako se ne moze ucitati. AWidth = trazena sirina u tockama (visina prema omjeru) }
function SvgFileToPng(const AFile: string; AWidth: Integer = 512): string;

implementation

uses
  Classes, SysUtils, Img32, Img32.SVG.Reader, Img32.Fmt.PNG;

function IsSvgBytes(const ABytes: string): Boolean;
var
  H: string;
begin
  H := LowerCase(Copy(ABytes, 1, 400));
  Result := (Pos('<svg', H) > 0) and ((Copy(TrimLeft(H), 1, 1) = '<'));
end;

function SvgFileToText(const AFile: string): string;
var
  Fs: TFileStream;
begin
  Result := '';
  if not FileExists(AFile) then Exit;
  Fs := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Fs.Size);
    if Fs.Size > 0 then Fs.ReadBuffer(Result[1], Fs.Size);
  finally
    Fs.Free;
  end;
  if not IsSvgBytes(Result) then Result := '';
end;

function SvgFileToPng(const AFile: string; AWidth: Integer): string;
begin
  Result := SvgTextToPng(SvgFileToText(AFile), AWidth);
end;

function SvgTextToPng(const ASvg: string; AWidth: Integer): string;
var
  Rd: TSvgReader;
  Img: TImage32;
  Ms: TMemoryStream;
  W, H: Integer;
  Ratio: Double;
begin
  Result := '';
  if ASvg = '' then Exit;
  Rd := TSvgReader.Create;
  Img := TImage32.Create;
  Ms := TMemoryStream.Create;
  try
    try
      if not Rd.LoadFromString(ASvg) then Exit;
      Ratio := 1;
      if (Rd.RootElement <> nil) and (Rd.RootElement.viewboxWH.Width > 0) and (Rd.RootElement.viewboxWH.Height > 0) then
        Ratio := Rd.RootElement.viewboxWH.Height / Rd.RootElement.viewboxWH.Width;
      W := AWidth;
      if W < 16 then W := 16;
      if W > 4096 then W := 4096;
      H := Round(W * Ratio);
      if H < 1 then H := 1;
      Img.SetSize(W, H);
      Rd.DrawImage(Img, True);
      Img.SaveToStream(Ms, 'PNG');
      SetLength(Result, Ms.Size);
      if Ms.Size > 0 then Move(Ms.Memory^, Result[1], Ms.Size);
    except
      Result := '';
    end;
  finally
    Ms.Free;
    Img.Free;
    Rd.Free;
  end;
end;

end.
