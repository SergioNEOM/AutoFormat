program aformat1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, mainform, DM, LoginFrm, ListFrm, GetFileFrm, ProjectFrm, CommonUnit,
  InputMemoFrm, Processing;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm1, MainForm1);
  Application.CreateForm(TDM1, DM1);
  Application.Run;
end.

