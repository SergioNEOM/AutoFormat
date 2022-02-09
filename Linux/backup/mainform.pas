unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, JSONPropStorage, IniPropStorage, DM, CommonUnit;

type

  { TMainForm1 }

  TMainForm1 = class(TForm)
    DelPrjAction: TAction;
    ClosePrjAction: TAction;
    FormatAction: TAction;
    ListBox1: TListBox;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    N3: TMenuItem;
    N1: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    N2: TMenuItem;
    OpenPrjAction: TAction;
    NewPrjAction: TAction;
    ExitAppAction: TAction;
    ChangeUserAction: TAction;
    ActionList1: TActionList;
    ActionImages: TImageList;
    procedure ChangeUserActionExecute(Sender: TObject);
    procedure ExitAppActionExecute(Sender: TObject);
    procedure FormatActionExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OpenPrjActionExecute(Sender: TObject);
  private
    AppStarted : boolean;
    function GetConfigFile : boolean;
    function GetConfigValues : boolean;
  public
    DBFile,
    ConfigFile   : string;
    CurrentUser  : TUserRec;
    CurrentBlock : TBlock;
    procedure ShowLogin;
    function Format(prj: integer; TargetFile: Widestring): boolean;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses StrUtils, LCLType, LoginFrm, ListFrm, GetFileFrm, IniFiles;


procedure TMainForm1.FormCreate(Sender: TObject);
begin
  AppStarted:=True;
  CurrentUser := TUserRec.Create;
  CurrentUser.Clear;
  CurrentBlock := TBlock.Create;
  CurrentBlock.Clear;
end;

procedure TMainForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if DM1.SQLite3Connection1.Connected  then
  begin
    if DM1.SQLTransaction1.Active then
    try
      DM1.SQLTransaction1.Commit;
    except
      DM1.SQLTransaction1.Rollback;
    end;
    DM1.SQLite3Connection1.Connected:=False;
  end;
  CanClose:=True;
end;


procedure TMainForm1.ChangeUserActionExecute(Sender: TObject);
begin
  CurrentUser.Clear;
  self.Caption:= AppHeader;
  ShowLogin;
end;

procedure TMainForm1.ExitAppActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm1.FormatActionExecute(Sender: TObject);
begin
  Format(1,ExpandFileName('Lorem ipsum.docx'));
end;

procedure TMainForm1.FormShow(Sender: TObject);
begin
  if AppStarted then
  begin
    AppStarted:=False; // no more pass
    //---
    if not GetConfigFile then
      with TGetFileForm1.Create(self) do
      try
        if ShowModal<>mrOK then
        begin
          Application.MessageBox('Не найден файл конфигурации! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
          Halt(999);
        end;
        ConfigFile:=FileNameEdit1.FileName;
      finally
        Free;
      end;
    //---
    if not GetConfigValues then
    begin
      Application.MessageBox('Недостаточно информации в файле конфигурации! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
      Halt(99);
    end;
    //---
    DM1.DBConnect;
    //---
    ShowLogin;
  end;
end;

function TMainForm1.GetConfigFile : boolean;
begin
  Result := False;
  ConfigFile :=  Application.GetOptionValue('c','config');
  if IsEmptyStr(ConfigFile,[' ']) then
    ConfigFile := ExtractFilePath(Application.ExeName)+ExtractFileName(Application.ExeName)+'.ini';
  //
  ConfigFile:= ExpandFileName(ConfigFile);
  if FileExists(ConfigFile) then Result := True;
end;

function TMainForm1.GetConfigValues : boolean;
var
  cofi : TIniFile;
begin
  Result := False;
  //---
  DBFile :=  Application.GetOptionValue('d','dbfile');
  if IsEmptyStr(DBFile,[' ']) or not FileExists(ExpandFileName(DBFile)) then
  begin
    // не передан как параметр или указан несуществующий файл БД, значит берем из конфиг-файла
    cofi := TIniFile.Create(ConfigFile);
    DBFile := ExpandFileName(cofi.ReadString('db','DBFile',''));
    if not FileExists(DBFile) then Exit;
  end;
  //...
  Result := True;
end;

procedure TMainForm1.OpenPrjActionExecute(Sender: TObject);
begin
  if CurrentUser.id <=0 then Exit;
  // prepare SQLQuery
  with DM1.SQLQuery1 do
  begin
    Close;
    SQL.Text:='SELECT * FROM projects where user_id=:u';
    ParamByName('u').Value:=CurrentUser.id;
    try
      Open;
    except
      Application.MessageBox('projects list error','ERROR',MB_ICONERROR+MB_OK);
    end;
  end;
  //--
  with TListForm1.Create(self,DM1.DataSource1,'Проекты',CurrentUser.project) do
  try
     if ShowModal = mrOk then
     begin
       CurrentUser.project:=DM1.DataSource1.DataSet.FieldByName('id').AsInteger;
       // project parameters...
     end;
  finally
    Free;
  end;
end;


procedure TMainForm1.ShowLogin;
begin
  with TLoginForm.Create(self) do
  try
    if ShowModal <> mrOK then Close; // exiting from app
    // CurrentUser was set in LoginForm
  finally
    Free;
  end;
  self.Caption:= AppHeader + ' : ' + CurrentUser.name;
  if CurrentUser.super then  self.Caption:= self.Caption + ' (***)';
end;


function TMainForm1.Format(prj: integer; TargetFile: WideString): boolean;
{const
  prefix = '{<block';
  suffix = '>}';}
begin
  ShowMessage('Format: '+TargetFile);
  Result := True;
end;


end.

