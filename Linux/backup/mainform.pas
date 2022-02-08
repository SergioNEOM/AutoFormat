unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, DM;

const
  AppHeader = 'Auto Format';

type

  TUserRec = class
    id     : integer;
    name   : string;
    super  : boolean;
    project: integer;
    public
      procedure Clear;
  end;

  { TMainForm1 }

  TMainForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    N2: TMenuItem;
    N1: TMenuItem;
    OpenPrjAction: TAction;
    NewPrjAction: TAction;
    ExitAppAction: TAction;
    ChangeUserAction: TAction;
    ActionList1: TActionList;
    ImageList1: TImageList;
    procedure ChangeUserActionExecute(Sender: TObject);
    procedure ExitAppActionExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OpenPrjActionExecute(Sender: TObject);
  private
    AppStarted : boolean;
    procedure FillConfig;
  public
    DBFile    : string;
    CurrentUser  : TUserRec;
    procedure ShowLogin;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses StrUtils, LCLType,
  LoginFrm, ListFrm;

procedure TUserRec.Clear;
begin
  id := -1;
  name := '';
  super := False;
  project := -1;
end;

//--------------------

procedure TMainForm1.FormCreate(Sender: TObject);
begin
  AppStarted:=True;
  CurrentUser := TUserRec.Create;
  CurrentUser.Clear;
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

procedure TMainForm1.FormShow(Sender: TObject);
begin
  if AppStarted then
  begin
    AppStarted:=False;
    FillConfig;
    //---
    DM1.DBConnect;
    //---
    ShowLogin;
  end;
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

procedure TMainForm1.FillConfig;
begin
  DBFile :=  Application.GetOptionValue('d','dbfile');
  if IsEmptyStr(DBFile,[' ']) then
    DBFile := ExtractFilePath(Application.ExeName)+ExtractFileName(Application.ExeName)+'.db';
  //
  DBFile:= ExpandFileName(DBFile);
  if not FileExists(DBFile) then
  begin
    Application.MessageBox('Не найден файл БД! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
    Close;
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

end.

