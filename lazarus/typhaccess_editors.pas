{ This file was automatically created by Typhon IDE. Do not edit!
  This source is only used to compile and install the package.
 }

unit typhaccess_editors;

{$warn 5023 off : no warning about unused units}
interface

uses
  ta_anchoreditor, ta_appdlg, ta_auditdlg, ta_bizdlg, ta_blockedit, 
  ta_calcdlg, ta_catalogdlg, ta_companydlg, ta_crosstabdlg, ta_datatoolsdlg, 
  ta_exprbuilder, ta_fielddlg, ta_filestoredlg, ta_filterdlg, ta_importdlg, ta_paramdlg, ta_propdlgs, ta_querywiz, ta_wizardfgl_dlg, 
  ta_wizardformgrid_dlg, ta_wizards, ta_skelwizard, ta_blockdlg, ta_fglblockdlg, ta_editdlg, ta_lovdlg, ta_gendlg, 
  TyphonPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('typhaccess_editors', @Register);
end.
