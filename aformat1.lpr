program aformat1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, mainform, DM, LoginFrm, ListFrm, GetFileFrm, Blockfrm, CommonUnit,
  InputMemoFrm;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm1, MainForm1);
  Application.CreateForm(TDM1, DM1);
  Application.Run;

  //TODO: Удаление шаблона реализовать (DM1.DelTemplate)

  //TODO: запись в debug log всех событий
  //TODO: подготовка к форматированию: шаблон из БД -> в файл
  //TODO: обычным пользователям д.б видны ВСЕ проекты
  //TODO: Чистка мусора...
end.

