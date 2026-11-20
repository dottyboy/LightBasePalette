{ This file was automatically created by Typhon IDE. Do not edit!
  This source is only used to compile and install the package.
 }

unit typhaccess_ext;

{$warn 5023 off : no warning about unused units}
interface

uses
  ta_ext_chart, ta_ext_grid, ta_ext_select, TyphonPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('typhaccess_ext', @Register);
end.
