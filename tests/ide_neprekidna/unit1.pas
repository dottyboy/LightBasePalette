unit unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ta_components, ta_edit, ta_contcomp;

type
  TForm1 = class(TForm)
    aDatabase1: TaDatabase;
    aCont: TaContinuousForm;
    lblNaziv: TLabel;
    edtFilter: TaEdit;
    eNaziv: TaEdit;
    eGrad: TaEdit;
    eIznos: TaEdit;
    zBroj: TaEdit;
    zSum: TaEdit;
  end;

var
  Form1: TForm1;

implementation

{$R *.frm}

end.
